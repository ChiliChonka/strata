# ADR-0001: Remain Debian, Do Not Become a Debian Fork

## Status

Accepted

## Context

Strata provides a curated Debian Testing image with Hyprland and Quickshell.

Projects of this kind can gradually accumulate:

- custom repositories,
- patched packages,
- custom update tools,
- custom kernels,
- bespoke installers,
- distribution-specific daemons.

That creates long-term maintenance burden and effectively turns a configuration project into an independent distribution.

## Decision

The installed system should remain a normal Debian Testing system wherever practical.

Strata will prefer, in this order:

1. official Debian packages,
2. standard Debian system configuration,
3. project configuration files,
4. small helper scripts.

A custom package repository is not part of the default architecture.

Before introducing a project-specific package, daemon, repository, kernel, installer component, or update mechanism, the project must first verify that the requirement cannot reasonably be solved with existing Debian-native mechanisms.

## Consequences

### Positive

- lower maintenance burden,
- Debian security and update ecosystem remains intact,
- fewer Strata-specific failure modes,
- easier troubleshooting,
- easier contribution,
- better long-term sustainability,
- installed systems remain understandable to Debian users.

### Negative

- some packages may lag upstream,
- some features may need to wait for Debian Testing,
- certain integrations may be less polished than in a fully custom distribution,
- upstream compatibility may occasionally take priority over the newest feature.

These trade-offs are accepted.

## Guiding Principle

**Strata is Debian, not a Debian fork.**
