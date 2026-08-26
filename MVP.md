# Strata MVP

## Definition of Done

The MVP is complete when a user can:

1. download the ISO,
2. verify its checksum,
3. write it to USB,
4. boot it on a UEFI Secure Boot enabled x86-64 machine,
5. install it,
6. boot the installed system with Secure Boot still enabled,
7. log into a Hyprland session,
8. see a minimal Quickshell shell,
9. connect to a network,
10. play and record audio,
11. use screen sharing where supported,
12. receive privilege prompts through Polkit,
13. update the system using ordinary Debian Testing APT commands.

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
- terminal
- launcher
- notifications
- clipboard
- screenshots
- screen lock
- idle manager

## Required Automation

- local build command
- CI build
- QEMU boot test
- checksum generation
- manual release workflow

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
- basic greeter styling if supported naturally by the chosen login stack

A polished custom login screen is not required for technical MVP completion.

If branding adds fragile dependencies or complicates authentication, defer it to the next milestone.
