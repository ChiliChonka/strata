# Build environment for Strata images.
#
# live-build is Debian-specific. Ubuntu ships a fork (3.0~a57) that predates
# --uefi-secure-boot, the flag ADR-0002 depends on, so building on an Ubuntu host
# is not an option. This container provides a real Debian Testing toolchain on
# any host that can run OCI containers.
#
# Works with docker and podman. scripts/build-in-docker.sh drives it.
#
# The base image is not pinned by digest. The archive state that actually
# determines image contents is pinned separately via snapshot.debian.org
# (ADR-0005), and the build manifest records the live-build version used.
# Pinning this too would tighten reproducibility further and is a reasonable
# later change.

FROM debian:testing

# DEBIAN_FRONTEND keeps debconf from trying to prompt during image build.
ENV DEBIAN_FRONTEND=noninteractive

# live-build pulls most of what it needs, but the tools that assemble a hybrid
# ISO with a signed EFI boot chain are listed explicitly so a missing one fails
# here rather than forty minutes into a build.
RUN apt-get update \
	&& apt-get install --yes --no-install-recommends \
		live-build \
		debootstrap \
		xorriso \
		isolinux \
		syslinux-common \
		grub-efi-amd64-bin \
		grub-common \
		mtools \
		dosfstools \
		squashfs-tools \
		rsync \
		ca-certificates \
		curl \
		git \
	&& rm -rf /var/lib/apt/lists/*

WORKDIR /build

# No ENTRYPOINT on purpose. The wrapper passes scripts/build.sh explicitly, so
# the container stays useful for poking around interactively when a build fails.
CMD ["/bin/bash"]
