#!/bin/bash
# Put this conversation on the USB stick, so it can be resumed from inside the
# booted system.
#
# Claude Code keeps a session as one JSONL transcript under
# ~/.claude/projects/<key>/<session-id>.jsonl, where <key> is the working
# directory with its slashes turned into dashes. Resuming therefore needs the
# transcript to sit under the key matching where the project will live on the
# other machine — here /home/user/strata, so -home-user-strata.
#
# The repository itself is not copied: it is on GitHub and every branch is
# pushed, so cloning there is faster and leaves no stale working tree.
#
# Usage:  sudo ./scripts/session-to-stick.sh [session-id]
#
# With no argument the most recently modified transcript for this project is
# used, which is almost always the one you are in.

set -euo pipefail

readonly STICK=/dev/disk/by-id/usb-SanDisk_Ultra_Fit_4C530001280308111332-0:0-part3
readonly SRC_DIR="/home/manuel/.claude/projects/-home-manuel-git-github-ChiliChonka-strata"
readonly DEST_KEY="-home-user-strata"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "needs root to mount the partition and set ownership"
[[ -b "$STICK" ]] || die "persistence partition not found at $STICK — is the stick plugged in?"

session="${1:-}"
if [[ -z "$session" ]]; then
	# find, not ls: the names are session UUIDs so parsing ls would be safe
	# here, but shellcheck is right that it is a habit not worth keeping.
	session="$(find "$SRC_DIR" -maxdepth 1 -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null \
		| sort -rn | head -1 | cut -d' ' -f2-)"
	[[ -n "$session" ]] || die "no transcript found in $SRC_DIR"
else
	session="${SRC_DIR}/${session%.jsonl}.jsonl"
	[[ -f "$session" ]] || die "no such transcript: $session"
fi
log "Transcript: $(basename "$session")  ($(du -h "$session" | cut -f1))"

mnt="$(mktemp -d)"
trap 'umount "$mnt" 2>/dev/null || true; rmdir "$mnt" 2>/dev/null || true' EXIT
mount "$STICK" "$mnt" || die "could not mount $STICK"

[[ -f "$mnt/persistence.conf" ]] \
	|| die "$STICK has no persistence.conf — this is not the persistence partition"

# The overlay is mounted with "/ union", so a path on this partition is the same
# path on the running system. A copy is also left at the partition root, because
# that assumption is the one thing here that cannot be checked from this side.
target="${mnt}/home/user/.claude/projects/${DEST_KEY}"
fallback="${mnt}/strata-session"

log "Copying the transcript and memories"
mkdir -p "$target" "$fallback"
cp "$session" "$target/"
cp "$session" "$fallback/"
if [[ -d "${SRC_DIR}/memory" ]]; then
	mkdir -p "${mnt}/home/user/.claude/projects/${DEST_KEY}/memory"
	cp -r "${SRC_DIR}/memory/." "${mnt}/home/user/.claude/projects/${DEST_KEY}/memory/"
	cp -r "${SRC_DIR}/memory" "$fallback/"
fi

cat > "${fallback}/README.txt" <<'NOTE'
Resuming the Strata conversation on this machine
================================================

1. Get the repository and the tools:

       git clone https://github.com/ChiliChonka/strata ~/strata
       strata install claude

2. Resume:

       cd ~/strata
       claude --resume

   The transcript should already be under
   ~/.claude/projects/-home-user-strata/ . If `--resume` does not list it,
   copy it there by hand from this directory:

       mkdir -p ~/.claude/projects/-home-user-strata
       cp /run/live/persistence/*/strata-session/*.jsonl \
          ~/.claude/projects/-home-user-strata/

   The directory name must match the working directory: /home/user/strata
   becomes -home-user-strata. Clone somewhere else and the name changes.

3. Optional, to let the other machine reach this one again:

       sudo apt install -y openssh-server
       sudo systemctl start ssh
       ip -brief addr
NOTE

chown -R 1000:1000 "${mnt}/home/user" "$fallback"
sync

log "Done"
printf '    %s\n' "in the session:  ~/.claude/projects/${DEST_KEY}/"
printf '    %s\n' "spare copy:      <persistence>/strata-session/"
printf '\n    On the other machine:  cd ~/strata && claude --resume\n'
