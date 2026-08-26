#!/bin/bash
# Build a Strata image inside a Debian Testing container.
#
# Use this on any host that is not Debian. live-build is Debian-specific, and
# Ubuntu's fork (3.0~a57) predates --uefi-secure-boot, the flag ADR-0002 depends
# on, so building directly on an Ubuntu host would silently produce an image
# without a signed boot chain.
#
# Usage:
#   ./scripts/build-in-docker.sh                     # pin today's snapshot
#   ./scripts/build-in-docker.sh 20260801T000000Z    # rebuild a past image
#
# The repository is bind-mounted, so live-build writes chroot/, cache/ and the
# ISO into the working tree on the host rather than into the container storage
# driver. On a host with a small root filesystem that is the difference between
# a build that fits and one that does not.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly IMAGE="strata-build:latest"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --- Container runtime -----------------------------------------------------

if command -v podman >/dev/null 2>&1; then
	RUNTIME=podman
elif command -v docker >/dev/null 2>&1; then
	RUNTIME=docker
else
	die "Neither podman nor docker found."
fi
readonly RUNTIME
log "Using $RUNTIME"

# --- Ownership -------------------------------------------------------------

# The container runs as root. Under docker that leaves root-owned build output
# in the host working tree, which is then awkward to clean up without sudo.
# Rootless podman maps the invoking user automatically and needs no fixup.
HOST_UID="${SUDO_UID:-$(id -u)}"
HOST_GID="${SUDO_GID:-$(id -g)}"
NEEDS_CHOWN=0
if [[ "$RUNTIME" == "docker" ]]; then
	NEEDS_CHOWN=1
fi

fix_ownership() {
	[[ "$NEEDS_CHOWN" -eq 1 ]] || return 0
	log "Restoring ownership of build output to ${HOST_UID}:${HOST_GID}"
	"$RUNTIME" run --rm -v "${REPO_ROOT}:/build" "$IMAGE" \
		chown -R "${HOST_UID}:${HOST_GID}" /build || true
}

# --- Preconditions ---------------------------------------------------------

# live-build needs loop devices to assemble the filesystem images.
[[ -e /dev/loop-control ]] || die "/dev/loop-control missing — the loop module is not available on this host."

avail_gb="$(df -BG --output=avail "$REPO_ROOT" | tail -1 | tr -dc '0-9')"
if (( avail_gb < 25 )); then
	log "WARNING: only ${avail_gb} GB free at $REPO_ROOT; a build needs roughly 20 GB"
fi

# --- Image -----------------------------------------------------------------

log "Building the build environment image"
"$RUNTIME" build -f Containerfile -t "$IMAGE" "$REPO_ROOT"

# --- Build -----------------------------------------------------------------

# --privileged is required: live-build mounts /proc and /sys inside its chroot
# and attaches loop devices. Narrower capability sets have historically not been
# enough. If mount operations still fail on an AppArmor host, adding
# --security-opt apparmor=unconfined is the next thing to try.
log "Starting the build"
trap fix_ownership EXIT

"$RUNTIME" run --rm --privileged \
	--volume "${REPO_ROOT}:/build" \
	--env "DEBIAN_CODENAME=${DEBIAN_CODENAME:-forky}" \
	--workdir /build \
	"$IMAGE" \
	./scripts/build.sh "$@"

log "Build finished"
