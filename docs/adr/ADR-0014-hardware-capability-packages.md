# ADR-0014: Packages for the Hardware Capabilities ADR-0012 Requires

## Status

Accepted. Settles the selection [ADR-0012](ADR-0012-complete-desktop-minimal-applications.md)
deferred, and extends [ADR-0009](ADR-0009-default-package-selection.md).

## Context

ADR-0012 requires that ordinary hardware work without the user installing
anything, and named battery reporting, power profiles, brightness and Bluetooth.
It deferred the package selection and said plainly that until a record existed,
nothing would be added.

Three of the four were then written against and none was provisioned. The
battery element reads `Quickshell.Services.UPower`; on a laptop with a battery
at 63% the element shows nothing at all, because `upower` is not installed —
not in any package list, not mentioned in ADR-0009, and the D-Bus name it needs
is provided by no service file. Quickshell said so in its log at every login:

    Could not launch service org.freedesktop.UPower:
    The name org.freedesktop.UPower was not provided by any .service files

That is the third instance of one pattern in this project, after hypridle and
hyprlock: a program is shipped, wired into the session, and never given the one
thing it needs to work. All three were found by looking at a running machine.

Verified against Debian Testing (forky), amd64, on 2026-08-29, from inside a
running Strata live session.

## Decision

| Capability | Package | Size | Notes |
|---|---|---|---|
| Battery | `upower` 1.91.3 | 361 kB | only `libupower-glib3` is a new dependency |
| Power profiles | `power-profiles-daemon` 0.30 | 186 kB | needs python3 and python3-gi, both already present |
| Bluetooth | `bluez` 5.87 | 5.3 MB | the stack itself |
| Bluetooth audio | `libspa-0.2-bluetooth` | 1.7 MB | reverses ADR-0009's deferral of this to a profile |

Total 7.5 MB.

### Brightness needs no package at all

The brightness element wrote to `/sys/class/backlight/*/brightness` and silently
did nothing: the file is root-owned, mode 644, and no Debian udev rule changes
that. The obvious fix was `brightnessctl`, which ships a udev rule granting the
`video` group access.

It is not used. logind already exposes `SetBrightness` for the active session on
the seat, which is the same permission model with none of the additions, and
`busctl` is part of systemd. Measured working on real hardware before the
alternative was rejected.

This is worth recording because the cheapest answer was not the obvious one, and
the obvious one would have been accepted without the measurement.

### What is still not included

`bluez` is installed so the hardware works and `bluetoothctl` can pair a device.
There is no Bluetooth bar element yet; ADR-0012's surface table still has that
row open, along with the clock's calendar, the screenshot menu and the window
list.

## Consequences

### Positive

- a laptop reports its battery, which it could not do before,
- Bluetooth headsets work without the user discovering that a package is
  missing,
- brightness costs nothing.

### Negative

- 7.5 MB, most of it `bluez`, on an image already 1.51 GiB against a 2 GiB
  ceiling that ADR-0012 declined to raise.
- `bluez` runs a daemon that listens on hardware Strata ships no interface for
  yet. It is attack surface for a capability nobody can currently reach from
  the desktop.
- `power-profiles-daemon` pulls python3-gi into a system whose profiles may do
  little: `amd_pstate` failed to register on the test machine and the kernel
  fell back to `acpi-cpufreq`. The element shows profiles only when something
  answers, so this degrades quietly rather than lying.

## Guiding Principle

Shipping the program is not shipping the capability. Whatever it needs to
actually run is part of the decision, and is checked on a machine that has the
hardware.
