# ADR-0003: Minimal Core, Optional Layers

## Status

Superseded by [ADR-0012](ADR-0012-complete-desktop-minimal-applications.md).

The application budget below still holds. What did not hold is the treatment of
system capability: this record left "minimal" ambiguous between *the system is
small* and *the desktop can do little*, and listed Bluetooth as an optional
layer. ADR-0012 separates the two budgets and puts Bluetooth in the base.

## Context

Strata aims to provide a lightweight Debian Testing desktop based on Hyprland and Quickshell.

Developer tools, AI agents, container platforms, IDEs, games, office applications, additional themes, and personalization can significantly increase:

- image size,
- dependency count,
- update surface,
- maintenance cost,
- security surface,
- user assumptions about how the system should be used.

Bundling these components would undermine the goal of providing a small, neutral base system.

## Decision

The base Strata image contains only the operating system and components required for a complete minimal desktop.

Core functionality includes:

- Debian Testing base,
- Secure Boot capable boot chain,
- Hyprland,
- Quickshell,
- NetworkManager,
- PipeWire,
- WirePlumber,
- XDG Desktop Portals,
- Polkit,
- lightweight authentication agent,
- terminal,
- launcher,
- notifications,
- clipboard tooling,
- screenshots,
- lock and idle handling,
- minimal default configuration.

Everything else should be optional.

Examples of optional layers:

- AI agents,
- development tools,
- container tooling,
- Bluetooth extras,
- gaming tools,
- additional themes,
- IDEs,
- office applications,
- cloud tooling.

Optional tooling should preferably be installed after system installation or through clearly separated profiles.

AI agents should follow a lazy-install approach wherever practical.

## Consequences

### Positive

- smaller image,
- faster builds,
- fewer dependencies,
- easier auditing,
- less maintenance,
- users retain control over their environment,
- Strata remains useful outside a single developer workflow.

### Negative

- users may need additional setup after installation,
- the system may feel less feature-complete than heavily opinionated distributions,
- optional profiles require documentation and possibly lightweight helper tooling.

These trade-offs are intentional.

## Guiding Principle

Strata should provide a **complete minimal desktop**, not a preconfigured personal workstation.
