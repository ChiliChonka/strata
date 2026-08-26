# ADR-0010: XWayland Stays in the Base Image

## Status

Accepted

Resolves the open question left by ADR-0009.

## Context

ADR-0009 deferred the question of whether XWayland belongs in the base image,
and named it as the last blocker before the package lists could be frozen.

The question was originally framed as "should XWayland be added?". That framing
is wrong.

**Debian's `hyprland` package Recommends `xwayland`.** With APT's default
behaviour, Recommends are installed. XWayland therefore arrives in the image on
its own. The decision is not whether to add it, but whether to actively exclude
it — which reverses the burden of proof, because excluding it means overriding
what the Debian package maintainer considers the sane default.

ADR-0001 makes that kind of deviation something that has to be argued for, not
assumed.

## Cost

Most of XWayland's dependency closure is already present via Mesa and Hyprland.
The packages genuinely added, measured as compressed `.deb` size on amd64 in
Testing:

| Package | Size |
|---|---|
| `xserver-common` | 2397 kB |
| `xwayland` | 968 kB |
| `libepoxy0` | 193 kB |
| `libxfont2` | 133 kB |
| `libei1` | 43 kB |
| `libdecor-0-0` | 15 kB |
| `liboeffis1` | 12 kB |
| `libxshmfence1` | 10 kB |
| `libxcvt0` | 5 kB |
| **Total** | **~3.8 MB** |

Less than that once squashfs-compressed into the ISO. Against an image measured
in gigabytes, size does not decide this question in either direction.

## Decision

**XWayland stays in the base image.** Strata does not exclude it, and does not
set `--no-install-recommends` for the purpose of removing it.

Additionally, **`libqt6waylandclient6` is listed explicitly in the package
lists** rather than being relied upon transitively. See below.

## Rationale

**It is infrastructure, not an application.** ADR-0003 requires every default
package to have a clear purpose. XWayland's purpose is X11 application
compatibility. That no base package uses it is true and beside the point —
exactly as it is for `xdg-desktop-portal-gtk`, which ADR-0009 already includes
even though nothing in the base image opens a file dialog. Both are there so
that software the user installs later works. Deciding these two cases
differently would be inconsistent.

**The failure mode is bad and silent-ish.** Without XWayland, an X11 application
fails to start with an error that does not name the actual cause. The user has
to work out both that a package is missing and that installing it requires
restarting the session. For an image whose stated goal is "minimal but complete",
that is the wrong first experience.

**Excluding it is the deviation.** Overriding a Debian Recommends is a
project-specific choice that ADR-0001 asks us to justify. Saving under 4 MB does
not justify it.

## The libqt6waylandclient6 Pin

This is a separate finding from the same investigation, recorded here because it
would otherwise be lost.

Calamares does not depend on `qt6-wayland`, which raised the question of whether
the installer itself requires XWayland. It does not: the Qt6 Wayland platform
plugin `platforms/libqwayland.so` is shipped in **`libqt6waylandclient6`**, and
`quickshell` depends on that package. Calamares therefore runs Wayland-native.

But only transitively. If Quickshell's packaging ever changes, Calamares falls
back to `libqxcb.so`, which lives in `libqt6gui6` and is always present. There
would be **no error** — just an installer silently running through XWayland,
with the scaling behaviour that implies under Hyprland.

Listing `libqt6waylandclient6` explicitly costs nothing and removes a silent
failure mode.

## Consequences

### Positive

- X11 applications work without user intervention,
- Strata matches Debian's own expectations for a Hyprland installation,
- consistent with the treatment of `xdg-desktop-portal-gtk` in ADR-0009,
- the package lists can now be frozen,
- the installer's Wayland path no longer depends on another package's
  dependency graph.

### Negative

- ~3.8 MB of X11 server infrastructure that a purely Wayland user never touches,
- a background Xwayland process exists in sessions that use X11 applications,
- Strata is marginally less minimal than an XWayland-free image would be.

## Note on --no-install-recommends

This ADR decides XWayland only. Whether live-build should set
`--no-install-recommends` globally is a much broader question affecting every
package in the image, and it is not decided here. If it is ever adopted,
`xwayland` must be added back to the package lists explicitly.
