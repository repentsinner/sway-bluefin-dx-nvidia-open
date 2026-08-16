# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image: Universal Blue base with Nvidia open kernel modules
# Tracks :latest (current Fedora), not :gts (Fedora N-1). The hyprland
# ecosystem COPRs that supply hyprlock and hypridle stopped building for
# N-1, and cliphist reaches Fedora proper only from 44.
# No desktop environment — we add niri + wayland stack in build.sh
FROM ghcr.io/ublue-os/base-nvidia:latest

### MODIFICATIONS
## make modifications desired in your image and install packages by modifying the build.sh script
## the following RUN directive does all the things required to run "build.sh" as recommended.

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh

### LINTING
## Verify final image and contents are correct.
RUN bootc container lint
