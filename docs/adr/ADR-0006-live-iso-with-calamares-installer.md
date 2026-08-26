# ADR-0006: Live ISO with Calamares as the Installation Path

## Status

Accepted

## Context

Two questions were left open and are coupled:

1. Is a live session required for the MVP, or is an install-only image enough?
2. Which installer does Strata use?

The original installer ranking placed Calamares last, to be used "only if
Debian-native approaches cannot satisfy usability requirements". That ranking
was written before the build technology was settled, and it does not survive the
choice of `live-build`.

`calamares-settings-debian` is an official Debian package, maintained in Debian,
and is precisely what the official Debian Live images use as their graphical
installer. Treating it as a last resort would mean treating the standard Debian
live path as an exception — the opposite of ADR-0001.

Debian Installer remains excellent, but it targets a different image type. Making
it the primary path for a live image means either shipping two installers or
giving up the live session.

A live session also has independent value for Strata specifically: Hyprland on
unfamiliar hardware is exactly the situation where a user wants to verify that
the compositor starts, the GPU works, and Wi-Fi is detected *before* committing
to an installation.

## Decision

The Strata MVP is a **live ISO with an installable session**.

Calamares, configured via `calamares-settings-debian`, is the primary
installation path.

The revised evaluation order is:

1. Debian-native live installation with Calamares — preferred,
2. classic Debian Installer — evaluated only if it demonstrates a concrete
   advantage over (1),
3. anything custom — requires its own ADR.

Deviations from `calamares-settings-debian` defaults must be minimal and
documented.

## Consequences

### Positive

- resolves the contradiction between the MVP definition of done, which requires
  installation, and the previously open live-mode question,
- uses the same tooling as official Debian Live images,
- hardware can be validated before installation,
- a live session doubles as a rescue environment,
- Secure Boot behaviour can be verified from the live image itself.

### Negative

- a live session enlarges the ISO,
- Calamares pulls a Qt stack into the image that the installed minimal desktop
  does not otherwise need,
- Calamares partitioning support for Btrfs subvolume layouts is more limited
  than Debian Installer's, which constrains ADR-0007,
- ISO size needs watching against the 2 GiB GitHub release asset limit.

## Notes

The Qt dependency is less costly than it first appears: Quickshell is itself a
Qt/QML framework, so a substantial part of that stack is already present in the
core desktop.
