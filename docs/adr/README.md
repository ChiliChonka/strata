# Architecture Decision Records

Significant architectural decisions are recorded here, one file per decision.

| ADR | Decision | Status |
|---|---|---|
| [0001](ADR-0001-debian-not-a-fork.md) | Remain Debian, do not become a Debian fork | Accepted |
| [0002](ADR-0002-secure-boot.md) | Secure Boot is a core requirement | Accepted |
| [0003](ADR-0003-minimal-core-optional-layers.md) | Minimal core, optional layers | Accepted |
| [0004](ADR-0004-branding-without-desktop-fork.md) | Branding without building a custom desktop environment | Accepted |
| [0005](ADR-0005-build-reproducibility-and-snapshot-pinning.md) | Build reproducibility and snapshot pinning | Accepted |
| [0006](ADR-0006-live-iso-with-calamares-installer.md) | Live ISO with Calamares as the installation path | Accepted |
| [0007](ADR-0007-default-filesystem-ext4.md) | Default filesystem is ext4 | Accepted |
| [0008](ADR-0008-session-and-greeter.md) | Session management with greetd and tuigreet | Accepted |
| [0009](ADR-0009-default-package-selection.md) | Default package selection for the minimal desktop | Accepted |
| [0010](ADR-0010-xwayland-in-the-base-image.md) | XWayland stays in the base image | Accepted |
| [0011](ADR-0011-optional-components.md) | Optional components and lazy installation | Accepted |
| [0012](ADR-0012-shell-theme-and-notifications.md) | A themed shell, and notifications served by Quickshell | Accepted |

The design phase is complete. No decisions are currently pending.

## Format

Each record states: context, decision, consequences. Keep them short and keep
them honest about the negative consequences — an ADR that only lists benefits is
not a decision record, it is an advertisement.

Records are immutable once accepted. A decision that changes gets a new ADR that
supersedes the old one, and the old one is marked `Superseded by ADR-XXXX`.
