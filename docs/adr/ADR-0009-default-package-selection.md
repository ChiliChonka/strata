# ADR-0009: Default Package Selection for the Minimal Desktop

## Status

Accepted, except for the Bluetooth exclusions, which are superseded by
[ADR-0012](ADR-0012-complete-desktop-minimal-applications.md). The tool choices
in the table below stand. Concrete Bluetooth, brightness, and power-profile
packages still need to be selected the same way the existing rows were.

## Context

ADR-0003 requires that every package in the base image have a clear purpose. The
individual tool choices were left open. This record settles them.

All versions and dependency counts were verified against Debian Testing (forky),
amd64, on 2026-08-26. Dependency counts are **direct** runtime dependencies.

The selection principle is **marginal** footprint, not absolute footprint. Qt6 is
already unavoidable because Quickshell requires it, so a Qt6 tool may well be
cheaper in practice than a GTK one.

What the image already pulls in regardless of these choices:

- **Qt6 and QML** — via `quickshell`
- **EGL/GLES and Mesa** — via `hyprland`
- **PipeWire client libraries, PAM, polkit-agent** — via `quickshell`
- **GTK3** — via `xdg-desktop-portal-gtk`, see below

## Decision

| Role | Chosen | Deps | Rejected |
|---|---|---|---|
| Terminal | `foot` 1.27.0 | 9 | `alacritty`, `kitty` |
| Launcher | `fuzzel` 1.12.0 | 9 | `wofi`, `rofi` |
| Notifications | `mako-notifier` 1.11.0 | 9 | `sway-notification-center` |
| Clipboard | `wl-clipboard` 2.3.0 + `cliphist` 0.5.0 | 3 + 2 | — |
| Screenshots | `grim` 1.5.0 + `slurp` 1.5.0 | 5 + 6 | `hyprshot` (not packaged) |
| Screen lock | `hyprlock` 0.9.6 | 16 | `swaylock` |
| Idle | `hypridle` 0.1.8 | 8 | `swayidle` |
| Wallpaper | drawn by `quickshell` | 0 | `hyprpaper`, `swaybg` |
| Polkit agent | `hyprpolkitagent` 0.1.3 | 15 | `lxqt-policykit`, `mate-polkit` |
| Portals | `xdg-desktop-portal` + `-hyprland` + `-gtk` | — | `-wlr` |
| Audio | `pipewire`, `pipewire-audio`, `pipewire-pulse`, `wireplumber` | — | PulseAudio |
| Network | `network-manager` | — | systemd-networkd, connman |
| Fonts | `fonts-dejavu-core` | — | — |

## Rationale

### Terminal: foot

`foot` renders on the CPU via pixman and has **no EGL or OpenGL dependency**.
`alacritty` depends on `libwayland-egl1` and needs a working GL context.

That is decisive for a specific reason: Strata's CI validates images in QEMU,
where GPU acceleration is unreliable or absent. A terminal that needs GL is a
terminal that may fail in exactly the environment used to prove the image works.
The same reasoning protects users on unusual or broken graphics drivers.

`kitty` pulls 21 dependencies including Python 3.14 — disproportionate for a
terminal in a minimal image.

### Launcher: fuzzel

Same upstream as `foot` and the same rendering stack (`libfcft4t64`,
`libpixman-1-0`), both of which `foot` already pulls in. The marginal cost of
`fuzzel` is therefore close to zero.

`wofi` depends on `libgtk-3-0t64`. `rofi` is X11-oriented.

### Notifications: mako-notifier

**Naming trap:** in Debian, the binary package `mako` does not exist as a
notification daemon. The source package `mako` builds `python3-mako`, the Python
template library. The Wayland notification daemon is packaged as
**`mako-notifier`**. Getting this wrong installs a template engine.

`mako-notifier` depends on cairo and pango, with no GTK. `sway-notification-center`
pulls GTK4, `libadwaita`, and `libpulse` — the last of which is undesirable in a
PipeWire-native image.

Quickshell could implement notifications natively, and may later. For the MVP,
AGENTS.md forbids building a large widget suite, so a packaged daemon is used.

### Clipboard: wl-clipboard and cliphist

`wl-clipboard` alone satisfies the stated MVP requirement. `cliphist` is added
deliberately: on Wayland the clipboard is owned by the source client, so
**copying from an application and then closing it loses the content**. This is a
recurring papercut, not a luxury. `cliphist` is a static Go binary with two
dependencies. The cost is negligible and the problem is real.

### Lock and idle: hyprlock and hypridle

`hyprlock` pulls EGL and GLES, but `hyprland` already requires both, so the
marginal cost is small. It authenticates through PAM.

`hypridle` has eight dependencies and no toolkit. Both integrate with Hyprland's
own session handling rather than reimplementing it.

### Wallpaper: none — Quickshell draws it

The desktop was a flat colour for the whole life of this project. `hyprpaper` was
in the table and in the image from the beginning, was never autostarted, and was
never given a wallpaper; when all three were finally fixed it turned out it
cannot draw here at all.

Two separate faults, both measured in QEMU against `hyprpaper` 0.8.4:

- The line form `wallpaper = ,/path` documented all over the internet is silently
  ignored by this version. It logs `Monitor Virtual-1 has no target: no wp will
  be created` and nothing else. The man page documents a `wallpaper { … }` block,
  which this version does parse.
- With the block form it finds the monitor and then allocates its buffer through
  KMS/GBM, as though it were the compositor. Hyprland already holds DRM master,
  so `DRM_IOCTL_MODE_CREATE_DUMB` returns `Permission denied` and the process
  segfaults. Forcing software rendering did not change it, so this is not a
  missing GPU.

`swaybg` is the obvious alternative and was not tried: it is another package, and
Quickshell is already running in that session and already renders correctly
there. The background is one more layer-shell surface below everything
else, so the answer costs no package at all and the colour behind the picture
comes from the same theme as the bar. A missing or unreadable image therefore
leaves the desktop in its own colour rather than black.

The cost is that the wallpaper now depends on the shell: a user who replaces
`shell.qml` wholesale replaces the background with it. That is consistent with
what replacing the shell already means, and it is why `Theme.wallpaper` is a
token next to the colours rather than a path buried in a window.

### Polkit agent: hyprpolkitagent

This choice is counter-intuitive by raw dependency count and correct by marginal
cost.

- `hyprpolkitagent` needs Qt6 and QML modules. Quickshell already brings Qt6,
  QML, and `qml6-module-qtquick-controls`. The genuine addition is
  `libpolkit-qt6-1-1` and two QML modules.
- `lxqt-policykit` depends on **`lxqt-session`** — a complete session manager,
  pulled in solely to display a password prompt.
- `mate-polkit` depends on `libgtk-3-0t64` and `accountsservice`.

Quickshell already links `libpolkit-agent-1-0`, so a Quickshell-native agent is
technically possible. ARCHITECTURE.md permits that only once mature and
reliable, so it is not an MVP path.

### Portals: hyprland plus gtk

`xdg-desktop-portal-hyprland` provides screencast and screenshot. It does **not**
implement the FileChooser interface, so `xdg-desktop-portal-gtk` is required for
file dialogs.

This is the one unavoidable GTK3 in the image, and it is accepted: without it,
applications cannot open or save files. `xdg-desktop-portal-wlr` is not needed —
it targets wlroots compositors, and Hyprland ships its own portal.

### Audio, network, fonts

PipeWire with WirePlumber per ARCHITECTURE.md. `pipewire-pulse` provides the
PulseAudio compatibility layer that most applications still expect.
Bluetooth audio via `libspa-0.2-bluetooth` was deferred to an optional
profile. ADR-0012 reverses this: Bluetooth belongs in the base image.

NetworkManager per ARCHITECTURE.md. No graphical applet in the base image —
Quickshell displays network state, and `nmtui` handles configuration.

`fonts-dejavu-core` is included because both `foot` and `fuzzel` need a monospace
font present and neither depends on one. Without it the desktop starts with no
usable text.

## Explicitly Excluded from the Base Image

- `wlogout` — logout is a Hyprland keybinding calling `hyprctl dispatch exit`.
  A dedicated package is not warranted.
- `cliphist` GUI frontends — the fuzzel integration is a shell one-liner.
- Printing and any developer tooling — optional layers per ADR-0011.
  (Bluetooth was listed here until ADR-0012 moved it into the base image.)
- Icon or Nerd fonts — needed only once Quickshell styling wants glyph icons.
  Revisit during the branding milestone.

## Open Questions

- **XWayland.** ~~Not yet decided.~~ **Resolved by ADR-0010: it stays in the base
  image.** ADR-0010 also adds `libqt6waylandclient6` to the package lists
  explicitly.
- Whether Quickshell should eventually replace `mako-notifier` and
  `hyprpolkitagent` natively.

## Consequences

### Positive

- every base package traces to a stated requirement,
- no GTK4, no LXQt, no Python, no PulseAudio in the base image,
- GTK3 enters through exactly one well-understood package,
- the terminal and launcher work without GPU acceleration, which keeps QEMU
  validation meaningful,
- choices are consistent with the Hyprland ecosystem, easing upstream support.

### Negative

- Hyprland-family tools tie Strata more tightly to that ecosystem's release
  cadence,
- `cliphist` and `fonts-dejavu-core` go slightly beyond the literal MVP list,
  both justified above,
- the XWayland question is unresolved and blocks freezing the package lists.
