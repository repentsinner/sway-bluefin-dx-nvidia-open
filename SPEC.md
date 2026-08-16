# SPEC: Tilefin System Image

## Purpose §spec:purpose

*Status: complete*

Tilefin is an immutable bootc/OSTree system image that provides a
keyboard-driven Wayland desktop on Nvidia hardware. It layers the Niri
tiling compositor, a Wayland session stack, and desktop applications on
top of Universal Blue's base-nvidia image.

The image provides desktop infrastructure only: compositor, session
management, display manager, theming, and system services. User tools
and development toolchains belong in distrobox containers or user-space
installers — not in the image.

## Base image §spec:base-image

*Status: complete*

`ghcr.io/ublue-os/base-nvidia:latest`

The image tracks `:latest` (current Fedora) rather than `:gts`
(Fedora N-1). The hyprland-ecosystem COPRs that supply `hyprlock`
and `hypridle` stopped building for N-1, leaving no source for two
packages the lock screen and idle management depend on, and
`cliphist` reaches Fedora proper only from 44. Tracking `:latest`
also makes a `bootc switch` from Bluefin a same-release operation.

The base image provides Fedora (bootc/OSTree), Nvidia open kernel
modules, nvidia-container-toolkit, Podman, distrobox, just/ujust,
Flatpak with Flathub, media codecs (ffmpeg/libva via negativo17),
XWayland, xdg-desktop-portal, and xdg-desktop-portal-gtk. It ships no
desktop environment or display manager.

Rationale: the previous base (`bluefin-dx-nvidia-open`) included GNOME,
Homebrew, Docker, Cockpit, ROCm, Samba/AD, and other packages the image
immediately removed or never used. Rebasing on base-nvidia eliminates
the install-then-strip cycle, reduces image size, and makes every
installed package an explicit choice.

## Image boundary §spec:image-boundary

*Status: complete*

The image shall contain only software that meets at least one of:

- Required before or during login (greetd, compositor, session wrapper).
- Required by the desktop session (waybar, clipboard, lock screen).
- A system service or kernel-level integration (libvirt, IOMMU, podman).
- Desktop applications tightly coupled to the session (file manager,
  terminal, polkit agent).

Software that runs on demand with no session dependency belongs
elsewhere:

| Delivery | For |
| --- | --- |
| **Userbox** (distrobox, pre-built OCI) | CLI tools, shell utilities, dev toolchains |
| **Flatpak** | Sandboxed GUI apps |
| **Native installer** (`~/.local/bin`) | Self-updating vendor CLIs (e.g., Claude Code) |

## Niri compositor §spec:niri-compositor

*Status: complete*

The image installs a custom niri fork (niri-desaturate) from a GitHub
release RPM until the desaturate window rule merges upstream.

The session launches via a wrapper script (`niri-tilefin-session`) that
sets `SSH_AUTH_SOCK` before starting niri. A custom `.desktop` file
registers the session with greetd.

System-wide config lives at `/etc/niri/config.kdl`. Users override via
`~/.config/niri/config.kdl`.

## Wayland environment §spec:wayland-stack

*Status: complete*

The image provides a complete Wayland desktop environment:

- **Status bar**: Waybar with system-wide config at `/etc/xdg/waybar/`.
  Custom modules for update checking and notification indicators live at
  `/usr/share/tilefin/scripts/`.
- **Lock screen**: Hyprlock with system config at `/etc/xdg/hypr/`.
- **Idle management**: Hypridle with system config at `/etc/xdg/hypr/`.
- **Notifications**: Mako. No XDG fallback path — uses `/etc/skel/`.
- **Wallpaper**: swaybg.
- **Clipboard**: wl-clipboard, wl-clip-persist, cliphist.
- **Screenshots**: grim, slurp, wf-recorder.
- **App launcher**: Fuzzel.
- **Logout**: wlogout, nwg-bar, compositor-exit script.
- **Desktop portal**: xdg-desktop-portal-gtk (inherited from base image;
  portals.conf selects GTK backend over GNOME).

## Display manager §spec:display-manager

*Status: complete*

greetd with tuigreet provides graphical session login. The base image
enables `getty@tty1` (console login); greetd overrides this. Config at
`/etc/greetd/config.toml`.
A tmpfiles.d entry creates `/var/lib/greetd` at boot (the package's
tmpfiles.d only sets ownership, doesn't create the directory).

## Desktop applications §spec:desktop-apps

*Status: complete*

- **Terminal**: Ptyxis (GTK4, native distrobox integration).
- **File manager**: Thunar with gvfs and tumbler.
- **Media**: mpv.
- **Polkit**: lxpolkit.
- **Utilities**: rofimoji, network-manager-applet, wdisplays.
- **Shell**: fish.
- **Flatpaks** (installed by `ujust setup-user`, not baked into image):
  Bitwarden, Firefox, Slack.

## Theming §spec:theming

*Status: complete*

adw-gtk3-dark for GTK 3/4. System-wide via `/etc/gtk-{3,4}.0/`. GTK 2
via `/etc/skel/.gtkrc-2.0`. Fonts: Fira Code, FontAwesome, Noto Emoji.

## System services §spec:system-services

*Status: complete*

Enabled at build time:

- `podman.socket` — container management.
- `libvirtd.socket` — VM management (socket-activated).
- `greetd.service` — display manager.
- `rpm-ostreed-automatic.timer` — auto-stage image upgrades.

## Virtualization §spec:virtualization

*Status: complete*

Full KVM/QEMU/libvirt stack for Windows VM hosting with Looking Glass
GPU passthrough support:

- libvirt, qemu-kvm, virt-manager, virt-install.
- edk2-ovmf (UEFI firmware), swtpm (TPM emulation for Windows 11).
- looking-glass-client (low-latency framebuffer, from COPR).
- virtiofsd (fast file sharing).
- Polkit rule: wheel group can manage VMs without extra groups.
- IOMMU kernel args enabled via `bootc kargs.d`.

## Wayland environment config §spec:wayland-config

*Status: complete*

- Electron apps forced to native Wayland via
  `/etc/environment.d/electron-wayland.conf`.
- System-wide Flatpak overrides enable Wayland socket and Electron
  Wayland flags.

## Shell configuration §spec:shell-config

*Status: complete*

### Tool aliases §spec:tool-aliases

`/etc/profile.d/tool-aliases.sh` (bash) and
`/etc/fish/conf.d/tool-aliases.fish` (fish) provide aliases and shell
hooks for CLI tools regardless of origin (userbox exports or native
installers): bat, eza, zoxide, starship, direnv, and mise. All entries
are guarded (`command -v` in bash, `command -sq` in fish) and silently
skipped when the tool is absent.

### User-local bin directory in PATH §spec:user-local-bin-path

`/etc/profile.d/local-path.sh` (bash) and
`/etc/fish/conf.d/local-path.fish` (fish) prepend `~/.local/bin` to
`PATH`. The path expands per-user at shell startup. Both scripts are
idempotent — bash guards against duplicate entries, fish uses
`fish_add_path`.

Rationale: userbox exports (§spec:skel-userbox-ini) and native
installers (§spec:ujust-setup-user) place binaries in `~/.local/bin`.
Without this PATH entry, those binaries are unreachable from interactive
shells.

## Userbox — move user tools to distrobox §spec:userbox

*Status: in progress*

### Problem

The image bakes in 7 CLI tools and 1 GUI app with no session-startup
dependencies: `gh`, `chezmoi`, `direnv`, `zoxide`, `starship`, `eza`,
`bws`, `antigravity`. Including them causes image rebuilds for tool
updates and blurs the boundary between OS and personal environment.

### Design

User tools move to a pre-built OCI container image consumed by
distrobox. The container is ephemeral — recreated from the image on
each login via a systemd user unit. No drift from the declaration.

See [repentsinner/userbox](https://github.com/repentsinner/userbox) for
the Containerfile and CI. This repo covers only the image-side changes.

Three repos, three concerns:

| Repo | Contains | Lifecycle |
| --- | --- | --- |
| **tilefin-nvidia-open** | OS image, ujust recipes, shell aliases, skel default | Rare |
| **repentsinner/userbox** | Containerfile for user tools image | Frequent |
| **chezmoi dotfiles** | `.ini`, systemd unit, shell config | Personal |

#### Bootstrap and graceful degradation

A fresh system has no chezmoi (it lives inside the userbox) and no
userbox `.ini` (it's managed by chezmoi). This cycle breaks via three
layers of the same file, each more specific than the last:

1. **Skel default** — the image ships
   `/etc/skel/.config/distrobox/userbox.ini` with a default image path.
   Every new user account gets a working `.ini` at account creation.
2. **ujust override** — `ujust setup-user [image]` accepts an optional
   image argument, rewrites the `.ini`, and runs assembly. Also installs
   native CLI tools (Claude Code, uv). Useful for first boot or
   switching images.
3. **Chezmoi steady-state** — once the userbox is running, chezmoi owns
   the `.ini` going forward. Changes flow from dotfiles.

All shell aliases and hooks are guarded with `command -v`. A system
with no userbox functions normally — it just lacks CLI tools.

### Image does not contain user tools §spec:image-excludes-user-tools

The image does not install `gh`, `chezmoi`, `direnv`, `zoxide`,
`starship`, `eza`, `bat`, `bws`, or `antigravity`. No COPR repos, curl
blocks, or package arrays exist for these tools in the build script.
Native installer tools (Claude Code, uv) are also not in the image —
they are installed per-user by `ujust setup-user`.

### Shell aliases degrade gracefully §spec:aliases-degrade-gracefully

Every alias and shell hook in `tool-aliases.sh` is guarded with
`command -v`. When a tool is absent (no userbox, or userbox not yet
assembled), the alias is silently skipped. No `command not found`
errors on a fresh system.

### Shell hooks for both bash and fish §spec:shell-hooks-bash-fish

`tool-aliases.sh` and `tool-aliases.fish` include guarded hooks
for direnv, zoxide, and starship in both shells. Both files are
system-wide (`/etc/profile.d/` and `/etc/fish/conf.d/`), so no
chezmoi-managed fish config is required for these tools.

### Skel default userbox.ini §spec:skel-userbox-ini

The image ships `/etc/skel/.config/distrobox/userbox.ini`. Every new
user account receives a working distrobox declaration at account
creation.

```ini
[userbox]
image=ghcr.io/repentsinner/userbox:latest
nvidia=true
pull=true
replace=true
start_now=true
exported_bins="/usr/bin/gh /usr/bin/chezmoi /usr/bin/direnv /usr/bin/zoxide /usr/bin/starship /usr/bin/eza /usr/bin/bws"
exported_bins_path="~/.local/bin"
```

`nvidia=true` matches the base image (`base-nvidia`), which ships Nvidia
open kernel modules and the container toolkit. The userbox inherits GPU
access for tools that need it.

Rationale: breaks the chezmoi↔userbox bootstrap cycle. Chezmoi lives
inside the userbox, so it cannot seed its own `.ini`. The skel file
provides a working default; chezmoi overwrites it once available.

### ujust setup-user recipe §spec:ujust-setup-user

The `ublue-os-just` package owns `/usr/share/ublue-os/justfile` and
imports numbered `.just` files up through `50-akmods.just`. It provides
a single downstream extension point: `import? ".../60-custom.just"`.
`just` has no glob imports, so files placed in the directory but not
imported are invisible to `ujust`.

`60-custom.just` is a shim that chains imports to domain-specific
recipe files. It contains no recipes of its own. The image build
installs it alongside the recipe files it references:

| Source file | Installed as | Content |
| --- | --- | --- |
| `build_files/60-custom.just` | `60-custom.just` | Import shim |
| `build_files/tilefin.just` | `61-tilefin.just` | General recipes (`setup-user`) |
| `build_files/bmd.just` | `62-bmd.just` | Blackmagic DeckLink recipes |

Adding a new recipe domain: create a `.just` file, add an `import?`
line to `60-custom.just`, and a `cp` line to `build.sh`.

`tilefin.just` provides a `setup-user` recipe that provisions a new
user's development environment in one step:

The recipe presents three interactive gum menus (all items selected by
default, user deselects with space):

1. **Native CLI tools** — Claude Code, uv, mise. Installed to
   `~/.local/bin` via vendor curl installers. All idempotent.
2. **Flatpak apps** — Firefox, Bitwarden (selected by default); Slack,
   Discord, Signal, Proton VPN (available, unselected). Installed as
   user Flatpaks (`--user`), which persist in `~/.local/share/flatpak`
   and self-update independently of the image.
3. **Userbox container** — yes/no. Assembles from
   `~/.config/distrobox/userbox.ini`.

When an optional image argument is provided, the recipe rewrites the
`image=` line in the `.ini` before assembly. This supports switching
images or overriding the skel default without chezmoi.

The recipe is idempotent. Running it again updates native tools,
skips already-installed Flatpaks, and reassembles the userbox with
`--replace`.

### Systemd user unit for auto-assembly (chezmoi) §spec:userbox-auto-assembly

A systemd user service (`~/.config/systemd/user/userbox.service`) runs
`distrobox assemble create --replace` on login. Managed by chezmoi.

```ini
[Unit]
Description=Assemble userbox distrobox container

[Service]
Type=oneshot
ExecStart=/usr/bin/distrobox assemble create --replace --file %h/.config/distrobox/userbox.ini
RemainAfterExit=true

[Install]
WantedBy=default.target
```

The service starts after login and does not block the GUI session. With
a cached image, container assembly takes ~10 seconds in the background.

## Sunshine streaming server §spec:sunshine

*Status: not started*

The image shall include Sunshine for game/desktop streaming.

Sunshine requires direct GPU access (NVENC encoding), KMS/DRM capture,
udev rules for virtual input devices, and a systemd service. These are
system-level integrations that cannot run from a distrobox.

*Requirements to be specified after research into Sunshine's Fedora
packaging and Niri/Wayland compatibility.*

## VS Code §spec:vscode

*Status: in progress*

The image installs VS Code from Microsoft's yum repository. The build
adds the repo and installs the `code` package directly.

Rationale: the previous base (Bluefin-DX) provided VS Code; base-nvidia
does not. VS Code is a host application that attaches to containers — it
does not belong in the userbox.

## Dynamic GPU detection for hybrid Intel+Nvidia systems §spec:gpu-detection

*Status: in progress*

### Problem

The niri config hardcodes Nvidia-specific environment variables
(`GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME`, `LIBVA_DRIVER_NAME`).
These force the compositor to render through Nvidia. On systems where
an Intel iGPU drives the display and the Nvidia GPU is reserved for
CUDA or PCI passthrough, these variables prevent niri from starting or
cause broken rendering.

Additionally, `WLR_NO_HARDWARE_CURSORS` is a wlroots variable. Niri
uses Smithay and ignores it. The equivalent niri setting is
`debug { disable-cursor-plane }`.

### Design

Nvidia environment variables move from the static niri config
(`config.kdl`) to the session wrapper (`niri-session.sh`). The wrapper
detects whether an Nvidia GPU drives a display output and sets the
variables conditionally.

Detection: if any DRM connector under an Nvidia-driven card reports a
connected display, the system is Nvidia-as-display. Otherwise (Intel
iGPU drives display, Nvidia has no outputs or is unbound), the
variables stay unset and mesa auto-detects Intel.

The niri config retains only hardware-independent environment variables
(`XDG_SESSION_TYPE`, `XCURSOR_SIZE`, `ELECTRON_OZONE_PLATFORM_HINT`).

### No Nvidia environment variables in niri config §spec:niri-config-no-nvidia-vars

`config.kdl` shall not set `GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME`,
`LIBVA_DRIVER_NAME`, or `WLR_NO_HARDWARE_CURSORS`.

### Session wrapper sets Nvidia variables conditionally §spec:session-wrapper-nvidia-vars

`niri-session.sh` shall detect whether Nvidia drives a display output.
When true, it exports `GBM_BACKEND=nvidia-drm`,
`__GLX_VENDOR_LIBRARY_NAME=nvidia`, and `LIBVA_DRIVER_NAME=nvidia`.
When false, it leaves them unset.

### WLR_NO_HARDWARE_CURSORS removed §spec:hardware-cursors-restored

The wlroots variable `WLR_NO_HARDWARE_CURSORS` is removed entirely. It
has no effect on niri (Smithay-based).

## Rebase from Bluefin-DX to base-nvidia §spec:base-image-rebase

*Status: in progress*

### Problem

The image based on Bluefin-DX (`bluefin-dx-nvidia-open:gts`) pulled in
four layers of upstream packages (ublue-os/main → Bluefin base →
Bluefin-DX) then immediately stripped most of them: GNOME Shell, GDM,
Homebrew, and all GNOME extensions. Packages never referenced by the
build — Docker, Cockpit, ROCm, Incus/LXC, Samba/AD/Kerberos, backup
tools — added image size and attack surface for no benefit.

### Design

The image rebases onto `ghcr.io/ublue-os/base-nvidia:gts`, the lowest
Universal Blue layer that includes Nvidia drivers. This image ships no
desktop environment, no display manager, and no application-layer
packages.

Changes from the previous base:

- The GNOME and Homebrew removal steps become no-ops — base-nvidia
  ships neither.
- VS Code (§spec:vscode) is installed directly from Microsoft's yum
  repo.
- `nvidia-container-toolkit` is no longer installed by the build — the
  base image provides it.
- `xdg-desktop-portal-gtk` is no longer installed by the build — the
  base image provides it.
- `tailscaled.service` is no longer enabled. Trayscale Flatpak and its
  `/run/tailscale` override are removed.
- `fish` is added to the package install (previously inherited from
  Bluefin base).

## Automated releases §spec:releases

*Status: in progress*

release-please generates semver tags and a CHANGELOG from conventional
commits. Configuration uses the `simple` release type (`version.txt` +
`CHANGELOG.md`).

Three workflows support the release lifecycle:

- **release-please.yml** — runs on push to main. Opens or updates a
  release PR. When the PR merges, creates a GitHub Release with a
  semver tag.
- **auto-merge-release.yml** — auto-merges release PRs opened by
  release-please after CI passes.
- **build.yml** — adds semver tags to the container image when a git
  tag exists on the commit (e.g., `ghcr.io/.../tilefin-nvidia-open:0.4.0`).

Daily and push builds continue producing `latest` and date-stamped
tags. Semver tags are additive — they appear only when a release is cut.

Version history: 0.1.0 (Sway on Bluefin-DX), 0.2.0 (Hyprland on
Bluefin-DX), 0.3.0 (Niri on Bluefin-DX), 0.4.0 (Niri on base-nvidia).

## Dual-channel image publishing §spec:image-channels

*Status: not started*

### Problem

The build workflow produces `latest` and `latest.YYYYMMDD` tags on
every push to main and daily cron. Semver tags (`0.4.4`) are generated
for release-please tag pushes but never published due to two
independent bugs:

1. **Job dependency skip cascade.** The `build_push` job declares
   `needs: [changes]`, but the `changes` job only runs on
   `pull_request` events (`if: github.event_name == 'pull_request'`).
   On tag pushes, schedule, and `workflow_dispatch`, `changes` is
   skipped. GitHub Actions propagates `skipped` status through `needs`
   — all downstream jobs skip unless they use `if: always()`. The
   `build_push` `if` condition is logically correct but never
   evaluated because the job is skipped before the condition runs.

2. **Push gate rejects tags.** The Login, Push-to-GHCR, and
   cosign-signing steps gate on
   `github.ref == format('refs/heads/{0}', ...)`, which excludes
   `refs/tags/v*`. Even if `build_push` ran on a tag push, it would
   build the image but not publish it.

Bug #1 was introduced in PR #36 (`772e10b`, merged 2026-03-31
after the daily cron). Since then, **no image has been published** —
push-to-main, scheduled cron, and tag push events all skip
`build_push`. The last published image is `latest.20260331`, built
from commit `647a599` by the March 31 scheduled cron before PR #36
merged. This image predates both the BMD justfile (PR #37) and the
AJA removal (PR #35).

The result is four user-facing problems:

1. **Image publishing is completely broken.** No new images have
   reached GHCR since the `changes` job was added.
2. Semver-tagged images never reach GHCR. There is no `stable`
   channel and no way to pin to a known release.
3. There is no distinction between "upstream base image rebuilt" and
   "we shipped a change." A user on `latest` receives both.
4. Daily tags (`latest.20260318`) carry no indication of which
   release they derive from. A user cannot tell whether
   `latest.20260318` contains changes from `0.4.4` or `0.4.3`.

### Design

Two update channels serve different stability preferences:

| Channel | Tag | Builds on | Contains |
| --- | --- | --- | --- |
| `latest` | `latest`, `latest.v0.4.4.20260318` | Daily cron, push to main | Latest main + whatever upstream shipped that day |
| `stable` | `stable`, `0.4.4` | release-please tag push (`v*`) | Exactly the code at the release tag, built against current upstream |

`bootc upgrade` pulls the newest image for whichever tag the machine
tracks. `latest` advances daily. `stable` advances only when
release-please creates a new tag.

#### Tag format

Daily and push-to-main builds embed the current semver from
`version.txt` in the datestamp tag:

- `latest` — rolling, overwritten each build
- `latest.v0.4.4.20260318` — pinned daily snapshot with semver provenance

Tag-triggered builds (release-please `v*` tags) produce:

- `stable` — rolling release channel, overwritten each release
- `0.4.4` — pinned semver snapshot (rollback target)

The `v` prefix appears in git tags (`v0.4.4`) but not in image tags
(`0.4.4`, `stable`). The daily datestamp tag retains `v` as a
separator: `latest.v0.4.4.20260318`.

#### Push gate

The push-to-GHCR and cosign-signing steps gate on:

```text
github.event_name != 'pull_request' && (
  github.ref == format('refs/heads/{0}', github.event.repository.default_branch) ||
  startsWith(github.ref, 'refs/tags/v')
)
```

This allows both main-branch builds and tag-triggered builds to
publish images.

#### OCI version label

The `org.opencontainers.image.version` label uses the semver from
`version.txt` for all builds (e.g., `0.4.4`), replacing the current
`latest.YYYYMMDD` value. This makes the version visible in `bootc
status` and container inspect output regardless of channel.

### Daily tags include semver provenance §spec:daily-tag-provenance

Daily and push-to-main builds read `version.txt` and produce tags
`latest` and `latest.v<version>.<YYYYMMDD>`. The bare `YYYYMMDD` and
`latest.YYYYMMDD` tags are removed.

### Tag builds publish to stable channel §spec:tag-builds-stable-channel

Builds triggered by `v*` tags produce tags `stable` and `<version>`.
The push gate permits `refs/tags/v*` in addition to the default
branch.

### build_push runs on all non-PR events §spec:build-push-all-events

The `build_push` job shall not skip on tag pushes, schedule, or
`workflow_dispatch` due to the `changes` job being skipped. The
`changes` job remains PR-only (path filtering is only useful for
PRs). The `build_push` job's dependency on `changes` shall not
cause a skip cascade for non-PR events.

Rationale: GitHub Actions skips jobs whose `needs` dependencies
were skipped, regardless of the job's own `if` condition. The fix
shall prevent this propagation without removing path filtering for
PRs.

### OCI version label uses semver §spec:oci-version-label

The `org.opencontainers.image.version` label is set to the value of
`version.txt` for all builds.

## Install media §spec:install-media

*Status: in progress*

### Problem

The image is consumed via `bootc switch` from a running Fedora system.
This requires an existing installation to migrate from — there is no
path to bare-metal install on a new machine.

### Design

bootc-image-builder (BIB) produces installable disk images from the
container image. Two ISO types serve different use cases:

| Type | Config | Network | Use case |
| --- | --- | --- | --- |
| `iso` (bootc-installer) | `disk_config/iso.toml` | Not required | Offline install from USB/Ventoy. Image embedded in ISO. |
| `anaconda-iso` | `disk_config/anaconda-iso.toml` | Required | Interactive Anaconda installer. Pulls image from GHCR at install time. |

Offline-first: the `iso` type is the primary install path. A user
copies the ISO to a Ventoy USB drive and boots it. No network, no
intermediate OS, no migration step.

The Anaconda ISO provides a graphical installer with disk, user,
timezone, and network configuration. It suits environments where
network access is available and interactive setup is preferred.

Both types use a 20 GiB minimum root filesystem on btrfs.

### Offline bootc-installer ISO §spec:iso-offline

BIB produces an `iso` type image that embeds the full container image.
The ISO is bootable without network access.

### Anaconda ISO §spec:iso-anaconda

BIB produces an `anaconda-iso` type image with a graphical Anaconda
installer. The RHEL Subscription module is disabled. All other
Anaconda modules use their defaults.

### CI builds both types §spec:ci-builds-iso-types

The `build-disk.yml` workflow matrix includes `iso` and `anaconda-iso`
alongside `qcow2`. Each type maps to its own config file. Builds run
on `workflow_dispatch` and on PRs that touch disk config or the
workflow itself.

### Local build recipes §spec:local-build-recipes

The Justfile provides `build-iso` (offline) and `build-anaconda-iso`
(network) recipes. Both delegate to BIB via `_build-bib` with the
appropriate type and config file.

## Video capture kernel module §spec:decklink-capture

*Status: complete*

### Problem

The system requires a professional SDI video I/O PCIe card for
broadcast capture and playout. The kernel driver for the capture card
shall load at boot on an immutable bootc/OSTree system where
`/usr/lib/modules` is read-only.

### History: AJA Corvid44

The original capture card was an AJA Corvid44 12G with its open-source
`ajantv2.ko` driver built at image time (multi-stage Containerfile
build with GPU Direct RDMA via `AJA_RDMA=1`). The Corvid44's Xilinx
XDMA engine has a 32-bit DMA mask, which required removing `iommu=pt`
from kernel args so the kernel's direct DMA path could bounce-buffer
through SWIOTLB for addresses above 4 GB. The upstream driver
incorrectly set a 64-bit mask; a fork was maintained to fix this.

The AJA card was removed from the system. The 32-bit DMA constraint,
the forked driver, and the IOMMU workaround are no longer needed.

### Current: Blackmagic DeckLink 8K Pro G2

The replacement capture card is a Blackmagic DeckLink 8K Pro G2
(quad-SDI, 64-bit DMA). Its kernel driver (`blackmagic-io.ko`,
`snd_blackmagic-io.ko`) ships as source in the proprietary
`desktopvideo` RPM from Blackmagic Design. The RPM requires accepting
a EULA and cannot be redistributed.

Because the driver is proprietary, it cannot be baked into the public
image. Instead, `ujust bmd-install` automates the out-of-band build
and install workflow:

1. User downloads the Desktop Video tarball after accepting the EULA.
2. `ujust bmd-install <path-to-tarball>` extracts the RPM from the
   tarball, builds kernel modules in a disposable Fedora container
   against the running kernel, installs modules/firmware/libraries
   to `/var/lib/blackmagic/`, configures SELinux contexts, installs
   systemd services (`blackmagic-io.service`,
   `DesktopVideoHelper.service`), udev rules, and ld.so config.
3. After kernel updates, the user re-runs the recipe to rebuild.

The recipe lives in `build_files/bmd.just`, installed as
`/usr/share/ublue-os/just/62-bmd.just` and imported via the
`60-custom.just` shim (see §spec:ujust-setup-user). A companion
`bmd-uninstall` recipe removes all installed artifacts.

The DeckLink's 64-bit DMA mask imposes no IOMMU constraints.
`iommu=pt` is safe with this card.

## Rivermax ST2110 streaming §spec:rivermax

*Status: not started*

### Problem

The machine has a Mellanox ConnectX-6 NIC capable of hardware-
accelerated SMPTE ST 2110 media transport via NVIDIA Rivermax. Rivermax
GPUDirect RDMA allows zero-copy packet I/O between the ConnectX NIC and
GPU memory over Ethernet.

### Rivermax SDK requirements (v1.81.21)

Rivermax hard-requires DOCA-Host (v2.10.0-0.5.3) on the host. Three
DOCA profiles are compatible:

| Profile | Scope |
| --- | --- |
| `doca-roce` | Minimal Ethernet/RoCE kernel drivers (replaces `MLNX_EN`) |
| `doca-ofed` | DOCA-OFED drivers and tools (replaces `MLNX_OFED`) |
| `doca-all` | Full DOCA-Host libraries |

The Rivermax SDK ships pre-built for RHEL 9.2 and Ubuntu 24.04.
Fedora is not a supported target. The SDK is a vendored tarball
containing shared libraries, demo applications (`media_sender`,
`media_receiver`, `generic_sender`, `generic_receiver`), a dev kit,
and CMake components. It requires a license file at
`/opt/mellanox/rivermax/rivermax.lic` (or via
`RIVERMAX_LICENSE_PATH`).

### GPUDirect in Rivermax

Rivermax GPUDirect uses CUDA to allocate GPU memory (which resides in
PCIe BAR1), then passes pointers to the Rivermax API. The NIC
reads/writes GPU memory directly. The v1.81.21 docs reference "CUDA
Toolkit Documentation -> GPUDirect RDMA" for setup — which is the
`nvidia-peermem` + IB verbs path (`ibv_reg_mr()`).

**Rivermax v1.81.21 does not support kernel DMA-BUF
(`ibv_reg_dmabuf_mr`).** Neither the installation guide nor the user
manual mentions DMA-BUF. The NVIDIA GPU Operator docs recommend
DMA-BUF for GPUDirect RDMA generally, but Rivermax has not adopted
it as of this version.

### GPU memory registration: background

Linux offers two mechanisms for an RDMA NIC to access GPU memory:

| | nvidia-peermem (legacy) | DMA-BUF (standard) |
| --- | --- | --- |
| Verbs call | `ibv_reg_mr()` on GPU pointer | `ibv_reg_dmabuf_mr()` on dma-buf fd |
| Kernel mechanism | Proprietary NVIDIA peer memory API registered into IB verbs | Standard Linux `dma-buf` fd sharing (kernel 5.12+) |
| NIC driver requirement | MLNX_OFED or DOCA-OFED | Inbox `rdma-core` sufficient |
| GPU requirement | Any data center GPU | Turing+ with open kernel modules |
| NVIDIA recommendation | Legacy | **Recommended** |

DMA-BUF would avoid the DOCA-OFED dependency entirely — the image
already meets its kernel/driver prerequisites (kernel 6.19, open
NVIDIA driver 595.45.04, Turing+ GPU, inbox `rdma-core`). But since
Rivermax does not use it, this path is blocked on NVIDIA updating
the SDK.

The ublue `kmod-nvidia` build compiles `nvidia-peermem` as a non-
functional stub (`NV_MLNX_IB_PEER_MEM_SYMBOLS_PRESENT` undefined)
because the build environment lacks DOCA-OFED headers. This stub
returns `-EINVAL` on load.

### Design

Rivermax userspace runs in a container. The host provides kernel
drivers and `nvidia-peermem`.

```text
Host (tilefin-nvidia-open):
  ├─ doca-roce or doca-ofed kernel drivers (replaces inbox mlx5)
  ├─ nvidia-peermem.ko (rebuilt with DOCA-OFED headers)
  └─ nvidia.ko, nvidia-uvm.ko (from ublue kmod-nvidia, unchanged)

Container (Rivermax workload):
  ├─ Rivermax SDK + libs (from vendored tarball)
  ├─ CUDA toolkit
  ├─ demo apps (media_sender, media_receiver, etc.)
  └─ rivermax.lic bind-mounted from host
```

Host-side changes required:

1. **Replace inbox Mellanox kernel driver with DOCA-OFED.** The inbox
   `mlx5_core` from Fedora's kernel shall be replaced (or overlaid)
   with DOCA's version. At minimum `doca-roce` profile. DOCA packages
   are published for RHEL — Fedora compatibility is unverified.
2. **Rebuild `nvidia-peermem.ko`** with DOCA-OFED headers present so
   `NV_MLNX_IB_PEER_MEM_SYMBOLS_PRESENT` is defined. This can follow
   the same Containerfile build-stage pattern as kmod-nvidia: compile
   from NVIDIA open-gpu-kernel-modules source, overlay the `.ko` on
   top of the stub from `kmod-nvidia`.
3. **`modules-load.d` entry for `nvidia-peermem`** once the module is
   functional.

A related project
([Fuse-Technical-Group/bluefin-gdx-doca](https://github.com/Fuse-Technical-Group/bluefin-gdx-doca))
has explored the full DOCA stack on CentOS Stream 10 (bluefin-gdx:lts
base). That project installs `doca-all`, `doca-roce`, `rivermax`, and
`rivermax-utils` directly into the image via the Mellanox yum repo.

### Open questions

- Can DOCA-OFED kernel packages (built for RHEL) install on Fedora
  42's kernel, or does Fedora's kernel ABI diverge too far?
- Is `doca-roce` sufficient, or does Rivermax GPUDirect require
  `doca-ofed`?
- Can the DOCA kernel drivers coexist with ublue's `kmod-nvidia`, or
  do they conflict on `nvidia-peermem`?
- Resizable BAR (per-machine BIOS setting) controls how much GPU
  memory the NIC can access for GPUDirect. Without it, BAR1 is
  256 MB regardless of GPU VRAM. This limits the total GPU memory
  registerable with the NIC at once — constraining the number of
  concurrent streams, not per-stream throughput. For low-latency
  broadcast use cases with shallow ring buffers, 256 MB is likely
  sufficient for a small number of streams.

Requirements to be specified after resolving DOCA-OFED packaging on
Fedora bootc.

## NVIDIA DRM modesetting §spec:nvidia-drm-modeset

*Status: in progress*

### Problem

The rebase from Bluefin-DX to base-nvidia (§spec:base-image-rebase) dropped
`nvidia-drm.modeset=1` from kernel args. Bluefin-DX passed it on the
command line; base-nvidia does not. Without DRM modesetting, NVIDIA
cannot properly manage display power states. Display DPMS power cycling
(especially DSC link retraining on 5K displays) corrupts GPU contexts,
causing:

- Electron apps (VS Code, Bitwarden) crash with SIGILL after display
  wakes from sleep.
- Hyprlock renders a flat magenta/red field instead of a blurred
  screenshot after extended display sleep.

### Design

A `bootc kargs.d` file (`30-nvidia-drm.toml`) adds
`nvidia-drm.modeset=1` to kernel arguments, following the same pattern
as `10-iommu.toml` and `20-verbose-boot.toml`.

The base image already ships `NVreg_PreserveVideoMemoryAllocations=1`
in `/usr/lib/modprobe.d/nvidia.conf` — no additional modprobe
configuration is needed.

### DRM modesetting kernel arg §spec:drm-modeset-karg

`/usr/lib/bootc/kargs.d/30-nvidia-drm.toml` sets
`nvidia-drm.modeset=1`. The arg appears in `/proc/cmdline` after reboot.

## Manual system suspend §spec:manual-suspend

*Status: in progress*

### Problem

The nwg-bar power menu provides Lock, Logout, Reboot, and Shutdown but
no suspend option. Users run `systemctl suspend` manually instead.

Auto-suspend during the workday remains intentionally disabled — an
unattended suspend during long-running builds or VM workloads is
destructive. Manual suspend via the power menu gives the user explicit
control at any time. §spec:auto-suspend adds time-gated auto-suspend
outside business hours in development mode; the manual button remains
the contract for this section.

### Design

nwg-bar gains a Sleep button between Lock and Logout. The button runs
`systemctl suspend`. The icon (`system-suspend.svg`) ships with the
nwg-bar package.

### Sleep button in nwg-bar §spec:nwg-bar-sleep

The nwg-bar config (`bar.json`) includes a Sleep entry that runs
`systemctl suspend`, positioned between Lock and Logout.

## EGL-Wayland platform plugin §spec:egl-wayland

*Status: in progress*

### Problem

NVIDIA's EGL implementation does not natively know how to create Wayland
surfaces. Without the `egl-wayland` package, `eglGetPlatformDisplay(
EGL_PLATFORM_WAYLAND, ...)` falls back to Mesa's EGL, which cannot drive
NVIDIA hardware. GDK/Flutter applications then either software-render or
fail to initialize.

Nothing in the base-nvidia driver stack pulls `egl-wayland` as a
dependency — it shall be installed explicitly.

### Design

The image installs `egl-wayland` in the `WAYLAND_CORE` package group.
This allows NVIDIA's EGL to handle Wayland platform display requests,
enabling:

- GDK/Flutter UI rendering directly on the NVIDIA EGL backend.
- Thermion/Filament sharing Flutter's NVIDIA EGL context and display
  via `EGLImage`, avoiding a cross-driver copy.

### egl-wayland in image §spec:egl-wayland-installed

`egl-wayland` is present in the installed image, providing
`/usr/lib64/libnvidia-egl-wayland.so.1` and the EGL external platform
registration at
`/usr/share/egl/egl_external_platform.d/10_nvidia_wayland.json`.

## Production mode §spec:production-mode

*Status: in progress*

### Problem

`rpm-ostreed-automatic.timer` runs in `stage` mode
(§spec:system-services): it fetches the latest image and stages it as
the next deployment while the system is running. The next reboot —
whatever the reason — applies the staged image. There is no per-machine
way to opt out without disabling the timer entirely.

For live workloads (video capture, broadcast, ST2110 streaming, GPU
passthrough VMs) the user's mental model of a reboot is "the system
comes back the way I left it." Auto-staging inverts that: every reboot
is a potential image transition, with kernel modules, NVIDIA driver, and
capture-card kmod versions changing under the user's feet. The staged
image is unvalidated against the workload — a regression in
`kmod-nvidia`, the AJA out-of-tree driver, or peermem header coupling
(§spec:decklink-capture, §spec:rivermax) only surfaces post-reboot,
often mid-show.

The destructive action is not the reboot — it is staging an unvetted
image *before* a reboot that the user expects to be non-destructive.
Production mode preserves the user's "current system is the system I
want" intent across reboots.

### Design

A flag file at `/etc/tilefin/production-mode` gates the auto-update
service. `/etc` is the per-machine mutable tree on bootc/OSTree —
files written there persist across image upgrades, rollbacks, and
channel switches. Presence of the file means "production mode is on."

A systemd drop-in adds `ConditionPathExists=!/etc/tilefin/production-mode`
to `rpm-ostreed-automatic.service`. The timer keeps firing on schedule;
each invocation checks the condition and silently no-ops while the flag
exists. Re-enabling auto-updates is a single `rm` away — no `systemctl
enable` dance, no risk of image rebuilds re-enabling masked units.

The lock blocks **automatic** staging only. Manual `bootc upgrade`,
`rpm-ostree update`, and `ujust update` go through `rpm-ostreed.service`
(the DBus daemon), not `rpm-ostreed-automatic.service`, and remain
available. A user in production mode who explicitly wants the latest
image can still apply it — the lock prevents surprise, not control.

A `ujust production-mode` recipe owns the lifecycle. `--start` is
interactive when a deployment is already staged: it surfaces the
staged version and asks whether to keep it (next reboot still applies
it; production mode only blocks future staging) or unstage it (reboot
returns to the currently booted image). `--start-from-current` is the
non-interactive form that always unstages, guaranteeing the next
reboot lands on the currently booted image. `--stop` removes the flag;
the next timer firing resumes staging.

Waybar surfaces the mode explicitly in the update-check tooltip and
text (e.g., `production · 5d` vs `development · 5d`) so the user
sees current state at a glance, not just by inspecting `systemctl
status`.

#### Rejected alternatives

- **`systemctl mask rpm-ostreed-automatic.timer`** — works, but the
  mask state lives in `/etc/systemd/system/` as a symlink to
  `/dev/null`. It is not a grep-able policy flag, does not extend
  cleanly to a second timer (e.g., if the base image later enables
  `bootc-fetch-apply-updates.timer`), and is harder to inspect than
  a bare flag file.
- **Disable the timer entirely** — loses the "ready to resume" path.
  Re-enabling is friction; toggling a flag is not.
- **`ExecStartPre` wrapper script that exits non-zero on the flag** —
  same effective behavior as `ConditionPathExists` with more moving
  parts and journal noise. The condition idiom is exactly what
  systemd provides for this.
- **Lock in `/var/` instead of `/etc/`** — `/var` is conventionally
  machine state (caches, spools, logs); `/etc` is policy. A flag
  toggling system update policy belongs with policy.

### Flag file gates auto-staging §spec:production-flag-gates-staging

When `/etc/tilefin/production-mode` exists, `rpm-ostreed-automatic.service`
does not run when triggered by its timer. `systemctl status
rpm-ostreed-automatic.service` reports the unmet condition. When the
flag is removed, the next timer firing stages updates as before.

### Manual updates remain available §spec:manual-updates-available

When production mode is on, `bootc upgrade`, `rpm-ostree update`, and
`ujust update` apply updates as normal. The lock applies only to
timer-triggered automatic staging.

### ujust production-mode recipe §spec:ujust-production-mode

`ujust production-mode --start | --stop | --start-from-current`
toggles the flag. `--start` is interactive: when a deployment is
staged at the time production mode is enabled, the user is prompted
to keep or unstage it. `--start-from-current` always unstages any
staged deployment non-interactively, guaranteeing the next reboot
boots the currently running image. `--stop` removes the flag.

### Waybar surfaces production mode §spec:waybar-production-indicator

When production mode is on, the waybar update module text reads
`production · <age>` and the tooltip includes a `Mode: production` line.
When off, the text reads `development · <age>` and the tooltip shows
`Mode: development`. Staging information continues to display as in
§spec:system-services — production mode does not hide a manually-staged
deployment.

The module re-execs immediately when the flag is toggled. The
`custom/update-check` module declares `"signal": 8`; the ujust
recipe sends `SIGRTMIN+8` to waybar after touching or removing the
flag, so the bar reflects the new mode without waiting for the
hourly poll. A reboot is not required.

### No idle interruptions in production mode §spec:production-no-idle-interrupt

When `/etc/tilefin/production-mode` exists, the hypridle display-off
listener (300s) and the lock listener (600s) are both skipped. The dim
listener (240s) continues to fire as in §spec:display-manager. The
§spec:auto-suspend auto-suspend listener is also skipped — production
machines never auto-suspend.

The gate lives inline in each gated listener's `on-timeout`:
`sh -c '[ ! -e /etc/tilefin/production-mode ] && <action>'`. Hypridle
keeps a single config and is not reloaded on toggle; the flag is
checked at fire time, so the new mode takes effect on the next idle
window.

#### Why gate idle display-off and idle lock

Production environments alternate between long idle stretches and
short urgent bursts of operator activity. A 5-minute display-off or
10-minute auto-lock in the middle of an idle stretch puts the
operator behind a black screen or an unlock prompt at the moment
the workload demands quick interaction.

- **Display-off** hides operator-facing state (status, errors, fader
  positions, capture telemetry). Returning to a dark screen forces a
  wake step before any diagnostic is even visible.
- **Lock** adds an authentication step in the same spot. The mental
  model in production is "the screen I left up is the screen I come
  back to" — idle auto-lock breaks it.
- **Dim** is `brightnessctl`-based and no-ops on desktop hardware
  (no `backlight` class device). On laptops it is harmless background
  behavior. Not gated.

Production mode trades automatic-lock security for predictable
operator latency. The assumption is that production-mode machines
are physically attended (live broadcast, capture booth, control
surface) where the room itself enforces access. `Mod+L` still locks
manually; only the idle trigger is gated.

## Time-gated auto-suspend in development mode §spec:auto-suspend

*Status: in progress*

### Problem

A development workstation left idle overnight or over a weekend stays
fully powered — GPU, fans, and PSU drawing wall power with no operator
present. §spec:manual-suspend deliberately disabled auto-suspend because
an unattended suspend during a long build or VM run is destructive. The
result is the opposite failure: a machine nobody is using never sleeps.

§spec:production-mode production mode already separates
attended-production machines (live capture, broadcast) from development
machines. Production machines shall never sleep. Development machines
should sleep when no one is working — but not during the workday, when
an auto-suspend mid-task is the destructive interruption
§spec:manual-suspend guards against.

### Design

In development mode (the `/etc/tilefin/production-mode` flag is absent),
the system auto-suspends to deep §spec:niri-compositor after 30 minutes
idle, but only outside business hours. Business hours are Monday–Friday
08:00–18:00 local time; 18:00:00 itself is outside the window. Manual
suspend (nwg-bar Sleep, `Mod+Shift+L`) works at any time, in any mode
(§spec:manual-suspend). Production mode never auto-suspends.

deep §spec:niri-compositor is the target because it is the deepest sleep
state this hardware can wake from via USB (`/sys/power/mem_sleep`
defaults to `deep`); a USB keyboard, mouse, or wireless receiver wakes
the machine. Hibernate (§spec:wayland-stack) is rejected: it is not
USB-wakeable (power-button only) and is not configured — swap is
zram-only, which cannot back a hibernation image.

Idle detection is hypridle's; the suspend decision is a guard script.
hypridle fires each listener once per idle period, so a machine that
went idle during business hours would not auto-suspend when 18:00
passes — the listener already fired and will not re-fire without
intervening activity. A re-arm timer restarts hypridle at 18:00 on
weekdays. The restart begins a fresh idle countdown: an already-idle
machine fires the 30-minute listener again and suspends near 18:30.
Restarting an in-use machine's hypridle is a no-op — it re-subscribes
to idle notifications and nothing fires until the next idle period.
This holds regardless of `ext-idle-notify-v1` fire semantics, because
the timeout is measured from notification-object creation.

### Why a guard script, not an inline gate

§spec:production-no-idle-interrupt gates idle display-off and lock with
an inline `[ ! -e /etc/tilefin/production-mode ] && <action>`. The
auto-suspend gate adds day-of-week and hour-of-day conditions that
exceed what a readable hypridle one-liner can carry and that warrant
tests. The guard is a script alongside the existing waybar helper
scripts, with its clock and flag path overridable so the decision matrix
is testable without suspending the host.

### Why restart hypridle, not a standalone idle check

The re-arm timer could instead query session idle time directly
(`loginctl` idle hints) and suspend without hypridle. Rejected: it would
duplicate idle tracking hypridle already owns and re-derive the same
30-minute threshold. Restarting hypridle reuses one idle source and
keeps the threshold defined in one place.

### Auto-suspend guard §spec:auto-suspend-guard

A guard script suspends the system via `systemctl suspend` unless either
condition holds:

- `/etc/tilefin/production-mode` exists, or
- the local time is Monday–Friday and the hour is in [08:00, 18:00).

Weekday derives from `date +%u` (1–5 = Mon–Fri) and hour from
`date +%H`. The flag path, suspend command, and current time are
overridable via environment variables for testing.

### Idle suspend listener §spec:idle-suspend-listener

hypridle includes a listener that, after 1800 seconds idle, runs the
guard. This replaces the previously commented-out auto-suspend block.

### hypridle runs as a user service §spec:hypridle-user-service

hypridle runs as a systemd `--user` service so the re-arm mechanism can
restart it. niri starts it from `spawn-at-startup` via
`systemctl --user start hypridle.service` instead of spawning the bare
binary; the service inherits `WAYLAND_DISPLAY` and `NIRI_SOCKET` from the
user manager, which `niri --session` populates.

The service is not bound to `graphical-session.target`. `niri --session`
imports the session environment into systemd and D-Bus but does not
activate that target, so a unit wired `WantedBy=graphical-session.target`
would never start. The compositor spawn is the start trigger instead.

### Weekday re-arm §spec:weekday-rearm

A systemd `--user` timer fires at 18:00 Monday–Friday, re-arming idle
detection at the business-hours boundary. It is enabled image-wide via
`systemctl --global enable` (the user manager reaches `timers.target`
independent of the graphical session). The timer triggers a service that
`try-restart`s hypridle — a no-op when hypridle is not running, so an
absent or already-suspended session is unaffected.

## Encrypted credential storage (Secret Service) §spec:credential-storage

*Status: in progress*

### Problem

The image ships no freedesktop Secret Service provider. `gh` — and any
application using `org.freedesktop.secrets` — therefore has no encrypted
credential store and falls back to writing its token in plaintext to
`~/.config/gh/hosts.yml` (the fallback is documented in gh's own
`auth login` help: "stored securely in the system credential store. If
a credential store is not found … fallback to writing the token to a
plain text file"). `secret-tool` is present but non-functional because
nothing owns the bus name.

### Design

The image installs gnome-keyring as the Secret Service provider,
auto-unlocked at greetd login.

The greetd PAM stack already ships the keyring hooks —
`-auth optional pam_gnome_keyring.so` and
`-session optional pam_gnome_keyring.so auto_start` — inert while the
module is absent (the `-` prefix ignores a missing module). Installing
`gnome-keyring-pam` activates them with no PAM edits: the login password
unlocks the login keyring at session start. gnome-keyring then owns
`org.freedesktop.secrets`, so gh's secure storage and `secret-tool`
resolve to the encrypted keyring instead of the plaintext fallback.

gnome-keyring shall not take over `SSH_AUTH_SOCK`: the Bitwarden flatpak
ssh-agent owns SSH for this user (§spec:niri-compositor session
wrapper). gnome-keyring 48 no longer ships an ssh-agent component (split
into `gcr-ssh-agent`, which is not installed), and `niri-session.sh`
sets `SSH_AUTH_SOCK` to the Bitwarden socket regardless — so the secrets
keyring and the SSH agent do not collide.

Why local, not a synced vault: no synced vault (Bitwarden, Proton Pass)
implements the Secret Service API — that role is local-only. A gh token
is machine-scoped and revocable, so a per-machine encrypted keyring is
the appropriate store.

Retrieving user-scoped secrets from a synced vault on demand (e.g. a
per-repo `GH_TOKEN` pulled from Bitwarden) is a separate concern handled
by `rbw`, delivered via userbox — not the image. Per the §spec:userbox
boundary, a Bitwarden CLI is a user tool, and it sits alongside `gh`
(also userbox). This image contributes only the existing plumbing: the
direnv hook (§spec:tool-aliases) and `~/.local/bin` on `PATH`
(§spec:user-local-bin-path), which a project's (gitignored) `.envrc`
uses to call `rbw` and export `GH_TOKEN`.

### Secret Service provider §spec:secret-service-provider

`gnome-keyring` and `gnome-keyring-pam` are installed. The daemon
provides `org.freedesktop.secrets`; the greetd PAM stack unlocks the
login keyring with the login password at session start. gh secure
storage and `secret-tool` resolve to this keyring; gh no longer writes
its token to plaintext `hosts.yml`.

## GPUDirect Storage §spec:gpudirect-storage

*Status: complete*

### Problem

A consuming project on this host needs NVIDIA GPUDirect Storage — the
`cuFile` API reading NVMe data directly into GPU memory, with no bounce
buffer through host RAM. GDS does not work on the image as shipped:
`cuFileDriverOpen` fails with `DRIVER_NOT_INITIALIZED (5001)`.

The image carries five NVIDIA modules from ublue's `kmod-nvidia`:
`nvidia`, `nvidia-drm`, `nvidia-modeset`, `nvidia-uvm`, and
`nvidia-peermem`. The last is GPUDirect RDMA for the network path
(§spec:rivermax), not storage. There is no `nvidia-fs`.

### Design

libcufile has three modes. `compat` bounces through host memory and
defeats the purpose; the other two are real DMA paths:

| Mode | Kernel module | Storage |
| --- | --- | --- |
| `nvfs` | `nvidia-fs.ko` | all VFS filesystems, distributed FS, NFS over RDMA |
| `p2pdma` | none | ext4/XFS on NVMe; no RAID0 or multipath |

The split is by storage type, not by preference: `p2pdma` covers NVMe
block devices and nothing else, so any distributed filesystem is
`nvfs`-only and out of reach here (see Deferred, below).

This image uses `p2pdma`. As of CUDA 12.8 it drives GDS through the
upstream NVMe driver and the kernel's PCI P2PDMA layer; NVIDIA states it
"eliminate[s] the need for custom MOFED NVMe patches and nvidia-fs.ko to
support GDS with Ext4 and XFS with NVMe drives."

Every prerequisite is already met — kernel 7.1.5 (≥ 6.2),
`CONFIG_PCI_P2PDMA=y`, open driver 610.43.03 (≥ 570), CUDA 13.2
userspace, plain NVMe with no RAID0 or multipath. Only a driver registry
key is missing (§spec:static-bar1-p2pdma). Kernel and driver versions
track the base image and move with it; the constraints are the floors,
not these exact builds.

Scope is the host enabling config alone. GDS userspace — `libcufile`,
`gdscheck` — is a CUDA toolkit component belonging to the consuming
project (see §spec:out-of-scope), matching the split this image draws
everywhere between host enabling config and userspace tooling.

That split leaves one obligation on the consumer: libcufile ships
`"use_pci_p2pdma": false`, so p2pdma is off by default and shall be
enabled in `cufile.json` (system-wide at `/etc/cufile.json`, or per
process via `CUFILE_ENV_PATH_JSON`). Neither the image nor the CUDA
packages create that file. A consumer that skips this gets `compat`
— a working cuFile API backed by a CPU bounce buffer — with no error to
distinguish it from a hardware or driver limitation.

#### PCIe topology

The GPU and the NVMe drives sit on different root complexes: the GPU at
`0000:41:00.0` under host bridge `0000:40`, both NVMe controllers under
`0000:20` (`0000:21:00.0` boot, `0000:22:00.0` the XFS data volume).
They share no upstream bridge, so the kernel classifies the transfer as
`PCI_P2PDMA_MAP_THRU_HOST_BRIDGE`.

That is supported here rather than rejected. `calc_map_type_and_dist()`
in `drivers/pci/p2pdma.c` disqualifies such a pair only when
`!cpu_supports_p2pdma() && !host_bridge_whitelist(...)`, and
`cpu_supports_p2pdma()` returns true for "any AMD CPU whose family ID is
Zen or newer" — this machine is a Threadripper PRO 3975WX, family 0x17.
The Intel-only device whitelist is never consulted. PCIe ACS redirect
likewise does not disqualify the path: it only downgrades the
shared-bridge `PCI_P2PDMA_MAP_BUS_ADDR` fast path, which a
cross-root-complex pair never takes.

Traffic therefore crosses the root complex by design, which bounds
achievable bandwidth below what a shared-switch topology would give.
That is a performance ceiling, not a functional blocker.

### Deferred: building nvidia-fs.ko

Compiling nvidia-fs into the image was prototyped and deferred, not
ruled out — see "Network filesystems will require it" below. It is
buildable — the module needs one driver header (`nv-p2p.h`, public
because the image runs the *open* driver), symbol CRCs read from the
shipped `nvidia.ko`, and `kernel-devel` from Fedora's `updates-archive`
— but:

- The `nvfs` path wants NVMe driver patches from DOCA's
  `mlnx-nvme-dkms`. DOCA on Fedora is the same blocker that stalls
  §spec:rivermax, so the module alone may not deliver a working DMA
  path.
- It commits the image to rebuilding an out-of-tree module against every
  kernel bump, pinned to an nvidia-fs release that supports that kernel.
- The result is unsigned. ublue signs its akmods with a key this repo
  does not hold, so the module loads only with Secure Boot disabled.

`p2pdma` avoids all three, and covers the local-NVMe workload this
section was raised for.

#### Network filesystems will require it

`p2pdma` is restricted to NVMe block devices. NVIDIA scopes the
exemption explicitly: nvidia-fs.ko "is not necessary for the case of
mounts of NVMe (local or with NVIDIA DOCA SNAP) for cuFile in CUDA
version 12.8 and higher" — NVMe only, nothing else.

GDS against a distributed filesystem — Lustre, WekaFS, EXAScaler, GPFS,
or NFS over RDMA — therefore still needs the `nvfs` path and
`nvidia-fs.ko`. Nothing in §spec:gpudirect-storage delivers that, and no
configuration of what §spec:gpudirect-storage does deliver reaches it.
When such a workload arrives this section reopens with the three costs
above intact, plus probably a fourth: RDMA-backed distributed clients
are likely to want the same DOCA/MOFED stack that blocks §spec:rivermax,
which would couple the two. That coupling is inferred from the shared
DOCA dependency rather than verified, and should be checked before it is
planned around.

### Static BAR1 for PCI P2PDMA §spec:static-bar1-p2pdma

The kernel's P2PDMA allocator hands NVMe the GPU's BAR1 addresses
directly, which requires the framebuffer to be statically mapped into
BAR1 rather than mapped through a sliding window.
`/usr/lib/bootc/kargs.d/40-nvidia-params.toml` sets
`nvidia.NVreg_RegistryDwords=RMForceStaticBar1=2`
(§spec:nvidia-params-as-kargs explains why this is a kernel arg rather
than a `modprobe.d` option).

The value is `2` (AUTO), not `1` (ENABLE). Per `nvrm_registry.h`, AUTO
"will only map static BAR1 if static BAR1 size is calculated to be big
enough to map all of FB once plus a calculated amount for other expected
BAR1 mappings", whereas ENABLE "does not take into account other
expected BAR1 mappings and may lead to BAR1 exhaustion later". Those
other mappings are GPUDirect RDMA's (§spec:rivermax), which this image
intends to keep working.

Static BAR1 does not conflict with resizable BAR; it requires a BAR1
large enough to map the whole framebuffer. What supplies that size is
the firmware, not the driver: on the target hardware BAR1 is 65536 MiB
against 49140 MiB of framebuffer — leaving ~16 GiB for other mappings —
while `NVreg_EnableResizableBar` read back as `0`, because the option
was set in `modprobe.d` and never applied
(§spec:nvidia-params-as-kargs). UEFI "Above 4G Decoding" and "Resizable
BAR" are therefore the real prerequisites. The driver-side opt-in is set
as a karg alongside the dword to make the request explicit rather than
incidental.

`RmForceDisableIomapWC=1` is set alongside it, and is not optional
despite NVIDIA documenting it as a workaround "for chipsets where
write-combine is broken". The driver gates P2PDMA registration on both
conditions — `uvm_devmem.c` returns early on
`!static_bar1_size || static_bar1_write_combined` before it ever calls
`pci_p2pdma_add_resource()` — so a write-combined static BAR1 registers
no `p2pmem` pool and cuFile silently falls back to `compat`. The cost is
that BAR1 is mapped uncached rather than write-combined, slowing
CPU-side writes through the aperture; GPU and NVMe DMA are unaffected.

The two keys go in one `NVreg_RegistryDwords` value separated by `;`,
which rules out delivering it as a kernel arg. GRUB parses `;` as a
statement separator and truncates the kernel line there, and quoting
does not rescue it because bootc normalises the quotes away when writing
the BLS entry — observed twice, with the entry holding both pairs while
`/proc/cmdline` and `/proc/driver/nvidia/params` showed only
`RMForceStaticBar1=2`. The driver hardcodes the separator
(`rm_string_token(&ptr, ';')` in `osapi.c`), so there is no alternative
to fall back on.

This one parameter therefore ships in
`/usr/lib/modprobe.d/nvidia-tilefin.conf`, which puts no bootloader in
the path, and the image regenerates its initramfs so the file is
actually read (§spec:nvidia-params-as-kargs). The `;`-free parameters
stay as kargs, so a dracut failure cannot regress settings that already
work.

The observable signal that both gates passed is
`/sys/bus/pci/devices/<gpu>/p2pmem/`. If that directory does not exist,
the driver never registered the pool and no userspace configuration will
produce a DMA path. Check `/proc/driver/nvidia/params` alongside it —
a truncated `RegistryDwords` means the parameter never arrived, which is
a different failure from the driver declining to register.

### IOMMU mode §spec:iommu-mode

GDS peer-to-peer DMA requires the NVMe device to reach the GPU's BAR.
Under a *translating* IOMMU that path is unreliable, which is the basis
for NVIDIA's `iommu=off` guidance — a functional constraint, not a
throughput one. Modern IOMMUs are close to free: `iommu=pt` runs an
identity-mapped domain for host-driven devices, and Linux defaults to
lazy IOTLB invalidation for those that are translated.

The image already sets `iommu=pt` (§spec:decklink-capture), and
`gdscheck -p` reports the GPU as "supports GDS" under it. That is the
starting position, not a proven one: the same output warns "GDS is not
guaranteed to work functionally or in a performant way with
iommu=on/pt", and NVIDIA's tool does not distinguish `pt` from `on`
there. Whether `pt` suffices in practice is an open question below.

Rebasing onto a current image is not sufficient to get `iommu=pt` on a
machine that once had it removed. `kargs.d` is applied as a diff against
the previous image, and a local deletion outranks it: this machine boots
`intel_iommu=on amd_iommu=on` from `10-iommu.toml` while `iommu=pt` from
the same file is absent, because it was deleted locally when the AJA
Corvid44 needed the SWIOTLB bounce path (§spec:decklink-capture).
Restoring it takes a one-time `rpm-ostree kargs --append=iommu=pt`; no
image change will do it.

### NVIDIA module parameters are kernel args §spec:nvidia-params-as-kargs

Module options this image adds under `/etc/modprobe.d/` never reach the
NVIDIA driver. `nvidia.ko` loads from the initramfs, seconds before
`initrd-switch-root`, and that initramfs is generated in the ublue base
image — so it captures the base's `/usr/lib/modprobe.d` and nothing
`build.sh` writes afterwards.

The evidence is a clean split in `/proc/driver/nvidia/params`: options
from the base image's `/usr/lib/modprobe.d/nvidia.conf`
(`PreserveVideoMemoryAllocations`, `UseKernelSuspendNotifiers`,
`TemporaryFilePath`) all apply, while every option this image added under
`/etc/modprobe.d/` reads back as its default.

Two deliveries are therefore in play. Parameters whose values contain no
`;` ship as kargs in `/usr/lib/bootc/kargs.d/40-nvidia-params.toml`,
matching the existing `nvidia-drm.modeset=1`; kernel command line
parameters bind at module load regardless of where the module came from.
`NVreg_RegistryDwords` cannot use that route (§spec:static-bar1-p2pdma),
so the image regenerates its initramfs — invocation mirroring
`ublue-os/main build_files/initramfs.sh` — and ships that parameter in
`/usr/lib/modprobe.d/nvidia-tilefin.conf`.

The build asserts the result with
`lsinitrd … | grep -q nvidia-tilefin.conf`. Every delivery failure in
this section's history was invisible until a reboot; this one fails the
build instead.

This subsumes the profiling option added for Nsight/CUPTI, which was
inert for the same reason — `RmProfilingAdminOnly` read back as `1`
despite `NVreg_RestrictProfilingToAdminUsers=0` in `/etc/modprobe.d/`.

Anything added to `/etc/modprobe.d/` for a module the initramfs loads is
silently ineffective. Check `/proc/driver/nvidia/params`, not the file.

### Verification

Confirmed working on 2026-08-03, kernel 7.1.5-101, driver 610.43.03.

The driver registered BAR1 with the kernel P2PDMA layer —
`/sys/bus/pci/devices/0000:41:00.0/p2pmem/` exists, which can only
happen past both gates in `uvm_devmem.c`, so AUTO did engage static
BAR1 and write-combine is off. `/proc/driver/nvidia/params` reads
`RegistryDwords: "RMForceStaticBar1=2;RmForceDisableIomapWC=1"`,
`EnableResizableBar: 1`, `RmProfilingAdminOnly: 0`.

End-to-end transfers with `allow_compat_mode: false`, so a fallback
would error rather than report success:

| Test (8 GiB, 4 MiB IO, 8 threads, XFS on NVMe) | Result |
| --- | --- |
| `gdsio -x 0 -I 0` (read) | `XferType: GPUD` 3.266 GiB/s |
| `gdsio -x 0 -I 1` (write) | `XferType: GPUD` 3.005 GiB/s |
| `gdsio -x 1 -I 0` (CPU control) | `XferType: CPUONLY` 3.269 GiB/s |

#### Do not use gdscheck as the acceptance test

`gdscheck -p` reports `NVMe : compat` on a working configuration. Its
storage rows describe the `nvidia-fs` path, which this image
deliberately does not have. A reviewer following it would conclude the
feature failed. The signals that mean something are the `p2pmem/`
directory and `gdsio` reporting `XferType: GPUD`.

`gdscheck` remains useful for the GPU and platform rows, and its
`iommu=on/pt` warning is worth reading — but that warning did not
predict failure here.

#### The storage device is the bottleneck, not the topology

GPUD and CPU paths measure the same because the drive is saturated,
not because P2PDMA is inactive. The XFS volume sits on
`0000:22:00.0`, a Samsung PM981-class part whose link maxes at
Gen3 x4 (8 GT/s) ≈ 3.5 GB/s; measured throughput is at that ceiling.
The Gen4 980 PRO on `0000:21:00.0` is the boot drive and carries
btrfs, which GDS cannot use.

The value of GDS here is therefore not peak throughput but that the
bytes never traverse host RAM or CPU cores. Raising the ceiling means a
Gen4/Gen5 part on the data volume — not RAID0, which NVIDIA does not
support with p2pdma, and not slot changes.

### Resolved questions

- **Is `iommu=pt` enough?** Yes. Verified working with
  `intel_iommu=on amd_iommu=on iommu=pt` and KASLR active. NVIDIA's
  `iommu=on/pt` warning and the KASLR known-issue both proved
  non-blocking on this platform, so neither `iommu=off` nor `nokaslr`
  is needed — and the §spec:virtualization passthrough capability is retained.
- **Filesystem coverage.** Unchanged and still a real constraint: GDS
  applies only to the XFS volume. The btrfs root qualifies for neither
  `p2pdma` nor `nvfs`.
- **Same-root-complex co-location.** Not worth pursuing. `0000:40` has
  exactly two root ports wired to slots — the GPU and the ConnectX-6 —
  with `07.1`/`08.1` leading to AMD internal functions, so co-locating
  an NVMe means displacing the NIC and the GPUDirect RDMA co-location
  §spec:rivermax wants. It would not change the mapping class either:
  `PCI_P2PDMA_MAP_BUS_ADDR` needs a common upstream bridge, i.e. a PCIe
  switch, and separate root ports under one host bridge still yield
  `THRU_HOST_BRIDGE`. Bifurcation creates root ports, not a switch.
  NUMA is moot — single node, `numa_node=-1` on every device.

## Out of scope §spec:out-of-scope

*Status: complete*

- **GDS userspace**: `libcufile`, `libcufile_rdma`, and `gdscheck` are
  CUDA toolkit components. They install with CUDA in the consuming
  environment (pip wheel or userbox); the image provides only the
  kernel module (§spec:gpudirect-storage).
- **User dotfiles**: Managed by chezmoi in a separate repo. This image
  provides system-wide defaults via `/etc/skel/`, `/etc/xdg/`, and
  `/etc/profile.d/`. Users override in `~/.config/`.
- **Userbox Containerfile**: Lives in repentsinner/userbox. This spec
  covers the image-side changes only — see §spec:userbox.
- **Flutter/FVM**: Future addition to the userbox Containerfile.
  The host image provides `egl-wayland` for NVIDIA-accelerated
  rendering (§spec:egl-wayland); Flutter itself runs in the userbox.
- **Flatpak apps beyond Bitwarden**: User-installed via
  `flatpak install --user`.
