# ADR-0016: A File Manager in the Base Image

## Status

Accepted. Amends [ADR-0012](ADR-0012-complete-desktop-minimal-applications.md),
whose application budget was "near zero".

## Context

Strata shipped no way to look at files without a terminal. ADR-0012 draws its
line between *system capability*, which must be complete, and *applications*,
which stay out, and a file manager sits awkwardly on it: it is unmistakably an
application, and a desktop that cannot show someone their own downloads folder
is unmistakably incomplete.

ADR-0012's own reference point was the Ubuntu desktop — spare, but able to do
the ordinary things. That desktop has a file manager.

## Decision

Thunar is in the base image. The application budget admits exactly one file
manager, and nothing else moves as a result: no browser, no office suite, no
editor beyond the terminal one, no IDE.

It was chosen by measuring against this image rather than by reputation.
Additional disk space on top of what Strata already installs, Debian Testing,
amd64, 2026-08-29:

| | Added | Packages | |
|---|---|---|---|
| **thunar** | **62 MB** | 67 | |
| dolphin | 388 MB | 226 | brings samba, ghostscript, flite |
| nemo | 619 MB | 292 | |
| pcmanfm-qt | 688 MB | 293 | Qt6 is already here and it still costs this |
| nautilus | 1288 MB | 524 | 24 GNOME core packages |

pcmanfm-qt is the instructive one. Being Qt-based should have made it nearly
free, since Quickshell already requires Qt6 — the "marginal footprint" rule
ADR-0009 uses would have picked it on reasoning alone. Measured, it is the
second most expensive option on the list, because it brings a large part of an
LXQt session with it. The rule survives; applying it without measuring does not.

Thunar is Xfce's file manager and does not bring Xfce. It needs
`libxfce4ui`, `libxfce4util`, `libxfce4windowing` and `libxfce4panel` — a few
hundred kilobytes of libraries — and none of `xfwm4`, `xfce4-session`,
`xfce4-panel` or `xfdesktop`. Nautilus, by contrast, pulls 24 GNOME core
packages. Strata already carries KDE libraries for Calamares without anyone
running KDE; this is the same arrangement.

Its recommends already include `gvfs-common` and `udisks2`, so removable media
mount from the file manager. Asking for `gvfs-backends` explicitly makes the
install larger rather than smaller, which is why it is not asked for.

## Consequences

### Positive

- the desktop can browse files without a terminal, which is the least a desktop
  owes someone,
- removable media mount, because udisks2 comes with it,
- 62 MB, against roughly 480 MB of headroom below the 2 GiB ceiling.

### Negative

- **It is an application in the base image, and ADR-0012 said there would be
  none.** That line is now "one file manager", which is a weaker line than "no
  applications" and will be easier to argue past next time. Anything further
  needs its own record and its own measurement.
- Thunar is GTK, and Strata's colour scheme does not reach GTK applications —
  a gap [ADR-0013](ADR-0013-typography-icons-and-one-colour-scheme.md) records
  and has not closed. It will look foreign until that is solved.
- 62 MB uncompressed on an image already at 1.52 GiB.

## Guiding Principle

One application, because a desktop that cannot show you your files is not one.
Measured, not assumed — the reasoning alone would have chosen the second worst
option on the list.
