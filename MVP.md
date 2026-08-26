# Strata MVP

## Definition of Done

The MVP is a **live ISO with an installable session** (ADR-0006).

It is complete when a user can:

1. download the ISO,
2. verify its checksum,
3. write it to USB,
4. boot it on a UEFI Secure Boot enabled x86-64 machine,
5. reach a working live Hyprland session without installing anything,
6. install it to disk from that live session using Calamares,
7. boot the installed system with Secure Boot still enabled,
8. log into a Hyprland session,
9. see a minimal Quickshell shell,
10. connect to a network,
11. play and record audio,
12. use screen sharing where supported,
13. receive privilege prompts through Polkit,
14. update the system using ordinary Debian Testing APT commands against the
    live Debian archive, not the build-time snapshot.

## Required Components

- Debian Testing
- signed Debian kernel
- Debian Secure Boot chain
- Hyprland
- Quickshell
- NetworkManager
- PipeWire
- WirePlumber
- xdg-desktop-portal
- xdg-desktop-portal-hyprland
- Polkit
- Polkit authentication agent
- greeter (greetd-based, packaged in Debian Testing)
- Calamares with `calamares-settings-debian`
- terminal
- launcher
- notifications
- clipboard
- screenshots
- screen lock
- idle manager

## Required Automation

- local build command, single invocation, no manual steps
- snapshot timestamp pinning and `SOURCE_DATE_EPOCH` export (ADR-0005)
- CI build
- QEMU boot test
- regression test asserting no snapshot URL reaches the installed `sources.list`
- checksum generation
- build manifest generation
- manual release workflow

## Reproducibility Bar for the MVP

Required:

- a clean checkout plus one command produces a working image,
- every release records the snapshot timestamp it was built from,
- rebuilding from that timestamp yields the same package set.

Not required:

- bit-identical ISOs between two builds of the same snapshot.

See ADR-0005.

## Deferred

- monthly auto-publish
- AI agent installer
- multiple themes
- developer profile
- laptop-specific extras
- NVIDIA proprietary driver integration


## Branding in the MVP

The MVP may include:

- project name
- simple logo
- default wallpaper

Explicitly **not** in the MVP:

- greeter branding of any kind — the MVP ships default greeter styling
- boot splash

A polished custom login screen is not required for technical MVP completion.

If branding adds fragile dependencies or complicates authentication, defer it to the next milestone.
