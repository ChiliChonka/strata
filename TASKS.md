# Strata — Task List

Status legend: `[x]` done · `[ ]` open · `[D]` decided, needs writing up

## Phase 0 — Repository Foundation

- [x] LICENSE (MIT) and LICENSES.md
- [x] Asset license (CC BY-SA 4.0)
- [x] .gitignore covering the live-build working tree
- [x] `.github/` with CI, build scaffold, issue and PR templates
- [x] ADRs consolidated under `docs/adr/` with an index
- [x] CONTRIBUTING.md
- [x] SECURITY.md

## Phase 1 — Research and Design

### Resolved

Package availability verified against Debian Testing (forky), amd64,
2026-08-26.

- [x] Hyprland available — `hyprland` 0.56.2+ds-1
- [x] Quickshell available — `quickshell` 0.3.0-1
- [x] Secure Boot chain available — `shim-signed` 1.51,
      `grub-efi-amd64-signed` 1+2.14+3
- [x] Build tooling available — `live-build` 1:20250814
- [x] Installer available — `calamares` 3.4.2-1.1,
      `calamares-settings-debian` 14.0.2-1
- [x] QEMU firmware available — `ovmf` 2026.05-2
- [x] Snapshot pinning viable — `snapshot.debian.org` serves Testing correctly
- [x] Compare live-build vs Debian Installer → ADR-0006
- [x] Decide whether Live mode is required for MVP → yes, ADR-0006
- [x] Define what "reproducible" means → ADR-0005
- [x] Decide ext4 vs Btrfs → ext4, ADR-0007
- [x] Select greeter and session model → greetd + tuigreet, ADR-0008
- [x] Select terminal, launcher, notifications, clipboard, screenshot, lock,
      idle, Polkit agent, portals and fonts → ADR-0009
- [x] Determine portal backend combination → hyprland + gtk, ADR-0009
- [x] Identify Quickshell 0.3.0 runtime dependencies → Qt6, QML, EGL, PipeWire,
      PAM, polkit-agent

Candidate packages confirmed present in Testing, pending selection:

| Role | Candidates in Testing |
|---|---|
| Terminal | **`foot` 1.27.0** · `alacritty`, `kitty` |
| Launcher | **`fuzzel` 1.12.0** · `wofi`, `rofi` |
| Notifications | ~~`mako-notifier` 1.11.0~~ — served by Quickshell, ADR-0012 |
| Clipboard | **`wl-clipboard` 2.3.0 + `cliphist` 0.5.0** |
| Screenshots | **`grim` 1.5.0 + `slurp` 1.5.0** |
| Lock / idle | **`hyprlock` 0.9.6 + `hypridle` 0.1.8** |
| Polkit agent | **`hyprpolkitagent` 0.1.3** · `lxqt-policykit`, `mate-polkit` |
| Portals | **`xdg-desktop-portal` 1.22.1 + `-hyprland` 1.4.1 + `-gtk` 1.15.3** |
| Greeter | **`greetd` 0.10.3 + `tuigreet` 0.9.1** · `gtkgreet` + `cage` |
| Wallpaper | **`hyprpaper` 0.8.4** |
| Fonts | **`fonts-dejavu-core`** |

Selections in bold are settled by ADR-0008 and ADR-0009.

**Naming trap**, kept because it will come up again if a notification daemon is
ever needed: the Debian binary package for the daemon is `mako-notifier`. The
source package `mako` builds `python3-mako`, the Python template library — not a
notification daemon. Strata no longer installs either; ADR-0012 moved
notifications into the shell.

Not packaged in Testing, do not plan around them: `regreet`, `hyprshot`,
`grub-btrfs`, `bcachefs-tools`, `zfsutils-linux`.

### Open

- [x] Decide XWayland in the base image → stays in, ADR-0010
- [x] Design QEMU Secure Boot testing with `ovmf` secboot variables —
      `OVMF_CODE_4M.secboot.fd` with `OVMF_VARS_4M.ms.fd`, so the image is
      validated against Microsoft's keys rather than a permissive firmware
- [ ] Validate GitHub Actions runner constraints: disk space for live-build,
      KVM availability for the QEMU test, snapshot.debian.org throughput.
      **This one cannot be answered locally.** The workflow is written against
      the known numbers — a stock runner leaves roughly 14 GB free on `/` and a
      build needs about 20 GB, so the build job clears the preinstalled
      toolchains first — but whether that suffices, whether KVM is present, and
      whether snapshot.debian.org sustains the throughput are only knowable from
      an actual run. The first `workflow_dispatch` is the experiment.
- [x] Define the minimal default keybinding set — every capability AGENTS.md
      requires, plus the ADR-0009 tools that would otherwise be unreachable
- [x] Define the repository directory layout — `auto/`, `config/`, `scripts/`,
      `tests/`, per live-build convention

**The design phase is otherwise complete.** ADR-0001 through ADR-0010 cover
every architectural decision needed to begin Phase 2.

## Phase 2 — MVP Build

- [x] Create live-build configuration with snapshot-pinned bootstrap and chroot
      mirrors, and live binary mirrors (ADR-0005)
- [x] Add `scripts/build.sh` as the single documented build entry point
- [x] Add a container build environment so non-Debian hosts can build
      (`Containerfile`, `scripts/build-in-docker.sh`)
- [x] Add explicit package lists
- [x] Add Hyprland minimal config under `/etc/strata/hypr/hyprland.lua` (Lua
      format, as Hyprland 0.56 in Debian requires), loaded by
      `/etc/skel/.config/hypr/hyprland.lua` via `dofile` so user settings
      override without editing a Strata file
- [x] Add Quickshell minimal config — `/etc/xdg/quickshell/shell.qml`, one bar
      per monitor with workspaces, clock, volume and battery; a user's
      `~/.config/quickshell/shell.qml` replaces it
- [x] Give the shell the controls a laptop needs and one palette across the
      desktop (ADR-0012) — `theme.js` plus `widgets/`, `services/` and
      `modules/`; network, brightness, sound, notifications, session menu, a
      hidden dock and an OSD; Hyprland, hyprlock, foot and fuzzel configured to
      the same colours
- [x] Configure PipeWire/WirePlumber — no configuration needed. Debian's
      defaults work: an installed system shows both a sink and a source, with
      quickshell and both portals connected as clients.
- [x] Configure portals — no configuration needed. Both services are active and
      xdg-desktop-portal-hyprland reports `[screencopy] init successful`.
- [x] Configure Polkit — no configuration beyond starting hyprpolkitagent from
      the Hyprland config; `pkexec` raises a graphical prompt.
- [x] Configure session startup and greeter (greetd + tuigreet on vt 7 —
      vt 1 collides with the console and the live autologin getty)
- [x] Autologin for the live session only, via a live-config component
- [x] Set the live hostname to `strata` instead of live-config's `debian`
- [x] Configure Calamares via `calamares-settings-debian` — used as shipped,
      with two overrides: `displaymanager.conf` (the greetd trap, ADR-0008) and
      `calamares-sources-final`, whose Debian version hardcodes a stable release
- [x] Produce first ISO — `strata-2026.08.26-amd64.iso`, 1.5 GB, built in 14 min
      from snapshot `20260826T000000Z`, 897 packages
- [x] Test UEFI boot — QEMU with OVMF, `tests/qemu-smoke-test.sh`
- [x] Test Secure Boot in QEMU with Microsoft keys enrolled — shim and GRUB
      signatures verified with sbverify
- [x] Test Secure Boot on real hardware, not only QEMU — the live ISO boots
      from USB on two machines (an AMD desktop and an Intel notebook) with
      Secure Boot left enabled, and `apt update` reaches forky over https
      from the live session

Two firmware complaints were observed and are **not** Strata defects. On the
AMD desktop, `amd_pstate` reports zero frequencies and fails to register with
`-19` (ENODEV), which points at CPPC being unavailable in firmware. On the
Intel notebook, ACPI cannot resolve a symbol under `\_SB.PC00.CNVW` — the
kernel labels it `(bug)` itself, blaming the DSDT. Both would occur on a plain
Debian Testing install and belong upstream (ADR-0001).
- [x] Test the live session before installation — boots unattended into a
      Hyprland session via greetd autologin
- [x] Test installation — Calamares reaches "All done" on GPT with a FAT32 ESP
      and an ext4 root (`tests/qemu-install-test.sh`)
- [x] Test installed boot — boots unaided, `mokutil --sb-state` reports
      "SecureBoot enabled" (`tests/qemu-verify-installed.sh`)
- [x] Add regression test that the installed `sources.list` points at the live
      Debian archive (`tests/check-no-snapshot-leak.sh`) — verified against a
      real image and against a planted leak
- [x] Test networking, audio, Hyprland, Quickshell — all verified inside an
      installed system, not only in the live session

## Phase 3 — CI and Release

- [x] Add CI workflow for repository hygiene and shellcheck
- [x] Add build workflow scaffold with snapshot resolution
- [x] Wire the build job to the build scripts — via `build-in-docker.sh`, not
      by installing live-build on the runner: Ubuntu ships the 3.0~a57 fork
      that predates `--uefi-secure-boot`, so a runner-native build would have
      quietly produced images without a signed boot chain
- [x] Add QEMU smoke tests — `tests/qemu-smoke-test.sh` now returns a verdict
      rather than only collecting screenshots, and gates the release job.
      Verified in both directions, including against a deliberately
      unbootable image
- [x] Generate SHA256 — in `scripts/build.sh`, and re-verified in the release
      job before anything is published
- [x] Generate build manifest (snapshot, epoch, commit, package versions) —
      in `scripts/build.sh`; published as a release asset
- [x] Add manual release job — `workflow_dispatch` with a snapshot input and a
      publish toggle
- [x] Add monthly scheduled evaluation — cron on the first of the month
- [x] Add conditional publish logic — a scheduled run publishes only when the
      package set differs from the last release. Comparing package versions
      rather than snapshot timestamps, since those differ every single day
- [x] Track ISO size against GitHub's 2 GiB release asset limit — the build
      fails outright above it, and warns within 200 MB of it

## Phase 4 — Optional Agent Support

- [x] Design provider-neutral agent metadata — declarative component files
      under `/usr/share/strata/components/`, recording origin rather than
      hardcoding vendors (ADR-0011)
- [x] Implement lazy install helper — `strata install`, with three origins
      (`debian`, `flatpak`, `external`) that are deliberately not treated the
      same. Also covers browsers and editors, not only agents
- [x] Add Codex, Claude Code, OpenCode, Gemini CLI, GitHub Copilot CLI
      definitions — all five, plus firefox, chromium, brave, neovim and kate
- [ ] Add project-aware agent skill/instructions

## Phase 5 — Branding

- [x] Default wallpaper — `scripts/make-wallpaper.py` renders
      `strata-layers.png` from the standard library alone; `hyprpaper` puts it
      up and `hyprlock` reuses it
- [x] Quickshell styling — ADR-0012
- [x] Lock screen — `/etc/hypr/hyprlock.conf`, with `/usr/lib/strata/lock` so
      the keybinding, the session menu and hypridle all produce the same one
- [ ] Logo and wordmark — still the blocker for Calamares branding, below
- [ ] Greeter branding — deliberately still out of scope (AGENTS.md); login
      reliability is not traded for appearance


Calamares branding is blocked on artwork, not on configuration. A branding
component needs an `images:` key with `productIcon`, `productLogo` and
`productWelcome`; omitting it is a **fatal** error and Calamares dies silently,
with no window and no dialog — the reason appears only in
`/root/.cache/calamares/session.log`:

```text
ERROR: FATAL in "/etc/calamares/branding/strata/branding.desc"
    invalid node; first invalid key: "images"
```

`slideshow` and `slideshowAPI` are required too. Until Strata has a logo the
installer keeps Debian's branding, which ADR-0001 makes defensible: what is
installed genuinely is Debian Testing. The launcher entry already says
"Install Strata".


Deliberately after a working MVP. Nothing here blocks Phase 2 or 3.

- [ ] Define Strata visual identity: color palette and typography
- [ ] Create canonical logo mark and wordmark
- [ ] Create SVG-first brand assets
- [ ] Create one default wallpaper
- [ ] Apply restrained Quickshell styling
- [ ] Ensure branding is fully separable from functional configuration

## Phase 6 — Branded Greeter

Separate from Phase 5 because it carries technical risk, not just design work.

- [ ] Evaluate what `gtkgreet` CSS theming can actually deliver
- [ ] Validate keyboard navigation
- [ ] Validate HiDPI behavior
- [ ] Validate multi-monitor login behavior
- [ ] Add Strata logo/background to the greeter only if supported cleanly
- [ ] Revisit ReGreet if and when it enters Debian Testing
