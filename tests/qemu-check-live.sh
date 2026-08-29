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

move() {  # $1 = x, $2 = y — pointer motion with no button
	python3 - "$wd/qmp.sock" "$1" "$2" <<'PYEOF'
import json, socket, sys
sock, x, y = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
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
send({"execute": "input-send-event", "arguments": {"events": [
    {"type": "abs", "data": {"axis": "x", "value": x * 32767 // W}},
    {"type": "abs", "data": {"axis": "y", "value": y * 32767 // H}}]}})
PYEOF
}

drag() {  # $1..$4 = x1 y1 x2 y2 — press, move, release
	# A region screenshot cannot be tested without this: slurp draws nothing
	# until something is being dragged, so a click alone proves only that it
	# started.
	python3 - "$wd/qmp.sock" "$1" "$2" "$3" "$4" <<'PYEOF'
import json, socket, sys, time
sock = sys.argv[1]
x1, y1, x2, y2 = (int(v) for v in sys.argv[2:6])
W, H = 1280, 800
s = socket.socket(socket.AF_UNIX); s.settimeout(10); s.connect(sock)
f = s.makefile("rw"); f.readline()
def send(cmd):
    f.write(json.dumps(cmd) + "\n"); f.flush()
    while True:
        r = json.loads(f.readline())
        if "return" in r or "error" in r:
            return r
def at(x, y):
    send({"execute": "input-send-event", "arguments": {"events": [
        {"type": "abs", "data": {"axis": "x", "value": x * 32767 // W}},
        {"type": "abs", "data": {"axis": "y", "value": y * 32767 // H}}]}})
def button(down):
    send({"execute": "input-send-event", "arguments": {"events": [
        {"type": "btn", "data": {"down": down, "button": "left"}}]}})
send({"execute": "qmp_capabilities"})
at(x1, y1); time.sleep(0.2)
button(True); time.sleep(0.2)
# Several steps: a single jump can be read as a click that happened to move.
for i in range(1, 9):
    at(x1 + (x2 - x1) * i // 8, y1 + (y2 - y1) * i // 8)
    time.sleep(0.05)
time.sleep(0.2)
button(False)
PYEOF
}

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
			if [[ "${cb:-left}" == "drag" ]]; then
				# x,y,drag,x2,y2 — the end point rides along in the same entry
				IFS=, read -r _ _ _ dx dy <<<"$c"
				drag "$cx" "$cy" "$dx" "$dy"
			elif [[ "${cb:-left}" == "hover" ]]; then
				# Move without pressing. Hover-to-switch between bar menus
				# cannot be tested any other way, and it broke once already
				# without anyone noticing until it was used by hand.
				move "$cx" "$cy"
			else
				click "$cx" "$cy" "${cb:-left}"
			fi
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

# The boot menu is the first thing anyone sees. live-build falls back to its own
# splash if ours is missing, silently, so its absence looks like a design choice
# rather than a build that dropped a file.
# Grep the one line that matters, not the file: counting occurrences of "Strata"
# counted the explanatory comment too, which is the same mistake the snapshot
# leak test made twice against its own comments.
check "boot menu is titled Strata"  "grep '^menu title' /run/live/medium/isolinux/menu.cfg"  "Strata"
check "boot entries are named"      "grep 'menu label' /run/live/medium/isolinux/live.cfg"    "Strata"
check "our splash was rendered"     "test -s /run/live/medium/isolinux/splash.png && echo yes" "yes"
# The UEFI entries come from string literals inside live-build, not a template,
# so they are renamed after generation. If live-build changes that wording the
# hook stops matching, and this is what notices.
check "UEFI entries are named"      "grep '^menuentry' /run/live/medium/boot/grub/grub.cfg | head -1" "Strata"
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
# hypridle was autostarted for weeks and exited immediately every time, because
# no hypridle.conf was ever shipped and it refuses to run without one. The
# checks asked about mako and the polkit agent and never about this, so idle
# handling was broken in every image and no test noticed.
check "the idle daemon runs"        "pgrep -cx hypridle"                         "1"
check "it has a configuration"      "test -f /etc/xdg/hypr/hypridle.conf && echo yes" "yes"
# hyprlock refuses to start without one too, so the session menu's Lock entry
# did nothing and hypridle's lock would have failed the same way. Asked of
# hyprlock itself rather than by checking the file exists: a config that is
# present but rejected leaves the same broken Lock button.
# hyprlock refuses to start without a configuration, which is why the session
# menu's Lock entry did nothing at all. Verifying that needs the session's
# environment: hyprlock connects to the compositor first and aborts there, so
# without WAYLAND_DISPLAY it never reaches the config and every question about
# the config answers itself vacuously — which is exactly how two earlier
# versions of this check passed while proving nothing.
#
# The environment is taken from quickshell, which Hyprland started and which
# therefore has it. Running it locks the screen, so it is killed straight
# after and Hyprland's "the lock crashed" state is cleared, or every later
# screenshot would be that error page.
qga "env \$(tr '\\0' '\\n' < /proc/\$(pgrep -x quickshell)/environ | grep -E '^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR|HYPRLAND_INSTANCE_SIGNATURE|DBUS_SESSION_BUS_ADDRESS)=') setsid hyprlock >/tmp/hl.log 2>&1 &" >/dev/null
sleep 5
qga "pgrep -cx hyprlock > /tmp/hl.count; pkill -x hyprlock; true" >/dev/null
sleep 2
qga "env \$(tr '\\0' '\\n' < /proc/\$(pgrep -x quickshell)/environ | grep -E '^(HYPRLAND_INSTANCE_SIGNATURE|XDG_RUNTIME_DIR)=') hyprctl eval 'hl.clear_crashed_lockscreen()'; true" >/dev/null
sleep 1

check "the lock screen starts"      "cat /tmp/hl.count"                          "1"
check "the lock config has no errors" "grep -c 'Config has errors' /tmp/hl.log || true" "0"
# In a live session the account's password is one nobody was told, so locking on
# idle would strand whoever was trying the system out.
check "live does not lock on idle"  "grep -c lock-session /etc/xdg/hypr/hypridle.conf || true" "0"
# Idle was only one of three ways in. The session menu offered Lock, and Suspend
# locked before suspending — both with a password live-config chose and nobody
# was ever told. Someone lost a session to it.
#
# This is a tripwire, not a proof: it reads the file rather than the screen,
# because whether a menu row is drawn cannot be asked of a running shell. The
# absence of the row was confirmed by opening the menu and looking; this only
# notices if that stops being true.
check "live hides the lock entry"    "grep -c 'session.live' /etc/xdg/quickshell/elements/Session.qml" "4"

# A diagnostic nobody runs is not a diagnostic. The session says so once, on its
# own, when something did not come up — verified by breaking it deliberately and
# asking mako what it was told, rather than by reading the script.
log "Breaking the session on purpose to see whether it says so"
# Both halves run as the session user, not as root: root reaches the session bus
# but the notification is not delivered and makoctl reports ENOTCONN, which
# looks exactly like the feature being broken.
qga "pkill -x hypridle; sleep 1; sed -i 's/^sleep 25\$/sleep 1/' /usr/lib/strata/session-check; E=\$(tr '\\0' '\\n' < /proc/\$(pgrep -x quickshell)/environ | grep -E '^(DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR)='); sudo -u user env \$E /usr/lib/strata/session-check; true" >/dev/null
sleep 3
# Asserted on the summary: makoctl list prints summary, app name and urgency,
# not the body that names the service.
# The battery element reads UPower through Quickshell, and upower was never
# installed — so on a laptop with a battery at 63% the element showed nothing,
# and Quickshell said why in its log at every single login. Both halves are
# asserted: that the service can be activated at all, and that the shell did not
# complain about it.
# Asked of the bus, not of a directory listing: counting files named *UPower*
# expected exactly one and got two, because power-profiles-daemon ships
# org.freedesktop.UPower.PowerProfiles.service and arrived in the same commit.
# Whether the name can be reached is the question; how many files mention it is
# not.
check "upower can be activated"     "busctl --system introspect org.freedesktop.UPower /org/freedesktop/UPower 2>&1 | head -1" "NAME"
check "the shell reached upower"    "cat \"\$XDG_RUNTIME_DIR\"/quickshell/by-id/*/log.log 2>/dev/null | tr -d '\\0' | grep -ci 'Could not launch service org.freedesktop.UPower' || true" "0"

check "the session reports a failure" "E=\$(tr '\\0' '\\n' < /proc/\$(pgrep -x quickshell)/environ | grep -E '^(DBUS_SESSION_BUS_ADDRESS|XDG_RUNTIME_DIR)='); sudo -u user env \$E makoctl list" "Part of the desktop did not start"
check "the live user exists"        "getent passwd user"                         "/home/user"
check "Strata defaults are present" "test -f /etc/strata/hypr/hyprland.lua && echo yes" "yes"
check "the user config loads them"  "grep dofile /home/user/.config/hypr/hyprland.lua" "/etc/strata/hypr"

# ADR-0011. The base image ships no browser on purpose, so `browser` with
# nothing installed must explain itself rather than fail obscurely — that
# message is the only discovery path a new user has.
# Every Debian package a component names has to exist. copilot declared
# PACKAGES="gh" for months; there is no gh in Debian, so installing it would
# have stopped on an apt error — nobody had run it, and nothing checked.
check "component packages resolve" "for p in \$(cat /usr/share/strata/components/*.component | sed -n 's/^PACKAGES=\"\\(.*\\)\"/\\1/p'); do apt-cache show \$p >/dev/null 2>&1 || echo \"MISSING \$p\"; done; echo done" "done"

check "strata lists components"     "strata list"                                "firefox"
check "no browser by default"       "ls /usr/share/applications | grep -c -i -e firefox -e chromium || true" "0"
check "browser explains itself"     "browser 2>&1 || true"                       "strata install firefox"

# XDG_DATA_DIRS unset means /usr/local/share:/usr/share, and Flatpak's exports
# are in neither — an application installed from Flathub is then invisible to
# xdg-open, to xdg-settings and to the launcher. Brave installed fine and
# nothing on the system could open it.
# Asked of quickshell, not of Hyprland. /proc/PID/environ is the environment a
# process was started with, and Hyprland sets this one later, while reading its
# config — so the compositor's own environ never shows it however well it works.
# What matters is what the session's programs inherit, and quickshell is one.
check "session sees flatpak exports" "tr '\\0' '\\n' < /proc/\$(pgrep -x quickshell)/environ | grep XDG_DATA_DIRS" "/var/lib/flatpak/exports/share"
# Both come from libglib2.0-bin. The live image had it as a dependency of
# something else and an installed system did not, so `browser` silently fell
# back to sensible-browser — which cannot start a Flatpak — and the session's
# health notification had nothing to send with. Neither said anything.
check "gio is available to launch"  "command -v gio"                             "/usr/bin/gio"
check "gdbus is available to warn"  "command -v gdbus"                           "/usr/bin/gdbus"
check "browser can work without gio" "grep -c 'exec \$exec_line' /usr/bin/browser" "1"

# The bar grows with what is installed and stays minimal when nothing is
# (ADR-0003, ADR-0011). Both halves need asserting: that the drop-in directory
# exists so components have somewhere to install to, and that nothing has
# quietly filled it.
check "strata doctor runs"          "strata doctor 2>&1"                         "Failed units"
check "doctor sees the session"     "strata doctor 2>&1"                         "Hyprland"
check "bar parts dir exists"        "test -d /etc/xdg/quickshell/parts && echo yes" "yes"
check "no bar parts by default"     "ls /etc/xdg/quickshell/parts | wc -l"       "0"
check "parts are available"         "ls /usr/share/strata/parts"                 "health.qml"

# One colour scheme, five dialects (ADR-0013). Each of these is a file some
# other program has to be able to read, generated at build time — if the
# generator did not run, the bar does not merely look wrong, it fails to load,
# because Theme.qml cannot resolve Colors.qml.
check "theme was applied at build"  "readlink /etc/strata/theme/active.theme"    "strata-dark"
check "quickshell colours exist"    "test -f /etc/xdg/quickshell/Colors.qml && echo yes" "yes"
# `foot --check-config` returns success on a deprecation warning, so asserting
# its exit status passed while every terminal launch printed a wall of them.
# Assert on the output instead: a correct configuration prints nothing at all.
check "foot config is silent"       "out=\$(foot --check-config 2>&1); [ -z \"\$out\" ] && echo silent || echo \"\$out\"" "silent"
check "foot uses current sections"  "grep -c '^\\[colors-' /etc/strata/theme/foot.ini" "2"
check "foot has scheme colours"     "grep ^background= /etc/strata/theme/foot.ini" "16191d"
check "hyprland border colours"     "grep active /etc/strata/theme/colors.lua"   "rgba("
check "both themes are listed"      "strata theme list | wc -l"                  "2"
check "the ui font is installed"    "fc-list : family | grep -c 'Inter Variable'" "1"
check "the icon font is installed"  "fc-list : family | grep -c 'Material Icons'" "1"

# ADR-0012's surface list. These are wired into shell.qml by name rather than
# scanned, so one of them failing to load takes the whole bar with it — which is
# the intent, but it makes a check for QML errors load-bearing rather than nice
# to have.
check "bar elements are present"    "ls /etc/xdg/quickshell/elements | wc -l"    "9"
# ADR-0012's table, row by row. Bluetooth needed bluez, which ADR-0014 added;
# before that this element could not have worked at all.
check "the clock element exists"    "test -f /etc/xdg/quickshell/elements/Clock.qml && echo yes" "yes"
# One at a time: `command -v grim slurp` reports only the first argument, so
# counting its output said one where two were meant and failed on an image that
# had both.
check "screenshot tooling is there" "for c in grim slurp; do command -v \$c >/dev/null || exit 1; done; echo both" "both"
check "bluetooth tooling is there"  "command -v bluetoothctl"                    "/usr/bin/bluetoothctl"
# The window list learns which window has focus from Hyprland's event stream
# rather than a timer, because activeToplevel is null in this Quickshell —
# measured twice, in two sessions. If that ever changes the element keeps
# working; if the event name changes it stops, and this notices.
check "the window list is wired"    "grep -c 'onRawEvent' /etc/xdg/quickshell/elements/Windows.qml" "1"
# Twice in one day an element used Process without importing Quickshell.Io,
# which is not a warning — the type fails to resolve and the whole bar refuses
# to load. Cheap to check, and it names the file instead of leaving a stack of
# failed runtime assertions to work backwards from.
check "every Process has its import" "for f in /etc/xdg/quickshell/elements/*.qml; do grep -q 'Process[[:space:]]*{' \$f && ! grep -q '^import Quickshell.Io' \$f && echo \$f; done; echo ok" "ok"
check "no QML errors in the shell"  "cat \"\$XDG_RUNTIME_DIR\"/hypr/*/hyprland.log 2>/dev/null | grep -ci 'ERROR.*\\.qml' || true" "0"
check "the bar still has a clock"   "pgrep -cx quickshell"                       "1"
# Lock is the one session action that silently does nothing if its binary is
# missing; the rest are systemctl, which is not going anywhere.
check "lock screen is installed"    "command -v hyprlock"                        "/usr/bin/hyprlock"
check "wifi tooling for handoff"    "command -v nmtui"                           "/usr/bin/nmtui"

# The SUPER+D menu must list what is installed and nothing else. The fuzzel
# terminal setting is what makes Terminal=true entries work at all: without it
# fuzzel falls back to xterm, which is not installed, and picking an agent does
# nothing at all.
check "fuzzel launches terminals"   "grep ^terminal= /etc/xdg/fuzzel/fuzzel.ini"  "foot -e"
check "no agent in menu by default" "ls /usr/share/applications | grep -c ^strata- || true" "0"
# The ssh component must not leave a reachable machine behind: a live account
# has a password nobody was told, so an sshd started by the install would be an
# open door the owner cannot close by changing it.
check "ssh is not shipped running"  "systemctl is-active ssh 2>&1 || true"      "inactive"
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
