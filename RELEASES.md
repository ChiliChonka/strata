# Strata Release Strategy

## Debian Testing Reality

Debian Testing does not have a traditional monthly version number.

It changes continuously.

Therefore image publication is based on project image snapshots, not Debian releases.

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

Optional signature:

```text
strata-2026.08.26-amd64.iso.sig
```

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

1. build image,
2. generate manifest,
3. run tests,
4. generate checksum,
5. create GitHub release,
6. publish ISO.

## Manual Releases

Support `workflow_dispatch`.

Manual releases are useful for:

- security fixes,
- broken previous image replacement,
- installer fixes,
- urgent Hyprland compatibility changes.

## Hosting

Start with GitHub Releases.

Only move to object storage/CDN when real usage demonstrates a need.

Avoid infrastructure before it is necessary.
