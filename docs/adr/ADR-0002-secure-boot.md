# ADR-0002: Secure Boot Is a Core Requirement

## Status

Accepted

## Context

Many corporate systems and modern Windows dual-boot environments require Secure Boot to remain enabled.

Disabling Secure Boot can:

- violate enterprise device policies,
- trigger recovery or compliance checks,
- interfere with BitLocker/device encryption workflows,
- conflict with software that expects Secure Boot, including some anti-cheat systems,
- make Strata impractical on otherwise compatible hardware.

Therefore Secure Boot cannot be treated as an optional enhancement.

## Decision

Strata must use Debian-native Secure Boot components wherever practical.

The preferred boot chain is:

```text
UEFI
 -> Debian shim
 -> signed GRUB
 -> Debian signed kernel
 -> Debian userspace
```

Strata should not require users to:

- disable Secure Boot,
- enroll project-specific Machine Owner Keys,
- replace firmware trust settings,
- maintain locally signed kernels or bootloaders for normal operation.

Where possible, Strata should inherit Debian's signed boot chain without modification.

Any change that affects the boot chain must explicitly document its Secure Boot implications.

## Consequences

### Positive

- suitable for managed corporate devices where permitted,
- better compatibility with Windows dual-boot systems,
- fewer firmware changes required,
- reduced user support burden,
- leverages Debian's signing and update infrastructure.

### Negative

- bootloader customization is constrained,
- custom kernels become significantly more complex,
- some experimental boot approaches may not be viable,
- certain low-level customizations may be rejected even if technically interesting.

These limitations are accepted.

## Priority Rule

Boot reliability and Secure Boot compatibility take precedence over visual boot customization or custom bootloader features.
