# Strata Architecture

## Layer Model

```text
+-----------------------------------+
| Optional user tooling             |
| agents / dev tools / applications |
+-----------------------------------+
| Quickshell                        |
| minimal shell UI                  |
+-----------------------------------+
| Hyprland                          |
| Wayland compositor                |
+-----------------------------------+
| Desktop infrastructure            |
| portals / polkit / pipewire       |
| network / notifications / lock    |
+-----------------------------------+
| Debian Testing                    |
| apt / systemd / signed kernel     |
+-----------------------------------+
| Debian Secure Boot chain          |
| UEFI / shim / GRUB                |
+-----------------------------------+
```

## Debian Layer

Responsibilities:

- kernel,
- boot chain,
- firmware,
- package management,
- systemd,
- userspace libraries,
- security updates.

Project policy:

Do not fork this layer.

## Desktop Infrastructure

### XDG Desktop Portals

Required for modern Wayland desktop integration.

Expected packages should be determined from Debian Testing and may include:

- xdg-desktop-portal
- xdg-desktop-portal-hyprland
- a GTK portal backend when useful for file chooser integration

### Polkit

Required for interactive privilege authorization.

Prefer a lightweight agent.

A future Quickshell-native agent is acceptable only if mature and reliable.

### PipeWire

Use:

- PipeWire
- WirePlumber

Avoid legacy PulseAudio-only architecture.

### Network

Use NetworkManager unless a strong reason exists to choose otherwise.

## Session Model

Investigate the smallest reliable session/login approach.

Candidate order:

1. TTY login + automatic/manual Hyprland start
2. greetd
3. another lightweight Wayland-capable greeter
4. traditional display manager

The default should remain simple and debuggable.

## Quickshell Design

Keep configuration modular.

Suggested modules:

```text
quickshell/
├── shell.qml
├── bar/
├── workspaces/
├── audio/
├── network/
├── battery/
└── clock/
```

The MVP should avoid building a full desktop environment.

## Hyprland Design

Keep project defaults separate from user overrides.

Suggested approach:

```text
/etc/<project>/hypr/
~/.config/hypr/
```

or another Debian-compatible layout selected during implementation.

User configuration must be easy to override.

## AI Integration

AI tooling is not part of the core runtime.

Architecture:

```text
Base ISO
   |
   +-- project agent knowledge
   |
   +-- optional lazy installer
          |
          +-- codex
          +-- claude
          +-- opencode
          +-- gemini
          +-- copilot
```

The base system must function fully without any agent provider.

## Secure Boot

Preferred chain:

```text
UEFI
 -> Debian shim
 -> signed GRUB
 -> Debian signed kernel
 -> Debian userspace
```

Do not replace this chain casually.

## Package Ownership

Project files should preferably be plain configuration files managed by the image build system.

Avoid creating Debian packages for project configuration unless packaging provides a clear lifecycle advantage.

## Update Model

System updates:

```text
APT -> Debian Testing
```

Image updates:

```text
GitHub Actions
 -> build current Testing snapshot/image
 -> validate
 -> publish image
```

These are intentionally separate concerns.


## Login and Branding Layer

Strata should eventually provide a lightweight branded login experience.

Desired presentation:

- Strata logo
- simple background
- clear username/password controls
- minimal status indicators
- keyboard-first operation

The login system must be selected based on reliability and dependency footprint first, theming second.

Do not implement authentication inside Quickshell unless that approach is mature, secure, and clearly preferable to established greeter tooling.

Branding is a presentation layer:

```text
Strata branding
   |
   +-- logo / wordmark
   +-- wallpaper
   +-- greeter theme
   +-- minimal shell accents
```

It must not affect package management, Secure Boot, or session reliability.
