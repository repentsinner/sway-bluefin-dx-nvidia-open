#!/bin/bash

set -ouex pipefail

# Customize OS name for GRUB boot menu
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Hyprfin-DX Nvidia Open"/' /usr/lib/os-release
# Also update /etc/os-release if it exists as a regular file
if [ -f /etc/os-release ] && [ ! -L /etc/os-release ]; then
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Hyprfin-DX Nvidia Open"/' /etc/os-release
fi

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
# dnf5 install -y tmux 

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

# Enable VPN services
systemctl enable tailscaled.service

# Remove GNOME components not needed for Hyprland setup
rpm-ostree override remove \
    gnome-shell \
    mutter \
    gdm \
    gnome-initial-setup \
    gnome-shell-extension-tailscale-gnome-qs \
    gnome-shell-extension-search-light \
    gnome-shell-extension-logo-menu \
    gnome-shell-extension-gsconnect \
    gnome-shell-extension-common \
    gnome-shell-extension-blur-my-shell \
    gnome-shell-extension-appindicator \
    gnome-shell-extension-window-list \
    nautilus-gsconnect \
    gnome-session-wayland-session \
    gnome-shell-extension-user-theme \
    gnome-classic-session \
    gnome-browser-connector \
    gnome-shell-extension-supergfxctl-gex \
    gnome-shell-theme-yaru \
    gnome-shell-extension-apps-menu \
    gnome-shell-extension-places-menu \
    gnome-shell-extension-launch-new-instance \
    yaru-theme \
    gnome-shell-extension-caffeine \
    gnome-shell-extension-dash-to-dock

# Install Hyprland and related packages
rpm-ostree install \
    hyprland \
    waybar \
    hyprlock \
    hypridle \
    wofi \
    wlogout \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    lxpolkit \
    foot \
    grim \
    slurp \
    mako \
    wl-clipboard \
    cliphist \
    pamixer \
    brightnessctl \
    wdisplays \
    swww \
    adw-gtk3-theme \
    thunar \
    wf-recorder \
    greetd \
    greetd-tuigreet \
    nvidia-container-toolkit \
    rofimoji \
    nwg-bar

# Configure greetd display manager
mkdir -p /etc/greetd
cp /ctx/greetd-config.toml /etc/greetd/config.toml

# Create greeter system user using sysusers.d (works with OSTree)
mkdir -p /usr/lib/sysusers.d
cp /ctx/greeter.conf /usr/lib/sysusers.d/greeter.conf

# Create cache directory for tuigreet using tmpfiles.d (works with OSTree)
mkdir -p /usr/lib/tmpfiles.d
cp /ctx/greeter-cache.conf /usr/lib/tmpfiles.d/greeter-cache.conf

# Configure Electron apps to use native Wayland rendering for proper fractional scaling
mkdir -p /etc/environment.d
cp /ctx/electron-wayland.conf /etc/environment.d/electron-wayland.conf

# Configure all Flatpak apps to use Wayland for proper fractional scaling
# This goes in /etc/skel so new users get it automatically
mkdir -p /etc/skel/.local/share/flatpak/overrides
cat > /etc/skel/.local/share/flatpak/overrides/global <<EOF
[Context]
sockets=wayland;

[Environment]
ELECTRON_ENABLE_WAYLAND=1
ELECTRON_OZONE_PLATFORM_HINT=wayland
EOF

# Configure trayscale to access tailscale socket
cat > /etc/skel/.local/share/flatpak/overrides/dev.deedles.Trayscale <<EOF
[Context]
filesystems=/run/tailscale:rw;
EOF

# Create Wayland session directory if needed
mkdir -p /usr/share/wayland-sessions

# Ensure hyprland.desktop exists for session selection
if [ ! -f /usr/share/wayland-sessions/hyprland.desktop ]; then
    cat > /usr/share/wayland-sessions/hyprland.desktop <<EOF
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
EOF
fi

systemctl enable greetd.service

# Configure Hyprland system-wide settings
mkdir -p /etc/hypr
cp /ctx/hyprland.conf /etc/hypr/hyprland.conf

# Configure default GTK theme (adw-gtk3-dark) for all users
mkdir -p /etc/skel/.config/gtk-3.0
mkdir -p /etc/skel/.config/gtk-4.0

# GTK 3 settings
cat > /etc/skel/.config/gtk-3.0/settings.ini <<EOF
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-font-name=Cantarell 11
gtk-application-prefer-dark-theme=true
EOF

# GTK 4 settings
cat > /etc/skel/.config/gtk-4.0/settings.ini <<EOF
[Settings]
gtk-theme-name=adw-gtk3-dark
gtk-icon-theme-name=Adwaita
gtk-cursor-theme-name=Adwaita
gtk-font-name=Cantarell 11
gtk-application-prefer-dark-theme=true
EOF

# GTK 2 settings (legacy apps)
cat > /etc/skel/.gtkrc-2.0 <<EOF
gtk-theme-name="adw-gtk3-dark"
gtk-icon-theme-name="Adwaita"
gtk-cursor-theme-name="Adwaita"
gtk-font-name="Cantarell 11"
EOF

# Pre-populate Hyprland config for new users (prevents autogenerated defaults from overriding system config)
mkdir -p /etc/skel/.config/hypr
cp /ctx/hyprland.conf /etc/skel/.config/hypr/hyprland.conf
cp /ctx/hyprlock.conf /etc/skel/.config/hypr/hyprlock.conf
cp /ctx/hypridle.conf /etc/skel/.config/hypr/hypridle.conf

# Configure waybar with system tray
mkdir -p /etc/skel/.config/waybar
cp /ctx/waybar-config.json /etc/skel/.config/waybar/config
cp /ctx/waybar-style.css /etc/skel/.config/waybar/style.css

# Configure yafti first-boot application installer
mkdir -p /usr/share/ublue-os/firstboot
cp /ctx/yafti.yml /usr/share/ublue-os/firstboot/yafti.yml