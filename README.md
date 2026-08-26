# Strata

> A minimal Debian Testing desktop built around Hyprland and Quickshell — lightweight, Secure-Boot-friendly, and deliberately close to upstream Debian.

## Status

Early project / architecture phase.

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

Expected naming style:

```text
project-2026.08.26-amd64.iso
project-2026.08.26-amd64.iso.sha256
```

## Build philosophy

The preferred build stack is Debian-native.

The project should investigate:

- `live-build`,
- Debian Installer integration,
- Debian live tooling.

A custom installer should be avoided unless Debian tooling proves insufficient.

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

Planned branding includes:

- Strata logo and wordmark
- minimal login/greeter branding
- one default wallpaper
- subtle Quickshell styling
- project name/version presentation

The rule is simple:

> Branding may make Strata recognizable, but it must not make Strata heavy.

## Login experience

Strata should provide a clean, modern, lightweight login experience.

The implementation is intentionally not fixed yet. The design phase must compare lightweight Wayland-compatible greeters and choose the best balance of:

- reliability
- dependency footprint
- theming
- keyboard-first operation
- HiDPI
- multi-monitor behavior

A custom background and Strata logo are desirable, but not at the expense of login reliability.

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
