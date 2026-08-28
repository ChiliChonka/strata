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

# --- Test tooling ----------------------------------------------------------
#
# Removed unconditionally, then re-added only on request. Doing it in this order
# means a release build cannot inherit the list from an interrupted test build:
# forgetting to clean up is not a failure mode, because cleanup is not optional.
readonly TEST_LIST="config/package-lists/strata-test-tools.list.chroot"
rm -f "$TEST_LIST"
if [[ "${STRATA_TEST_TOOLS:-0}" == "1" ]]; then
	warn "STRATA_TEST_TOOLS=1 — building a TEST image, not a release image"
	cp tests/packages/test-tools.list.chroot "$TEST_LIST"
	log "Added $(grep -cvE '^\s*(#|$)' "$TEST_LIST") test package(s)"
fi

# Deliberately NOT --purge. Per live-build's clean script, --purge additionally
# does `rm -rf cache`, which destroys the package cache that --cache-packages
# built up, forcing a full re-download from the rate-limited snapshot archive on
# every build (ADR-0005 names that cost explicitly). Plain `lb clean` still
# removes stage, chroot, binary and source, so the rebuild is complete.
#
# --purge also clears the config stagefile, which only affects `lb config
# --config <git-url>`. Strata does not use that, and lb config re-evaluates
# auto/config either way.
log "lb clean (keeping the package cache)"
lb clean

log "lb config"
lb config

log "Checking the snapshot pin did not reach the installed sources.list"
./tests/check-no-snapshot-leak.sh

log "lb build (this takes a while)"
lb build

# Re-run against the finished image. Only now can the check read the
# sources.list that an installed system actually inherits (ADR-0005).
log "Re-checking the snapshot pin against the built image"
./tests/check-no-snapshot-leak.sh

# The boot parameters decide whether a prepared USB stick has any writable
# space at all. Without "persistence" live-boot never looks for the partition,
# and the failure is silent: the system boots fine and simply forgets
# everything. Assert it on the generated bootloader configs, where a lost flag
# would otherwise only surface on someone's stick.
log "Checking the live boot parameters"
for cfg in binary/boot/grub/grub.cfg binary/isolinux/live.cfg; do
	[[ -f "$cfg" ]] || die "expected bootloader config missing: $cfg"
	grep -q 'boot=live[^\n]*persistence' "$cfg" \
		|| die "$cfg has no persistence in its live boot line — check auto/config, and check that no '#' comment was added inside the lb config call"
done

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

git_commit="$(git -c "safe.directory=${REPO_ROOT}" -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
if [[ "$git_commit" == "unknown" ]]; then
	warn "could not determine the git commit; the manifest will not identify this build"
fi
{
	echo "# Strata build manifest"
	echo "snapshot: $snapshot"
	echo "codename: $DEBIAN_CODENAME"
	echo "suite: testing"
	echo "source_date_epoch: $SOURCE_DATE_EPOCH"
	echo "version: $STRATA_VERSION"
	# -c safe.directory is required because the build runs as root against a
	# repository owned by the invoking user, which git otherwise refuses to read.
	# Without it this silently became "unknown", defeating ADR-0005's requirement
	# that a release records the commit it was built from.
	echo "git_commit: ${git_commit}"
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
