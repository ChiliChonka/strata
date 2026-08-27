# Strata Licensing

Strata is a build configuration project. Three different things in this
repository carry three different licenses.

## 1. Strata's own code and configuration — MIT

Everything in this repository that Strata itself authors is MIT licensed. See
[LICENSE](LICENSE).

This covers:

- image build configuration,
- package lists,
- Hyprland default configuration,
- Quickshell default configuration,
- helper scripts,
- CI workflows,
- documentation.

MIT is deliberate. Strata's product position is "a clean starting point rather
than a finished workstation", so lifting a config fragment into a personal
dotfiles repository should carry no obligations.

## 2. Strata's visual assets — CC BY-SA 4.0

Original visual assets under `assets/` are licensed under
[Creative Commons Attribution-ShareAlike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/).

This covers the logo mark, wordmark, wallpapers, and greeter artwork.

See [assets/LICENSE](assets/LICENSE).

## 3. The contents of a built ISO — not covered here

A Strata ISO is an aggregation of Debian packages. Each package keeps its own
upstream license, exactly as shipped by Debian. Strata's MIT license applies to
the build configuration that selects and configures those packages, not to the
packages themselves.

Every published image ships a package manifest so the contents can be audited.

## 4. Debian's trademarks

Debian is a registered trademark of Software in the Public Interest, Inc. Strata
is not affiliated with, nor endorsed by, the Debian project.

Strata states factually that it is built on Debian and ships Debian packages —
which Debian's trademark policy permits without asking. What that policy does
**not** permit, and what Strata therefore does not do, is use Debian's logos as
part of its own logo or branding. A Strata mark derived from the Debian swirl
would be exactly that, however it were restyled.

Note that this is a separate question from copyright. The Debian Open Use Logo
is released under LGPL-3+ or CC BY-SA 3.0, so modifying it is permitted by its
licence; that licence grants no trademark rights, and says outright that use
"does not indicate endorsement by the project".

This is the same principle Strata applies to its own name below, pointed the
other way.

## 5. Strata's name and logo

The name "Strata" and the Strata logo identify this project.

The CC BY-SA license on the artwork permits redistribution and modification of
the artwork itself. It does not grant permission to present a modified or
derived distribution as being Strata, or to use the name and mark in a way that
implies endorsement by or affiliation with this project.

Fork the code freely. Please pick your own name.

This mirrors long-standing practice in Debian, Fedora, and Firefox.
