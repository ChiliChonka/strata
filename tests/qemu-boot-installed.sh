#!/bin/bash
# Boot the installed system from tests/qemu-install-test.sh in a real window.
#
# The install test runs headless and only leaves screenshots. This opens the
# same disk in a normal QEMU window so the result can be used by hand: log in,
# open a terminal, check whether anything actually works.
#
# Secure Boot is enforced exactly as in the automated test, using OVMF with
# Microsoft's keys, and the ISO is NOT attached — this boots the disk alone,
# which is the whole point.
#
# The VM gets a sound card and a network interface on purpose. Without an
# explicit -audiodev there is no audio hardware at all, which makes "play and
# record audio" — a Definition of Done item — impossible to test rather than
# merely broken. hda-duplex provides capture as well as playback. The NIC is
# QEMU user-mode networking: outbound connections work, ICMP largely does not,
# so test with curl or apt rather than ping.
#
# Credentials come from the install test: strata / strataqemu2026
#
# Close the window to shut the VM down. The disk keeps its state, so changes
# made here persist until the next install run recreates it.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
cd "$REPO_ROOT"

readonly TARGET="tests/target.qcow2"
readonly VARS="tests/OVMF_VARS-installed.fd"
readonly OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.secboot.fd"

die() { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ -f "$TARGET" ]] || die "$TARGET not found — run tests/qemu-install-test.sh first."
[[ -f "$VARS" ]]   || die "$VARS not found — run tests/qemu-install-test.sh first."
[[ -f "$OVMF_CODE" ]] || die "$OVMF_CODE missing. apt install ovmf"

accel=()
[[ -r /dev/kvm && -w /dev/kvm ]] && accel=(-enable-kvm -cpu host)

printf '\033[1;34m==>\033[0m Booting %s with Secure Boot enforced\n' "$TARGET"
printf '    Log in as strata / strataqemu2026\n'
printf '    Close the window to shut down.\n'

exec qemu-system-x86_64 \
	-machine q35,smm=on \
	-global driver=cfi.pflash01,property=secure,value=on \
	-global ICH9-LPC.disable_s3=1 \
	-drive "if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_CODE}" \
	-drive "if=pflash,format=raw,unit=1,file=${VARS}" \
	-drive "file=${TARGET},if=virtio,format=qcow2" \
	-m 4096 -smp 4 "${accel[@]}" \
	-vga virtio \
	-nic user,model=virtio-net-pci \
	-audiodev pipewire,id=snd0 \
	-device intel-hda \
	-device hda-duplex,audiodev=snd0 \
	-display gtk,show-cursor=on \
	-name "Strata (installed)"
