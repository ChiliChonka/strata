# ADR-0007: Default Filesystem Is ext4

## Status

Accepted

## Context

The default filesystem had been left as an open evaluation between ext4 and
Btrfs, with a note that snapshots must not become mandatory for the MVP.

Btrfs has a genuinely project-specific argument in its favour. Strata tracks
Debian **Testing**, which is the one place Strata is riskier than Debian Stable:
a `apt full-upgrade` can pull a broken Mesa, kernel, or Hyprland. Snapshotting
before an upgrade addresses exactly that risk.

Other candidates were considered and eliminated first.

## Eliminated Candidates

**ZFS** and **bcachefs** both require an out-of-tree kernel module built via
DKMS. A locally built module is unsigned, so Secure Boot would require enrolling
a Machine Owner Key — precisely what ADR-0002 rules out. Neither
`zfsutils-linux` nor `bcachefs-tools` is in Debian Testing. Eliminated on
ADR-0002 grounds alone.

**XFS** is solid but offers nothing ext4 does not for a desktop workload: no
snapshots, and it cannot be shrunk. No reason to deviate from the Debian default.

**F2FS** targets raw flash without a translation layer. Irrelevant for the
SSD and NVMe hardware Strata targets.

That leaves ext4 and Btrfs.

## Decision

**ext4 is the default filesystem**, using whatever layout
`calamares-settings-debian` offers by default.

Btrfs remains available to users who select it manually in Calamares. Strata
does not configure subvolumes, snapshots, or compression on their behalf, and
does not ship snapshot tooling in the base image.

## Why Not Btrfs, Given the Rolling-Release Argument

The valuable half of the Btrfs story is not deliverable with Debian-packaged
tooling.

**Boot-into-snapshot is missing.** `grub-btrfs` is not in Debian Testing
(verified 2026-08-26). Without it, rollback only works on a system that still
boots — which excludes the broken-kernel and broken-Mesa cases that motivated
Btrfs in the first place. The remaining benefit is a rollback for problems the
user could likely have fixed from a working shell anyway.

**Snapshot tooling is per-install state, not configuration.** `snapper` 0.10.6
and `timeshift` 25.12.4 are both in Testing, but a working setup needs
configuration, quota groups, cleanup timers, and APT pre/post hooks. That is
ongoing per-installation state management, which works against ADR-0003's
minimal core and against ADR-0001's preference for plain configuration over
project-specific machinery.

**Calamares constrains the layout.** Btrfs subvolume support in
`calamares-settings-debian` is more limited than Debian Installer's, and
ADR-0006 commits Strata to Calamares.

**Btrfs asks more of the user.** Free-space fragmentation, balance operations,
and full-disk edge cases behave differently than on ext4. That is a support
burden Strata cannot carry before it has any users.

ext4, by contrast, is the Debian and Calamares default, needs no configuration,
adds no packages, and has the best-understood recovery path of any Linux
filesystem. That is "boring underneath" applied literally.

## Consequences

### Positive

- zero configuration and zero added packages,
- matches Debian and Calamares defaults, so the installed system is unsurprising,
- best-documented recovery and repair story,
- no per-install state for Strata to manage,
- keeps ADR-0003 intact.

### Negative

- no snapshot-before-upgrade safety net on a rolling suite, which is a real
  loss,
- users who want Btrfs must configure snapshots themselves,
- transparent compression is not available by default.

## Mitigation

The rolling-upgrade risk is real and is not being ignored. It is addressed
elsewhere and more cheaply:

- Debian Testing keeps the previous kernel installed, so a bad kernel is
  recoverable from the GRUB menu without any filesystem support,
- documentation should tell users how to hold or roll back a package with
  ordinary APT,
- monthly image validation catches broken combinations before users meet them.

## Revisit When

- `grub-btrfs` enters Debian Testing, **or**
- snapper integration becomes deliverable as plain configuration with no
  Strata-specific tooling.

Either condition warrants a new ADR superseding this one.
