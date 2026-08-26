#!/bin/bash
# Strata image build entry point.
#
# This is the single supported way to build an image. It resolves the
# snapshot.debian.org timestamp, derives SOURCE_DATE_EPOCH from it, and runs
# live-build.
#
# Usage:
#   sudo ./scripts/build.sh                     # pin today's midnight snapshot
#   sudo ./scripts/build.sh 20260801T000000Z    # rebuild from a past snapshot
#
# ADR-0005 requires that a clean checkout plus this one command produces an
# image, with no manual steps.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly DEBIAN_CODENAME="${DEBIAN_CODENAME:-forky}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==> WARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m==> ERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --- Preconditions ---------------------------------------------------------

[[ $EUID -eq 0 ]] || die "live-build needs root. Re-run with sudo."

command -v lb >/dev/null || die "live-build is not installed. apt install live-build"

# --- Resolve the snapshot --------------------------------------------------

snapshot="${1:-${STRATA_SNAPSHOT:-}}"
if [[ -z "$snapshot" ]]; then
	# Midnight UTC today is a timestamp snapshot.debian.org reliably carries.
	snapshot="$(date -u +%Y%m%dT000000Z)"
	log "No snapshot given, using $snapshot"
fi

[[ "$snapshot" =~ ^[0-9]{8}T[0-9]{6}Z$ ]] \
	|| die "Invalid snapshot timestamp: $snapshot (expected YYYYMMDDTHHMMSSZ)"

release_url="https://snapshot.debian.org/archive/debian/${snapshot}/dists/${DEBIAN_CODENAME}/Release"
log "Verifying $release_url"
tmp_release="$(mktemp)"
trap 'rm -f "$tmp_release"' EXIT
curl -fsSL --retry 3 --retry-delay 5 "$release_url" -o "$tmp_release" \
	|| die "snapshot $snapshot does not serve $DEBIAN_CODENAME"

grep -E '^(Origin|Suite|Codename|Date):' "$tmp_release" | sed 's/^/    /'

# ADR-0005: derive SOURCE_DATE_EPOCH from the same timestamp so the two cannot
# drift apart.
SOURCE_DATE_EPOCH="$(date -u -d "${snapshot:0:8} ${snapshot:9:2}:${snapshot:11:2}:${snapshot:13:2}" +%s)"
STRATA_VERSION="$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y.%m.%d)"

export STRATA_SNAPSHOT="$snapshot"
export SOURCE_DATE_EPOCH STRATA_VERSION DEBIAN_CODENAME

log "Snapshot          $snapshot"
log "Codename          $DEBIAN_CODENAME"
log "SOURCE_DATE_EPOCH $SOURCE_DATE_EPOCH"
log "Image version     $STRATA_VERSION"

# --- Build -----------------------------------------------------------------

cd "$REPO_ROOT"

log "lb clean"
lb clean --purge

log "lb config"
lb config

log "Checking the snapshot pin did not reach the installed sources.list"
./tests/check-no-snapshot-leak.sh

log "lb build (this takes a while)"
lb build

# --- Artifacts -------------------------------------------------------------

# live-build emits strata-<version>-<arch>.hybrid.iso; the published name drops
# the .hybrid infix. See RELEASES.md.
shopt -s nullglob
built=( strata-*.hybrid.iso )
[[ ${#built[@]} -eq 1 ]] || die "expected exactly one ISO, found ${#built[@]}"

final="strata-${STRATA_VERSION}-amd64.iso"
mv "${built[0]}" "$final"
sha256sum "$final" > "${final}.sha256"

log "Writing build manifest"
manifest="manifest-${STRATA_VERSION}.txt"
{
	echo "# Strata build manifest"
	echo "snapshot: $snapshot"
	echo "codename: $DEBIAN_CODENAME"
	echo "suite: testing"
	echo "source_date_epoch: $SOURCE_DATE_EPOCH"
	echo "version: $STRATA_VERSION"
	echo "git_commit: $(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
	echo "live_build: $(dpkg-query -W -f='${Version}' live-build 2>/dev/null || echo unknown)"
	# shellcheck disable=SC1091  # /etc/os-release is not present at lint time
	echo "build_host: $(. /etc/os-release && echo "$PRETTY_NAME")"
	echo
	echo "# packages"
	if [[ -f chroot.packages.live ]]; then
		cat chroot.packages.live
	else
		warn "chroot.packages.live not found — package list missing from manifest"
	fi
} > "$manifest"

log "Done"
printf '    %s\n    %s\n    %s\n' "$final" "${final}.sha256" "$manifest"
