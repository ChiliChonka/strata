# AGENTS.md

## Project Name

**Strata**

## Project Mission

Build and maintain **Strata**, a minimal, reproducible Debian Testing based Linux ISO with:

- Debian Testing as the upstream operating system
- Hyprland as the Wayland compositor
- Quickshell as the shell/UI framework
- Secure Boot support using Debian-native components wherever possible
- Minimal default software
- Optional developer and AI-agent tooling installed lazily on demand
- Reproducible ISO builds
- Monthly release evaluation and image generation

The resulting installed system must remain, as far as practical, a normal Debian Testing system.

## Core Architecture Rule

**This is Debian, not a Debian fork.**

Do not create a separate package distribution, custom kernel, independent package universe, or project-specific package repository unless there is a strong technical reason and it is explicitly justified.

Before introducing any project-specific daemon, binary, package, repository, installer, boot component, or update mechanism, first determine whether the requirement can be solved with:

1. an existing Debian package,
2. a Debian-native configuration,
3. a small declarative config file,
4. a small shell helper script.

Prefer Debian-native solutions.

## Primary Goals

1. Minimal system footprint.
2. Reliable Secure Boot support.
3. Current Hyprland and Quickshell from Debian Testing where feasible.
4. Reproducible ISO creation.
5. Easy local rebuilds.
6. Automated CI validation.
7. Monthly image publication when meaningful upstream changes exist.
8. No unnecessary bundled applications.
9. No hidden manual build steps.
10. Easy extensibility for personal configurations and optional tooling.

## Non-Goals

Do not:

- fork Debian,
- maintain an independent package ecosystem,
- build a custom kernel without a compelling reason,
- ship proprietary GPU drivers by default,
- copy Omarchy wholesale,
- create a large preconfigured desktop suite,
- bundle full IDEs,
- bundle games,
- bundle office software,
- bundle container platforms by default,
- create a proprietary update mechanism,
- create a large custom installer unless Debian tooling is insufficient,
- introduce complex infrastructure for features that can remain optional.

## Mandatory Technical Principles

### Debian First

Use official Debian Testing repositories whenever possible.

Third-party repositories must be treated as exceptions and documented with:

- why Debian packages are insufficient,
- security implications,
- update implications,
- removal strategy.

### Secure Boot

Secure Boot must be treated as a first-class requirement.

Prefer Debian's existing signed boot chain:

- shim,
- GRUB,
- Debian signed kernel,
- Debian firmware,
- Debian installer/live tooling.

Do not require users to disable Secure Boot for normal operation.

Do not introduce custom Machine Owner Keys unless unavoidable.

### Minimal Desktop

The default graphical stack should contain only the components necessary for a functional desktop:

- Hyprland
- Quickshell
- xdg-desktop-portal
- xdg-desktop-portal-hyprland
- PipeWire
- WirePlumber
- Polkit
- a lightweight Polkit authentication agent or Quickshell integration
- NetworkManager
- a minimal terminal
- a minimal launcher
- notification support
- clipboard support
- screenshot support
- lock/idle support
- file chooser support where necessary

Every package included by default should have a clear purpose.

### Quickshell

Quickshell should provide a minimal shell layer only.

Default UI should be limited to useful essentials such as:

- workspace indicator,
- clock,
- network status,
- volume,
- battery status where applicable.

Do not build a large widget suite for the MVP.

### Hyprland

Provide only a minimal usable default configuration.

Required capabilities:

- open terminal,
- launch application,
- close window,
- change focus,
- move windows,
- switch workspaces,
- logout.

Avoid excessive theming, animations, or opinionated keymaps.

## AI Agent Support

AI tooling is an optional layer and must not bloat the base ISO.

Supported initial targets:

- OpenAI Codex CLI
- Claude Code
- OpenCode
- Gemini CLI
- GitHub Copilot CLI

Do not preinstall complete agent stacks in the base image unless they are tiny and dependency-free.

Prefer lazy installation.

A future generic helper may expose commands such as:

```text
agent install codex
agent install claude
agent install opencode
agent install gemini
agent install copilot

agent default codex
agent run
```

The implementation must remain provider-neutral.

Agent integrations should be modular.

## Project Agent Skill

Provide project-specific agent documentation so supported coding agents understand:

- Debian package conventions,
- project directory structure,
- Hyprland configuration locations,
- Quickshell configuration locations,
- build workflow,
- release workflow,
- project constraints,
- troubleshooting conventions,
- Debian-first policy.

This documentation should avoid vendor-specific assumptions.

## Build System

Investigate Debian-native image tooling first.

Preferred candidates:

1. live-build
2. Debian Installer based image generation
3. Debian live tooling

Avoid inventing a new build system.

The build must be reproducible from repository contents with minimal manual interaction.

## Installer Strategy

Do not build a custom installer unless necessary.

Evaluate in this order:

1. Debian Installer
2. Debian Live Installer
3. Calamares only if Debian-native approaches cannot satisfy usability requirements

The installed result should remain a standard Debian Testing installation.

## Filesystem

Evaluate ext4 and Btrfs.

Default to the simpler and more robust option unless Btrfs provides a clearly documented benefit.

Snapshots must not become mandatory for the MVP.

## Updates

Installed systems must use standard Debian update mechanisms:

```bash
sudo apt update
sudo apt full-upgrade
```

Do not introduce a custom package update framework.

## Release Strategy

Debian Testing is rolling and does not produce conventional monthly releases.

The project should therefore run a monthly release evaluation.

A new ISO should be published when relevant upstream changes occurred since the previous image.

Relevant components include:

- Debian base packages,
- kernel,
- Hyprland,
- Quickshell,
- Mesa,
- Wayland,
- PipeWire,
- WirePlumber,
- NetworkManager,
- firmware,
- installer components,
- Secure Boot components.

Prefer date-based image versions such as:

```text
2026.08.26
2026.09.26
```

The agent may propose a better versioning scheme if it remains simple and transparent.

## CI/CD

GitHub Actions should support:

- scheduled monthly evaluation,
- manual workflow dispatch,
- ISO build,
- package manifest generation,
- checksum generation,
- boot testing,
- release artifact generation,
- release publication.

Do not automatically publish broken or untested images.

## Testing

Automate as much as practical with QEMU/KVM.

At minimum validate:

- ISO builds successfully,
- UEFI boot works,
- kernel boots,
- root filesystem starts,
- networking is available,
- Hyprland can start,
- Quickshell can start,
- PipeWire/WirePlumber start,
- required portals are present,
- Secure Boot chain remains valid.

Document tests that cannot be performed reliably in CI.

## Repository Quality

Prefer:

- small scripts,
- readable shell,
- explicit package lists,
- comments for non-obvious decisions,
- idempotent build steps,
- predictable directory names,
- no generated files committed unless necessary.

## Decision Process

For major decisions, document:

- problem,
- options,
- trade-offs,
- chosen approach,
- reason.

Store important decisions under `docs/adr/`.

## First Implementation Phase

Before writing major implementation code, produce a technical design covering:

1. ISO build technology
2. Secure Boot strategy
3. package selection
4. Hyprland setup
5. Quickshell setup
6. login/session strategy
7. installer strategy
8. filesystem decision
9. CI design
10. QEMU testing
11. release/version strategy
12. artifact hosting
13. repository structure
14. risks
15. MVP milestones

Do not overbuild the MVP.

## MVP Definition

A reproducibly built Debian Testing amd64 ISO that:

- boots in UEFI mode,
- supports Secure Boot,
- provides a functional Hyprland session,
- starts a minimal Quickshell shell,
- has networking and audio,
- provides the required desktop portal/polkit infrastructure,
- can be installed to disk,
- remains a normal Debian Testing system after installation.


## Branding and Login Experience

Strata may have its own visual identity, but branding must remain lightweight, replaceable, and separate from the system architecture.

Allowed project-owned visual assets include:

- Strata logo and wordmark
- login/greeter background
- default wallpaper
- optional boot splash artwork where technically appropriate
- restrained Quickshell styling
- project name/version presentation

Branding must not require a heavy desktop environment or a large runtime framework.

The login experience must be evaluated in this order:

1. lightweight Wayland-native greeter with theming support,
2. greetd-compatible graphical greeter,
3. another lightweight display manager only if technically justified.

The greeter should ideally support:

- Strata logo
- custom background
- username/password login
- keyboard-first navigation
- HiDPI
- multi-monitor handling
- session selection where useful

Boot and authentication reliability take priority over appearance.

For the technical MVP, branding is optional. A polished greeter is a follow-up milestone if it adds meaningful complexity.

## Branding Asset Policy

Keep branding assets separate from functional configuration.

Suggested structure:

```text
assets/
├── brand/
│   ├── logo-mark.svg
│   ├── wordmark.svg
│   └── logo.svg
├── wallpapers/
│   └── default.*
└── greeter/
    └── background.*
```

Prefer SVG for logos.

Do not hard-code branding into boot, authentication, package management, or update logic.
