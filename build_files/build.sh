#!/bin/bash

set -ouex pipefail

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/39/x86_64/repoview/index.html&protocol=https&redirect=1

# this installs a package from fedora repos
dnf5 install -y tmux 

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket

# Remove GNOME components not needed for Sway setup
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

# Install Sway and related packages
rpm-ostree install \
    sway \
    waybar \
    swaylock \
    swayidle \
    wofi \
    wlogout \
    xdg-desktop-portal-wlr \
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
    xdg-desktop-portal-gtk \
    thunar \
    wf-recorder \
    greetd \
    greetd-tuigreet

# Configure greetd display manager
mkdir -p /etc/greetd
cp /ctx/greetd-config.toml /etc/greetd/config.toml
systemctl enable greetd.service

# Configure polkit agent to autostart with Sway
mkdir -p /etc/sway/config.d
cp /ctx/sway-polkit.conf /etc/sway/config.d/10-polkit.conf

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