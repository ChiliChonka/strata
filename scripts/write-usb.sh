#!/bin/bash
# Write a Strata ISO to a USB device, with guards.
#
# MVP.md step 3 is "write it to USB", and a bare dd is a poor way to document
# that. The reason is concrete rather than theoretical: on the machine this was
# developed on, the running system lives on /dev/sda — an external USB SSD —
# while the USB stick is /dev/sdd. "USB means removable" is not a safe rule, and
# device letters move when things are replugged.
#
# So this refuses to write to anything that is not flagged removable, anything
# that currently backs a mounted system directory, and requires the device name
# to be typed out.
#
# Usage:
#   sudo ./scripts/write-usb.sh strata-YYYY.MM.DD-amd64.iso /dev/sdX
#   sudo ./scripts/write-usb.sh --persistent strata-...iso /dev/sdX
#
# Without --persistent a live session's writable layer is RAM, so the space on
# the stick past the image is unreachable and nothing installed survives a
# reboot. With it, the leftover space becomes a partition live-boot unions over
# the read-only system.

set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> WARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --persistent adds a second partition covering the space the image leaves
# unused, so installs in a live session survive a reboot. Without it a 512 GB
# stick still gives a live session only as much room as it has RAM.
persistent=0
args=()
for a in "$@"; do
	case "$a" in
		--persistent) persistent=1 ;;
		*)            args+=("$a") ;;
	esac
done
set -- "${args[@]}"

[[ $# -eq 2 ]] || die "Usage: sudo $0 [--persistent] <image.iso> /dev/sdX"
iso="$1"; dev="$2"

[[ $EUID -eq 0 ]] || die "Writing to a block device needs root. Re-run with sudo."
[[ -f "$iso" ]] || die "No such image: $iso"
[[ -b "$dev" ]] || die "$dev is not a block device."

name="$(basename "$dev")"
[[ -d "/sys/block/${name}" ]] || die "$dev is a partition, not a whole disk. Pass /dev/sdX, not /dev/sdX1."

# --- Guard 1: removable ----------------------------------------------------

removable="$(cat "/sys/block/${name}/removable" 2>/dev/null || echo 0)"
[[ "$removable" == "1" ]] || die "$dev is not flagged removable. Refusing."

# --- Guard 2: not backing anything mounted that matters --------------------

for mnt in / /boot /boot/efi /home; do
	src="$(findmnt -no SOURCE --target "$mnt" 2>/dev/null || true)"
	[[ -n "$src" ]] || continue
	holder="$(lsblk -no PKNAME "$src" 2>/dev/null || true)"
	[[ -z "$holder" ]] && holder="$(basename "$src")"
	if [[ "/dev/${holder}" == "$dev" || "$src" == "$dev"* ]]; then
		die "$dev currently backs $mnt. Refusing, emphatically."
	fi
done

# --- Show what is about to be destroyed ------------------------------------

model="$(lsblk -dno MODEL "$dev" | xargs)"
serial="$(lsblk -dno SERIAL "$dev" | xargs)"
size="$(lsblk -dno SIZE "$dev" | xargs)"

echo
log "About to OVERWRITE this device, destroying everything on it:"
printf '      device: %s\n      model:  %s\n      serial: %s\n      size:   %s\n' \
	"$dev" "${model:-unknown}" "${serial:-unknown}" "$size"
echo
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS "$dev" | sed 's/^/      /'
echo
log "Writing: $(basename "$iso") ($(du -h "$iso" | cut -f1))"
echo

printf '  Type the device name (%s) to confirm, anything else to abort: ' "$name"
read -r answer
[[ "$answer" == "$name" ]] || die "Aborted."

# --- Unmount ---------------------------------------------------------------

while read -r part; do
	[[ -n "$part" ]] || continue
	if findmnt -no TARGET "$part" >/dev/null 2>&1; then
		log "Unmounting $part"
		umount "$part" || die "Could not unmount $part"
	fi
done < <(lsblk -lno PATH "$dev" | tail -n +2)

# --- Write -----------------------------------------------------------------

log "Writing. Do not unplug."
dd if="$iso" of="$dev" bs=4M status=progress oflag=sync conv=fsync
sync

# --- Verify ----------------------------------------------------------------
#
# dd reporting success is not proof: a failing stick can accept writes and
# return different bytes on read. Compare what is actually on the device.

log "Verifying by reading back"
iso_size="$(stat -c %s "$iso")"
iso_sum="$(sha256sum "$iso" | cut -d' ' -f1)"
dev_sum="$(head -c "$iso_size" "$dev" | sha256sum | cut -d' ' -f1)"

if [[ "$iso_sum" == "$dev_sum" ]]; then
	log "Verified: the device matches the image."
else
	die "MISMATCH. The device does not contain the image that was written.
     image:  $iso_sum
     device: $dev_sum
     Do not boot this stick. Try another one, or another port."
fi

# --- Persistence -----------------------------------------------------------
#
# The image is written with dd, so the stick's partition table is the image's:
# everything past the image is unallocated, and a 512 GB stick carries a 1.6 GB
# system with nowhere to put anything. Worse, a live session's writable layer is
# RAM, so installing a browser competes with the browser's own memory.
#
# A partition labelled "persistence" holding a persistence.conf that says
# "/ union" is what live-boot looks for. It is created after the image, in the
# space the image did not use.

if [[ "$persistent" == "1" ]]; then
	log "Adding a persistence partition in the remaining space"

	# The image's own table ends somewhere; ask the kernel rather than guess.
	partprobe "$dev" 2>/dev/null || true
	sleep 1
	last_end="$(sfdisk -l -o End "$dev" 2>/dev/null | grep -E '^ *[0-9]+$' | sort -n | tail -1)"
	[[ -n "$last_end" ]] || die "Could not read the partition table written by the image"

	start=$(( last_end + 1 ))
	total="$(blockdev --getsz "$dev")"
	free_mb=$(( (total - start) / 2048 ))
	[[ "$free_mb" -gt 256 ]] || die "Only ${free_mb} MB left after the image — too little to be useful"

	log "Creating a ${free_mb} MB persistence partition"
	sfdisk --append --no-reread --force "$dev" <<-EOF
		${start},,L
	EOF
	partprobe "$dev" 2>/dev/null || true
	sleep 2

	newpart="$(lsblk -lno PATH "$dev" | tail -1)"
	[[ -b "$newpart" ]] || die "The new partition did not appear as a device"

	mkfs.ext4 -q -L persistence "$newpart" || die "Could not format $newpart"

	mnt="$(mktemp -d)"
	mount "$newpart" "$mnt" || die "Could not mount the new partition"
	printf '/ union\n' > "${mnt}/persistence.conf"
	sync
	umount "$mnt"
	rmdir "$mnt"

	log "Persistence ready: ${free_mb} MB that survives a reboot"
fi

log "Done. Eject with: udisksctl power-off -b $dev"
