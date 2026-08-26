#!/bin/bash
# Boot a Strata ISO in QEMU with Secure Boot enabled and capture screenshots.
#
# This is the cheap iteration loop for ADR-0002. It uses OVMF firmware with
# Microsoft's keys enrolled — the same trust anchor real hardware ships with — so
# a shim that would be rejected on a real machine is rejected here too.
#
# It does not replace booting on real hardware, which TASKS.md still requires.
# Firmware quirks, GPU drivers, and vendor Secure Boot implementations are not
# reproduced by OVMF.
#
# Usage:
#   ./tests/qemu-smoke-test.sh [image.iso] [seconds] [user:password]
#
# Passing credentials makes the test type them into the greeter once it appears,
# which is how the session itself — Hyprland and Quickshell — gets exercised
# rather than only the boot chain. For the live image the live-config defaults
# are user:live.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
cd "$REPO_ROOT"

readonly OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.secboot.fd"
# .ms.fd carries Microsoft's KEK and db pre-enrolled. Using the plain VARS file
# would boot with Secure Boot in setup mode and prove nothing.
readonly OVMF_VARS_TEMPLATE="/usr/share/OVMF/OVMF_VARS_4M.ms.fd"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

iso="${1:-}"
if [[ -z "$iso" ]]; then
	shopt -s nullglob
	candidates=( strata-*.iso )
	[[ ${#candidates[@]} -gt 0 ]] || die "No strata-*.iso found. Build one first."
	iso="${candidates[-1]}"
fi
[[ -f "$iso" ]] || die "No such image: $iso"

duration="${2:-150}"
login="${3:-}"

command -v qemu-system-x86_64 >/dev/null || die "qemu-system-x86_64 not installed."
[[ -f "$OVMF_CODE" ]] || die "$OVMF_CODE missing. apt install ovmf"
[[ -f "$OVMF_VARS_TEMPLATE" ]] || die "$OVMF_VARS_TEMPLATE missing. apt install ovmf"

outdir="tests/screenshots"
mkdir -p "$outdir"
rm -f "$outdir"/*.ppm "$outdir"/*.png 2>/dev/null || true

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
vars="$workdir/OVMF_VARS.fd"
cp "$OVMF_VARS_TEMPLATE" "$vars"

qmp="$workdir/qmp.sock"
serial="$outdir/serial.log"

accel=()
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
	accel=(-enable-kvm -cpu host)
	log "KVM acceleration enabled"
else
	log "No KVM access — falling back to emulation, this will be slow"
fi

log "Image:    $iso"
log "Firmware: $(basename "$OVMF_CODE") + $(basename "$OVMF_VARS_TEMPLATE") (Microsoft keys enrolled)"
log "Running for ${duration}s"

# smm=on and the secure pflash property are both required; without them OVMF
# will happily boot an unsigned binary and the test proves nothing.
qemu-system-x86_64 \
	-machine q35,smm=on \
	-global driver=cfi.pflash01,property=secure,value=on \
	-global ICH9-LPC.disable_s3=1 \
	-drive "if=pflash,format=raw,unit=0,readonly=on,file=${OVMF_CODE}" \
	-drive "if=pflash,format=raw,unit=1,file=${vars}" \
	-drive "file=${iso},media=cdrom,readonly=on" \
	-boot d \
	-m 4096 \
	-smp 4 \
	"${accel[@]}" \
	-vga virtio \
	-display none \
	-serial "file:${serial}" \
	-qmp "unix:${qmp},server,nowait" \
	-no-reboot &
qemu_pid=$!

cleanup() {
	kill "$qemu_pid" 2>/dev/null || true
	wait "$qemu_pid" 2>/dev/null || true
	rm -rf "$workdir"
}
trap cleanup EXIT

QMP_SOCK="$qmp" OUTDIR="$outdir" DURATION="$duration" LOGIN="$login" python3 - <<'PYEOF'
import json, os, socket, time, sys

sock_path = os.environ["QMP_SOCK"]
outdir = os.path.abspath(os.environ["OUTDIR"])
duration = int(os.environ["DURATION"])
login = os.environ.get("LOGIN", "")

for _ in range(50):
    if os.path.exists(sock_path):
        break
    time.sleep(0.2)
else:
    sys.exit("QMP socket never appeared")

s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(sock_path)
f = s.makefile("rw", encoding="utf-8", newline="\n")
f.readline()                                    # greeting
f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n"); f.flush()
f.readline()

def cmd(name, **args):
    f.write(json.dumps({"execute": name, "arguments": args} if args
                       else {"execute": name}) + "\n")
    f.flush()
    while True:
        line = f.readline()
        if not line:
            return None
        msg = json.loads(line)
        if "event" not in msg:
            return msg

# QMP wants qcode names, not characters.
QCODE = {c: c for c in "abcdefghijklmnopqrstuvwxyz0123456789"}
QCODE.update({".": "dot", "-": "minus", "_": "shift-minus", "\n": "ret"})

def typewrite(text):
    # tuigreet drops or reorders keys when they arrive faster than it redraws.
    # 0.06s produced "us" + "er" with the Enter landing mid-word; 0.25s is
    # reliable. Slow, but this runs once per test.
    for ch in text:
        key = QCODE.get(ch.lower())
        if key is None:
            continue
        cmd("send-key", keys=[{"type": "qcode", "data": key}])
        time.sleep(0.25)

def press(key):
    cmd("send-key", keys=[{"type": "qcode", "data": key}])

def shot(label):
    path = os.path.join(outdir, f"{label}.ppm")
    r = cmd("screendump", filename=path)
    ok = r is not None and "error" not in r
    print(f"    {label:<12} {'captured' if ok else 'FAILED'}")

# Screenshots early and often at the start, where the boot chain decides.
marks = [5, 10, 15, 20, 30, 45, 60, 90, 120, 150, 180, 240, 300]
marks = [m for m in marks if m <= duration]
start = time.time()

login_at = None
if login and ":" in login:
    # Give the greeter time to come up before typing at it.
    login_at = 100 if duration > 160 else max(60, duration // 2)

typed = False
for m in marks:
    delay = m - (time.time() - start)
    if delay > 0:
        time.sleep(delay)

    if login_at is not None and not typed and m >= login_at:
        user, _, password = login.partition(":")
        print(f"    logging in as {user}")
        shot("pre-login")
        time.sleep(2)
        typewrite(user)
        time.sleep(1)
        press("ret")
        time.sleep(2.5)
        shot("after-username")
        typewrite(password)
        time.sleep(1)
        # Captured before Enter: tuigreet does not echo the password, so this is
        # the only way to see whether the keystrokes landed at all.
        shot("password-typed")
        press("ret")
        typed = True
        time.sleep(3)
        shot("post-login")

    shot(f"t{m:03d}")
PYEOF

log "Shutting the VM down"
cleanup
trap - EXIT

log "Converting screenshots"
converted=0
for ppm in "$outdir"/*.ppm; do
	[[ -f "$ppm" ]] || continue
	if command -v convert >/dev/null 2>&1; then
		convert "$ppm" "${ppm%.ppm}.png" && converted=$((converted + 1))
	elif python3 -c 'import PIL' 2>/dev/null; then
		python3 -c "from PIL import Image; Image.open('$ppm').save('${ppm%.ppm}.png')" \
			&& converted=$((converted + 1))
	fi
done
log "Converted $converted screenshot(s) to PNG"

if [[ -s "$serial" ]]; then
	log "Serial output captured: $serial ($(wc -l < "$serial") lines)"
else
	log "No serial output — expected, the ISO does not put a console on ttyS0"
fi

log "Screenshots in $outdir"
