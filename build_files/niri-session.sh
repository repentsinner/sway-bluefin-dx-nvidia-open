#!/bin/bash
# Niri session wrapper
# Sets up environment before starting niri

# Bitwarden SSH agent socket
export SSH_AUTH_SOCK="$HOME/.var/app/com.bitwarden.desktop/data/.bitwarden-ssh-agent.sock"

# Propagate to systemd and dbus for services
systemctl --user set-environment SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
dbus-update-activation-environment SSH_AUTH_SOCK

# Nvidia GPU detection: set rendering env vars only when Nvidia drives a display
# On Intel iGPU + Nvidia passthrough systems, these stay unset and mesa auto-detects
nvidia_has_display=false
for card_dir in /sys/class/drm/card[0-9]*; do
    [ -d "$card_dir/device/driver" ] || continue
    driver=$(basename "$(readlink "$card_dir/device/driver")")
    [ "$driver" = "nvidia" ] || continue
    # Check if any connector on this card has a display attached
    for connector in "$card_dir"/card[0-9]*-*; do
        [ -f "$connector/status" ] || continue
        if [ "$(cat "$connector/status")" = "connected" ]; then
            nvidia_has_display=true
            break 2
        fi
    done
done

if [ "$nvidia_has_display" = true ]; then
    export GBM_BACKEND="nvidia-drm"
    export __GLX_VENDOR_LIBRARY_NAME="nvidia"
    export LIBVA_DRIVER_NAME="nvidia"
fi

# Hand off to niri-session, which starts niri.service and so activates
# graphical-session-pre.target, graphical-session.target and
# xdg-desktop-autostart.target (§spec:session-targets). Running
# `niri --session` directly leaves all three inactive, which silently
# disables xdg-user-dirs.service, xdg-desktop-portal and every autostart
# entry. niri-session re-execs through a login shell, so exports above
# survive into the session.
exec niri-session
