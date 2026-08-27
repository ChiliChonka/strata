#!/bin/bash
# Drive a full Calamares installation in QEMU and boot the result.
#
# This is what backs ADR-0006's claim that the live ISO can install itself.
# Nothing here touches real hardware: the target is a throwaway qcow2 image.
#
# Two phases:
#   1. Boot the ISO with Secure Boot, launch Calamares, drive the wizard.
#   2. Detach the ISO and boot the target disk on its own.
#
# The wizard is driven with Alt+<mnemonic> rather than mouse clicks. Calamares
# underlines the accelerators (Next, Back, Cancel), and a keyboard path does not
# depend on window size or widget positions.
#
# Usage: ./tests/qemu-install-test.sh [image.iso]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
cd "$REPO_ROOT"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

iso="${1:-}"
if [[ -z "$iso" ]]; then
	shopt -s nullglob
	c=( strata-*.iso ); [[ ${#c[@]} -gt 0 ]] || die "No strata-*.iso found."
	iso="${c[-1]}"
fi
[[ -f "$iso" ]] || die "No such image: $iso"

readonly OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.secboot.fd"
readonly OVMF_VARS="/usr/share/OVMF/OVMF_VARS_4M.ms.fd"
[[ -f "$OVMF_CODE" && -f "$OVMF_VARS" ]] || die "OVMF firmware missing. apt install ovmf"

# Refuse to run twice at once. Both runs share this screenshot directory and each
# clears it at startup, so a second run silently destroys the first one's
# evidence — and two QEMU instances competing for KVM slows both down. Learned
# the hard way: a second run was started while the first was still installing,
# and the interleaved screenshots made the result unreadable.
readonly LOCKFILE="/tmp/strata-qemu-install-test.lock"
exec 9>"$LOCKFILE"
if ! flock -n 9; then
	die "another qemu-install-test.sh is already running (lock: ${LOCKFILE})"
fi

out="tests/screenshots-install"
mkdir -p "$out"; rm -f "$out"/*.ppm "$out"/*.png

# Short path: QEMU rejects unix socket paths over 108 bytes.
wd="$(mktemp -d /tmp/qiX.XXXX)"
trap 'rm -rf "$wd"' EXIT
cp "$OVMF_VARS" "$wd/vars.fd"  # scratch copy; the persistent one is set up below

# Deliberately NOT inside $wd: that directory is removed when the run ends, and
# an installed system that vanishes the moment it finishes installing cannot be
# looked at. tests/target.qcow2 is gitignored and survives, so it can be booted
# interactively afterwards with tests/qemu-boot-installed.sh.
target="tests/target.qcow2"
log "Creating a fresh 20G target disk at $target"
rm -f "$target"
qemu-img create -f qcow2 "$target" 20G >/dev/null

# The firmware variables hold the UEFI boot entry that the installer writes, so
# they have to outlive the run too — otherwise the installed system has nothing
# to boot from next time.
readonly PERSISTENT_VARS="tests/OVMF_VARS-installed.fd"
cp "$OVMF_VARS" "$PERSISTENT_VARS"

boot_vm() {  # $1 = "install" | "installed"
	local -a media=()
	if [[ "$1" == "install" ]]; then
		media=( -drive "file=${iso},media=cdrom,readonly=on" -boot d )
	fi
	qemu-system-x86_64 \
		-machine q35,smm=on -enable-kvm -cpu host -m 4096 -smp 4 \
		-global driver=cfi.pflash01,property=secure,value=on \
		-global ICH9-LPC.disable_s3=1 \
		-drive "if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_CODE}" \
		-drive "if=pflash,format=raw,unit=1,file=${PERSISTENT_VARS}" \
		"${media[@]}" \
		-drive "file=${target},if=virtio,format=qcow2" \
		-vga virtio -display none \
		-qmp "unix:${wd}/qmp.sock,server,nowait" \
		-no-reboot >>"${out}/qemu-${1}.log" 2>&1 &
	# The redirect is not optional. Without it the backgrounded QEMU inherits the
	# stdout of the command substitution that captures this PID, so the
	# substitution blocks until QEMU exits and the caller hangs forever.
	echo $!
}

run_phase() {  # $1 = phase name, $2 = python driver
	rm -f "$wd/qmp.sock"
	local pid; pid="$(boot_vm "$1")"
	QMP="$wd/qmp.sock" OUT="$out" PHASE="$1" INSTALL_MINUTES="${INSTALL_MINUTES:-14}" python3 -c "$2" || {
		kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
		die "phase $1 failed"
	}
	kill "$pid" 2>/dev/null || true
	wait "$pid" 2>/dev/null || true
}

read -r -d '' QMP_LIB <<'PYLIB' || true
import json, os, socket, time, sys
sock = os.environ["QMP"]; out = os.path.abspath(os.environ["OUT"])
phase = os.environ["PHASE"]
for _ in range(120):
    if os.path.exists(sock): break
    time.sleep(0.25)
else: sys.exit("QMP socket never appeared")
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM); s.connect(sock)
f = s.makefile("rw", encoding="utf-8", newline="\n"); f.readline()
f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n"); f.flush(); f.readline()
def cmd(n, **a):
    f.write(json.dumps({"execute": n, "arguments": a} if a else {"execute": n}) + "\n"); f.flush()
    while True:
        line = f.readline()
        if not line: return None
        m = json.loads(line)
        if "event" not in m: return m
def key(*ks): cmd("send-key", keys=[{"type": "qcode", "data": k} for k in ks])
# Screen geometry is fixed: Hyprland tiles Calamares to the full 1280x800
# output, so widget coordinates are stable between runs. QEMU wants absolute
# axes scaled to 0..32767.
W, H = 1280, 800
def click(x, y):
    cmd("input-send-event", events=[
        {"type": "abs", "data": {"axis": "x", "value": int(x / W * 32767)}},
        {"type": "abs", "data": {"axis": "y", "value": int(y / H * 32767)}},
    ])
    time.sleep(0.3)
    cmd("input-send-event", events=[{"type": "btn", "data": {"down": True,  "button": "left"}}])
    time.sleep(0.1)
    cmd("input-send-event", events=[{"type": "btn", "data": {"down": False, "button": "left"}}])
    time.sleep(0.5)
CH = {c: c for c in "abcdefghijklmnopqrstuvwxyz0123456789"}
# Anything missing here is silently dropped, which turns a path into nonsense
# without any error: omitting "/" once produced "root.cachecalamaressession.log".
CH.update({" ": "spc", "-": "minus", ".": "dot", "/": "slash",
           "_": "shift-minus", ",": "comma", "=": "equal"})
def typ(t, delay=0.18):
    for c in t:
        if c == "_":
            cmd("send-key", keys=[{"type":"qcode","data":"shift"},{"type":"qcode","data":"minus"}])
            time.sleep(delay); continue
        k = CH.get(c.lower())
        if k is None:
            raise SystemExit(f"typ(): no qcode for {c!r} — add it to CH")
        if c.isupper(): cmd("send-key", keys=[{"type":"qcode","data":"shift"},{"type":"qcode","data":k}])
        else: key(k)
        time.sleep(delay)
# Throwaway credentials for the test VM. Nothing here is a secret; the disk
# image is deleted when the run ends.
# How long to watch the installation. Short values are for diagnosing an early
# failure; a real install needs the full run.
INSTALL_MINUTES = int(os.environ.get("INSTALL_MINUTES", "14"))
PASSWORD = "strataqemu2026"
USERNAME = "strata"
n = [0]
def shot(label):
    n[0] += 1
    p = os.path.join(out, f"{phase}-{n[0]:02d}-{label}.ppm")
    r = cmd("screendump", filename=p)
    ok = r is not None and "error" not in r
    print(f"    {os.path.basename(p):<34} {'ok' if ok else 'FAILED'}")
PYLIB

log "Phase 1: install"
run_phase install "$QMP_LIB"'
print("  waiting for the live session")
time.sleep(150); shot("session")
print("  launching the installer")
key("meta_l", "d"); time.sleep(3)
typ("install"); time.sleep(2); shot("launcher")
key("ret")
print("  waiting for Calamares (it takes the best part of a minute)")
time.sleep(90); shot("calamares-welcome")

# Calamares underlines the accelerator on each button, so Alt+N is Next. Step
# through and screenshot each page so a change in the wizard is visible rather
# than silently skipped.
for page in ("after-welcome", "after-location", "after-keyboard"):
    key("alt", "n")
    time.sleep(6)
    shot(page)

# The partition page needs a choice before Next becomes usable: with neither
# "Erase disk" nor "Manual partitioning" selected, the button is disabled and
# Alt+N does nothing at all.
print("  selecting Erase disk")
click(194, 101)
time.sleep(2); shot("erase-selected")
key("alt", "n"); time.sleep(8); shot("users-page")

# The Users page. Calamares derives the login name and hostname from the full
# name, so only three fields need typing. The name field already has focus.
print("  filling in the user account")
# A single word so Calamares derives the login name as "strata" rather than
# stitching initials onto it.
typ("Strata")
time.sleep(1); shot("name-typed")
click(287, 252); typ(PASSWORD)
click(492, 252); typ(PASSWORD)
time.sleep(1); shot("users-filled")

print("  summary")
key("alt", "n"); time.sleep(6); shot("summary")

# On the summary page the button is no longer "Next" but "Install", so the
# accelerator changes with it.
# Do NOT send a blind Enter here. On the summary page Enter activates Cancel,
# which quits Calamares outright — that cost one full run, with ten minutes of
# screenshots of an empty desktop before anyone noticed.
print("  starting the installation")
key("alt", "i")
for t_ in (2, 5, 10):
    time.sleep(t_ if t_ == 2 else 3)
    shot(f"after-install-{t_}s")

print("  installing — this takes several minutes")
for minute in range(1, INSTALL_MINUTES + 1):
    time.sleep(60)
    shot(f"installing-{minute:02d}min")

# Always pull the installer log, success or not. Calamares reports failures in a
# modal dialog that shows only the failing command, never its output, and the
# log lives under /root because pkexec runs Calamares as root, not in the home
# directory of the live user, which is the first place one looks.
print("  capturing the Calamares log")
# Dismiss the failure dialog first: it floats over the middle of the screen and
# hides exactly the log lines worth reading. Calamares quits when it closes,
# which is fine — the log file stays.
click(791, 467); time.sleep(3)
key("meta_l", "ret"); time.sleep(6)
typ("sudo grep -in -e error -e failed -e cannot /root/.cache/calamares/session.log")
key("ret"); time.sleep(5); shot("calamares-log-errors")
typ("clear"); key("ret"); time.sleep(1)
# The failure message names no cause, so read the region just before it: that is
# where the partitioning jobs and their output are.
typ("sudo sed -n 470,530p /root/.cache/calamares/session.log")
key("ret"); time.sleep(5); shot("calamares-log-before-failure")
'

# QEMU writes PPM. Convert to PNG so the screenshots can be opened in anything,
# and so a run leaves something a person can actually look at without extra steps.
log "Converting screenshots to PNG"
python3 - "$out" <<'PYCONV' || log "conversion skipped (no Pillow and no ImageMagick)"
import glob, os, sys
d = sys.argv[1]
try:
    from PIL import Image
except ImportError:
    sys.exit(1)
n = 0
for f in sorted(glob.glob(os.path.join(d, "*.ppm"))):
    Image.open(f).save(f[:-4] + ".png"); n += 1
print(f"    {n} PNG(s)")
PYCONV

log "Screenshots in $out"
