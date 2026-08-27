# ADR-0011: Optional Components and Lazy Installation

## Status

Accepted

## Context

ADR-0003 keeps the base image to a complete minimal desktop and says everything
else "should preferably be installed after system installation or through
clearly separated profiles". That mechanism was never built, so "optional layer"
has meant "the user reads the documentation and runs apt".

That is not unreasonable — it is Debian, and `sudo apt install firefox-esr`
works. But it leaves two things unsolved.

A freshly installed Strata has no browser, and nothing tells the user that or
what to do about it. The first experience of the system is a bar, a terminal,
and no obvious way to reach the web.

And the AI agent CLIs the project wants to support — Claude Code, Codex, Gemini
CLI, Copilot CLI, OpenCode — are **not in Debian**. Installing them means npm,
or a vendor script. That is a genuine departure from ADR-0001, and it must be
visible when it happens rather than hidden behind a command that makes
everything look equally Debian.

## Decision

Strata ships a `strata` command that installs declared optional components, and
a `browser` command that opens or selects the default browser.

Components are declarative files under `/usr/share/strata/components/`, each
recording where the software comes from. Three origins exist and they are not
treated the same:

**`debian`** — installed with apt from the archive the system already trusts.
No prompt beyond apt's own.

**`flatpak`** — from Flathub, sandboxed, in its own trust domain. `flatpak`
itself is a Debian package, and the portal stack Flatpak applications need is
already in the base image for other reasons.

**`external`** — not in Debian and not sandboxed. `strata install` states
plainly what is about to be fetched and from where, and requires confirmation.
The confirmation is not ceremony: it is the moment ADR-0001's guarantee stops
applying, and the user should know it.

### Why Flatpak rather than a vendor APT repository

Several desirable applications — Brave among them — are distributed as a
third-party APT repository. Strata will not add one.

The reason is not tidiness. An APT repository ships a signing key, and once that
key is trusted it is trusted for *every package name*, including replacements
for system components. It is a systemwide grant. A Flatpak remote cannot do
that: it can offer applications, and nothing it offers can replace a Debian
package or touch the boot chain.

For a project whose central promise is that an installed system remains ordinary
Debian, that difference decides it. `npm --global` sits between the two — it
writes to `/usr/local` and gains no package-manager trust — which is why the
agent CLIs use it and are still marked `external`.

Adding a component is adding a file. Nothing is compiled in.

## The browser command

Debian already solves *opening* a browser: `sensible-browser` honours `$BROWSER`
and the `x-www-browser` alternative, and `xdg-open` handles URLs. Strata does
not reimplement any of that.

What Debian has no single command for is *choosing*, which is spread across
`update-alternatives --config x-www-browser` and `xdg-settings set
default-web-browser`. `browser --set` does both, and `browser` alone delegates
to `sensible-browser`.

When no browser is installed it says so and names the command that would fix it,
rather than failing obscurely — which is the actual problem being solved.

## Consequences

### Positive

- a newly installed system explains how to become useful,
- the Debian boundary is visible at the moment it is crossed,
- the base image stays as small as ADR-0003 requires,
- new components need no code,
- Phase 4's agent support becomes a few declarative files rather than a
  subsystem.

### Negative

- Strata now owns two commands in `/usr/bin` and a component format,
- `browser` overlaps `sensible-browser`, justified only by the `--set` half and
  by being the name people actually type,
- component definitions can rot when upstreams rename packages; nothing checks
  them automatically.

## Rejected alternatives

**Put a browser in the base image.** Directly contradicts ADR-0003, and the
README lists browsers among what is deliberately absent. Roughly 250 MB for
something a third of users would replace immediately.

**Ship a `strata` command that wraps apt for everything.** Wrapping apt makes
Strata a package manager's package manager, and ADR-0001 exists to prevent that.
The command installs *declared components*; anything else is `apt install`, and
the documentation says so.

**Add third-party APT repositories for VSCodium, Brave and similar.** ADR-0001
keeps custom repositories out of the default architecture, and the reason is
given above: a repository key is a systemwide trust grant, not an application.
A user may add one; Strata will not do it for them. Where Flathub carries the
application, that is the route Strata offers instead. Where an editor is wanted,
Debian has neovim, micro, geany and kate.
