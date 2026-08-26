# ADR-0004: Branding Without Building a Custom Desktop Environment

## Status

Accepted

## Context

Strata should be recognizable, but excessive branding can introduce custom daemons, fragile login components, large dependencies, and long-term maintenance cost.

## Decision

Strata may own:

- logo
- wordmark
- wallpaper
- greeter theme
- minimal Quickshell styling
- documentation visuals

Branding remains a presentation layer.

It must not require:

- a custom compositor
- a custom authentication daemon
- a custom display server
- a large theming framework
- an independent desktop environment

## Consequences

Strata can have a polished identity while remaining close to Debian.

Visual ideas that materially increase runtime or maintenance complexity may be rejected.
