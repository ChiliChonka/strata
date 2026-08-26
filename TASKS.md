# Strata — Initial Agent Task List

## Phase 1 — Research and Design

- [ ] Verify current Debian Testing availability of Hyprland.
- [ ] Verify current Debian Testing availability of Quickshell.
- [ ] Identify required runtime dependencies.
- [ ] Verify Debian Secure Boot path for live and installed images.
- [ ] Compare live-build vs Debian Installer based approaches.
- [ ] Decide whether Live mode is required for MVP.
- [ ] Select login/session approach.
- [ ] Select terminal.
- [ ] Select launcher.
- [ ] Select notification daemon or Quickshell equivalent.
- [ ] Select clipboard tooling.
- [ ] Select screenshot tooling.
- [ ] Select lock and idle tooling.
- [ ] Select Polkit agent.
- [ ] Determine portal backend combination.
- [ ] Decide ext4 vs Btrfs.
- [ ] Design QEMU Secure Boot testing.
- [ ] Validate GitHub Actions feasibility and runner constraints.
- [ ] Document findings before implementation.

## Phase 2 — MVP Build

- [ ] Create live-build configuration.
- [ ] Add explicit package lists.
- [ ] Add Hyprland minimal config.
- [ ] Add Quickshell minimal config.
- [ ] Configure PipeWire/WirePlumber.
- [ ] Configure portals.
- [ ] Configure Polkit.
- [ ] Configure session startup.
- [ ] Produce first ISO.
- [ ] Test UEFI boot.
- [ ] Test Secure Boot.
- [ ] Test installation.
- [ ] Test installed boot.
- [ ] Test networking.
- [ ] Test audio.
- [ ] Test Hyprland.
- [ ] Test Quickshell.

## Phase 3 — CI and Release

- [ ] Add GitHub Actions build workflow.
- [ ] Add QEMU smoke tests.
- [ ] Generate SHA256.
- [ ] Generate package manifest.
- [ ] Add manual release job.
- [ ] Add monthly scheduled evaluation.
- [ ] Add conditional publish logic.

## Phase 4 — Optional Agent Support

- [ ] Design provider-neutral agent metadata.
- [ ] Implement lazy install helper.
- [ ] Add Codex definition.
- [ ] Add Claude Code definition.
- [ ] Add OpenCode definition.
- [ ] Add Gemini CLI definition.
- [ ] Add GitHub Copilot CLI definition.
- [ ] Add project-aware agent skill/instructions.


## Phase 5 — Branding and Greeter

- [ ] Define Strata visual identity.
- [ ] Create canonical logo mark and wordmark.
- [ ] Create SVG-first brand assets.
- [ ] Create one default wallpaper.
- [ ] Evaluate lightweight Wayland-native greeters.
- [ ] Compare greetd-based graphical greeters with other lightweight display managers.
- [ ] Validate keyboard navigation.
- [ ] Validate HiDPI behavior.
- [ ] Validate multi-monitor login behavior.
- [ ] Add Strata logo/background to greeter if supported cleanly.
- [ ] Ensure branding is fully separable from functional configuration.
- [ ] Document asset licensing.
