#!/bin/bash
# ADR-0005 regression test.
#
# The snapshot.debian.org pin is a build-time mechanism. If it reaches the
# installed system's sources.list, every Strata installation is frozen at image
# build date and stops receiving security updates, which would violate ADR-0001.
#
# There are two places worth checking, and they are not equivalent:
#
#   1. config/binary, after `lb config` — the mirror settings live-build will
#      apply. Catches a misconfiguration before an hour of build time is spent.
#
#   2. the sources.list inside binary/live/filesystem.squashfs, after
#      `lb build` — what an installed system actually inherits. This is the
#      authoritative check.
#
# Do not rely on the leftover chroot/ directory. live-build swaps the mirrors
# around during the binary stage and restores the build-time ones afterwards, so
# chroot/etc/apt/sources.list shows the build mirrors even when the image itself
# is correct. Reading it produces a false positive.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly SNAPSHOT_HOST='snapshot\.debian\.org'

cd "$REPO_ROOT"

fail=0
checked=0
report() { printf '  FAIL: %s\n' "$*" >&2; fail=1; }
pass()   { printf '  OK:   %s\n' "$*"; }

# --- 1. Generated live-build configuration ---------------------------------

if [[ -f config/binary ]]; then
	checked=1
	leaked=0
	while IFS= read -r line; do
		case "$line" in
			LB_MIRROR_BINARY=*|LB_MIRROR_BINARY_SECURITY=*)
				if [[ "$line" == *snapshot.debian.org* ]]; then
					report "snapshot mirror in config/binary: $line"
					leaked=1
				fi
				;;
		esac
	done < config/binary
	[[ $leaked -eq 0 ]] && pass "config/binary points at the live Debian archive"
fi

# --- 2. The built image ----------------------------------------------------

squashfs="binary/live/filesystem.squashfs"
if [[ -f "$squashfs" ]]; then
	if ! command -v unsquashfs >/dev/null 2>&1; then
		echo "  SKIP: $squashfs present but unsquashfs is unavailable" >&2
	else
		checked=1
		tmp="$(mktemp -d)"
		trap 'rm -rf "$tmp"' EXIT
		unsquashfs -q -d "$tmp/fs" -f "$squashfs" \
			etc/apt/sources.list etc/apt/sources.list.d >/dev/null 2>&1 || true

		if [[ ! -f "$tmp/fs/etc/apt/sources.list" ]]; then
			report "could not read /etc/apt/sources.list out of $squashfs"
		elif grep -qE "$SNAPSHOT_HOST" "$tmp/fs/etc/apt/sources.list"; then
			report "snapshot URL in the image's /etc/apt/sources.list"
			grep -nE "$SNAPSHOT_HOST" "$tmp/fs/etc/apt/sources.list" | sed 's/^/        /' >&2
		else
			pass "the image's /etc/apt/sources.list points at the live Debian archive"
		fi

		# Checking the host is not enough. calamares-settings-debian ships a
		# helper with RELEASE="trixie" hardcoded, which rewrites the installed
		# system's sources.list to track Debian stable. That passes every check
		# above — the host is right, there is no snapshot URL — while quietly
		# contradicting the project's premise. Strata overrides that helper; this
		# guards the override.
		expected_suite="${DEBIAN_CODENAME:-forky}"
		if [[ -f "$tmp/fs/etc/apt/sources.list" ]] \
			&& ! grep -qE "[[:space:]]${expected_suite}[[:space:]]" "$tmp/fs/etc/apt/sources.list"; then
			report "the image's sources.list does not track ${expected_suite}"
			grep -vE '^\s*(#|$)' "$tmp/fs/etc/apt/sources.list" | sed 's/^/        /' >&2
		else
			pass "the image's sources.list tracks ${expected_suite}"
		fi

		helper="$tmp/fs/usr/share/calamares/helpers/calamares-sources-final"
		unsquashfs -q -d "$tmp/fs" -f "$squashfs" \
			usr/share/calamares/helpers/calamares-sources-final >/dev/null 2>&1 || true
		# Comment lines are excluded, and for the same reason as above: Strata's
		# replacement quotes Debian's `RELEASE="trixie"` in its header to explain
		# why the override exists. Matching that is a false positive, and it
		# aborted a build once already.
		if [[ -f "$helper" ]] \
			&& grep -vE '^[[:space:]]*#' "$helper" | grep -qE 'RELEASE=["'"'"']?(trixie|bookworm|bullseye)'; then
			report "calamares-sources-final hardcodes a stable release"
		elif [[ -f "$helper" ]]; then
			pass "calamares-sources-final derives the release rather than hardcoding it"
		fi

		if [[ -d "$tmp/fs/etc/apt/sources.list.d" ]] \
			&& grep -rqE "$SNAPSHOT_HOST" "$tmp/fs/etc/apt/sources.list.d" 2>/dev/null; then
			report "snapshot URL in the image's /etc/apt/sources.list.d"
		fi

		# The build-time freshness override must not ship either.
		if grep -rqE "$SNAPSHOT_HOST|Check-Valid-Until" "$tmp/fs/etc/apt/" 2>/dev/null; then
			report "build-time APT settings leaked into the image"
		fi
	fi
fi

# --- 3. Anything shipped verbatim into the image ---------------------------

if [[ -d config/includes.chroot ]]; then
	checked=1
	# Match an actual URL, and skip comment lines. A file may legitimately
	# mention the snapshot archive in prose — Strata's replacement for
	# calamares-sources-final explains this very check in its header — and
	# flagging that is a false positive that fails the build for no reason.
	leaks="$(grep -rn --exclude-dir=.git -E "https?://${SNAPSHOT_HOST}" config/includes.chroot 2>/dev/null \
		| grep -vE ':[[:space:]]*#' || true)"
	if [[ -n "$leaks" ]]; then
		report "snapshot URL in config/includes.chroot (shipped into the image)"
		printf '        %s\n' "$leaks" >&2
	else
		pass "config/includes.chroot carries no snapshot URL"
	fi
fi

# --- Verdict ---------------------------------------------------------------

if [[ $checked -eq 0 ]]; then
	echo "  ERROR: nothing to check — run lb config first" >&2
	exit 1
fi
exit "$fail"
