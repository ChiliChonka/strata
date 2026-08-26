#!/bin/bash
# ADR-0005 regression test.
#
# The snapshot.debian.org pin is a build-time mechanism. If it reaches the
# installed system's sources.list, every Strata installation is frozen at image
# build date and stops receiving security updates, which would violate ADR-0001.
#
# Run after `lb config`, which is when live-build has written the mirror
# settings that the installed system inherits.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
cd "$REPO_ROOT"

fail=0
report() { printf '  FAIL: %s\n' "$*" >&2; fail=1; }

# The binary mirrors are what the installed system inherits.
if [[ -f config/binary ]]; then
	while IFS= read -r line; do
		case "$line" in
			LB_MIRROR_BINARY=*|LB_MIRROR_BINARY_SECURITY=*)
				if [[ "$line" == *snapshot.debian.org* ]]; then
					report "snapshot mirror in $line"
				fi
				;;
		esac
	done < config/binary
else
	echo "  config/binary not found — run lb config first" >&2
	exit 1
fi

# Nothing shipped into the image may carry a snapshot URL either.
if [[ -d config/includes.chroot ]]; then
	if grep -rl 'snapshot\.debian\.org' config/includes.chroot 2>/dev/null; then
		report "snapshot URL in config/includes.chroot (shipped into the image)"
	fi
fi

if [[ $fail -eq 0 ]]; then
	echo "  OK: no snapshot URL reaches the installed system"
fi
exit "$fail"
