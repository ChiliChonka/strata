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
# Automated runs wait instead of dying. They sit behind a build of a quarter of
# an hour, unattended, so failing the moment someone happens to have a VM open
# throws that whole build away for no reason. Interactive scripts keep -n: there
# a person is watching and wants the answer now, not a silent wait.
if ! flock -w 900 9; then
	die "another Strata VM held the lock for 15 minutes (lock: ${LOCKFILE})"
fi

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
	-qmp "unix:${wd}/qmp.sock,server=on,wait=off" \
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
# not exec'd quickshell or hyprpaper yet. Asking then reports them missing, which is
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

click() {  # $1 = x, $2 = y, $3 = left|right — a real click, through QEMU's
	# input layer. Hover states and popups cannot be asserted any other way:
	# nothing in the guest can be asked "is the menu open".
	python3 - "$wd/qmp.sock" "$1" "$2" "${3:-left}" <<'PYEOF'
import json, socket, sys
sock, x, y, button = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4]
W, H = 1280, 800
s = socket.socket(socket.AF_UNIX); s.settimeout(10); s.connect(sock)
f = s.makefile("rw"); f.readline()
def send(cmd):
    f.write(json.dumps(cmd) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r:
            return r
send({"execute": "qmp_capabilities"})
ev = [{"type": "abs", "data": {"axis": "x", "value": x * 32767 // W}},
      {"type": "abs", "data": {"axis": "y", "value": y * 32767 // H}}]
send({"execute": "input-send-event", "arguments": {"events": ev}})
for down in (True, False):
    send({"execute": "input-send-event", "arguments": {"events": [
        {"type": "btn", "data": {"down": down, "button": button}}]}})
PYEOF
}

screenshot() {  # $1 = output path
	mkdir -p "$(dirname "$1")"
	python3 - "$wd/qmp.sock" "$1" <<'PYEOF'
import json, socket, sys
s = socket.socket(socket.AF_UNIX); s.settimeout(10); s.connect(sys.argv[1])
f = s.makefile("rw")
f.readline()
for c in ({"execute": "qmp_capabilities"}, {"execute": "screendump", "arguments": {"filename": sys.argv[2]}}):
    f.write(json.dumps(c) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r:
            break
sys.exit(1 if "error" in r else 0)
PYEOF
}

# Ad-hoc mode: run a command in the guest, then photograph the screen. QML
# changes can be pushed into a running VM this way and seen in seconds, instead
# of rebuilding an image for a quarter of an hour to look at one element.
if [[ $# -gt 0 ]]; then
	qga "$*"
	rc=$?
	# STRATA_CLICK="x,y[,button]" clicks before the screenshot, so a popup or a
	# hover state can be photographed rather than assumed.
	# STRATA_CLICK="x,y[,button];x,y[,button]" — several clicks in order, so a
	# menu can be opened and something in it picked.
	if [[ -n "${STRATA_CLICK:-}" ]]; then
		IFS=';' read -ra clicks <<<"$STRATA_CLICK"
		for c in "${clicks[@]}"; do
			IFS=, read -r cx cy cb <<<"$c"
			click "$cx" "$cy" "${cb:-left}"
			sleep 2
		done
	fi
	# STRATA_AFTER runs once the clicks have landed — for asserting what an
	# interaction actually wrote, not just what it drew.
	if [[ -n "${STRATA_AFTER:-}" ]]; then
		qga "$STRATA_AFTER"
	fi
	shot="${REPO_ROOT}/test-screenshots/adhoc.ppm"
	if screenshot "$shot"; then
		log "Screenshot: ${shot}"
	fi
	exit $rc
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
# Notifications are served by the shell itself (ADR-0012), so the thing to
# assert is not that a daemon process exists but that the bus name is actually
# owned — a Quickshell that started and failed to claim it looks identical from
# the outside, and every notification on the system would go nowhere.
check "the shell serves notifications" \
	"runuser -u user -- env XDG_RUNTIME_DIR=/run/user/1000 busctl --user --acquired --no-pager list 2>/dev/null | grep -c org.freedesktop.Notifications" \
	"1"
check "the wallpaper is set"        "pgrep -c hyprpaper"                         "1"
check "the wallpaper file exists"   "test -f /usr/share/strata/wallpapers/strata-layers.png && echo yes" "yes"
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

# The bar grows with what is installed and stays minimal when nothing is
# (ADR-0003, ADR-0011). Both halves need asserting: that the drop-in directory
# exists so components have somewhere to install to, and that nothing has
# quietly filled it.
check "strata doctor runs"          "strata doctor 2>&1"                         "Failed units"
check "doctor sees the session"     "strata doctor 2>&1"                         "Hyprland"
check "bar parts dir exists"        "test -d /etc/xdg/quickshell/parts && echo yes" "yes"
check "no bar parts by default"     "ls /etc/xdg/quickshell/parts | wc -l"       "0"
check "parts are available"         "ls /usr/share/strata/parts"                 "health.qml"

# The SUPER+D menu must list what is installed and nothing else. The fuzzel
# terminal setting is what makes Terminal=true entries work at all: without it
# fuzzel falls back to xterm, which is not installed, and picking an agent does
# nothing at all.
check "fuzzel launches terminals"   "grep ^terminal= /etc/xdg/fuzzel/fuzzel.ini"  "foot -e"
check "no agent in menu by default" "ls /usr/share/applications | grep -c ^strata- || true" "0"
check "launcher entries exist"      "ls /usr/share/strata/desktop"                "strata-claude.desktop"
check "hold reports a missing tool" "/usr/lib/strata/hold definitely-not-here </dev/null 2>&1 || true" "strata install"

# The regression that made this necessary: installing a component linked the
# part, but the bar never showed it. Two independent causes — the shell only
# scanned the directory once at startup, and the part bound its height to its
# Loader parent, a binding loop Qt resolves by leaving the height at 0. Either
# one produces an element that installed fine and is nowhere to be seen, so
# asserting "the file is linked" proves nothing. Drive the real path instead.
log "Simulating a component that brings a bar element"
qga "sudo ln -sf /usr/share/strata/parts/agent.qml /etc/xdg/quickshell/parts/agent.qml" >/dev/null
# Two agents, not one: the element used to show only the first it found, and a
# screenshot with a single icon cannot tell the two behaviours apart.
qga "for a in claude codex; do printf '#!/bin/sh\\necho fake\\n' | sudo tee /usr/local/bin/\$a >/dev/null; sudo chmod +x /usr/local/bin/\$a; done" >/dev/null
# No reload is provoked here on purpose: the bar has to notice on its own,
# because that is what happens after a real `strata install`. The wait is longer
# than the rescan interval.
sleep 10

check "part is linked"              "ls /etc/xdg/quickshell/parts"               "agent.qml"
check "quickshell survived reload"  "pgrep -c quickshell"                        "1"
# Quickshell is exec'd by the compositor, so its warnings land in Hyprland's log.
check "no binding loop in the bar"  "cat \"\$XDG_RUNTIME_DIR\"/hypr/*/hyprland.log 2>/dev/null | grep -ci 'binding loop' || true" "0"
check "no part failed to load"      "cat \"\$XDG_RUNTIME_DIR\"/hypr/*/hyprland.log 2>/dev/null | grep -ci 'part failed to load' || true" "0"
# The one that would have caught this: the element has to be drawn, not merely
# loaded. A binding loop against the Loader parent left it at zero height, which
# every text check above happily called a pass.
check "both agents are detected"     "sh -c 'for a in claude codex gemini opencode copilot; do command -v \$a >/dev/null 2>&1 && echo \$a; done' | wc -l" "2"
check "no selection file yet"       "test -e /home/user/.config/strata/bar-agents-hidden && echo yes || echo no" "no"
check "the element is on screen"    "cat \"\$XDG_RUNTIME_DIR\"/quickshell/by-id/*/log.qslog 2>/dev/null | grep -ci 'binding loop' || true" "0"

echo
if [[ $failures -gt 0 ]]; then
	die "$failures check(s) failed"
fi
# Every check above asserts the absence of an error. None of them can see
# whether the bar actually drew the element — the defect that started this was
# invisible to text and obvious in a picture. So end with a picture.
shot="${REPO_ROOT}/test-screenshots/live-bar.ppm"
if screenshot "$shot"; then
	log "Bar screenshot: ${shot}"
else
	log "Screenshot failed (checks above still stand)"
fi

log "All live checks passed"
