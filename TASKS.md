# Strata — Task List

Status legend: `[x]` done · `[ ]` open · `[D]` decided, needs writing up

## Phase 0 — Repository Foundation

- [x] LICENSE (MIT) and LICENSES.md
- [x] Asset license (CC BY-SA 4.0)
- [x] .gitignore covering the live-build working tree
- [x] `.github/` with CI, build scaffold, issue and PR templates
- [x] ADRs consolidated under `docs/adr/` with an index
- [ ] CONTRIBUTING.md
- [ ] SECURITY.md

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
| Notifications | **`mako-notifier` 1.11.0** · `sway-notification-center` |
| Clipboard | **`wl-clipboard` 2.3.0 + `cliphist` 0.5.0** |
| Screenshots | **`grim` 1.5.0 + `slurp` 1.5.0** |
| Lock / idle | **`hyprlock` 0.9.6 + `hypridle` 0.1.8** |
| Polkit agent | **`hyprpolkitagent` 0.1.3** · `lxqt-policykit`, `mate-polkit` |
| Portals | **`xdg-desktop-portal` 1.22.1 + `-hyprland` 1.4.1 + `-gtk` 1.15.3** |
| Greeter | **`greetd` 0.10.3 + `tuigreet` 0.9.1** · `gtkgreet` + `cage` |
| Wallpaper | **`hyprpaper` 0.8.4** |
| Fonts | **`fonts-dejavu-core`** |

Selections in bold are settled by ADR-0008 and ADR-0009.

**Naming trap:** the Debian binary package for the notification daemon is
`mako-notifier`. The source package `mako` builds `python3-mako`, the Python
template library — not a notification daemon.

Not packaged in Testing, do not plan around them: `regreet`, `hyprshot`,
`grub-btrfs`, `bcachefs-tools`, `zfsutils-linux`.

### Open

- [x] Decide XWayland in the base image → stays in, ADR-0010
- [ ] Design QEMU Secure Boot testing with `ovmf` secboot variables
- [ ] Validate GitHub Actions runner constraints: disk space for live-build,
      KVM availability for the QEMU test, snapshot.debian.org throughput
- [ ] Define the minimal default keybinding set
- [ ] Define the repository directory layout

**The design phase is otherwise complete.** ADR-0001 through ADR-0010 cover
every architectural decision needed to begin Phase 2.

## Phase 2 — MVP Build

- [ ] Create live-build configuration with snapshot-pinned bootstrap and chroot
      mirrors, and live binary mirrors (ADR-0005)
- [ ] Add `scripts/build.sh` as the single documented build entry point
- [ ] Add explicit package lists
- [ ] Add Hyprland minimal config under `/etc/strata/hypr/`
- [ ] Add Quickshell minimal config
- [ ] Configure greetd to launch tuigreet, with TTY login documented as fallback
- [ ] Configure PipeWire/WirePlumber
- [ ] Configure portals
- [ ] Configure Polkit
- [ ] Configure session startup and greeter
- [ ] Configure Calamares via `calamares-settings-debian`
- [ ] Produce first ISO
- [ ] Test UEFI boot
- [ ] Test Secure Boot on real hardware, not only QEMU
- [ ] Test the live session before installation
- [ ] Test installation
- [ ] Test installed boot
- [ ] Test that the installed `sources.list` points at the live Debian archive
- [ ] Test networking, audio, Hyprland, Quickshell

## Phase 3 — CI and Release

- [x] Add CI workflow for repository hygiene and shellcheck
- [x] Add build workflow scaffold with snapshot resolution
- [ ] Wire the build job to `scripts/build.sh`
- [ ] Add QEMU smoke tests
- [ ] Generate SHA256
- [ ] Generate build manifest (snapshot, epoch, commit, package versions)
- [ ] Add manual release job
- [ ] Add monthly scheduled evaluation
- [ ] Add conditional publish logic
- [ ] Track ISO size against GitHub's 2 GiB release asset limit

## Phase 4 — Optional Agent Support

- [ ] Design provider-neutral agent metadata
- [ ] Implement lazy install helper
- [ ] Add Codex, Claude Code, OpenCode, Gemini CLI, GitHub Copilot CLI definitions
- [ ] Add project-aware agent skill/instructions

## Phase 5 — Branding

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
