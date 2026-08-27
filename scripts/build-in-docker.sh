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

# Only the artifacts a person actually handles. NOT chroot/, cache/ or binary/.
#
# Those must keep root ownership. live-build's bootstrap cache stores /var/lib
# owned by root, and the path-safety check in dbus-daemon's postinst refuses to
# configure when it sees "unsafe path transition /var/lib (owned by 1000) ->
# /var/lib/dbus (owned by root)". Chowning the whole tree poisons the cache, and
# the next build that reuses it dies in a cascade of dpkg configure failures.
#
# Removing build scratch therefore needs the container:
#   docker run --rm -v "$PWD:/build" -w /build strata-build:latest lb clean
fix_ownership() {
	[[ "$NEEDS_CHOWN" -eq 1 ]] || return 0
	log "Restoring ownership of build artifacts to ${HOST_UID}:${HOST_GID}"
	# shellcheck disable=SC2016  # deliberate: $1 expands inside the container
	"$RUNTIME" run --rm -v "${REPO_ROOT}:/build" -w /build "$IMAGE" \
		bash -c '
			shopt -s nullglob
			files=( strata-*.iso strata-*.iso.sha256 strata-*.contents \
			        strata-*.files strata-*.packages manifest-*.txt \
			        build.log chroot.packages.* chroot.files \
			        binary.modified_timestamps )
			if [ ${#files[@]} -gt 0 ]; then
				chown "$1" "${files[@]}"
			fi
		' _ "${HOST_UID}:${HOST_GID}" || true
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
	--env "STRATA_TEST_TOOLS=${STRATA_TEST_TOOLS:-0}" \
	--workdir /build \
	"$IMAGE" \
	./scripts/build.sh "$@"

log "Build finished"
