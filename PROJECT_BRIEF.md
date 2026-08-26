# Strata — Project Brief

## Objective

Create **Strata**, a public GitHub project that builds a minimal Debian Testing based desktop ISO using Hyprland and Quickshell.

The project should prioritize:

- low complexity,
- low system overhead,
- Secure Boot compatibility,
- Debian-native tooling,
- reproducibility,
- maintainability,
- monthly image refreshes,
- optional AI-agent integrations.

## Product Position

The project should sit between:

- plain Debian installed manually, and
- heavily opinionated desktop distributions.

It should offer a clean starting point rather than a finished personal workstation.

## Target User

Users who want:

- Debian package management,
- modern Wayland,
- Hyprland,
- Quickshell,
- a lightweight desktop,
- Secure Boot,
- minimal preinstalled software,
- full control over personalization.

## Guiding Principle

The installed system should be boring underneath and modern on top.

"Debian underneath" is a feature.

## MVP Scope

The MVP must provide:

- Debian Testing amd64
- UEFI
- Secure Boot
- installable image
- Hyprland
- Quickshell
- NetworkManager
- PipeWire
- WirePlumber
- XDG portals
- Polkit
- terminal
- launcher
- notifications
- clipboard
- screenshots
- lock/idle handling
- minimal default keybindings

## Explicitly Out of Scope for MVP

- custom kernel
- proprietary drivers
- custom package repository
- application store
- custom updater
- custom installer unless required
- large theme system
- bundled development environment
- bundled container runtime
- bundled games
- bundled AI agents
- cloud account integration

## Optional Phase 2

- lazy-install AI agent helper
- project-aware agent skill
- optional developer profile
- optional Bluetooth profile
- optional laptop profile
- optional visual theme packs


## Brand Experience

Strata should be recognizable without becoming technically or visually heavy.

Desired identity:

- modern
- restrained
- technical
- clean
- durable rather than trendy

Initial branded surfaces:

- project logo
- GitHub README
- default wallpaper
- login/greeter screen
- optional boot splash if it can be implemented cleanly

Branding is not a blocker for the technical MVP.
