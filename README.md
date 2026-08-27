# Strata

> A minimal Debian Testing desktop built around Hyprland and Quickshell — lightweight, Secure-Boot-friendly, and deliberately close to upstream Debian.

<a href="https://www.debian.org/">
  <img src="assets/third-party/debian-openlogo-nd.svg" alt="Debian" height="48" align="left" hspace="12">
</a>

**Built on Debian.** Packages, kernels, security updates and the signed boot
chain all come from Debian Testing. Strata contributes configuration, not a
package universe.

<br clear="left">

## Status

Early project / architecture phase. No image is published yet.

Key decisions are recorded in [docs/adr/](docs/adr/).

## What this project is

**Strata** builds a minimal, reproducible Linux image based on Debian Testing.

The intended stack is:

```text
Debian Testing
    |
    +-- Debian signed boot chain
    +-- Wayland
    +-- Hyprland
    +-- Quickshell
    +-- PipeWire + WirePlumber
    +-- XDG Desktop Portals
    +-- Polkit
    +-- NetworkManager
```

The goal is a small, modern Wayland desktop that remains as close as possible to ordinary Debian.

## What this project is not

This project is not intended to become an independent Linux distribution with its own package universe.

It does not aim to:

- fork Debian,
- replace APT,
- maintain a custom kernel,
- operate a custom package repository by default,
- bundle a large application suite,
- recreate Omarchy,
- ship a fully personalized developer workstation.

## Core principle

**This is Debian, not a Debian fork.**

After installation, the system should remain a normal Debian Testing installation wherever practical.

Packages, kernels, security fixes, firmware, and system libraries should come from official Debian repositories.

Project-specific components should be limited primarily to:

- image build configuration,
- package selection,
- Hyprland defaults,
- Quickshell defaults,
- small helper scripts,
- optional integrations,
- documentation.

## Why Debian Testing?

Hyprland and the surrounding Wayland ecosystem move quickly.

Debian Testing provides a useful compromise:

- newer packages than Debian Stable,
- Debian's package ecosystem,
- Debian-native Secure Boot support,
- APT,
- no need to adopt a completely different operating model such as NixOS,
- less distribution-specific customization than a heavily opinionated desktop distribution.

## Why Hyprland?

Hyprland provides a modern Wayland-native tiling workflow with:

- keyboard-oriented window management,
- workspaces,
- efficient desktop interaction,
- a lightweight compositor stack,
- strong integration with modern Wayland tools.

## Why Quickshell?

Quickshell provides a programmable shell framework for lightweight desktop UI.

The default project configuration stays small, and covers what a desktop cannot
otherwise reach with a mouse (ADR-0012):

- workspaces and the focused window,
- clock and calendar,
- notifications, with a do-not-disturb switch — the shell is the notification
  daemon, so there is no second one on the image,
- network state, the Wi-Fi radio and joining a network,
- output and input volume, and the output device,
- display brightness,
- battery state,
- lock, log out, suspend, restart and shut down,
- a dock of running applications, hidden until the pointer reaches the bottom
  edge,
- an on-screen display for the volume and brightness keys.

There is deliberately no media player, weather, system monitor or wallpaper
switcher.

Everything the shell draws takes its colours from one file,
`/etc/xdg/quickshell/theme.js`, and the Hyprland window borders, the lock
screen, the terminal and the launcher are configured to the same values.

Users should be able to replace or extend the configuration easily: a
`~/.config/quickshell/shell.qml` replaces all of it, and optional components can
drop their own element into the bar.

## Desktop infrastructure

A minimal desktop still needs several supporting components.

### XDG Desktop Portals

Desktop portals provide standardized interfaces for operations such as:

- file pickers,
- opening files and URLs,
- screen sharing,
- screen capture,
- sandboxed application integration.

For Hyprland, `xdg-desktop-portal-hyprland` is particularly important for screen sharing and Wayland integration.

### Polkit

Polkit provides authorization for privileged desktop operations.

A Polkit authentication agent is required so graphical applications can request authorization interactively.

### PipeWire

PipeWire provides the modern Linux audio/video routing layer.

It is used for:

- application audio,
- microphone input,
- Bluetooth audio,
- screen sharing,
- recording,
- multimedia routing.

WirePlumber is used as the session manager.

## Secure Boot

Secure Boot is a first-class project requirement.

The preferred implementation uses Debian's own signed boot chain and signed kernel packages.

The normal user experience should not require disabling Secure Boot or enrolling custom Machine Owner Keys.

## Minimal by design

The default ISO should not include large application stacks.

Examples of software that should not be installed by default:

- LibreOffice
- GNOME
- KDE Plasma
- IDEs
- Docker
- Kubernetes
- Steam
- office suites
- chat applications
- game launchers
- large theme collections

Optional software belongs in optional layers or post-install tooling.

## Optional AI agent support

AI coding agents are useful but should not enlarge the base image unnecessarily.

The project intends to support lazy installation of tools such as:

- OpenAI Codex CLI
- Claude Code
- OpenCode
- Gemini CLI
- GitHub Copilot CLI

This is implemented. `strata` installs optional components on request, and is
explicit about where each one comes from:

```text
strata list
strata install claude
strata install firefox
```

Three origins, deliberately not treated alike: `debian` (apt, from the archive
the system already trusts), `flatpak` (Flathub, sandboxed) and `external` (not
in Debian, not sandboxed — stated plainly and confirmed before anything is
fetched). Agent CLIs are `external`: they come from npm, and that boundary is
shown rather than smoothed over. See
[ADR-0011](docs/adr/ADR-0011-optional-components.md).

## Project-aware agent support

The project should provide agent documentation or skills that describe:

- system architecture,
- Debian-first rules,
- package management,
- Hyprland configuration,
- Quickshell configuration,
- build and test commands,
- repository conventions.

This allows coding agents to modify the system without violating project design principles.

## Updates

Installed systems should use ordinary Debian commands:

```bash
sudo apt update
sudo apt full-upgrade
```

There should be no custom system update service unless a future technical requirement strongly justifies one.

## Releases

Debian Testing is rolling release.

The project therefore does not wait for a new "Debian Testing version".

Instead, once per month CI should evaluate whether relevant upstream components changed.

If meaningful changes exist, a new image is built, tested, checksummed, and published.

Artifact naming:

```text
strata-2026.08.26-amd64.iso
strata-2026.08.26-amd64.iso.sha256
strata-2026.08.26-amd64.iso.sig
```

Each release also ships a build manifest recording the exact
`snapshot.debian.org` timestamp and package versions the image was built from,
so any published image can be rebuilt later. See
[ADR-0005](docs/adr/ADR-0005-build-reproducibility-and-snapshot-pinning.md).

## Build philosophy

The build stack is Debian-native: **`live-build`**, producing a **live ISO** with
**Calamares** as the installer, configured through the official
`calamares-settings-debian` package.

That is the same path the official Debian Live images take. See
[ADR-0006](docs/adr/ADR-0006-live-iso-with-calamares-installer.md).

Builds are pinned to a `snapshot.debian.org` timestamp so a published image can
be rebuilt from the same package set later. "Reproducible" here means
script-driven repeatability plus snapshot pinning — bit-identical ISOs are a
later goal, not a release requirement. See
[ADR-0005](docs/adr/ADR-0005-build-reproducibility-and-snapshot-pinning.md).

A custom installer is out of scope.

## Building

Roughly 20 GB of free disk space is required either way.

### On any host, via a container

This is the normal path. It needs only Docker or Podman:

```bash
./scripts/build-in-docker.sh
```

The repository is bind-mounted, so the build writes its working tree and the
finished ISO into the checkout on the host rather than into container storage.

A container is not merely a convenience. live-build is Debian-specific, and
Ubuntu ships a fork (3.0~a57) that predates `--uefi-secure-boot` — building
there would silently produce an image without a signed boot chain, failing
[ADR-0002](docs/adr/ADR-0002-secure-boot.md).

### On a Debian host, directly

```bash
sudo apt install live-build
sudo ./scripts/build.sh
```

That is the whole build. `scripts/build.sh` is the only supported entry point:
it resolves a `snapshot.debian.org` timestamp, derives `SOURCE_DATE_EPOCH` from
it, runs live-build, and writes the ISO, its checksum, and a build manifest.

To rebuild a past image, pass the snapshot timestamp its manifest records:

```bash
./scripts/build-in-docker.sh 20260801T000000Z
```

## Testing

Automated validation should use QEMU/KVM where practical.

Target checks include:

- UEFI boot,
- Secure Boot,
- kernel startup,
- networking,
- Hyprland startup,
- Quickshell startup,
- PipeWire/WirePlumber,
- desktop portals,
- installer viability.

## Project maturity

The first milestone is not a polished distribution.

The MVP is:

> A reproducibly built Debian Testing amd64 ISO that boots with Secure Boot enabled and provides a functional minimal Hyprland + Quickshell desktop.

## License

Strata's own configuration, scripts, and documentation are MIT licensed.
Original visual assets are CC BY-SA 4.0. A built ISO is an aggregation of Debian
packages, each keeping its own upstream license.

See [LICENSES.md](LICENSES.md) for details, including what the license does and
does not permit regarding the Strata name.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the workflow, the test tiers, and the
places where something looks wrong on purpose. Security issues go through
[SECURITY.md](SECURITY.md).

Contributions should preserve:

- minimalism,
- Debian compatibility,
- reproducibility,
- Secure Boot,
- maintainability.

Before adding a custom component, ask:

> Can this be solved with an existing Debian package or configuration?

If yes, prefer that solution.


## Visual identity

Strata has its own lightweight visual identity without becoming a custom desktop environment.

In the image:

- one default wallpaper — layered stone, generated by
  `scripts/make-wallpaper.py` and reused by the lock screen
- one palette, applied to the shell, the window borders, the lock screen, the
  terminal and the launcher

Still to do:

- Strata logo and wordmark, which is what Calamares branding is blocked on

Deferred to a later milestone, deliberately:

- login/greeter branding

The rule is simple:

> Branding may make Strata recognizable, but it must not make Strata heavy.

## Login experience

Strata aims for a small, reliable, keyboard-friendly login.

The working assumption is `greetd` with a Debian-packaged greeter — `tuigreet`
or `gtkgreet` under `cage`. The final choice is pending an ADR and is made on
reliability and dependency footprint, not appearance.

A branded greeter with a custom background and the Strata logo is a later
milestone. The obvious candidate for that, ReGreet, is not currently packaged in
Debian Testing, and building it from source would require an explicit exception
to the Debian-first rule.

Login reliability wins over login aesthetics, without exception.

## Trademarks

Debian is a registered trademark of Software in the Public Interest, Inc.

Strata is not affiliated with, nor endorsed by, the Debian project. The Debian
Open Use Logo is used here under its own license to state truthfully that Strata
is built on Debian. See [assets/LICENSE](assets/LICENSE) for its terms and
[www.debian.org/trademark](https://www.debian.org/trademark) for Debian's policy.

## Why the name Strata?

The name reflects the project's layered architecture:

```text
optional tools
Quickshell
Hyprland / Wayland
Debian Testing
Secure Boot / UEFI
```

Each layer should stay understandable and replaceable.
