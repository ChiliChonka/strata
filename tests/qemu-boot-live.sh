#!/bin/bash
# Boot the live ISO in a window, to use by hand.
#
# The counterpart to qemu-check-live.sh, which runs the same image headless and
# asserts on text. This one is for looking and clicking: seeing whether something
# renders, whether a menu behaves, whether the bar changes when a component is
# installed.
#
# Nothing is installed to disk and no disk is attached, so this cannot damage
# anything. Secure Boot is enforced exactly as in the automated tests.
#
# Usage:
#   ./tests/qemu-boot-live.sh [image.iso]
#
# Once inside, SUPER+Return opens a terminal. Worth trying:
#
#   strata list                    what can be installed
#   strata install diagnostics     watch a bar element appear
#   strata doctor                  the diagnostic summary
#   browser                        explains how to get one

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
cd "$REPO_ROOT"

readonly OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.secboot.fd"
readonly OVMF_VARS="/usr/share/OVMF/OVMF_VARS_4M.ms.fd"

die() { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

readonly LOCKFILE="/tmp/strata-qemu-install-test.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
	printf '\033[1;31m==> ERROR:\033[0m another Strata VM is running.\n' >&2
	printf '    Held by: %s\n' "$(fuser "$LOCKFILE" 2>&1 | tr -s ' ' || echo unknown)" >&2
	printf '    An automated test run finishes on its own; wait for it with:\n' >&2
	printf '      flock %s true && echo free\n' "$LOCKFILE" >&2
	exit 1
fi

iso="${1:-}"
if [[ -z "$iso" ]]; then
	shopt -s nullglob
	c=( strata-*.iso ); [[ ${#c[@]} -gt 0 ]] || die "No strata-*.iso found. Build one first."
	iso="${c[-1]}"
fi
[[ -f "$iso" ]] || die "No such image: $iso"
[[ -f "$OVMF_CODE" ]] || die "$OVMF_CODE missing. apt install ovmf"

wd="$(mktemp -d /tmp/qbX.XXXX)"
trap 'rm -rf "$wd"' EXIT
cp "$OVMF_VARS" "$wd/vars.fd"

accel=()
[[ -r /dev/kvm && -w /dev/kvm ]] && accel=(-enable-kvm -cpu host)

printf '\033[1;34m==>\033[0m Booting %s with Secure Boot enforced\n' "$iso"
printf '    Nothing is written to disk — no disk is attached.\n'
printf '    SUPER+Return for a terminal, then try: strata list\n'
printf '    Close the window to shut down.\n'

exec qemu-system-x86_64 \
	-machine q35,smm=on \
	-global driver=cfi.pflash01,property=secure,value=on \
	-global ICH9-LPC.disable_s3=1 \
	-drive "if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_CODE}" \
	-drive "if=pflash,format=raw,unit=1,file=${wd}/vars.fd" \
	-drive "file=${iso},media=cdrom,readonly=on" -boot d \
	-m 4096 -smp 4 "${accel[@]}" \
	-vga virtio \
	-display gtk,show-cursor=on \
	-nic user,model=virtio-net-pci \
	-audiodev pipewire,id=snd0 -device intel-hda -device hda-duplex,audiodev=snd0 \
	-name "Strata (live)"
