## What does this change?

<!-- One or two sentences. -->

## Why?

<!-- Link an issue or ADR where possible. -->

## Checklist

- [ ] Solved with an existing Debian package or configuration where possible (ADR-0001)
- [ ] No new package added to the base image without justification (ADR-0003)
- [ ] Secure Boot implications considered and documented if the boot chain is touched (ADR-0002)
- [ ] No `snapshot.debian.org` URL reaches the installed system's `sources.list` (ADR-0005)
- [ ] Branding stays separable from functional configuration (ADR-0004)
- [ ] A major architectural decision here has an ADR under `docs/adr/`
- [ ] Documentation updated

## Testing

<!-- What did you actually run? QEMU, bare metal, Secure Boot on or off? -->
