# ADR-0008: Session Management with greetd and tuigreet

## Status

Accepted

## Context

Strata needs a way to authenticate a user and start a Hyprland session. The
choice was deliberately left open pending a comparison of what Debian Testing
actually packages.

The relevant constraint from ADR-0004 and the MVP scope is that greeter
*branding* is explicitly out of scope for the MVP. That removes the main reason
to prefer a graphical greeter and turns this into a pure reliability and
footprint question.

## Options

Verified against Debian Testing (forky) on 2026-08-26.

| Option | Direct dependencies | Notes |
|---|---|---|
| `greetd` + `tuigreet` 0.9.1 | 8 + 2 | text UI, renders on the TTY |
| `greetd` + `gtkgreet` 0.8 under `cage` 0.3.1 | 8 + 7 + 4 | GTK3, CSS themable |
| TTY login + Hyprland from shell profile | 0 | no authentication separation |
| `sddm` / `lightdm` | many | full display manager |

`ReGreet` — the natural choice for a themable Wayland greeter — is **not
packaged in Debian Testing**. Using it would mean building from source, which
ADR-0001 forbids absent a dedicated exception.

## Decision

**`greetd` with `tuigreet`.**

`greetd` starts `tuigreet`, `tuigreet` authenticates via PAM and launches
Hyprland.

TTY login remains a documented, always-available fallback. Starting a session
must stay debuggable from a TTY with no graphical component running.

## Rationale

**`cage` would introduce a second compositor stack.** Debian's Hyprland is built
on `libaquamarine13`, not wlroots (verified). `cage` depends on
`libwlroots-0.20`. Choosing `gtkgreet` therefore means shipping and maintaining a
second, otherwise-unused compositor implementation whose only job is to draw a
login box before the real compositor starts. That is a poor trade for a screen
the user sees for four seconds.

**`tuigreet` is two dependencies.** `libc6` and `libgcc-s1`. It is a statically
linked Rust binary. Nothing else in the graphical stack depends on it, and it
cannot fail because of a GPU, driver, or Wayland protocol problem.

**It eliminates three MVP validation tasks outright.** HiDPI scaling and
multi-monitor login behaviour were listed as things to validate. `tuigreet`
renders in the TTY using the console font, so neither question arises. Nor does
keyboard-first operation need validating — a text UI has no other mode.

**Failure mode is better.** If a graphical greeter cannot start, the user faces
a black screen. If `tuigreet` cannot start, the user is looking at a TTY, which
is where they would need to go to debug it anyway.

**The branding cost is already accepted.** `tuigreet` cannot display a logo or a
background image. Since ADR-0004 and the MVP scope already defer greeter
branding, this costs nothing that was promised.

## Consequences

### Positive

- smallest possible authentication path,
- no GPU or Wayland dependency in the boot-to-login path,
- HiDPI and multi-monitor login problems cannot occur,
- session selection is still supported,
- failures land the user somewhere useful.

### Negative

- text-only login may read as unfinished to users expecting a graphical screen,
- no logo or background is possible at all,
- moving to a branded greeter later means replacing the greeter, not theming
  this one.

## Revisit When

The branding milestone requires a graphical greeter. At that point the choice is
between `gtkgreet` under `cage`, accepting the second compositor stack, and
`ReGreet` if it has entered Debian Testing by then. Either needs a new ADR that
weighs the added failure surface against the visual gain — and ADR-0002's
priority rule still applies: authentication reliability outranks appearance.
