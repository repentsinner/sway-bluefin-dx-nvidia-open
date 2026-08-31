#!/bin/bash

set -ouex pipefail

###############################################################################
# Tilefin Build Script
# Niri compositor on Universal Blue base-nvidia
###############################################################################

# Customize OS name for GRUB boot menu
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Tilefin Nvidia Open"/' /usr/lib/os-release
if [ -f /etc/os-release ] && [ ! -L /etc/os-release ]; then
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Tilefin Nvidia Open"/' /etc/os-release
fi

###############################################################################
# Package Arrays
###############################################################################

#------------------------------------------------------------------------------
# Compositor
#------------------------------------------------------------------------------

COMPOSITOR=(
    niri
)

#------------------------------------------------------------------------------
# Shared Wayland Environment
#------------------------------------------------------------------------------

WAYLAND_CORE=(
    waybar
    fuzzel
    wlogout
    hyprlock                  # Lock screen
    hypridle                  # Idle daemon
    mako                      # Notifications
    swaybg                    # Wallpaper (Fedora; swww is unpackaged)
)

WAYLAND_CLIPBOARD=(
    wl-clipboard
    wl-clip-persist           # Prevents clipboard clearing when source app closes
    cliphist
)

WAYLAND_SCREENSHOT=(
    grim
    slurp
    wf-recorder
)

#------------------------------------------------------------------------------
# Desktop Applications
#------------------------------------------------------------------------------

DESKTOP_APPS=(
    ptyxis                    # Terminal
    thunar                    # File manager
    gvfs                      # Virtual filesystem (network, MTP, trash)
    tumbler                   # Thumbnail service
    mpv                       # Media player
    fish                      # Shell
)

DESKTOP_UTILITIES=(
    lxpolkit                  # Polkit agent
    rofimoji                  # Emoji picker
    nwg-bar                   # Power menu
    network-manager-applet    # Network tray icon
    wdisplays                 # Display configuration
)

#------------------------------------------------------------------------------
# System
#------------------------------------------------------------------------------

SYSTEM_UTILS=(
    pamixer
    brightnessctl
    greetd
    greetd-tuigreet
    gum                       # TUI menus for ujust recipes
    gnome-keyring             # Secret Service (org.freedesktop.secrets) for gh/secret-tool (§spec:credential-storage)
    gnome-keyring-pam         # Activates the keyring auto-unlock lines already in /etc/pam.d/greetd
    xdg-user-dirs             # Creates ~/Downloads etc. so Flatpak xdg-* grants resolve (§spec:xdg-user-dirs)
    dbus-tools                # dbus-update-activation-environment, needed by the session wrapper (§spec:session-targets)
    linuxptp                  # ptp4l/phc2sys — PTP clock sync for ST2110 (§spec:ptp)
)

SYSTEM_THEMING=(
    adw-gtk3-theme
)

FONTS=(
    fira-code-fonts
    fontawesome-fonts-all
    google-noto-emoji-fonts
)

#------------------------------------------------------------------------------
# Virtualization (Windows VM + Looking Glass support)
#------------------------------------------------------------------------------

VIRTUALIZATION=(
    libvirt
    libvirt-daemon-kvm
    qemu-kvm
    virt-manager
    virt-install
    edk2-ovmf                 # UEFI firmware for VMs
    swtpm                     # TPM emulation (Windows 11 requirement)
    swtpm-tools
    looking-glass-client      # Low-latency framebuffer for GPU passthrough (from COPR)
    virtiofsd                 # Fast file sharing with VMs
)

#------------------------------------------------------------------------------
# Repositories
#------------------------------------------------------------------------------

COPR_REPOS=(
    craftidore/wayblueorg-hyprland  # hyprlock, hypridle (used with Niri too)
    leloubil/wl-clip-persist
    pgaskin/looking-glass-client
)

###############################################################################
# Enable System Services (base image)
###############################################################################

systemctl enable podman.socket
systemctl enable rpm-ostreed-automatic.timer  # Auto-stage image upgrades

# Production-mode update lock (§spec:production-mode): drop-in gates auto-staging on the
# presence of /etc/tilefin/production-mode. The drop-in ships read-only
# in /usr/lib/; the flag file is mutable per-machine in /etc/.
install -Dm644 /ctx/rpm-ostreed-automatic-production.conf \
    /usr/lib/systemd/system/rpm-ostreed-automatic.service.d/production.conf

###############################################################################
# Configure Repositories
###############################################################################

echo "Enabling COPR repositories..."
for repo in "${COPR_REPOS[@]}"; do
    echo "  Enabling COPR: $repo"
    dnf5 -y copr enable "$repo" || echo "  Warning: Failed to enable $repo (may not support this Fedora version)"
done

###############################################################################
# Install Packages
###############################################################################

ALL_PACKAGES=(
    # Compositor
    "${COMPOSITOR[@]}"
    # Wayland environment
    "${WAYLAND_CORE[@]}"
    "${WAYLAND_CLIPBOARD[@]}"
    "${WAYLAND_SCREENSHOT[@]}"
    # Desktop
    "${DESKTOP_APPS[@]}"
    "${DESKTOP_UTILITIES[@]}"
    # System
    "${SYSTEM_UTILS[@]}"
    "${SYSTEM_THEMING[@]}"
    "${FONTS[@]}"
    # Virtualization
    "${VIRTUALIZATION[@]}"
)

echo "Installing ${#ALL_PACKAGES[@]} packages..."
dnf5 install -y --setopt=install_weak_deps=False "${ALL_PACKAGES[@]}"

# VMware guest tooling ships in the base image but this is bare metal
# (systemd-detect-virt reports none). open-vm-tools-desktop drops
# /etc/xdg/autostart/vmware-user.desktop, which fails at every login with
# "could not open /proc/fs/vmblock/dev". Nothing else depends on it.
if rpm -q open-vm-tools >/dev/null 2>&1; then
    echo "Removing VMware guest tooling (bare metal host)..."
    dnf5 remove -y open-vm-tools open-vm-tools-desktop
fi

###############################################################################
# Enable System Services (installed packages)
###############################################################################

systemctl enable libvirtd.socket          # VM management (socket-activated)

###############################################################################
# Cleanup Repositories
###############################################################################

echo "Cleaning up repositories..."
for repo in "${COPR_REPOS[@]}"; do
    dnf5 -y copr disable "$repo" || true
done

###############################################################################
# Install Additional Tools
###############################################################################

# VS Code: install from Microsoft repo (not in base image)
echo "Installing VS Code..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc
dnf5 config-manager addrepo --from-repofile=https://packages.microsoft.com/yumrepos/vscode/config.repo
dnf5 install -y code

# Tailscale: install from Tailscale's yum repo (§spec:tailscale). Neither
# Fedora nor base-nvidia packages it. The repo baseurl is keyed on $basearch,
# not $releasever, so it survives Fedora release bumps.
echo "Installing Tailscale..."
rpm --import https://pkgs.tailscale.com/stable/fedora/repo.gpg
dnf5 config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
dnf5 install -y tailscale

# tailscaled owns the tailscale0 interface, routes and DNS, so it belongs to
# the host rather than a container. Enabled here, not in the package-service
# block above, because the package is installed in this section.
systemctl enable tailscaled.service

# niri-desaturate (fork with desaturate window rule support)
# Replaces the COPR niri package until upstream merges the PR
# https://github.com/repentsinner/niri-desaturate
echo "Installing niri-desaturate..."
curl -Lo /tmp/niri-desaturate.rpm "https://github.com/repentsinner/niri-desaturate/releases/download/v26.04.0.1/niri-26.04.0.1-1.x86_64.rpm"
dnf5 install -y --allowerasing /tmp/niri-desaturate.rpm
rm -f /tmp/niri-desaturate.rpm

###############################################################################
# Configure Display Manager (greetd)
# Note: greetd package provides /usr/lib/sysusers.d/greetd.conf (creates greetd user)
# but its tmpfiles.d only sets ownership, doesn't create /var/lib/greetd
###############################################################################

mkdir -p /etc/greetd
cp /ctx/greetd-config.toml /etc/greetd/config.toml

# Create greetd home directory (package tmpfiles.d doesn't do this)
mkdir -p /usr/lib/tmpfiles.d
cp /ctx/greeter-cache.conf /usr/lib/tmpfiles.d/greetd-home.conf

# Create Wayland session directory if needed
mkdir -p /usr/share/wayland-sessions

systemctl enable greetd.service

# The base image enables authselect's with-fingerprint, but fprintd-pam is
# not installed and this hardware has no reader. The generated stack then
# references a missing pam_fprintd.so and logs a dlopen error on every
# login. Drop the feature so the stack matches what is installed.
if authselect current 2>/dev/null | grep -q with-fingerprint; then
    echo "Disabling authselect with-fingerprint (no reader, no fprintd-pam)..."
    authselect disable-feature with-fingerprint
fi

###############################################################################
# Configure Wayland Environment
###############################################################################

# Electron apps: use native Wayland for proper fractional scaling
mkdir -p /etc/environment.d
cp /ctx/electron-wayland.conf /etc/environment.d/electron-wayland.conf

# Flatpak overrides: system-wide (apply to all users automatically)
mkdir -p /var/lib/flatpak/overrides
cat > /var/lib/flatpak/overrides/global <<EOF
[Context]
sockets=wayland;

[Environment]
ELECTRON_ENABLE_WAYLAND=1
ELECTRON_OZONE_PLATFORM_HINT=wayland
EOF

###############################################################################
# Configure CLI Tools
###############################################################################

# Tool aliases and shell hooks (resolved at runtime from $PATH)
cp /ctx/tool-aliases.sh /etc/profile.d/tool-aliases.sh
cp /ctx/local-path.sh /etc/profile.d/local-path.sh
mkdir -p /etc/fish/conf.d
cp /ctx/tool-aliases.fish /etc/fish/conf.d/tool-aliases.fish
cp /ctx/local-path.fish /etc/fish/conf.d/local-path.fish

# Silence kbd unicode_start on the tty1 login shell (see the file's comment)
mkdir -p /etc/fish/functions
cp /ctx/unicode-start-noop.fish /etc/fish/functions/unicode_start.fish

# Default userbox distrobox declaration (bootstrap for new accounts)
mkdir -p /etc/skel/.config/distrobox
cp /ctx/userbox.ini /etc/skel/.config/distrobox/userbox.ini

###############################################################################
# Configure Wayland Components
###############################################################################

# hyprlock + hypridle (lock screen and idle management)
# System-wide via XDG fallback (/etc/xdg/hypr/) — hyprutils findConfig() checks this path
# Users can override in ~/.config/hypr/
mkdir -p /etc/xdg/hypr
cp /ctx/hyprlock.conf /etc/xdg/hypr/hyprlock.conf
cp /ctx/hypridle-niri.conf /etc/xdg/hypr/hypridle.conf

# hypridle runs as a --user service (§spec:auto-suspend §spec:hypridle-user-service) so the re-arm timer can
# restart it. niri starts it via spawn-at-startup; not enabled here
# because niri --session does not activate graphical-session.target.
install -Dm644 /ctx/hypridle.service /usr/lib/systemd/user/hypridle.service

# Weekday 18:00 timer re-arms hypridle at the business-hours boundary
# (§spec:auto-suspend §spec:weekday-rearm). Enabled for all users; timers.target is reached by the
# user manager independent of the graphical session.
install -Dm644 /ctx/tilefin-hypridle-rearm.service /usr/lib/systemd/user/tilefin-hypridle-rearm.service
install -Dm644 /ctx/tilefin-hypridle-rearm.timer /usr/lib/systemd/user/tilefin-hypridle-rearm.timer
systemctl --global enable hypridle.service        # Pulled in by graphical-session.target (§spec:session-targets)
systemctl --global enable tilefin-hypridle-rearm.timer

# waybar (status bar)
# System-wide config via XDG fallback (/etc/xdg/waybar/)
# Users can override by creating ~/.config/waybar/config
mkdir -p /etc/xdg/waybar
cp /ctx/waybar-config-niri.json /etc/xdg/waybar/config
cp /ctx/waybar-style.css /etc/xdg/waybar/style.css
install -Dm755 /ctx/update-check.sh /usr/share/tilefin/scripts/update-check.sh
install -Dm755 /ctx/notification-indicator.sh /usr/share/tilefin/scripts/notification-indicator.sh
install -Dm755 /ctx/auto-suspend.sh /usr/share/tilefin/scripts/auto-suspend.sh

# mako (notifications) — no system path support, must use skel
mkdir -p /etc/skel/.config/mako
cp /ctx/mako.conf /etc/skel/.config/mako/config

# nwg-bar (power menu) — no system path support, must use skel
mkdir -p /etc/skel/.config/nwg-bar
cp /ctx/nwg-bar.json /etc/skel/.config/nwg-bar/bar.json

# compositor-exit (logout script)
install -Dm755 /ctx/compositor-exit.sh /usr/bin/compositor-exit

# XDG desktop portal (use GTK backend instead of GNOME)
# System-wide via XDG_CONFIG_DIRS fallback
mkdir -p /etc/xdg/xdg-desktop-portal
cp /ctx/portals.conf /etc/xdg/xdg-desktop-portal/portals.conf

###############################################################################
# Configure Niri
###############################################################################

# Niri config: system-wide via /etc/niri/ fallback
# Users can override by creating ~/.config/niri/config.kdl
mkdir -p /etc/niri
cp /ctx/niri-config.kdl /etc/niri/config.kdl

# Session wrapper (sets SSH_AUTH_SOCK before starting niri)
install -Dm755 /ctx/niri-session.sh /usr/bin/niri-tilefin-session
cp /ctx/niri-tilefin.desktop /usr/share/wayland-sessions/niri-tilefin.desktop

# Remove stock niri session file (we use our Tilefin version)
rm -f /usr/share/wayland-sessions/niri.desktop

###############################################################################
# Configure GTK Theming
###############################################################################

# GTK 3/4: system-wide defaults (users can override in ~/.config/gtk-*/settings.ini)
mkdir -p /etc/gtk-3.0
mkdir -p /etc/gtk-4.0

cat > /etc/gtk-3.0/settings.ini <<EOF
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-font-name=Cantarell 11
gtk-application-prefer-dark-theme=true
EOF

cat > /etc/gtk-4.0/settings.ini <<EOF
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-font-name=Cantarell 11
gtk-application-prefer-dark-theme=true
EOF

# GTK 2: no system path, must use skel
cat > /etc/skel/.gtkrc-2.0 <<EOF
gtk-theme-name="adw-gtk3-dark"
gtk-icon-theme-name="Adwaita"
gtk-cursor-theme-name="Adwaita"
gtk-font-name="Cantarell 11"
EOF

###############################################################################
# Configure Virtualization
###############################################################################

# Allow wheel group to manage VMs without additional group membership
mkdir -p /etc/polkit-1/rules.d
cat > /etc/polkit-1/rules.d/50-libvirt.rules <<'EOF'
polkit.addRule(function(action, subject) {
    if (action.id == "org.libvirt.unix.manage" &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

# Raise memlock limit for GPU/RDMA workloads (nvidia_p2p_get_pages,
# ibv_reg_mr). Applies to all users in wheel group.
# PAM path — covers interactive login sessions (greetd → niri → terminal)
mkdir -p /etc/security/limits.d
cat > /etc/security/limits.d/99-memlock.conf <<'EOF'
# Unlimited memlock for wheel group — required for GPU pinned memory
# and RDMA verb registration (DeckLink capture, future Rivermax)
@wheel  -  memlock  unlimited
EOF

# systemd path — covers user services (e.g. userbox.service)
mkdir -p /etc/systemd/user.conf.d
cat > /etc/systemd/user.conf.d/memlock.conf <<'EOF'
[Manager]
DefaultLimitMEMLOCK=infinity
EOF

# Raise the inotify instance cap. The kernel default (128) is exhausted by
# a development workload: every conmon (one per podman container, including
# userbox and kind nodes) takes an instance, as do editors, direnv, and file
# watchers. Exhaustion shows up as "conmon: Failed to create inotify fd".
# See §spec:inotify-instance-cap.
mkdir -p /usr/lib/sysctl.d
cat > /usr/lib/sysctl.d/90-inotify.conf <<'EOF'
# 512 matches the kind rootless-podman recommendation
fs.inotify.max_user_instances = 512
EOF

# Turn an unrecoverable hang into a recorded panic. The capture chain below
# this is already complete — pstore registers the firmware-backed ERST
# backend and systemd-pstore.service is enabled in the base image — but
# nothing converted a hang into a panic, so a freeze left no evidence at all.
# See §spec:crash-capture.
cat > /usr/lib/sysctl.d/91-crash-capture.conf <<'EOF'
# All SysRq functions. Alt+SysRq+w (blocked tasks) and Alt+SysRq+l (CPU
# backtraces) put a diagnosis in the log while the machine is still wedged;
# REISUB gets a clean sync out of one that is past saving. The kernel default
# of 16 permits only an emergency sync.
kernel.sysrq = 1

# A hard lockup — a CPU that stopped answering the NMI watchdog — is already
# fatal. Panicking records why, instead of leaving a silent freeze.
kernel.hardlockup_panic = 1

# An oops leaves the kernel in an undefined state. Panic while the trace can
# still be written rather than limping on to a worse failure.
kernel.panic_on_oops = 1

# Reboot 20s after a panic, which gives pstore time to write. The default of 0
# leaves the machine dead at the panic screen until someone walks over to it,
# and the trace is in pstore either way.
kernel.panic = 20

# kernel.softlockup_panic is deliberately left at 0. A soft lockup is 20s in
# the kernel without scheduling, which heavy DMA from the capture card or the
# NICs can reach without the machine being wedged, so enabling it trades a
# silent freeze for spurious reboots. Turn it on for the duration of a bisect,
# not as standing configuration.
EOF

# Enable IOMMU for GPU passthrough (harmless on single-GPU systems)
# This sets kernel args that will be applied on next boot after image switch
mkdir -p /usr/lib/bootc/kargs.d
cat > /usr/lib/bootc/kargs.d/10-iommu.toml <<'EOF'
# Enable the IOMMU so VFIO can hand a GPU to a guest (§spec:virtualization).
# These two are the whole requirement for passthrough and are harmless on a
# host that never passes anything through.
#
# iommu=pt is deliberately absent (§spec:iommu-mode). It is a host-side
# performance preference, not a passthrough prerequisite, and it costs the
# IOMMU protection that is the reason to turn the thing on.
kargs = ["intel_iommu=on", "amd_iommu=on"]
EOF

# Enable verbose boot (show kernel and systemd messages instead of splash)
# Note: bootc kargs.d only supports adding args, not deleting.
# To remove 'quiet' and 'rhgb' from base image, run after first boot:
#   rpm-ostree kargs --delete=quiet --delete=rhgb
cat > /usr/lib/bootc/kargs.d/20-verbose-boot.toml <<'EOF'
# Show systemd service status during boot
kargs = ["systemd.show_status=1"]
EOF

# NVIDIA module parameters — kernel args, deliberately not modprobe.d.
#
# nvidia.ko loads from the initramfs, seconds before switch-root. That
# initramfs is generated in the ublue base image, so it captures the base's
# /usr/lib/modprobe.d and nothing this script writes afterwards: options
# placed in /etc/modprobe.d read back as their defaults on the running
# system (verify with /proc/driver/nvidia/params). Kernel command line
# parameters bind at module load regardless of when the module is loaded.
# Regenerating the initramfs in this layer would also work, but kargs are
# cheaper and are already the established pattern here.
#
# One parameter remains. nvidia-drm.modeset was dropped — the driver has
# defaulted it on since 560 and this image ships 610 (§spec:nvidia-drm-modeset)
# — and NVreg_EnableResizableBar with it, a no-op wherever firmware already
# sizes BAR1 to full VRAM (§spec:static-bar1-p2pdma).
#
# NVreg_RestrictProfilingToAdminUsers=0: non-root access to GPU
#   performance counters for Nsight Compute/Systems and CUPTI, which
#   otherwise fail with ERR_NVGPUCTRPERM. Confirm with
#   RmProfilingAdminOnly in /proc/driver/nvidia/params.
cat > /usr/lib/bootc/kargs.d/40-nvidia-params.toml <<'EOF'
kargs = ["nvidia.NVreg_RestrictProfilingToAdminUsers=0"]
EOF

###############################################################################
# Install Custom Justfile (ujust recipes)
###############################################################################

echo "Installing custom ujust recipes..."
cp /ctx/60-custom.just /usr/share/ublue-os/just/60-custom.just
cp /ctx/tilefin.just /usr/share/ublue-os/just/61-tilefin.just
cp /ctx/bmd.just /usr/share/ublue-os/just/62-bmd.just

echo "Build complete!"
