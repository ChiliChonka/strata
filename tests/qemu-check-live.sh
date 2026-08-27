#!/bin/bash
# Boot the ISO and ask the live system questions. No installation.
#
# This is the fast path. Most questions — is this config file right, is that
# service running, did the package land — are answerable from the live session,
# and installing first to find out costs twelve minutes for nothing. Booting and
# asking takes two or three.
#
# Use tests/qemu-install-test.sh when the question is genuinely about the
# installer, or about something that differs between the live and the installed
# system. The sources.list is exactly such a case: the live system and the
# installed one are written by different mechanisms, and the difference is where
# a whole class of defect hid.
#
# Needs a test image: STRATA_TEST_TOOLS=1 ./scripts/build-in-docker.sh
#
# Usage:
#   ./tests/qemu-check-live.sh                       run the built-in checks
#   ./tests/qemu-check-live.sh 'cat /etc/hostname'   run one command and print it

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
cd "$REPO_ROOT"

readonly OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.secboot.fd"
readonly OVMF_VARS="/usr/share/OVMF/OVMF_VARS_4M.ms.fd"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

readonly LOCKFILE="/tmp/strata-qemu-install-test.lock"
exec 9>"$LOCKFILE"
flock -n 9 || die "another Strata VM is running (lock: ${LOCKFILE})"

shopt -s nullglob
isos=( strata-*.iso )
[[ ${#isos[@]} -gt 0 ]] || die "No strata-*.iso found."
iso="${isos[-1]}"

wd="$(mktemp -d /tmp/qlX.XXXX)"
trap 'rm -rf "$wd"' EXIT
cp "$OVMF_VARS" "$wd/vars.fd"

accel=()
[[ -r /dev/kvm && -w /dev/kvm ]] && accel=(-enable-kvm -cpu host)

log "Booting $iso (live, nothing is installed)"
qemu-system-x86_64 \
	-machine q35,smm=on \
	-global driver=cfi.pflash01,property=secure,value=on \
	-global ICH9-LPC.disable_s3=1 \
	-drive "if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_CODE}" \
	-drive "if=pflash,format=raw,unit=1,file=${wd}/vars.fd" \
	-drive "file=${iso},media=cdrom,readonly=on" -boot d \
	-m 4096 -smp 4 "${accel[@]}" \
	-vga virtio -display none \
	-nic user,model=virtio-net-pci \
	-chardev "socket,path=${wd}/qga.sock,server=on,wait=off,id=qga0" \
	-device virtio-serial \
	-device "virtserialport,chardev=qga0,name=org.qemu.guest_agent.0" \
	-no-reboot >"${wd}/qemu.log" 2>&1 &
qemu_pid=$!
trap 'kill "$qemu_pid" 2>/dev/null || true; wait "$qemu_pid" 2>/dev/null || true; rm -rf "$wd"' EXIT

qga() { python3 tests/lib/qga.py "${wd}/qga.sock" "$@"; }

log "Waiting for the guest agent"
if ! qga "true" >/dev/null 2>&1; then
	die "the guest agent never answered — build a test image with STRATA_TEST_TOOLS=1"
fi
log "Guest is up"

# The agent answering is not the same as the session being up, and conflating the
# two turned this test into a race the moment it got fast: the agent replies
# around 40 seconds in, while start-hyprland is still running its checks and has
# not exec'd quickshell or mako yet. Asking then reports them missing, which is
# true and useless.
#
# The Wayland socket is the honest readiness signal — it exists once the
# compositor is actually serving clients.
log "Waiting for the Wayland session"
session_ready=0
for _ in $(seq 1 60); do
	if qga 'ls /run/user/1000/wayland-* >/dev/null 2>&1' >/dev/null 2>&1; then
		session_ready=1
		break
	fi
	sleep 3
done
[[ "$session_ready" == "1" ]] || die "the Wayland session never came up"
# Autostarted clients are exec'd by the compositor, so give them a moment after
# the socket appears.
sleep 8
log "Session is up"

if [[ $# -gt 0 ]]; then
	qga "$*"
	exit $?
fi

failures=0
check() {  # $1 = description, $2 = command, $3 = expected substring
	local output
	output="$(qga "$2" 2>&1 || true)"
	if grep -qF "$3" <<<"$output"; then
		printf '    \033[32mOK\033[0m   %s\n' "$1"
	else
		# shellcheck disable=SC2001  # indenting a multi-line string
		printf '    \033[31mFAIL\033[0m %s\n      expected %q in:\n%s\n' \
			"$1" "$3" "$(sed 's/^/        /' <<<"$output")"
		failures=$((failures + 1))
	fi
}

log "Checking the live system"
check "hostname is strata"          "cat /etc/hostname"                          "strata"
check "apt uses the live archive"   "grep -v ^# /etc/apt/sources.list"           "deb.debian.org"
check "no snapshot mirror"          "grep -c snapshot.debian.org /etc/apt/sources.list || true" "0"
check "Secure Boot is enabled"      "mokutil --sb-state"                         "SecureBoot enabled"
check "greetd is running"           "systemctl is-active greetd"                 "active"
check "Hyprland is running"         "pgrep -c Hyprland || pgrep -c hyprland"     "1"
check "Quickshell is running"       "pgrep -c quickshell"                        "1"
check "the notification daemon runs" "pgrep -c mako"                             "1"
# -x, not -f: matching the full command line makes pgrep find this very check,
# which reported 3 processes where there is one.
check "the polkit agent runs"       "pgrep -cx hyprpolkitagent"                  "1"
check "the live user exists"        "getent passwd user"                         "/home/user"
check "Strata defaults are present" "test -f /etc/strata/hypr/hyprland.lua && echo yes" "yes"
check "the user config loads them"  "grep dofile /home/user/.config/hypr/hyprland.lua" "/etc/strata/hypr"

# ADR-0011. The base image ships no browser on purpose, so `browser` with
# nothing installed must explain itself rather than fail obscurely — that
# message is the only discovery path a new user has.
check "strata lists components"     "strata list"                                "firefox"
check "no browser by default"       "ls /usr/share/applications | grep -c -i -e firefox -e chromium || true" "0"
check "browser explains itself"     "browser 2>&1 || true"                       "strata install firefox"

echo
if [[ $failures -gt 0 ]]; then
	die "$failures check(s) failed"
fi
log "All live checks passed"
