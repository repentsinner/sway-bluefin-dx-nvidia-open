# Tiling Bluefin-DX (Experimental)

A custom [bootc](https://github.com/bootc-dev/bootc) image based on Universal Blue's Bluefin-DX, replacing GNOME with a tiling window manager for a keyboard-driven Wayland workflow with Nvidia GPU support.

**Current Implementation**: Hyprland

## Project Goals

This image aims to provide:

1. **Reliability**: A stable, well-supported tiling window manager that works consistently
2. **Visual Quality**: Proper high-DPI support and modern aesthetics (not terminal-era visuals)
3. **Nvidia Compatibility**: Full GPU support for Nvidia hardware
4. **Developer Workflow**: Preserve Bluefin-DX's development tools while adding tiling capabilities
5. **Keyboard-Driven**: Efficient tiling window management

## Key Features

### Excellent High-DPI Support
Hyprland provides superior HiDPI scaling with proper fractional scaling support, ensuring crisp text and UI elements on modern displays.

### Master Layout
Native master-stack tiling layout that intelligently manages window placement, perfect for focused development workflows.

## What This Image Does

This image transforms Bluefin-DX into a tiling window manager system by:

### GNOME Removal
Removes GNOME Shell, GDM, Mutter, and all GNOME Shell extensions to create a minimal base for Hyprland.

### Hyprland Installation
Installs a complete Hyprland environment including:
- **Window Manager**: Hyprland with full Nvidia compatibility
- **Status Bar**: Waybar
- **Application Launcher**: Wofi
- **Terminal**: Foot
- **Lock Screen**: Hyprlock with hypridle for automatic locking
- **Notifications**: Mako
- **Screenshots**: Grim and Slurp
- **Screen Recording**: wf-recorder
- **Wallpaper**: swww
- **File Manager**: Thunar
- **Display Management**: wdisplays
- **Utilities**: wl-clipboard, cliphist, pamixer, brightnessctl

### Display Manager
- Uses **greetd** with **tuigreet** instead of GDM
- Properly configured for OSTree-based systems using sysusers.d and tmpfiles.d
- Greeter user and cache directory set up correctly
- Launches Hyprland with full Nvidia environment variables

### Theming
- Default GTK theme set to **adw-gtk3-dark** for both GTK 3 and GTK 4
- Dark theme preference enabled by default
- Configuration applied via `/etc/skel` for all new users

### System Configuration
- **Polkit agent**: lxpolkit configured to autostart with the compositor
- **Portals**: xdg-desktop-portal-hyprland and xdg-desktop-portal-gtk for proper Wayland integration
- **Input settings**:
  - Caps Lock remapped to Control
  - Natural scrolling enabled for touchpads
  - Custom keyboard and mouse configuration
- **Podman socket**: Enabled by default
- **Layout**: Master-stack layout configured as default
- **Nvidia optimizations**: Full environment variable configuration for optimal GPU performance

## Identified Requirements

Based on the current setup, any replacement compositor must support:

### Core Requirements
- **Nvidia GPU compatibility**: Must work with proprietary Nvidia drivers
- **Wayland-native**: No X11 dependencies
- **HiDPI scaling**: Proper fractional scaling and readable text/UI elements
- **OSTree compatibility**: Works with immutable/atomic OS structure

### Integration Requirements
- **Display Manager**: Works with greetd/tuigreet ✓
- **Desktop Portals**: Compatible with xdg-desktop-portal-hyprland ✓
- **Session Management**: Launched via Wayland session files ✓
- **Polkit Integration**: Supports polkit agents for privilege escalation ✓

### User Experience
- **Tiling Management**: Automatic window tiling with keyboard controls
- **Multi-monitor**: Robust multi-display support
- **Configuration**: Declarative config files (no GUI-only settings)
- **Input Remapping**: Custom keyboard layouts (e.g., Caps→Ctrl)

### Development Workflow (Inherited from Bluefin-DX)
- Container tooling compatibility (Podman, distrobox)
- Terminal emulator support
- Screen capture/recording tools
- Visual theming capabilities (GTK apps)

## Installation

From a bootc-based system (Bazzite, Bluefin, Aurora, etc.):

```bash
sudo bootc switch ghcr.io/<username>/hyprland-bluefin-dx-nvidia-open
sudo reboot
```

## Post-Installation Setup

### Tailscale VPN (Optional)

Tailscale is pre-installed and enabled. To set up the GUI:

1. **Set your user as operator** (allows GUI control without sudo):
   ```bash
   sudo tailscale set --operator=$USER
   ```

2. **Install trayscale GUI** (already configured to auto-start):
   ```bash
   flatpak install flathub dev.deedles.Trayscale
   ```

The trayscale icon will appear in your system tray for easy VPN management.

### WireGuard VPN

WireGuard tools are pre-installed. Configure VPN connections via NetworkManager:
- Use `nmcli` for CLI configuration
- Or install `nm-connection-editor` for GUI setup

WireGuard status is shown in the waybar status bar.

## Configuration

After installation, users can customize Hyprland by creating `~/.config/hypr/hyprland.conf`. This file will be sourced by the system configuration and can override any settings.

### Key Bindings (Default)

- **Super + Enter**: Launch terminal (foot)
- **Super + D**: Application launcher (wofi)
- **Super + Q**: Close window
- **Super + M**: Exit Hyprland
- **Super + E**: File manager (Thunar)
- **Super + V**: Toggle floating
- **Super + H/J/K/L**: Move focus (vim keys)
- **Super + 1-9**: Switch workspace
- **Super + Shift + 1-9**: Move window to workspace
- **Print**: Screenshot selection
- **Shift + Print**: Screenshot full screen

All keybindings can be customized in your user configuration file.

## Community Resources

- [Universal Blue Forums](https://universal-blue.discourse.group/)
- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [bootc Discussion Forums](https://github.com/bootc-dev/bootc/discussions)
