# ADR-0012: A Complete Desktop, Not a Minimal Application Set

## Status

Accepted. Supersedes [ADR-0003](ADR-0003-minimal-core-optional-layers.md).
Amends [ADR-0009](ADR-0009-default-package-selection.md), which excluded
Bluetooth from the base image.

## Context

ADR-0003 asked for a "complete minimal desktop" and then listed what the base
image may contain. In practice the word *minimal* got applied to the wrong
budget, and the record could not settle the argument, because it never said
which of two very different things it was minimising.

Two incidents made the ambiguity concrete.

A bar element for an installed component was refused on the grounds that
ADR-0003 requires a minimal system. That was a misreading, but a defensible one:
nothing in ADR-0003 distinguishes *the system is small* from *the desktop can do
little*, so both readings survive the text.

Separately, ADR-0009 records that NetworkManager is in the base image and that
"Quickshell displays network state, and `nmtui` handles configuration". A daemon
is installed; whether the desktop can reach it is left to chance. A user who
cannot join a wireless network without first opening a terminal does not have a
working desktop, however small the image is.

The Ubuntu desktop is a useful reference point here — not as something to copy,
but as evidence that a bar can stay visually spare while still exposing network,
sound, brightness, battery and power profile, session actions, screenshots, a
clock with a calendar, and the windows that are open. None of that makes it a
heavy system. It makes it a usable one.

## Decision

Strata keeps two separate budgets, and only one of them is minimised.

### Applications: near zero

Unchanged from ADR-0003. The base image ships no browser, no office suite, no
IDE, no games, no container tooling, no coding agents, no additional themes.
These arrive through [ADR-0011](ADR-0011-optional-components.md) when the user
asks for them, and not before.

### System capability: complete

Hardware that an ordinary laptop or desktop has must work out of the box,
without the user installing anything:

- wired and wireless networking,
- **Bluetooth**, including audio — this reverses ADR-0009's exclusion,
- audio output and input,
- display brightness,
- battery reporting and power profiles,
- multiple monitors, including hotplug,
- suspend, lock, and idle handling.

The test is not "is this package small". It is "does the machine work". A laptop
whose Bluetooth headset cannot connect is not a smaller system; it is a broken
one, and the user fixes it by installing packages we chose to leave out.

### Shell surface: the capability must be reachable

A capability that exists only as a running daemon is not delivered. The shell
must expose, in the bar:

| Surface | Inline in the bar | Handed off to |
|---|---|---|
| Network | state, pick a known or visible network, toggle radio | `nmtui` for the rest |
| Bluetooth | state, connect and disconnect known devices | Debian's Bluetooth tooling for pairing edge cases |
| Sound | output volume, input mute, pick a device | `wpctl` / PipeWire tools |
| Brightness | level, where the hardware has it | — |
| Battery | charge, time remaining, power profile | — |
| Clock | time and date, a calendar | — |
| Session | lock, log out, suspend, reboot, shut down | — |
| Screenshot | region, window, whole screen | — |
| Windows | what is currently open, and switching to it | Hyprland |

"Handed off" means an existing Debian tool is launched. It does not mean a
Strata configuration application. There is no settings app, and there will not
be one — that is where [ADR-0004](ADR-0004-branding-without-desktop-fork.md)
still binds: Strata configures a desktop, it does not become one.

### Extensibility is a requirement, not a side effect

Quickshell with QtQuick was chosen so the user can change the desktop without
first learning a compositor's plugin API or rebuilding anything. That only holds
if what Strata ships is readable. Therefore:

- every bar element is a QML file a person can open, copy, and modify,
- elements live as separate files rather than one large shell,
- the drop-in mechanism under `/etc/xdg/quickshell/parts` and
  `~/.config/quickshell/parts` is the supported way to add one,
- a user's own part must not require editing anything Strata ships.

An element that is clever but unreadable fails this ADR even if it works.

## What this does not change

- ADR-0001: an installed Strata is ordinary Debian. Capabilities come from
  Debian packages, not from Strata-maintained forks.
- ADR-0004: no custom desktop environment, no settings application.
- ADR-0011: applications remain optional and opt-in.
- The image size ceiling of 2 GiB stays. If the baseline above cannot fit, the
  baseline is re-argued in a new ADR — it is not silently trimmed.

## Consequences

### Positive

- the desktop is usable on real hardware without a terminal detour,
- the minimal/complete argument has a written answer, so it stops being
  relitigated per feature,
- Bluetooth works on the machines most likely to need it — laptops,
- the extensibility promise becomes testable rather than aspirational.

### Negative

- **This is a real scope increase.** More QML to write, review, and keep
  working across Quickshell versions.
- More surface to break, and bar elements break visibly.
- The base image grows. Bluetooth, brightness, and power-profile tooling are not
  free, and the 2 GiB ceiling gets closer.
- Strata moves closer to something that looks like a desktop environment, which
  ADR-0004 deliberately avoided. The line held here is *no settings
  application*; that line will be under pressure and must be defended
  explicitly, not by habit.
- Every inline control is a chance to disagree with the tool it hands off to.
  Two places that set brightness will eventually disagree about the value.

### Deferred

Concrete package choices for Bluetooth, brightness, and power profiles are not
settled here. They extend ADR-0009's table and need the same treatment its
existing rows got: verified against Debian Testing, with dependency counts and
rejected alternatives. Until that record exists, nothing from this section is
added to the base image.

## Guiding Principle

Strata should provide **a complete desktop with almost no applications** — not a
desktop that is incomplete in order to look small.
