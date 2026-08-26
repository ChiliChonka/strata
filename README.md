# Strata

> A minimal Debian Testing desktop built around Hyprland and Quickshell — lightweight, Secure-Boot-friendly, and deliberately close to upstream Debian.

## Status

Early project / architecture phase. No image is published yet.

Key decisions are recorded in [docs/adr/](docs/adr/).

## What this project is

**Strata** builds a minimal, reproducible Linux image based on Debian Testing.

The intended stack is:

```text
Debian Testing
    |
    +-- Debian signed boot chain
    +-- Wayland
    +-- Hyprland
    +-- Quickshell
    +-- PipeWire + WirePlumber
    +-- XDG Desktop Portals
    +-- Polkit
    +-- NetworkManager
```

The goal is a small, modern Wayland desktop that remains as close as possible to ordinary Debian.

## What this project is not

This project is not intended to become an independent Linux distribution with its own package universe.

It does not aim to:

- fork Debian,
- replace APT,
- maintain a custom kernel,
- operate a custom package repository by default,
- bundle a large application suite,
- recreate Omarchy,
- ship a fully personalized developer workstation.

## Core principle

**This is Debian, not a Debian fork.**

After installation, the system should remain a normal Debian Testing installation wherever practical.

Packages, kernels, security fixes, firmware, and system libraries should come from official Debian repositories.

Project-specific components should be limited primarily to:

- image build configuration,
- package selection,
- Hyprland defaults,
- Quickshell defaults,
- small helper scripts,
- optional integrations,
- documentation.

## Why Debian Testing?

Hyprland and the surrounding Wayland ecosystem move quickly.

Debian Testing provides a useful compromise:

- newer packages than Debian Stable,
- Debian's package ecosystem,
- Debian-native Secure Boot support,
- APT,
- no need to adopt a completely different operating model such as NixOS,
- less distribution-specific customization than a heavily opinionated desktop distribution.

## Why Hyprland?

Hyprland provides a modern Wayland-native tiling workflow with:

- keyboard-oriented window management,
- workspaces,
- efficient desktop interaction,
- a lightweight compositor stack,
- strong integration with modern Wayland tools.

## Why Quickshell?

Quickshell provides a programmable shell framework for lightweight desktop UI.

The default project configuration should remain intentionally small.

Expected initial components:

- workspace indicator,
- clock,
- network state,
- volume,
- battery state.

Users should be able to replace or extend the configuration easily.

## Desktop infrastructure

A minimal desktop still needs several supporting components.

### XDG Desktop Portals

Desktop portals provide standardized interfaces for operations such as:

- file pickers,
- opening files and URLs,
- screen sharing,
- screen capture,
- sandboxed application integration.

For Hyprland, `xdg-desktop-portal-hyprland` is particularly important for screen sharing and Wayland integration.

### Polkit

Polkit provides authorization for privileged desktop operations.

A Polkit authentication agent is required so graphical applications can request authorization interactively.

### PipeWire

PipeWire provides the modern Linux audio/video routing layer.

It is used for:

- application audio,
- microphone input,
- Bluetooth audio,
- screen sharing,
- recording,
- multimedia routing.

WirePlumber is used as the session manager.

## Secure Boot

Secure Boot is a first-class project requirement.

The preferred implementation uses Debian's own signed boot chain and signed kernel packages.

The normal user experience should not require disabling Secure Boot or enrolling custom Machine Owner Keys.

## Minimal by design

The default ISO should not include large application stacks.

Examples of software that should not be installed by default:

- LibreOffice
- GNOME
- KDE Plasma
- IDEs
- Docker
- Kubernetes
- Steam
- office suites
- chat applications
- game launchers
- large theme collections

Optional software belongs in optional layers or post-install tooling.

## Optional AI agent support

AI coding agents are useful but should not enlarge the base image unnecessarily.

The project intends to support lazy installation of tools such as:

- OpenAI Codex CLI
- Claude Code
- OpenCode
- Gemini CLI
- GitHub Copilot CLI

A generic provider-neutral interface may later expose commands such as:

```text
agent install codex
agent default codex
agent run
```

Agents should be downloaded only when the user explicitly chooses them.

## Project-aware agent support

The project should provide agent documentation or skills that describe:

- system architecture,
- Debian-first rules,
- package management,
- Hyprland configuration,
- Quickshell configuration,
- build and test commands,
- repository conventions.

This allows coding agents to modify the system without violating project design principles.

## Updates

Installed systems should use ordinary Debian commands:

```bash
sudo apt update
sudo apt full-upgrade
```

There should be no custom system update service unless a future technical requirement strongly justifies one.

## Releases

Debian Testing is rolling release.

The project therefore does not wait for a new "Debian Testing version".

Instead, once per month CI should evaluate whether relevant upstream components changed.

If meaningful changes exist, a new image is built, tested, checksummed, and published.

Artifact naming:

```text
strata-2026.08.26-amd64.iso
strata-2026.08.26-amd64.iso.sha256
strata-2026.08.26-amd64.iso.sig
```

Each release also ships a build manifest recording the exact
`snapshot.debian.org` timestamp and package versions the image was built from,
so any published image can be rebuilt later. See
[ADR-0005](docs/adr/ADR-0005-build-reproducibility-and-snapshot-pinning.md).

## Build philosophy

The build stack is Debian-native: **`live-build`**, producing a **live ISO** with
**Calamares** as the installer, configured through the official
`calamares-settings-debian` package.

That is the same path the official Debian Live images take. See
[ADR-0006](docs/adr/ADR-0006-live-iso-with-calamares-installer.md).

Builds are pinned to a `snapshot.debian.org` timestamp so a published image can
be rebuilt from the same package set later. "Reproducible" here means
script-driven repeatability plus snapshot pinning — bit-identical ISOs are a
later goal, not a release requirement. See
[ADR-0005](docs/adr/ADR-0005-build-reproducibility-and-snapshot-pinning.md).

A custom installer is out of scope.

## Testing

Automated validation should use QEMU/KVM where practical.

Target checks include:

- UEFI boot,
- Secure Boot,
- kernel startup,
- networking,
- Hyprland startup,
- Quickshell startup,
- PipeWire/WirePlumber,
- desktop portals,
- installer viability.

## Project maturity

The first milestone is not a polished distribution.

The MVP is:

> A reproducibly built Debian Testing amd64 ISO that boots with Secure Boot enabled and provides a functional minimal Hyprland + Quickshell desktop.

## License

Strata's own configuration, scripts, and documentation are MIT licensed.
Original visual assets are CC BY-SA 4.0. A built ISO is an aggregation of Debian
packages, each keeping its own upstream license.

See [LICENSES.md](LICENSES.md) for details, including what the license does and
does not permit regarding the Strata name.

## Contributing

Contributions should preserve:

- minimalism,
- Debian compatibility,
- reproducibility,
- Secure Boot,
- maintainability.

Before adding a custom component, ask:

> Can this be solved with an existing Debian package or configuration?

If yes, prefer that solution.


## Visual identity

Strata has its own lightweight visual identity without becoming a custom desktop environment.

Planned for the MVP:

- Strata logo and wordmark
- one default wallpaper
- subtle Quickshell styling
- project name/version presentation

Deferred to a later milestone:

- login/greeter branding

The rule is simple:

> Branding may make Strata recognizable, but it must not make Strata heavy.

## Login experience

Strata aims for a small, reliable, keyboard-friendly login.

The working assumption is `greetd` with a Debian-packaged greeter — `tuigreet`
or `gtkgreet` under `cage`. The final choice is pending an ADR and is made on
reliability and dependency footprint, not appearance.

A branded greeter with a custom background and the Strata logo is a later
milestone. The obvious candidate for that, ReGreet, is not currently packaged in
Debian Testing, and building it from source would require an explicit exception
to the Debian-first rule.

Login reliability wins over login aesthetics, without exception.

## Why the name Strata?

The name reflects the project's layered architecture:

```text
optional tools
Quickshell
Hyprland / Wayland
Debian Testing
Secure Boot / UEFI
```

Each layer should stay understandable and replaceable.
