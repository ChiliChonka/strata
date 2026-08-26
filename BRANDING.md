# Strata Branding

## Goal

Strata should have a recognizable identity while remaining technically minimal.

The visual language should reinforce:

- layers
- structure
- clarity
- precision
- minimalism

## Name

**Strata**

The name refers to layered structure, matching the system architecture:

```text
Presentation
Quickshell
Hyprland
Wayland services
Debian Testing
Secure Boot / UEFI
```

## Visual Direction

Prefer:

- geometric forms
- layered planes
- clean typography
- restrained visual complexity
- strong silhouette at small icon sizes
- neutral, durable design

Avoid:

- mascots unless strongly justified
- highly detailed illustrations
- gaming aesthetics
- excessive neon/cyberpunk styling
- branding tied to a specific AI provider

## Logo Requirements

The final logo should work as:

- GitHub avatar
- login mark
- menu/application icon
- documentation mark
- monochrome symbol
- small favicon-like icon

Required source assets:

```text
assets/brand/logo-mark.svg
assets/brand/wordmark.svg
assets/brand/logo.svg
```

## Wallpaper

The default wallpaper should be:

- calm
- non-distracting behind tiled windows
- suitable for 16:9 and 16:10
- visually related to layering/strata
- preferably text-free

One excellent default is preferable to a large wallpaper pack.

## Login Screen

**Not an MVP deliverable.** The MVP ships a packaged greeter with default
styling. Greeter branding is a follow-up milestone.

The eventual target, once a greeter is settled in ADR-0008:

- subtle Strata logo
- one background
- clear authentication controls
- minimal status information
- keyboard friendly
- accessible contrast

Constraint: greeter branding must work within what a Debian-packaged greeter
already supports. `tuigreet` is text-only and takes no logo at all; `gtkgreet`
accepts CSS but has limited background and multi-monitor handling. If the
desired look requires an unpackaged greeter such as ReGreet, that needs its own
ADR accepting the departure from ADR-0001 — it is not something to slip in
quietly for aesthetic reasons.

Authentication reliability takes precedence over styling. Always.

## Quickshell Styling

Use only restrained branding:

- spacing
- typography
- corner treatment
- subtle accents

Do not turn Quickshell into a large custom desktop suite during MVP.

## Licensing

All original Strata visual assets must have a documented redistribution-compatible license.
