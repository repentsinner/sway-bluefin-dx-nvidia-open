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
    nvidia-container-toolkit

# Configure greetd display manager
mkdir -p /etc/greetd
cp /ctx/greetd-config.toml /etc/greetd/config.toml

# Create greeter system user using sysusers.d (works with OSTree)
mkdir -p /usr/lib/sysusers.d
cp /ctx/greeter.conf /usr/lib/sysusers.d/greeter.conf

# Create cache directory for tuigreet using tmpfiles.d (works with OSTree)
mkdir -p /usr/lib/tmpfiles.d
cp /ctx/greeter-cache.conf /usr/lib/tmpfiles.d/greeter-cache.conf

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

# Create base hyprland.conf that sources user configs
cat > /etc/hypr/hyprland.conf <<EOF
# Hyprland system-wide configuration
# User configs in ~/.config/hypr/hyprland.conf will override these settings

# Nvidia-specific environment variables
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = WLR_NO_HARDWARE_CURSORS,1

# Aquamarine (Hyprland's rendering backend) settings for Nvidia
env = AQ_DRM_DEVICES,/dev/dri/card0

# General environment variables
env = XCURSOR_SIZE,24
env = ELECTRON_OZONE_PLATFORM_HINT,wayland

# Monitor configuration - HiDPI scaling
monitor=,preferred,auto,1.25

# Input configuration
input {
    kb_layout = us
    kb_options = caps:ctrl_modifier

    follow_mouse = 1

    touchpad {
        natural_scroll = yes
    }

    sensitivity = 0
}

# General settings
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)

    layout = master
}

# Master layout configuration
master {
    new_status = master
    new_on_top = true
    mfact = 0.5
}

# Decorations
decoration {
    rounding = 5

    blur {
        enabled = true
        size = 3
        passes = 1
    }

    drop_shadow = yes
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

# Animations
animations {
    enabled = yes

    bezier = myBezier, 0.05, 0.9, 0.1, 1.05

    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

# Gestures
gestures {
    workspace_swipe = on
}

# Autostart applications
exec-once = lxpolkit
exec-once = mako
exec-once = waybar
exec-once = swww-daemon

# Example keybindings (users should customize in ~/.config/hypr/hyprland.conf)
\$mainMod = SUPER

bind = \$mainMod, RETURN, exec, foot
bind = \$mainMod, Q, killactive,
bind = \$mainMod, M, exit,
bind = \$mainMod, E, exec, thunar
bind = \$mainMod, V, togglefloating,
bind = \$mainMod, D, exec, wofi --show drun
bind = \$mainMod, P, pseudo,
bind = \$mainMod, J, togglesplit,

# Move focus with mainMod + arrow keys
bind = \$mainMod, left, movefocus, l
bind = \$mainMod, right, movefocus, r
bind = \$mainMod, up, movefocus, u
bind = \$mainMod, down, movefocus, d

# Move focus with mainMod + hjkl (vim keys)
bind = \$mainMod, h, movefocus, l
bind = \$mainMod, l, movefocus, r
bind = \$mainMod, k, movefocus, u
bind = \$mainMod, j, movefocus, d

# Switch workspaces with mainMod + [0-9]
bind = \$mainMod, 1, workspace, 1
bind = \$mainMod, 2, workspace, 2
bind = \$mainMod, 3, workspace, 3
bind = \$mainMod, 4, workspace, 4
bind = \$mainMod, 5, workspace, 5
bind = \$mainMod, 6, workspace, 6
bind = \$mainMod, 7, workspace, 7
bind = \$mainMod, 8, workspace, 8
bind = \$mainMod, 9, workspace, 9
bind = \$mainMod, 0, workspace, 10

# Move active window to a workspace with mainMod + SHIFT + [0-9]
bind = \$mainMod SHIFT, 1, movetoworkspace, 1
bind = \$mainMod SHIFT, 2, movetoworkspace, 2
bind = \$mainMod SHIFT, 3, movetoworkspace, 3
bind = \$mainMod SHIFT, 4, movetoworkspace, 4
bind = \$mainMod SHIFT, 5, movetoworkspace, 5
bind = \$mainMod SHIFT, 6, movetoworkspace, 6
bind = \$mainMod SHIFT, 7, movetoworkspace, 7
bind = \$mainMod SHIFT, 8, movetoworkspace, 8
bind = \$mainMod SHIFT, 9, movetoworkspace, 9
bind = \$mainMod SHIFT, 0, movetoworkspace, 10

# Scroll through existing workspaces with mainMod + scroll
bind = \$mainMod, mouse_down, workspace, e+1
bind = \$mainMod, mouse_up, workspace, e-1

# Move/resize windows with mainMod + LMB/RMB and dragging
bindm = \$mainMod, mouse:272, movewindow
bindm = \$mainMod, mouse:273, resizewindow

# Screenshot bindings
bind = , PRINT, exec, grim -g "\$(slurp)" - | wl-copy
bind = SHIFT, PRINT, exec, grim - | wl-copy

# Volume controls
bind = , XF86AudioRaiseVolume, exec, pamixer -i 5
bind = , XF86AudioLowerVolume, exec, pamixer -d 5
bind = , XF86AudioMute, exec, pamixer -t

# Brightness controls
bind = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bind = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# Source user configuration (if it exists)
source = ~/.config/hypr/hyprland.conf
EOF

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

# Configure yafti first-boot application installer
mkdir -p /usr/share/ublue-os/firstboot
cp /ctx/yafti.yml /usr/share/ublue-os/firstboot/yafti.yml