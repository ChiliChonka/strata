# ADR-0013: Typography, Icons, and One Colour Scheme

## Status

Accepted. Settles the package selection [ADR-0012](ADR-0012-complete-desktop-minimal-applications.md)
deferred, and extends [ADR-0009](ADR-0009-default-package-selection.md).

## Context

The base image shipped exactly three font families — DejaVu Sans, Serif and Mono
— and the Adwaita and hicolor icon themes. Every colour in the system was
written by hand in the file that used it: the bar in `shell.qml`, window borders
in `hyprland.lua`, and nothing at all for the terminal, the launcher, or
notifications, which each used their own defaults.

Two consequences followed. Changing one colour meant editing several files in
several syntaxes and finding all of them. And the parts did not match, because
nothing required them to.

Verified against Debian Testing (forky), amd64, on 2026-08-28.

## Decision

### Typography

| Role | Chosen | Size | Deps | Rejected |
|---|---|---|---|---|
| Interface | `fonts-inter-variable` 4.1 | 1.8 MB | none | `fonts-inter` (21 MB, same faces), `fonts-cantarell`, DejaVu Sans |
| Terminal | `fonts-jetbrains-mono` 2.304 | 7.4 MB | none | `fonts-firacode` (2.9 MB), DejaVu Sans Mono |
| Icons | `fonts-material-design-icons-iconfont` 6.7 | 1.1 MB | none | `papirus-icon-theme` (191 MB), `fonts-font-awesome` |

Total 10.3 MB, and not one of the three pulls a dependency.

`fonts-inter` and `fonts-inter-variable` are the same typeface; the variable
build is one file covering every weight, at a twelfth of the size. There is no
argument for the static one here.

`papirus-icon-theme` is 191 MB — a tenth of the whole image — for artwork that
is mostly application icons the base image has no applications for. The
Material icon font is a font: it renders at any size, follows the text colour,
and costs a hundredth as much.

That font is chosen for one property beyond its looks: it resolves **ligatures**,
so an icon is written by name.

```qml
Text { text: "bluetooth"; font.family: "Material Icons" }
```

No codepoint tables. Someone reading a bar element sees the word for the thing
they are looking at, which is what ADR-0012 requires of anything Strata ships.

Emoji are deliberately left out. `fonts-noto-color-emoji` is 10.9 MB and matters
only for notification text from applications that are not installed by default.
It is a candidate for an optional component, not for the base image.

### One colour scheme, five dialects

Colour is defined once, in a scheme file, and translated into each
application's own configuration language by `/usr/lib/strata/apply-theme`:

| Target | Written to | Mechanism |
|---|---|---|
| Quickshell | `/etc/xdg/quickshell/Colors.qml` | generated QML singleton |
| foot | `/etc/strata/theme/foot.ini` | pulled in by `include=`, verified supported |
| fuzzel | `/etc/xdg/fuzzel/fuzzel.ini` | generated whole — fuzzel has no include |
| mako | `/etc/strata/theme/mako.conf` | passed with `mako -c`, verified supported |
| Hyprland | `/etc/strata/theme/colors.lua` | `dofile`, with a fallback if absent |

The format is **base16**: sixteen slots with settled meanings, shared by a large
body of existing schemes. Strata ships `strata-dark` and `strata-light` in that
format and adds nothing to it. Anyone who prefers a different desktop drops a
scheme into `~/.local/share/strata/themes` and runs `strata theme set <name>`;
bar, launcher, notifications, window borders and terminal all follow. That
interoperability is the reason for choosing an existing format over a better
tuned private one.

`Theme.qml` holds names — `bar`, `raised`, `accent`, `danger`, the radii, the
animation timings — and reads its colours from the generated `Colors.qml`. A
part written by a user says `Theme.accent`, never a hex value.

## Consequences

### Positive

- one edit changes the colour of the whole desktop, including the terminal,
- existing base16 schemes work without Strata knowing about them,
- the interface stops looking like four programs that share a screen,
- icons cost 1.1 MB and are written as words.

### Negative

- **10.3 MB added to the base image**, against a 2 GiB ceiling that ADR-0012
  declined to raise.
- `apply-theme` is a generator, and generated files invite hand-editing that
  gets silently overwritten. Every output says so in its first line.
- Strata now owns `/etc/xdg/fuzzel/fuzzel.ini` outright, which is a package
  conffile. A fuzzel upgrade that changes it will prompt, and the prompt will be
  confusing. Accepted because fuzzel offers no include; revisit if it gains one.
- A scheme is sourced as shell. `apply-theme` refuses any line that is not a
  plain assignment, which is a check, not a sandbox.
- Qt and GTK applications do not follow this scheme. They read their own theme
  settings, and making them agree is a separate problem this record does not
  solve.

## Guiding Principle

One decision about colour, expressed once, translated as many times as there are
applications that insist on their own syntax.
