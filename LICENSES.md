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

## 4. Name and logo

The name "Strata" and the Strata logo identify this project.

The CC BY-SA license on the artwork permits redistribution and modification of
the artwork itself. It does not grant permission to present a modified or
derived distribution as being Strata, or to use the name and mark in a way that
implies endorsement by or affiliation with this project.

Fork the code freely. Please pick your own name.

This mirrors long-standing practice in Debian, Fedora, and Firefox.
