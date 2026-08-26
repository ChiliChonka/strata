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
- Reproducible ISO builds, meaning script-driven repeatability plus snapshot
  pinning (ADR-0005) — not bit-identical output
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
4. Reproducible ISO creation as defined in ADR-0005.
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

**Decided: `live-build`.** It is the Debian-native tool for exactly this job and
is available in Testing. Do not invent a new build system, and do not wrap
live-build in an abstraction layer that hides how it works.

The build must be repeatable from repository contents with no manual
interaction: a clean checkout plus one documented command produces an image.

Every build pins a `snapshot.debian.org` timestamp and exports
`SOURCE_DATE_EPOCH` derived from that same timestamp (ADR-0005).

**Critical constraint.** The snapshot mirror is build-time only. It configures
`--mirror-bootstrap` and `--mirror-chroot`. The `--mirror-binary` settings, which
the installed system inherits, must always point at the live Debian archive. A
snapshot URL reaching an installed `sources.list` freezes that installation and
cuts it off from security updates.

## Installer Strategy

**Decided: live ISO with Calamares** (ADR-0006).

`calamares-settings-debian` is an official Debian package and is what the
official Debian Live images use. It is the Debian-native path for a live image,
not a fallback.

Evaluation order:

1. Debian-native live installation with Calamares via `calamares-settings-debian`
2. classic Debian Installer, only if it shows a concrete advantage over (1)
3. anything custom, only with its own ADR

Keep deviations from `calamares-settings-debian` defaults minimal and document
each one.

The installed result must remain a standard Debian Testing installation.

## Filesystem

Evaluate ext4 and Btrfs. The decision belongs in ADR-0007.

Default to the simpler and more robust option unless Btrfs provides a clearly
documented benefit that is deliverable with Debian-packaged tooling alone.

Snapshots must not become mandatory for the MVP, and no snapshot workflow may
require a package that is not in Debian Testing.

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

Use date-based image versions. Artifact names are fixed and used verbatim
everywhere:

```text
strata-YYYY.MM.DD-amd64.iso
strata-YYYY.MM.DD-amd64.iso.sha256
strata-YYYY.MM.DD-amd64.iso.sig
```

Do not introduce alternative names or prefixes in documentation, scripts, or
workflows.

## CI/CD

GitHub Actions should support:

- scheduled monthly evaluation,
- manual workflow dispatch with an explicit snapshot timestamp,
- ISO build against a pinned snapshot,
- build manifest generation, recording the snapshot timestamp,
  `SOURCE_DATE_EPOCH`, git commit, and exact package versions,
- checksum generation,
- boot testing,
- release artifact generation,
- release publication.

Do not automatically publish broken or untested images.

Watch the image size against GitHub's 2 GiB per-release-asset limit. A live ISO
with Hyprland and Calamares can approach it.

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

A repeatably built, snapshot-pinned Debian Testing amd64 **live ISO** that:

- boots in UEFI mode,
- supports Secure Boot,
- provides a usable live session before installation,
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

The login experience is evaluated on technical fit first, using only greeters
packaged in Debian Testing:

1. `greetd` with `tuigreet` or `gtkgreet` under `cage`,
2. TTY login with Hyprland started from the shell profile,
3. a traditional display manager only if technically justified.

`ReGreet` is not packaged in Debian Testing. Do not build it from source without
an ADR that explicitly accepts the exception to ADR-0001.

Required of the greeter for the MVP:

- reliable username/password login
- keyboard-first navigation

Desirable later, not MVP requirements:

- Strata logo
- custom background
- HiDPI
- multi-monitor handling
- session selection

Boot and authentication reliability take priority over appearance.

**For the MVP, greeter branding is out of scope.** Ship default greeter styling.
A branded greeter is a separate milestone that must not be traded against login
reliability.

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
