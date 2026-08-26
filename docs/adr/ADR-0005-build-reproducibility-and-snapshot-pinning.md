# ADR-0005: Build Reproducibility and Snapshot Pinning

## Status

Accepted

## Context

Strata's documentation repeatedly requires "reproducible" builds. The term was
never defined, and taken literally it conflicts with the rest of the
architecture: Debian Testing is a rolling suite that changes daily. Two builds
from the same git commit, run a week apart, will pull different packages and
produce a different image.

Three distinct properties were being conflated:

1. **Repeatability** — anyone can rebuild the image from repository contents
   with no hidden manual steps.
2. **Historical reproducibility** — a previously published image can be rebuilt
   later from the same package set.
3. **Bit-identical output** — two builds produce byte-for-byte identical ISOs.

These have very different costs. (1) is a matter of build hygiene. (2) requires
pinning an archive state. (3) additionally requires eliminating every source of
non-determinism in squashfs, ISO generation, initramfs, timestamps, file
ordering, and package maintainer scripts — a large, ongoing effort that the
Reproducible Builds project has spent years on.

Committing to (3) as an MVP requirement would stall the project.

## Decision

Strata defines "reproducible" as **(1) and (2), but not (3)**.

### Required for MVP

**Repeatability.** A clean checkout plus a single documented build command must
produce a working image. No manual steps, no undocumented host dependencies, no
interactive prompts.

**Historical reproducibility via snapshot pinning.** Every build resolves
packages from a fixed `snapshot.debian.org` timestamp rather than a live mirror.
Every release records that timestamp. Rebuilding from the recorded timestamp
yields the same package set.

### Explicitly not required for MVP

**Bit-identical ISOs** are a desirable later goal, not a release gate. Strata
should avoid introducing gratuitous non-determinism, and `SOURCE_DATE_EPOCH` is
set from the start so the option stays open, but a diverging checksum between
two builds of the same snapshot is not a bug that blocks a release.

## Mechanism

### Snapshot archive

Builds bootstrap from:

```text
https://snapshot.debian.org/archive/debian/<YYYYMMDDTHHMMSSZ>/
```

Verified to serve Testing correctly, e.g. `20260801T000000Z` resolves to
`Suite: testing, Codename: forky`.

Pin the **codename** (`forky`), not the `testing` alias. The alias moves to a new
codename at every Debian release; the codename is stable forever. Record both.

### Expired Release files

Snapshot `Release` files carry a `Valid-Until` in the past. APT rejects them by
default, which is the single most common way a snapshot-pinned build fails.

Build-time APT configuration must therefore set:

```text
Acquire::Check-Valid-Until "false";
```

This is safe here because the archive is content-addressed and the build still
verifies the Debian archive signature. It disables freshness checking, not
authenticity checking.

### The pin must not leak into installed systems

This is critical and easy to get wrong.

The snapshot mirror is a **build-time** concern only. If it ends up in the
installed system's `sources.list`, every Strata installation is frozen at the
image's snapshot date and stops receiving security updates — which would
directly violate ADR-0001.

Concretely, for live-build:

| Setting | Value |
|---|---|
| `--mirror-bootstrap` | snapshot URL |
| `--mirror-chroot` | snapshot URL |
| `--mirror-chroot-security` | snapshot URL |
| `--mirror-binary` | `https://deb.debian.org/debian/` |
| `--mirror-binary-security` | `https://security.debian.org/debian-security/` |

The `binary` mirrors are what the installed system inherits. They must always
point at the live Debian archive.

A build test must assert that no snapshot URL appears in the installed
`sources.list`.

### SOURCE_DATE_EPOCH

`SOURCE_DATE_EPOCH` is exported for every build, derived from the same snapshot
timestamp:

```bash
SOURCE_DATE_EPOCH=$(date -u -d "${SNAPSHOT_TIMESTAMP}" +%s)
```

Keeping the two derived from one source prevents them from drifting apart.

### Build manifest

Every published image ships a build manifest recording at minimum:

- snapshot timestamp,
- Debian codename and suite,
- `SOURCE_DATE_EPOCH`,
- Strata git commit,
- live-build version,
- full package list with exact versions,
- host distribution used for the build.

The manifest is what makes a rebuild possible. It is a release artifact, not a
committed file.

### Choosing a timestamp

The monthly release workflow selects a recent snapshot timestamp and pins it for
that build. A manual `workflow_dispatch` build accepts an explicit timestamp so
any past release can be rebuilt on demand.

## Consequences

### Positive

- published images can be rebuilt and audited after the fact,
- CI builds stop being a moving target, so a failed build is a real regression
  rather than archive drift,
- security incidents can be traced to an exact package set,
- the path to bit-identical builds stays open without blocking the MVP,
- installed systems keep tracking Debian Testing normally.

### Negative

- `snapshot.debian.org` is slower than a regular mirror and is rate-limited,
  so CI needs a package cache and generous timeouts,
- builds are pinned to a slightly older archive state than a live mirror,
- an extra APT configuration knob is required at build time,
- the build/installed mirror split is a permanent correctness trap that needs a
  regression test.

## Open Questions

- Whether `snapshot.debian.org` throughput is sufficient for CI builds, or
  whether a caching proxy is needed.
- Whether the monthly evaluation compares snapshot timestamps or package
  versions when deciding if a rebuild is warranted.
