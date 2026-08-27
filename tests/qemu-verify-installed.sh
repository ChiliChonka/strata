#!/bin/bash
# Boot the installed system headless and check the Definition of Done items that
# can only be answered from a real installation.
#
# This is the automated counterpart to tests/qemu-boot-installed.sh: same disk,
# same firmware, no window. It logs in through the greeter, opens a terminal and
# runs a handful of commands, leaving screenshots behind.
#
# It shuts the VM down when finished, so the disk is free for interactive use
# afterwards. Never run it while a window from qemu-boot-installed.sh is open —
# two QEMU processes writing one qcow2 corrupts it.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
cd "$REPO_ROOT"

readonly TARGET="tests/target.qcow2"
readonly VARS="tests/OVMF_VARS-installed.fd"
readonly OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.secboot.fd"
readonly USERNAME="strata"
readonly PASSWORD="strataqemu2026"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

readonly LOCKFILE="/tmp/strata-qemu-install-test.lock"
exec 9>"$LOCKFILE"
flock -n 9 || die "another Strata VM is running (lock: ${LOCKFILE})"

[[ -f "$TARGET" ]] || die "$TARGET not found — run tests/qemu-install-test.sh first."
[[ -f "$VARS" ]]   || die "$VARS not found — run tests/qemu-install-test.sh first."

out="tests/screenshots-installed"
mkdir -p "$out"; rm -f "$out"/*.ppm "$out"/*.png

wd="$(mktemp -d /tmp/qvX.XXXX)"
trap 'rm -rf "$wd"' EXIT

accel=()
[[ -r /dev/kvm && -w /dev/kvm ]] && accel=(-enable-kvm -cpu host)

log "Booting the installed disk with Secure Boot enforced"
qemu-system-x86_64 \
	-machine q35,smm=on \
	-global driver=cfi.pflash01,property=secure,value=on \
	-global ICH9-LPC.disable_s3=1 \
	-drive "if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_CODE}" \
	-drive "if=pflash,format=raw,unit=1,file=${VARS}" \
	-drive "file=${TARGET},if=virtio,format=qcow2" \
	-m 4096 -smp 4 "${accel[@]}" \
	-vga virtio -display none \
	-nic user,model=virtio-net-pci \
	-audiodev pipewire,id=snd0 -device intel-hda -device hda-duplex,audiodev=snd0 \
	-qmp "unix:${wd}/qmp.sock,server,nowait" \
	-no-reboot >>"${out}/qemu.log" 2>&1 &
qemu_pid=$!
trap 'kill "$qemu_pid" 2>/dev/null || true; wait "$qemu_pid" 2>/dev/null || true; rm -rf "$wd"' EXIT

# Different names on purpose: USERNAME and PASSWORD are readonly above, and
# bash refuses to reassign a readonly variable even in an env prefix.
QMP="$wd/qmp.sock" OUT="$out" VM_USER="$USERNAME" VM_PASS="$PASSWORD" python3 - <<'PY'
import json, os, socket, time, sys

sock = os.environ["QMP"]; out = os.path.abspath(os.environ["OUT"])
user = os.environ["VM_USER"]; password = os.environ["VM_PASS"]
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
CH.update({" ": "spc", "-": "minus", ".": "dot", "/": "slash", ",": "comma", "=": "equal"})
def typ(t, delay=0.22):
    for c in t:
        k = CH.get(c.lower())
        if k is None: raise SystemExit(f"typ(): no qcode for {c!r}")
        if c.isupper(): cmd("send-key", keys=[{"type":"qcode","data":"shift"},{"type":"qcode","data":k}])
        else: key(k)
        time.sleep(delay)
n = [0]
def shot(label):
    n[0] += 1
    cmd("screendump", filename=os.path.join(out, f"{n[0]:02d}-{label}.ppm"))
    print(f"    {n[0]:02d}-{label}")

print("  waiting for the greeter")
time.sleep(120); shot("greeter")

# No autologin here: the live-config component that provides it is removed
# during installation, which is the intended behaviour.
print(f"  logging in as {user}")
typ(user); time.sleep(1); key("ret"); time.sleep(2.5)
typ(password); time.sleep(1); key("ret")
time.sleep(45); shot("session")

print("  opening a terminal")
key("meta_l", "ret"); time.sleep(8); shot("terminal")

for label, command in [
    ("secureboot", "mokutil --sb-state"),
    ("sources",    "cat /etc/apt/sources.list"),
    ("hostname",   "hostnamectl"),
]:
    typ("clear"); key("ret"); time.sleep(1)
    typ(command); key("ret"); time.sleep(6)
    shot(label)
PY

log "Shutting the VM down"
kill "$qemu_pid" 2>/dev/null || true
wait "$qemu_pid" 2>/dev/null || true
trap 'rm -rf "$wd"' EXIT

log "Converting screenshots"
python3 - "$out" <<'PYCONV' || log "conversion skipped (no Pillow)"
import glob, os, sys
try: from PIL import Image
except ImportError: sys.exit(1)
d = sys.argv[1]; n = 0
for f in sorted(glob.glob(os.path.join(d, "*.ppm"))):
    Image.open(f).save(f[:-4] + ".png"); n += 1
print(f"    {n} PNG(s)")
PYCONV

log "Screenshots in $out"
