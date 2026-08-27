# Security

## Reporting a vulnerability

Use GitHub's [private vulnerability reporting](https://github.com/ChiliChonka/strata/security/advisories/new)
rather than a public issue.

Include the image version from `/etc/strata-release` or the build manifest, and
say whether you saw it in a live session or an installed system — the two differ
in ways that have already mattered.

Strata is a small project with no paid maintainers. Expect a reply in days, not
hours.

## What is in scope

Strata contributes package selection, configuration and build tooling. Those are
in scope:

- the package lists, and anything they pull in that should not be there
- the configuration under `config/includes.chroot/`
- the build and release pipeline, including the snapshot pinning in
  [ADR-0005](docs/adr/ADR-0005-build-reproducibility-and-snapshot-pinning.md)
- the Secure Boot chain as Strata assembles it
- the installer overrides in `config/includes.chroot/etc/calamares/`

## What is not

A vulnerability in a Debian package that Strata merely installs belongs to
Debian. Report it through
[Debian's security process](https://www.debian.org/security/faq); Strata picks
up the fix with the next build, because installed systems track the ordinary
Debian archive.

If you are unsure, ask here. Reporting to both is never wrong.

## Two properties worth attacking

These are the assumptions the project rests on. Evidence against either is
valuable.

**Installed systems receive Debian's security updates.** Builds resolve packages
from a pinned `snapshot.debian.org` timestamp, but that pin is build-time only:
an installed system's `sources.list` must point at `deb.debian.org` and
`security.debian.org`. If a snapshot URL reaches an installed system, that
system is frozen at image build date and silently stops receiving security
fixes. `tests/check-no-snapshot-leak.sh` guards this, and the guard exists
because a related defect got through — the installed system tracked Debian
*stable* while every automated check passed, since they all examined the
hostname and none the suite.

**Secure Boot works without weakening it.** Strata uses Debian's signed shim,
GRUB and kernel. It should never require disabling Secure Boot or enrolling a
Machine Owner Key, and `--uefi-secure-boot` is set to `enable` rather than `auto`
precisely so that a missing signed package fails the build instead of silently
producing an unsigned image. A path that boots with Secure Boot enabled but
verifies nothing meaningful is a vulnerability, not a feature.

## Things that look alarming and are not

- **`Acquire::Check-Valid-Until=false`** is set at build time because
  snapshot.debian.org serves `Release` files whose `Valid-Until` is in the past.
  It disables freshness checking, not signature verification, and it is
  deliberately not written into images.
- **Passwordless polkit in the live session** comes from live-config's
  `1080-policykit`, which grants the live user administrative access without a
  prompt. It exists so the installer can run, applies only while running from
  the live medium, and is removed on installation along with live-config.
- **Autologin in the live session** is the same shape: a live-config component
  guarded twice over, by the removal of live-config during installation and by a
  check that the live medium is mounted.

## Test images are not release images

Building with `STRATA_TEST_TOOLS=1` adds `qemu-guest-agent`, which lets the host
run commands inside a VM. Released images do not contain it, and the build
removes the test package list unconditionally before every build so an
interrupted test build cannot leak it into one.

Every release ships a manifest listing every package, so this is verifiable
rather than merely asserted:

```bash
grep -c qemu-guest-agent manifest-YYYY.MM.DD.txt   # expected: 0
```

## Verifying a download

```bash
sha256sum -c strata-YYYY.MM.DD-amd64.iso.sha256
```

The manifest records the snapshot timestamp and git commit the image was built
from, so it can be rebuilt and compared:

```bash
git checkout <commit>
sudo ./scripts/build-in-docker.sh <snapshot>
```

Note that this reproduces the *package set*, not a byte-identical ISO —
[ADR-0005](docs/adr/ADR-0005-build-reproducibility-and-snapshot-pinning.md)
explains why bit-for-bit reproducibility is a later goal and what is guaranteed
today.
