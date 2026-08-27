# Contributing to Strata

Strata is configuration, not a distribution. Almost everything it does is decide
which Debian packages to install and how to configure them. Contributions that
keep it that way are easy to accept; contributions that grow it into something
else are not, however good they are in isolation.

## The first question

> Can this be solved with an existing Debian package or configuration?

If yes, that is the solution. This is [ADR-0001](docs/adr/ADR-0001-debian-not-a-fork.md)
and it is the reason the project exists at all: an installed Strata system should
stay a normal Debian Testing system, so that Debian's security updates, kernels
and firmware keep working without anyone here maintaining them.

Three tasks in this repository were closed as *verified* rather than
*configured* — PipeWire, the desktop portals and Polkit needed no configuration
files whatsoever. That is the ideal outcome, not a gap.

## The decisions are binding

`docs/adr/` holds ten accepted decisions. They are constraints, not history.
Before proposing anything that adds a package, a daemon or a repository, read
the relevant one:

| If your change… | Read |
|---|---|
| adds a package to the base image | [ADR-0003](docs/adr/ADR-0003-minimal-core-optional-layers.md) |
| touches the boot chain | [ADR-0002](docs/adr/ADR-0002-secure-boot.md) |
| touches mirrors or the build | [ADR-0005](docs/adr/ADR-0005-build-reproducibility-and-snapshot-pinning.md) |
| touches the installer | [ADR-0006](docs/adr/ADR-0006-live-iso-with-calamares-installer.md) |
| touches the greeter or session | [ADR-0008](docs/adr/ADR-0008-session-and-greeter.md) |
| adds artwork or theming | [ADR-0004](docs/adr/ADR-0004-branding-without-desktop-fork.md) |

A decision that should change gets a new ADR superseding the old one. It does
not get quietly worked around.

## Some code exists to stop you

Not every oddity in this repository is an oversight. Several are load-bearing,
and each says so in a comment where it lives:

- **greetd is deliberately absent** from `calamares/modules/displaymanager.conf`.
  Adding it looks like fixing an omission and breaks every installation.
- **`--uefi-secure-boot` is `enable`, not `auto`.** On `auto`, live-build falls
  back to unsigned GRUB with only a warning.
- **`auto/config` carries no inline comments** inside the `lb config` call. A `#`
  after a line continuation silently discards every flag that follows.
- **`sudo` is listed explicitly** in the package lists rather than arriving as a
  dependency, or `apt-get autoremove` removes it during installation.

If a comment explains why something is written awkwardly, that explanation is the
change history of a real failure.

## Building and testing

Any host with Docker or Podman:

```bash
sudo ./scripts/build-in-docker.sh          # about 10 minutes
```

Do not install `live-build` from Ubuntu's repositories to build this. Ubuntu
ships a fork predating `--uefi-secure-boot`, so it produces images without a
signed boot chain and does not tell you.

Three test tiers, cheapest first. Use the cheapest one that can answer your
question:

```bash
STRATA_TEST_TOOLS=1 sudo ./scripts/build-in-docker.sh   # image with a guest agent

./tests/qemu-check-live.sh          # ~1 min   boot the ISO and ask it questions
./tests/qemu-verify-installed.sh    # ~4 min   check an installed system
./tests/qemu-install-test.sh        # ~13 min  drive a full installation
./tests/qemu-boot-installed.sh      #          open the installed system in a window
```

`qemu-check-live.sh` also runs a single command:

```bash
./tests/qemu-check-live.sh 'systemctl --failed'
```

The live and installed systems differ in ways that matter — their
`sources.list` files are written by entirely different mechanisms, and a defect
hid in exactly that gap. If your change could differ between them, test both.

## Pull requests

- Explain **why**, not what. The diff shows what.
- If you found a defect, say how it presented, not only what fixed it. The
  symptom is what the next person will search for.
- State what you did *not* verify. "Not tested on real hardware" is useful;
  silence is not.
- Say when something is deliberate but looks wrong.

CI runs repository hygiene and shellcheck. Shell scripts must pass shellcheck
cleanly; where a warning is wrong, disable it by number with a comment saying
why.

## Reporting problems

If the same behaviour occurs on plain Debian Testing with the same packages, it
belongs upstream in Debian, not here. Two firmware complaints on real hardware —
`amd_pstate` failing to register and an ACPI symbol the DSDT does not define —
are Debian's business, and are recorded in TASKS.md as such.

For security issues see [SECURITY.md](SECURITY.md).
