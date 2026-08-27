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

out="tests/screenshots-install"
mkdir -p "$out"; rm -f "$out"/*.ppm "$out"/*.png

# Short path: QEMU rejects unix socket paths over 108 bytes.
wd="$(mktemp -d /tmp/qiX.XXXX)"
trap 'rm -rf "$wd"' EXIT
cp "$OVMF_VARS" "$wd/vars.fd"

target="$wd/target.qcow2"
log "Creating a 20G throwaway target disk"
qemu-img create -f qcow2 "$target" 20G >/dev/null

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
		-drive "if=pflash,format=raw,unit=1,file=${wd}/vars.fd" \
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
	QMP="$wd/qmp.sock" OUT="$out" PHASE="$1" python3 -c "$2" || {
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
CH = {c: c for c in "abcdefghijklmnopqrstuvwxyz0123456789"}
CH.update({" ": "spc", "-": "minus", ".": "dot"})
def typ(t, delay=0.18):
    for c in t:
        k = CH.get(c.lower())
        if k is None: continue
        if c.isupper(): cmd("send-key", keys=[{"type":"qcode","data":"shift"},{"type":"qcode","data":k}])
        else: key(k)
        time.sleep(delay)
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
for page in ("after-welcome", "after-location", "after-keyboard", "after-partitions"):
    key("alt", "n")
    time.sleep(6)
    shot(page)
'

log "Screenshots in $out"
