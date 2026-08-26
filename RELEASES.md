# Strata Release Strategy

## Debian Testing Reality

Debian Testing does not have a traditional monthly version number.

It changes continuously.

Therefore image publication is based on project image snapshots, not Debian
releases.

Because the suite is a moving target, every build pins a `snapshot.debian.org`
timestamp and records it. That pin is what makes a published image rebuildable
later. See
[ADR-0005](adr/ADR-0005-build-reproducibility-and-snapshot-pinning.md) —
including the rule that the pin must never reach an installed system's
`sources.list`.

## Recommended Versioning

Use build dates:

```text
YYYY.MM.DD
```

Example:

```text
2026.08.26
```

Artifact names:

```text
strata-2026.08.26-amd64.iso
strata-2026.08.26-amd64.iso.sha256
```

Signature:

```text
strata-2026.08.26-amd64.iso.sig
```

These three names are canonical. Do not use any other prefix or ordering in
documentation, scripts, or workflows.

Each release additionally ships a build manifest recording:

- the `snapshot.debian.org` timestamp,
- the Debian codename and suite,
- `SOURCE_DATE_EPOCH`,
- the Strata git commit,
- the live-build version,
- every package with its exact version.

## Monthly Evaluation

Run a scheduled workflow once per month.

The workflow should compare the current build-relevant package state against the last published release.

Relevant packages include:

- linux-image-amd64
- grub
- shim
- Hyprland
- Quickshell
- Mesa
- Wayland
- PipeWire
- WirePlumber
- NetworkManager
- firmware
- live-build / installer components

If nothing meaningful changed, the workflow may skip publication.

If relevant components changed:

1. pin a snapshot timestamp and derive `SOURCE_DATE_EPOCH` from it,
2. build image from the pinned archive state,
3. generate manifest,
4. run tests, including the check that no snapshot URL leaked into the
   installed `sources.list`,
5. generate checksum,
6. create GitHub release,
7. publish ISO.

## Manual Releases

Support `workflow_dispatch`, accepting an explicit snapshot timestamp so any
previously published image can be rebuilt on demand.

Manual releases are useful for:

- security fixes,
- broken previous image replacement,
- installer fixes,
- urgent Hyprland compatibility changes,
- reproducing a past image for auditing.

## Hosting

Start with GitHub Releases.

**Constraint:** GitHub caps individual release assets at 2 GiB. A live ISO
carrying Hyprland, Quickshell, and Calamares can get close to that. Track image
size from the first successful build, and treat approaching the limit as a
release blocker to be solved by trimming the image, not by adding
infrastructure.

Only move to object storage/CDN when real usage demonstrates a need.

Avoid infrastructure before it is necessary.
