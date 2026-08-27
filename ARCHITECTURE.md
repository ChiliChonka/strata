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

The shell reads state from `nmcli` and offers only the two actions a bar is
expected to have — toggle the radio, join a network. Anything further is
`nmtui`'s job (ADR-0009, ADR-0012).

## Session Model

The session layer is chosen for reliability and dependency footprint first.
Appearance is a later concern (ADR-0004).

`greetd` is the working assumption: it is in Debian Testing, it is small, and it
is Wayland-native. The remaining question is which greeter runs on top of it.

Candidate order:

1. greetd with a packaged greeter — `tuigreet` (text) or `gtkgreet` under `cage`
   (graphical, CSS themable)
2. TTY login with Hyprland started from the shell profile — the fallback that
   always works and is trivially debuggable
3. a traditional display manager, only with a concrete technical justification

`ReGreet` would be the natural graphical choice but is **not packaged in Debian
Testing**. Using it would mean building from source, which ADR-0001 rules out
unless a dedicated ADR accepts the exception.

The final choice belongs in ADR-0008. Whatever is selected, starting a session
must remain debuggable from a TTY without any graphical component running.

## Quickshell Design

Keep configuration modular. The layout in `/etc/xdg/quickshell/` is
(ADR-0012):

```text
quickshell/
├── shell.qml      the root: services, and one set of surfaces per monitor
├── theme.js       every colour, radius, size and duration
├── widgets/       the pieces the modules are built from
├── services/      what the shell reads from the system, instantiated once
├── modules/       the bar, its panels, the dock, the toasts and the OSD
└── parts/         drop-in elements installed by optional components
```

`theme.js` is the single source of the palette, and the Hyprland border
colours, the lock screen, the terminal and the launcher are configured to the
same values.

The shell also serves `org.freedesktop.Notifications`; there is no separate
notification daemon (ADR-0012).

The MVP should avoid building a full desktop environment. The line ADR-0012
draws is that a control the desktop cannot otherwise reach is in scope, and
everything else — media players, weather, system monitors — is not.

## Hyprland Design

Keep project defaults separate from user overrides.

Approach:

```text
/etc/strata/hypr/     Strata defaults, shipped by the image
~/.config/hypr/       user configuration, always takes precedence
```

Strata defaults are reference material. The image never edits a user's
configuration in place, and a user never has to edit a Strata default to
override it.

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
 -> pin a snapshot.debian.org timestamp
 -> build image from the pinned archive state
 -> validate
 -> record build manifest
 -> publish image
```

These are intentionally separate concerns.

The snapshot pin exists so a published image can be rebuilt later. It is a
build-time mechanism only: the installed system's `sources.list` always points
at the live Debian archive, so installed systems keep receiving updates
normally. See ADR-0005.


## Login and Branding Layer

The MVP does not promise a branded graphical login. It ships whichever packaged
greeter has the best technical fit, styled only to the extent that greeter
supports out of the box.

Required for the MVP:

- reliable authentication
- clear username/password controls
- keyboard-first operation

Deferred to a later branding milestone:

- Strata logo on the greeter
- custom background
- multi-monitor and HiDPI polish

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
