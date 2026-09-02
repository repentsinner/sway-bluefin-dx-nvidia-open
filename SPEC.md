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
| **Userbox** (distrobox, pre-built OCI) | Dev toolchains and distro packages |
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
  Bitwarden, Firefox, Slack, Trayscale (§spec:tailscale).

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
- `tailscaled.service` — mesh VPN daemon (§spec:tailscale).

`linuxptp` ships `ptp4l.service` and `phc2sys.service`. Neither is
enabled: `ptp4l` needs a per-machine interface in `/etc/ptp4l.conf`
(§spec:ptp).

## Virtualization §spec:virtualization

*Status: complete*

Full KVM/QEMU/libvirt stack for Windows VM hosting with Looking Glass
GPU passthrough support:

- libvirt, qemu-kvm, virt-manager, virt-install.
- edk2-ovmf (UEFI firmware), swtpm (TPM emulation for Windows 11).
- looking-glass-client (low-latency framebuffer, from COPR).
- virtiofsd (fast file sharing).
- Polkit rule: wheel group can manage VMs without extra groups.
- IOMMU kernel args `intel_iommu=on` and `amd_iommu=on` via `bootc
  kargs.d`. `iommu=pt` is deliberately absent (§spec:iommu-mode).

## Wayland environment config §spec:wayland-config

*Status: complete*

- Electron apps forced to native Wayland via
  `/etc/environment.d/electron-wayland.conf`.
- Flatpak overrides enable the Wayland socket and the Electron Wayland
  flags in both Flatpak installations (§spec:flatpak-override-scope).

### Flatpak overrides apply per installation §spec:flatpak-override-scope

Flatpak reads overrides from the installation an application belongs to.
`/var/lib/flatpak/overrides/global` covers the system installation and
`~/.local/share/flatpak/overrides/global` covers the per-user one. The
system file does not reach a `--user` install.

`build.sh` writes the system copy. §spec:ujust-setup-user installs
Flatpaks with `--user`, so it writes the same overrides to the user
installation; without them Electron applications fall back to XWayland
and lose fractional scaling.

`setup-user` applies the overrides through `flatpak override --user`
rather than writing the file. The command merges into an existing global
file, so re-running the recipe preserves per-user grants added by hand.
The calls sit outside the app-selection branch — an override applies to
applications installed later, not only to the ones chosen in that run.

## XDG user directories §spec:xdg-user-dirs

*Status: complete*

### Problem

`xdg-user-dirs` reaches most Fedora systems through a desktop
metapackage. base-nvidia pulls no desktop environment, so the package
was absent and `~/.config/user-dirs.dirs` never got written.

Flatpak resolves `--filesystem=xdg-download` and its siblings through
GLib's special-directory lookup, which reads that file. With the file
missing the token resolves to nothing and Flatpak skips the bind mount
without an error. Firefox and Bitwarden request `xdg-download`; neither
received a writable directory. Creating `~/Downloads` by hand does not
help — the config file, not the directory, is what the lookup consults.

Applications that request no filesystem access, such as Signal, see an
empty tmpfs at `$HOME`. Files saved there vanish when the application
exits.

### Design

`xdg-user-dirs` joins `SYSTEM_UTILS`. The package ships
`/etc/xdg/user-dirs.defaults` naming the eight standard directories —
Desktop, Downloads, Templates, Public, Documents, Music, Pictures,
Videos — and `xdg-user-dirs-update`, which creates them and writes
`~/.config/user-dirs.dirs`.

The image keeps the packaged defaults unedited. A trimmed set would
reproduce the original failure for whichever token got dropped, and the
directories are cheap. `~/Pictures` in particular backs the niri
`screenshot-path` in §spec:niri-compositor.

### The packaged unit runs the update §spec:xdg-user-dirs-session-hook

The package ships `xdg-user-dirs.service`, wired
`WantedBy=graphical-session-pre.target`, and an autostart entry that
sets `X-systemd-skip=true` to defer to it. The session activates that
target (§spec:session-targets), so the unit runs on its own and the
image adds no hook of its own.

`xdg-user-dirs-update` merges new defaults into an existing
`user-dirs.dirs` and leaves current entries alone, so it is safe on
every login.

### Flatpak grants stay per-application §spec:xdg-user-dirs-no-blanket-grant

The image adds no blanket `--filesystem=home` override. Applications
declaring `xdg-download` gain a real shared directory from this change
alone. An application declaring no filesystem access, such as Signal,
needs an explicit per-application override or a file-chooser portal;
that grant is a user decision, not an image default.

## Session targets §spec:session-targets

*Status: complete*

### Problem

greetd ran `niri-tilefin-session`, which ended in `exec niri --session`.
That starts the compositor and imports the session environment, but it
never enters `niri.service`, so `graphical-session-pre.target`,
`graphical-session.target` and `xdg-desktop-autostart.target` all stayed
inactive.

Packages wire session-scoped units to those targets. With the targets
inactive the units never ran, and nothing reported an error:

- `xdg-user-dirs.service` (`WantedBy=graphical-session-pre.target`) —
  see §spec:xdg-user-dirs.
- `xdg-desktop-portal.service` — Fedora 44 carries
  `Requisite=graphical-session.target`, so D-Bus activation fails
  outright and every sandboxed file chooser falls back to an in-sandbox
  dialog that can only see the sandbox.
- Every `/etc/xdg/autostart` entry admitting this desktop.

The image had absorbed the gap one workaround at a time: hypridle
started from `spawn-at-startup`, `nm-applet` and `lxpolkit` respawned
from niri config rather than their autostart entries, and an
`xdg-user-dirs-update` call bolted into the session wrapper. Each
compensated for the same missing mechanism, and the next package to
assume a conventional session would have needed a fourth.

### Design

`niri-tilefin-session` ends in `exec niri-session`. That script imports
the environment, then runs `systemctl --user --wait start niri.service`.
`niri.service` declares `BindsTo=graphical-session.target` with
`Wants=graphical-session-pre.target` and `Wants=xdg-desktop-autostart.target`,
so all three targets activate in order. `RefuseManualStart=yes` on the
two systemd-owned targets blocks manual starts, not dependency-driven
ones.

The wrapper keeps its own work — the Bitwarden `SSH_AUTH_SOCK` and the
§spec:gpu-detection probe — ahead of the `exec`. `niri-session` re-execs
through a login shell, and exported variables survive that.

On exit, `niri-session` stops the session through `niri-shutdown.target`
rather than leaving the targets active.

### Autostart entries replace compositor spawns §spec:session-targets-autostart

`systemd-xdg-autostart-generator` translates `OnlyShowIn` and
`NotShowIn` into an `ExecCondition=`, so each entry decides for itself
whether it admits `XDG_CURRENT_DESKTOP=niri`. Duplication is the risk
worth naming: an entry that admits niri and is also listed
`spawn-at-startup` runs twice.

- `nm-applet` (`NotShowIn=KDE;GNOME`) admits niri, so the
  `spawn-at-startup` entry is removed.
- `lxpolkit` (`OnlyShowIn=LXDE`) does not, so it stays in niri config.
- The gnome-keyring entries (`OnlyShowIn=GNOME;Unity;MATE`) do not run,
  leaving §spec:credential-storage on D-Bus activation and the Bitwarden
  agent in sole possession of `SSH_AUTH_SOCK`.
- `mako`, `waybar` and `swaybg` ship no autostart entry and stay in niri
  config.

## Shell configuration §spec:shell-config

*Status: complete*

### Tool aliases §spec:tool-aliases

`/etc/profile.d/tool-aliases.sh` (bash) and
`/etc/fish/conf.d/tool-aliases.fish` (fish) provide aliases and shell
hooks for CLI tools: bat, eza, zoxide, starship, direnv, and mise. The
first five ship in this image (§spec:image-ships-shell-tools); mise
arrives from `ujust setup-user`. All entries are guarded (`command -v`
in bash, `command -sq` in fish) and silently skipped when the tool is
absent.

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

The move applies to tools carrying no image-side configuration. Tools
that `tool-aliases.{sh,fish}` aliases or hooks stay in the image
(§spec:image-ships-shell-tools); exporting those from the userbox broke
the prompt and the direnv hook. The rebuild-churn argument holds for the
remaining tier (§spec:image-excludes-user-tools).

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

### Image ships shell-integration tools §spec:image-ships-shell-tools

The image installs `bat`, `eza`, `zoxide`, `direnv`, and `starship`,
alongside `rbw` and `pinentry`. `starship` comes from the
`atim/starship` COPR; the rest are Fedora packages.

Rationale: `tool-aliases.sh` and `tool-aliases.fish` ship in this image
and depend on these binaries. Sourcing the configuration from the image
while the binaries arrive from a distrobox export splits one contract
across two lifecycles, and the export wrappers break it outright. An
exported wrapper runs the binary inside the container, so `starship`
reads the container's own `/run/.containerenv` and prints a container
marker in host shells, and `direnv hook` emits `/usr/bin/direnv` — a
path the host does not have, raising an error at every prompt.
Configuration and binary shall share a lifecycle.

`rbw` joins them because `.envrc` files call it to export
per-organization tokens; reachable only inside the userbox, it exports
nothing in a host shell and does so silently. `pinentry` is named
explicitly because the build installs with `install_weak_deps=False`.

### Runtime libraries for vendored binaries §spec:host-runtime-libs

The image installs `libatomic`. Tools that ship their own prebuilt
binaries link against it: `pyright` downloads a Node runtime that dies
with `error while loading shared libraries: libatomic.so.1`, so
`uv run pyright` cannot run on the host without it. It is the only
missing dependency of that runtime, and 37 KB installed.

Rationale: a Python project managed by `uv` needs nothing else from the
system to typecheck. Absent this library the host looks incapable of
running the project's own toolchain, which argues for moving development
into a container that has it — a large answer to a small gap.

### Image excludes fast-moving user tools §spec:image-excludes-user-tools

The image does not install `gh`, `chezmoi`, `bws`, or `antigravity`.
Native installer tools (Claude Code, uv, mise) are also not in the
image. `ujust setup-user` installs this tier per-user into
`~/.local/bin` (§spec:ujust-setup-user), where a tool updates without an
image rebuild.

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
exported_bins="/usr/bin/fvm"
exported_bins_path="~/.local/bin"
```

`nvidia=true` matches the base image (`base-nvidia`), which ships Nvidia
open kernel modules and the container toolkit. The userbox inherits GPU
access for tools that need it.

`fvm` is the only binary the host needs from the userbox: it drives a
Flutter toolchain that lives in the container. The shell tools shall not
appear here — `distrobox assemble` re-exports every entry, and the
wrappers would shadow the image's own copies in `~/.local/bin`,
restoring the failures described in §spec:image-ships-shell-tools.

Rationale: the skel file provides a working default at account creation.
The chezmoi↔userbox bootstrap cycle no longer arises, because chezmoi
installs from `ujust setup-user` (§spec:ujust-setup-user) rather than
from the userbox.

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

1. **Native CLI tools** — Claude Code, uv, mise, gh, chezmoi, the lint
   gate (shellcheck), and the Kubernetes clients. Installed to
   `~/.local/bin` via vendor curl installers, upstream release
   binaries, or `mise use -g`. All idempotent.
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

### Compose provider §spec:compose-provider

The image installs `docker-compose`.

Rationale: `podman compose` is a shim that execs an external provider. The
image ships podman but shipped no provider, so every compose command failed
with `looking up compose provider failed`. A host capability the image
already claims half of belongs in the image, not in a per-user install.
`docker-compose` over `podman-compose` because podman prefers it and it
implements Compose semantics more faithfully — `stop <service>` stops every
replica, where `podman-compose` stops one.

### Kubernetes clients §spec:k8s-clients

`setup-user` installs `kubectl`, `talosctl`, `helm`, `kubeseal`, `mc` and
`kind` through `mise use -g`, at loose versions.

Rationale: these are leaf binaries. No configuration in this image refers to
them, so they carry none of the coupling that keeps the shell tier in the
image (§spec:image-ships-shell-tools), and baking them in would mean an image
rebuild and a reboot to update a command-line client.

The versions are loose deliberately. `kubectl` is supported within one minor
version of the API server and patch versions do not affect compatibility, so
a single set of clients serves every cluster reached from this host — which
is the point of the skew policy, and the reason a per-repository pin would
solve a problem Kubernetes does not have. `helm` is held at `3.21` only
because a bare `3` resolves to a release candidate.

### Lint gates reachable on PATH §spec:lint-gates-on-path

`setup-user` installs `shellcheck` into `~/.local/bin`.

Rationale: project `ci.sh` scripts and the governance skills guard these
tools with `command -v` so a machine without them still runs. The guard
skips silently, so a local run reports success where the remote gate
would fail. Installing them makes a local check mean what it appears to
mean.

Neither `vale` nor a markdown linter is installed. The governance
contract pins both and resolves them itself — `vale` through `mise`,
which fronts aqua's registry of errata-ai's own release archives, and
the markdown linter through `uvx`. A copy installed here is a second
version to drift from that pin rather than a convenience.

`shellcheck` has no such resolver: the `ci.sh` scripts that call it are
project-owned, name it directly, and pin nothing.

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

## Tailscale mesh VPN §spec:tailscale

*Status: in progress*

### Problem

Bluefin-DX shipped the `tailscale` RPM and enabled `tailscaled.service`;
`base-nvidia` ships neither. The rebase (§spec:base-image-rebase) dropped
both, along with the Trayscale Flatpak. The Flatpak survives on machines
that predate the rebase — Flatpaks live in `/var`, which image updates
never touch — leaving a GUI with no daemon behind it.

Client-side layering (`rpm-ostree install tailscale`) is not the answer.
`rpm-ostreed-automatic.timer` re-resolves every layered package against
its remote repo on each staged upgrade, so an unreachable
`pkgs.tailscale.com` turns into a failed system update. Baking the
package into the image moves that failure into CI.

### Design

The build adds Tailscale's yum repo and installs `tailscale`, following
the pattern already used for VS Code (§spec:vscode). The repo `baseurl`
is keyed on `$basearch` rather than `$releasever`, so it does not pin the
image to a Fedora release.

`tailscaled` runs on the host, not in a container: it opens
`/dev/net/tun`, creates `tailscale0`, and rewrites routes and DNS in the
host network namespace.

Two steps stay per-machine and are deliberately not in the image:

- `tailscale up` — enrolls the node in a tailnet, which is an account
  action, not an image property.
- `tailscale set --operator=<user>` — chowns
  `/run/tailscale/tailscaled.sock` to a login user. Without it the
  socket is root-only, and Trayscale connects to nothing.

Trayscale is offered by `ujust setup-user` rather than baked in, matching
every other Flatpak (§spec:desktop-apps). No Flatpak override is needed:
upstream's manifest already grants `filesystems=/run/tailscale:ro`. The
override the pre-rebase build wrote is obsolete.

### tailscale in image §spec:tailscale-installed

The image contains `/usr/bin/tailscale`, `/usr/sbin/tailscaled`, and
`/usr/lib/systemd/system/tailscaled.service`.

### tailscaled enabled at build §spec:tailscaled-enabled

`tailscaled.service` shall be enabled in the image, so a node reaches the
login-ready state on first boot without a manual `systemctl enable`.

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

The image rebases onto `ghcr.io/ublue-os/base-nvidia`, the lowest
Universal Blue layer that includes Nvidia drivers. It ships no desktop
environment, no display manager, and no application-layer packages.
§spec:base-image records which tag the image tracks.

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

*Status: complete*

Flywheel (`point-source/flywheel`) generates semver tags and a CHANGELOG
from conventional commits, driven by `.flywheel.yml`. It replaced
release-please on 2026-08-31.

Two flywheel workflows carry it, both SHA-pinned rather than tracking a
tag: the action receives a GitHub App private key, and a floating tag would
let its repository repoint that credential at new code without review.

- **flywheel-pr.yml** — runs on pull request. Checks the conventional-commit
  title and auto-merges the types `.flywheel.yml` permits.
- **flywheel-push.yml** — runs on push. Cuts a release on the managed
  branch and maintains `CHANGELOG.md` and `version.txt`.

`build.yml` keeps its existing role, adding semver tags to the container
image when a git tag exists on the commit (e.g.
`ghcr.io/.../tilefin-nvidia-open:0.4.0`).

`auto_merge` is deliberately narrow. This image boots a workstation, so
every version-bumping type — `feat`, `fix`, `perf`, and any `!` breaking
variant — gates on a human, and only non-bumping types merge unattended.

Credentials are `vars.FLYWHEEL_GH_APP_ID` and
`secrets.FLYWHEEL_GH_APP_PRIVATE_KEY`, from the Flywheel GitHub App
installed on the account. Dependabot is a separate gate: those PRs
auto-merge under `chore` only once the App private key is also registered
in the Dependabot secret store, and wait for review until then.

### Why release-please was dropped

No defect in release-please. Other projects maintained alongside this one
converged on flywheel and this repository was the outlier.

One artefact of the old setup is worth recording, because it hid in plain
sight for months. `auto-merge-release.yml` existed to merge release PRs once
CI passed, and **never executed a single step**. Its `if:` value carried
`'autorelease: pending'` unquoted, and YAML terminates a plain scalar at a
colon-space regardless of the inner single quotes, so the file never parsed.
GitHub could not read it well enough to know it wanted `pull_request` only,
so every push produced a zero-job failed run — identifiable by the run being
named for the file path rather than the workflow. Release PRs were therefore
never auto-merged, and the red mark on every push was that same failure
repeating. Flywheel takes over the capability, so the file is deleted rather
than repaired.

Daily and push builds continue producing `latest` and date-stamped
tags. Semver tags are additive — they appear only when a release is cut.

Version history: 0.1.0 (Sway on Bluefin-DX), 0.2.0 (Hyprland on
Bluefin-DX), 0.3.0 (Niri on Bluefin-DX), 0.4.0 (Niri on base-nvidia).

## Required status checks §spec:quality-gate

*Status: complete*

### Problem

Two workflows in this repository failed silently for months.
`auto-merge-release.yml` never parsed, so it never ran a step
(§spec:releases). `build.yml`'s path filter was missing
`predicate-quantifier`, so its docs-only skip never fired and every
documentation change paid a full image build. Neither was visible in review,
and no check would have caught either.

Nothing validated `build_files/build.sh` — roughly 500 lines of shell that
*is* the image — and nothing validated the workflows themselves.

### Design

Three required status checks, named identically across the repositories
maintained alongside this one so one ruleset definition serves all of them.
The names are the contract; what runs inside each varies by repository.

| Check | Role |
| --- | --- |
| `flywheel/conventional-commit` | commit message hygiene, supplied by flywheel |
| `governance / lint` | SPEC, ROADMAP and README governance |
| `quality` | everything else this repository verifies |

A repository with nothing to put in a slot ships the job saying so, rather
than dropping the check from the ruleset. Removing it trades a visible gap
for an invisible one, and the entry has to be restored the moment the
repository grows the capability.

### One required check per gating workflow §spec:require-aggregate-check

A required status check shall name a job that reports on every run, and the
number of required checks shall follow the number of distinct merge
decisions rather than the number of kinds of work.

Two constraints set the shape.

A skipped job reports nothing at all. `build_push` skips on
documentation-only pull requests, so requiring it directly would leave the
check pending forever and the pull request unmergeable. The `quality` job
exists for this: it runs under `if: always()`, and treats a `skipped`
dependency as a pass and a failed one as a failure. The same trap catches a
check name copied between repositories — a context no workflow emits is
indistinguishable, from the ruleset's side, from one that has not reported
yet.

`needs:` cannot cross workflow files, so an aggregate covers only its own
file. That sets the floor: one required check per workflow file that gates
merges. `governance / lint` is separate because it comes from a reusable
workflow in its own file, not by choice.

Everything else that gates a merge therefore lives in `build.yml` behind the
one `quality` aggregate. Adding a job means adding it to that job's `needs`;
the ruleset does not change.

Splitting a second required check out by *kind* of work — static analysis
against tests, say — is rejected. Individual job results are visible in the
checks list whatever the ruleset names, so a second context adds no
information; it only adds a second thing to keep in sync. A second required
check earns its place when the *policy* differs, such as an advisory suite
that should report without blocking.

### Quality gate contents §spec:quality-gate-contents

`quality` aggregates `build_push` and `static-analysis`.

`static-analysis` runs `shellcheck` over `build_files/` and `test/`, and
`actionlint` over `.github/workflows/`, from version-pinned images rather
than the runner's copies so the tool versions do not drift underneath the
gate. It takes seconds and reports independently of the image build.

`actionlint` is the direct answer to the failure that motivated this
section: run against the deleted `auto-merge-release.yml`, it reports
`could not parse as YAML` with the file, line and column. Adopting it also
found a `concurrency` group referencing `inputs` that `build.yml` never
declares.

## Dual-channel image publishing §spec:image-channels

*Status: not started*

### Problem

The build workflow produces `latest` and `latest.YYYYMMDD` tags on
every push to main and daily cron. Semver tags (`0.4.4`) are generated
for release tag pushes but never published due to two
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
| `stable` | `stable`, `0.4.4` | flywheel tag push (`v*`) | Exactly the code at the release tag, built against current upstream |

`bootc upgrade` pulls the newest image for whichever tag the machine
tracks. `latest` advances daily. `stable` advances only when
flywheel creates a new tag.

#### Tag format

Daily and push-to-main builds embed the current semver from
`version.txt` in the datestamp tag:

- `latest` — rolling, overwritten each build
- `latest.v0.4.4.20260318` — pinned daily snapshot with semver provenance

Tag-triggered builds (flywheel `v*` tags) produce:

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

The image is consumed via `bootc switch` from a running Fedora system,
which requires an existing installation to migrate from. That migration
carries the previous system's `/etc` forward through a three-way merge,
which is where §spec:cross-release-switch went wrong. There is no path
to a bare-metal install on a new machine.

### Design

bootc-image-builder (BIB) produces installable media from the container
image. BIB offers `anaconda-iso`, `bootc-installer` and `iso` types.
This image builds `anaconda-iso`: it runs the Anaconda installer, so
the operator partitions the disk and creates the account interactively,
which is what provisioning bare metal needs.

**The kickstart is what makes the installer interactive.** Given no
kickstart of its own, BIB generates a complete one and the ISO installs
unattended: `clearpart --all` with no drive restriction, root locked,
no user created, reboot. That erases every attached disk and leaves a
system nobody can log into. It did exactly that on 2026-08-17.

Supplying `[customizations.installer.kickstart] contents` changes the
contract. BIB then adds only the `ostreecontainer` command, so every
other directive is the image's — and every directive omitted becomes a
screen Anaconda stops on. `disk_config/iso.toml` omits partitioning and
account creation so the operator chooses the target disk and sets
credentials. Adding `clearpart`, `autopart`, `part`, `ignoredisk`,
`rootpw` or `user` silently removes an interactive step.

The kickstart also re-points the installed system's origin. Installation
reads the image from the OCI archive on the media, recording
`/run/install/repo/container` as the origin — a path that ceases to
exist once the media is removed, which breaks `bootc upgrade`. A
`%post` runs `bootc switch --mutate-in-place --transport registry`
against the published image. The configs inherited from the upstream
image-template carried that same `%post`, pointing at
`ghcr.io/ublue-os/image-template`; the mechanism was right and only the
target was wrong.

The install runs offline. `ostreecontainer` reads the image from
`/run/install/repo/container` over the `oci` transport, so the media
carries the image and no registry is contacted during installation.

The builder tracks `quay.io/centos-bootc/bootc-image-builder:latest`.
The previous pin, `ghcr.io/lorbuschris/bootc-image-builder:20250608`,
returns 403 and can no longer be pulled.

### Anaconda installer ISO §spec:iso-anaconda

`disk_config/iso.toml` enables the Storage, Runtime, Network, Security,
Services, Users and Timezone Anaconda modules, and disables
Subscription, which is Red Hat entitlement handling. Storage backs the
disk-selection screen and Users the account screen, so the interactive
install depends on both. Builds pass `--rootfs=btrfs`.

Booting the ISO stops at Anaconda without writing to any disk until the
operator selects a destination. The generated kickstart contains no
`clearpart`, `autopart`, `rootpw` or `user`.

The installer does not ask for a hostname. Anaconda keeps that field
inside the Network spoke, and the kickstart's `network` line satisfies
that spoke, so it is never flagged and the field is never seen. An
installed machine therefore has no static hostname: the greeter falls
back to the kernel default and announces it as `fedora`, while the name
it answers to on the network comes from a DHCP lease. `ujust setup-user`
prompts for it (§spec:ujust-setup-user), defaulting to the transient
name, which is the first point after install where a human is present.

`setup-user` also prompts for the login shell. Anaconda creates the
account with `/bin/bash`, while the image ships fish and carries
fish-specific integration (§spec:shell-config), so without a prompt the
shell differs per machine according to which installer made the
account.

### CI builds the ISO §spec:ci-builds-iso-types

The `build-disk.yml` matrix builds `qcow2` and `anaconda-iso`. Builds
run on `workflow_dispatch` and on pull requests touching `disk_config/`
or the workflow itself. Path filters are relative to the repository
root and carry no `./` prefix; the earlier prefixed patterns matched
nothing, so the pull-request trigger never fired.

### Local build recipe §spec:local-build-recipes

`just build-iso` builds the same `anaconda-iso` type from the same
config through `_build-bib`, so a local build exercises the path CI
takes. BIB runs under rootful podman.

BIB no longer pulls the image it is given — it reads it from local
container storage and exits 125 otherwise. `_build-bib` depends on
`_rootful_load_image`, which satisfies this. Invoking BIB by hand needs
`sudo podman pull` first; the CI action pulls both the builder and the
input image itself.

BIB reads that storage from `/var/lib/containers/storage` inside its
container, so the mount has to point at the graphroot podman actually
uses. `/etc/containers/storage.conf` may relocate it — on a host that
does, mounting the default path presents an empty store and BIB reports
`image not known` for an image that is present. `_build-bib` resolves
the path from `podman info` rather than assuming it.

### Verification §spec:iso-verification

An installer that erases disks is verified before it reaches hardware,
not after. Two checks, both cheap:

- Read the generated kickstart out of the build manifest's
  `org.osbuild.kickstart` stage and confirm no `clearpart`, `autopart`,
  `rootpw` or `user`.
- Boot the ISO in a VM against a blank disk and confirm it writes
  nothing while it waits. `just run-vm-iso` exists for this; a plain
  `qemu-system-x86_64` with a raw file and OVMF works equally well.

The unattended build was declared sound on artifact properties alone —
bootable, correct size, image embedded, checksum implanted — none of
which say what it does when it boots.

## Local test VM §spec:vm-test-harness

*Status: complete*

### Problem

`just run-vm-*` handed the built disk to the `qemux/qemu` container as
`/boot.qcow2`. When that container could not parse the image it did not
fail — it downloaded Alpine Linux, created a blank disk and booted that
instead, over a browser console on port 8006. A broken build therefore
presented as a working VM of an unrelated operating system.

Two further faults compounded it. §spec:install-media leaves account
creation to Anaconda, so a disk image built from `disk_config/disk.toml`
had no account and greetd rejected every login. And niri skips software
EGL renderers, so a virtio-gpu without 3D produced a running compositor
that drew nothing.

### Design

`_run-vm` calls `virt-install` against `qemu:///session`. A rootless
session domain reads the image straight from the work tree, so no
relabelling or privileged podman step is needed.

The recipe refuses to start rather than improvising:

- An absent or empty artifact is an error naming the build recipe.
- `qemu-img info` gates disk types; an unreadable image is an error.
- An existing domain is an error pointing at `just clean-vm`.

`--tpm none` is explicit. `virt-install` otherwise attaches an emulated
TPM, and `swtpm` cannot execute under a rootless session. Nothing in the
image needs one — §spec:virtualization carries `swtpm` for Windows
guests.

`--noautoconsole` avoids a hard dependency on `virt-viewer`, which the
image does not ship; the recipe opens the console with `virt-manager`
instead and prints the command when that is absent too.

### Rendering needs 3D §spec:vm-test-harness-gl

The domain requests `virtio,accel3d=on` with `spice,gl.enable=yes`.
Without 3D niri logs `software EGL renderers are skipped` and presents a
blank display, which reads as a hung session rather than a missing
feature. `VM_GL=off` selects plain virtio for hosts without virgl and
warns that the display stays blank. A failed `virt-install` prints the
fallback invocation.

`VM_NAME`, `VM_CONNECT`, `VM_RAM` and `VM_CPUS` override the rest.

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

One finding outlived the card and is recorded here so it is not
rediscovered. The workaround was removing `iommu=pt` rather than fixing the
DMA mask alone because the two mapping paths behave differently on failure:
`dma_direct_map_page` checks `dma_capable()` and falls back to
`swiotlb_map()` when a device cannot reach an address, while
`iommu_dma_map_page` — the path `iommu=pt` selects — has no equivalent
fallback and emits no diagnostic. A restricted-mask device under `pt`
therefore fails silently instead of bouncing. That is a property of the
kernel's `iommu-dma` layer, not of the AJA card, and it applies to any
device with a restricted mask.

### Capture hardware shall use a 64-bit DMA mask §spec:dma-mask-64bit

Capture, network and storage hardware selected for this image shall
advertise a 64-bit DMA mask. A device needing SWIOTLB bounce buffering for
addresses above 4 GB is out of scope.

This closes the constraint rather than carrying it forward. The DeckLink
8K Pro G2 meets it, as does the ConnectX-6 (§spec:rivermax). No part of
the image works around a restricted DMA mask, and none shall be added:
the AJA history above is the cost of the alternative — a driver fork, a
kernel-arg workaround, and a silent failure mode with no diagnostic.

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

## PTP time sync §spec:ptp

*Status: in progress*

### Problem

ST2110 senders and receivers derive their media clock from a PTP
grandmaster (SMPTE 2059-2). Without `ptp4l` disciplining the NIC's
hardware clock and `phc2sys` carrying that time to the system clock, an
ST2110 stream has no common timebase and receivers cannot align
essences. This gates §spec:rivermax, and is equally needed for
packet-capture timestamping and for talking to third-party ST2110
hardware before any Rivermax work starts.

`linuxptp` was reaching machines as an `rpm-ostree` layered package,
which carries the same upgrade fragility described in §spec:tailscale.

### Design

`linuxptp` installs in the `SYSTEM_UTILS` package group, providing
`ptp4l`, `phc2sys`, `pmc`, and `ts2phc`.

Neither `ptp4l.service` nor `phc2sys.service` is enabled. `ptp4l` runs
`-f /etc/ptp4l.conf`, whose shipped default carries a single `[eth0]`
section — an interface no machine here has, and one that differs per
host and per media fabric anyway. Enabling a unit that fails on every
boot is worse than leaving the choice explicit, so configuration stays
a per-machine act in `/etc`.

The packaged defaults suit an ST2110 client once the interface is
corrected: `clientOnly 1` and `time_stamping hardware`, disciplining the
NIC PHC from an external grandmaster rather than electing one.

### linuxptp in image §spec:linuxptp-installed

The image contains `/usr/sbin/ptp4l` and `/usr/sbin/phc2sys`, with
`ptp4l.service` and `phc2sys.service` present but disabled.

## NVIDIA DRM modesetting §spec:nvidia-drm-modeset

*Status: complete*

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

The DSC attribution is a hypothesis carried from the original report
and remains unconfirmed. The one reproduction captured since traced to
a display standby setting instead (§spec:display-deep-sleep).

### Design

`30-nvidia-drm.toml` carried `nvidia-drm.modeset=1` from 2026 until
2026-08-31, when it was removed. Three findings retired it:

- **The driver already defaults it on.** NVIDIA enables modesetting by
  default from the 560 series, and this image ships 610. Setting it
  restates a default.
- **The symptom it was adopted against was a display setting.**
  §spec:display-deep-sleep traced the Electron losses to the LG panel's
  Deep Sleep Mode. No capture ever isolated the karg.
- **It is irrelevant to the passthrough target.** Where an Intel iGPU
  drives the display and the NVIDIA GPU is handed to a guest, the GPU
  binds to `vfio-pci` and the NVIDIA DRM driver never drives an output
  (§spec:gpu-detection, §spec:virtualization).

The base image ships `NVreg_PreserveVideoMemoryAllocations=1` in
`/usr/lib/modprobe.d/nvidia.conf`, so suspend and resume keep their
framebuffer handling without configuration from this image.

### DRM modesetting is left to the driver §spec:drm-modeset-karg

This image shall not set `nvidia-drm.modeset`.

Confirm the driver's own value with
`sudo cat /sys/module/nvidia_drm/parameters/modeset`. The file is
root-readable only, which is why the removal rests on NVIDIA's
documented default rather than on a reading from this host; `Y` is the
expected value on 560 and later.

Restore the karg only against a capture showing modesetting off on
hardware this image targets. The reported failing case is a hybrid
laptop whose NVIDIA GPU drives no output — which is also the case where
modesetting changes nothing.

### Display deep sleep and wake disconnects §spec:display-deep-sleep

Bench captures on molecule, 2026-04-10 to 2026-04-15, connector
`card1-DP-4`, kernel 6.19.10 and 6.19.11-100.fc42, driver 595.58.03,
sampling connector `status` and `dpms` at 2 Hz across idle display-off
and wake. The modeset karg was deployed at the time, and `dmesg`
reports `fbcon: nvidia-drmdrmfb (fb0) is primary device`, which the
driver reaches only under modesetting — so these record behavior with
DRM modesetting active.

An LG 40WP95C at 5120x2160 lost applications on wake:

```text
14:08:20.032 connected On
14:08:47.351 connected Off      idle display-off
14:17:01.170 connected On       wake
14:17:02.181 disconnected Off   link drops
14:17:04.717 connected Off
14:17:05.223 connected On
```

Both Bitwarden scopes ended at 14:17:02.31 and the Chromium scope at
14:17:04.93, inside that disconnect. A check twelve seconds later found
VS Code and Bitwarden gone.

A BenQ PD3200U at 3840x2160 on the same connector did not reproduce it:
86 clean On/Off transitions over 19 hours, no `disconnected` sample and
no application loss. The distinguishing variable is the display, not
the DPMS cycle.

The cause is a display setting, not the GPU. Setting
`[Settings] > [General] > [Deep Sleep Mode]` to `[Off]` on the LG ends
the session loss. With it `[On]`, the panel powers down its electronics
in standby and the host sees a hotplug disconnect rather than a display
in standby; the GPU contexts behind the Electron apps do not survive
the reconnect.

LG documents the setting and its power purpose alone. The owner's
manual for this panel gives it as "When [Deep Sleep Mode] is [On],
power consumption is minimized while the monitor is in standby mode",
states no default, and says nothing about link teardown. The disconnect
behavior is established here by capture and corroborated by third-party
reports of the same setting presenting as an unplug to macOS hosts.

Turning it off is an operator step at display bring-up, not image
configuration: the setting lives in the monitor's own non-volatile
storage and no host-side change reaches it.

### Resolved questions

- **Does the karg resolve anything on its own?** No evidence that it
  does. It was adopted against a symptom that traced to a display
  setting, no capture isolated it, and the driver defaults it on
  regardless. Removed on that basis rather than on a disproof.
- **Capture hygiene.** The 2026-04 baseline records kernel and driver
  version but not `/proc/cmdline`, so its karg state is inferred from
  `dmesg`. A repeat shall record the command line directly.

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
`kmod-nvidia`, the DeckLink out-of-tree driver, or peermem header coupling
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
When off, the text reads `development · <age>` — or
`hot-development · <age>` under §spec:hot-development — and the tooltip
shows the same mode name. Staging information continues to display as in
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
(§spec:manual-suspend). Production mode never auto-suspends, and neither
does §spec:hot-development, the opt-out for a development machine left
running deliberately.

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

A guard script suspends the system via `systemctl suspend` unless one of
these conditions holds:

- `/etc/tilefin/production-mode` exists,
- `/etc/tilefin/hot-development` exists (§spec:hot-development), or
- the local time is Monday–Friday and the hour is in [08:00, 18:00).

Weekday derives from `date +%u` (1–5 = Mon–Fri) and hour from
`date +%H`. The flag paths, suspend command, and current time are
overridable via environment variables for testing.

### Idle suspend listener §spec:idle-suspend-listener

hypridle includes a listener that, after 1800 seconds idle, runs the
guard. This replaces the previously commented-out auto-suspend block.

### hypridle runs as a user service §spec:hypridle-user-service

hypridle runs as a systemd `--user` service so the re-arm mechanism can
restart it. The unit is `WantedBy=graphical-session.target` and enabled
image-wide with `systemctl --global enable`, so the target starts it
(§spec:session-targets). `PartOf=` ties teardown to the same target.

The service inherits `WAYLAND_DISPLAY` and `NIRI_SOCKET` from the user
manager, which `niri-session` populates before starting `niri.service`.

### Weekday re-arm §spec:weekday-rearm

A systemd `--user` timer fires at 18:00 Monday–Friday, re-arming idle
detection at the business-hours boundary. It is enabled image-wide via
`systemctl --global enable` (the user manager reaches `timers.target`
independent of the graphical session). The timer triggers a service that
`try-restart`s hypridle — a no-op when hypridle is not running, so an
absent or already-suspended session is unaffected.

## Hot-development mode §spec:hot-development

*Status: in progress*

### Problem

§spec:auto-suspend suspends an idle development machine outside business
hours. That is right for a workstation nobody is using and wrong for one
left running deliberately — an overnight build, a long-running VM, a
capture soak test. The operator walks away expecting the work to
continue; the machine sleeps 30 minutes later and the work stops.

§spec:production-mode is the wrong instrument for the exemption. It
holds auto-suspend, but it also holds idle display-off and idle lock and
blocks automatic image staging — the whole attended-operator policy —
when the machine needs only to stay awake. A workstation grinding
through background work overnight is unattended: the display should
sleep and the session should lock.

### Design

A second flag file, `/etc/tilefin/hot-development`, marks a development
machine that shall not auto-suspend. Everything else stays development
behaviour: dim at 240s, display-off at 300s, lock at 600s, and
`rpm-ostreed-automatic.timer` keeps staging images —
§spec:production-flag-gates-staging gates on the production flag alone.

Three modes result, ordered by how much idle behaviour each holds:

| Mode | Dim | Display off | Lock | Auto-suspend | Auto-staging |
| --- | --- | --- | --- | --- | --- |
| `development` | yes | yes | yes | outside business hours | yes |
| `hot-development` | yes | yes | yes | never | yes |
| `production` | yes | no | no | never | no |

The gate lives in the §spec:auto-suspend-guard script, beside the
production and business-hours conditions it joins, and is covered by the
same decision-matrix test. Production takes precedence when both flags
exist: it is the stricter idle policy, and its update lock has no
hot-development counterpart.

#### Rejected alternatives

- **A value inside `/etc/tilefin/production-mode`** — the systemd
  drop-in gates on `ConditionPathExists`, which reads presence, not
  content. Splitting the meaning across a file's existence and its
  contents makes the update lock depend on parsing.
- **A display-off variant of `ujust production-mode`** — conflates two
  policies. This machine is unattended; production mode assumes an
  operator in the room (§spec:production-no-idle-interrupt).
- **`systemd-inhibit` wrapping each long job** — correct where the job
  is known and wrapped, but it requires every background task to opt in.
  The mode is a property of how the machine is used this week, not of
  one command.
- **A longer idle timeout** — trades one wrong constant for another and
  still suspends mid-build.

### Flag holds auto-suspend §spec:hot-development-holds-suspend

When `/etc/tilefin/hot-development` exists, the auto-suspend guard holds
at every hour on every day. Idle dim, display-off, and lock fire as in
§spec:display-manager. Manual suspend stays available
(§spec:manual-suspend).

### ujust hot-development recipe §spec:ujust-hot-development

`ujust hot-development --start | --stop` creates or removes the flag and
signals waybar as in §spec:waybar-production-indicator. `--start`
reports that production mode takes precedence when the production flag
exists.

### Waybar surfaces hot-development §spec:waybar-hot-development-indicator

When the hot-development flag exists and the production flag does not,
the waybar update module text reads `hot-development · <age>` and the
tooltip includes a `Mode: hot-development` line. When both flags exist,
the module reads `production` (§spec:waybar-production-indicator).

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

*Status: not started*

### Problem

A consuming project on this host needs NVIDIA GPUDirect Storage — the
`cuFile` API reading NVMe data directly into GPU memory, with no bounce
buffer through host RAM. GDS does not work on the image as shipped:
`cuFileDriverOpen` fails with `DRIVER_NOT_INITIALIZED (5001)`.

The image carries five NVIDIA modules from ublue's `kmod-nvidia`:
`nvidia`, `nvidia-drm`, `nvidia-modeset`, `nvidia-uvm`, and
`nvidia-peermem`. The last is GPUDirect RDMA for the network path
(§spec:rivermax), not storage. There is no `nvidia-fs`.

### Backed out

This configuration shipped and was verified on 2026-08-03, and was removed
on 2026-08-31. §spec:static-bar1-p2pdma is retained below as the record of
what it did and why, not as a description of the running image. Three
findings drove the reversal:

- **It had already stopped working.** On driver 610.57.04 the pool reads
  empty — `p2pmem/size`, `p2pmem/available` and `p2pmem/published` are all
  `0` — where 610.43.03 gave a populated pool and `gdsio` reporting
  `XferType: GPUD`. The acceptance test did not catch that, because it
  tested for the `p2pmem/` directory, and the directory exists with an
  empty pool.
- **Nothing consumes it yet.** The consuming project reads through an
  abstraction that presents one API over cuFile and POSIX and falls back
  where GDS is absent, so a dev host without it works unchanged. Its own
  benchmark records direct and bounced reads completing in the same time on
  this host, because NVMe latency swamps both — the win here is host CPU and
  RAM, not latency.

  This bullet previously claimed the consumer needed only a distributed
  filesystem, which `p2pdma` cannot serve. That was half right. The
  consumer's eventual target is distributed (§road:gpudirect-storage, which
  needs `nvidia-fs.ko`), but it also has a *local* NVMe read path that
  `p2pdma` serves exactly. Restoring this section is the first step when
  that work starts.
- **It is not free.** `RmForceDisableIomapWC=1` maps BAR1 uncached, which
  slows every CPU-side write through the aperture, and `RMForceStaticBar1`
  pins the whole 48 GiB framebuffer into the aperture across suspend and
  resume — standing cost and standing surface for a path nothing currently
  uses.

The image now leaves BAR1 at the driver's own defaults: resizable, sized to
full VRAM by firmware, write-combined, and mapped through a sliding window.
`NVreg_EnableResizableBar=1` is kept, being idiomatic, free, and
independent of static BAR1.

Restoring the feature means re-adding one `modprobe.d` file and the
initramfs regeneration that carries it (§spec:nvidia-params-as-kargs).
Reopen this section with §road:gpudirect-storage, and repair the acceptance
test before trusting either.

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

**Not applied.** This subsection records a configuration the image shipped
between 2026-08-03 and 2026-08-31 and no longer carries (see Backed out).
It is kept because the reasoning is expensive to rediscover, and reinstating
it is the first step whenever §road:gpudirect-storage resumes.

The kernel's P2PDMA allocator hands NVMe the GPU's BAR1 addresses
directly, which requires the framebuffer to be statically mapped into
BAR1 rather than mapped through a sliding window. That took
`NVreg_RegistryDwords=RMForceStaticBar1=2`, delivered through
`/usr/lib/modprobe.d/nvidia-tilefin.conf` rather than a kernel arg
(§spec:nvidia-params-as-kargs explains why).

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

**The image does not set `iommu=pt`.** It sets `intel_iommu=on` and
`amd_iommu=on` and nothing more (§spec:virtualization).

`iommu=pt` was carried for GDS: peer-to-peer DMA needs the NVMe device to
reach the GPU's BAR, and under a *translating* IOMMU that path is
unreliable — the basis for NVIDIA's `iommu=off` guidance, a functional
constraint rather than a throughput one. GDS is no longer delivered
(§spec:gpudirect-storage), which leaves the arg with no requirement behind
it.

Three things decided the removal rather than a rewrite of the rationale:

- **It is not a passthrough prerequisite.** `intel_iommu=on` or
  `amd_iommu=on` alone is the minimum for VFIO to hand a device to a
  guest. `iommu=pt` is a host-side performance preference layered on top.
- **It costs the protection the IOMMU exists to provide.** Under `pt`,
  host-owned devices DMA to physical addresses through an identity
  domain. On a machine carrying a capture card, a 100G NIC and
  Thunderbolt, that is a real reduction in isolation.
- **The performance case is unmeasured, here and upstream.** A March 2026
  patch proposing that the AMD IOMMU default to passthrough "for improved
  performance" was rejected by the IOMMU maintainer, who noted that lazy
  translated mode preserves most of the security benefit — and no
  quantified AMD figures were produced in that thread. An earlier revision
  of this section asserted that modern IOMMUs are "close to free"; that
  claim had no measurement behind it and has been withdrawn.

The cost of removal is likewise unmeasured. Translated DMA applies to the
ConnectX-6 and the DeckLink, and this repository has no before-and-after
figures for either. Restoring `iommu=pt` is a one-line change to
`10-iommu.toml` and is the correct response to a measured regression in
§spec:rivermax or §spec:decklink-capture throughput — not to a suspicion
of one.

A local karg outranks the image in both directions, which this arg
demonstrated twice. It was deleted locally when the AJA Corvid44 needed the
SWIOTLB bounce path (§spec:decklink-capture), and no rebase restored it —
that took a one-time `rpm-ostree kargs --append=iommu=pt`. That local append
now outranks the image in the other direction: dropping the arg from
`10-iommu.toml` does not remove it from a host where it was added by hand.
Removing it there is an operator step (§spec:karg-drift).

### Local kernel argument drift §spec:karg-drift

`kargs.d` adds arguments and cannot delete them, and a local append or
delete outranks the image in either direction. The running command line is
therefore not a description of the image, and the two drift apart silently.

`rpm-ostree kargs` on molecule, 2026-08-31:

```text
rhgb quiet root=… rootflags=subvol=root rw ostree=…
intel_iommu=on amd_iommu=on systemd.show_status=1 nvidia-drm.modeset=1
nvidia.NVreg_EnableResizableBar=1
nvidia.NVreg_RestrictProfilingToAdminUsers=0
iommu=pt iomem=relaxed
```

Two entries are local state rather than image state, and both shall be
deleted:

- `iommu=pt` — appended by hand to repair the AJA-era deletion described
  in §spec:iommu-mode. The image has since stopped setting it deliberately,
  but a local append outranks the image, so dropping it from
  `10-iommu.toml` does not remove it here. Delete with
  `rpm-ostree kargs --delete=iommu=pt`. Its position after the NVIDIA
  parameters, rather than beside `amd_iommu=on`, is what marks it local.
- `iomem=relaxed` — no file in this repository sets it and no section asks
  for it. It relaxes the kernel's restriction on `/dev/mem` access to
  reserved regions: a standing weakening of memory protection, adopted for
  some one-off PCIe or GPU inspection and never removed. Delete with
  `rpm-ostree kargs --delete=iomem=relaxed`.

`nvidia-drm.modeset=1` and `nvidia.NVreg_EnableResizableBar=1` need no
action. Both came from this image's own `kargs.d`, so removing them there
removes them on the next upgrade.

`rhgb` and `quiet` also survive from the base image, against the intent of
`20-verbose-boot.toml`; `build.sh` documents
`rpm-ostree kargs --delete=quiet --delete=rhgb` as a first-boot step that
was never run. Harmless, and recorded so the comparison is complete.

Compare `rpm-ostree kargs` against `build_files/build.sh` after any
incident that prompts a configuration change, and treat an unexplained
argument as drift rather than as intent.

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

Every parameter this image sets therefore ships as a karg in
`/usr/lib/bootc/kargs.d/40-nvidia-params.toml`, matching the existing
`nvidia-drm.modeset=1`; kernel command line parameters bind at module load
regardless of where the module came from.

A parameter whose value contains `;` cannot use that route
(§spec:static-bar1-p2pdma). Delivering one takes `/usr/lib/modprobe.d/`,
which puts no bootloader in the path, plus an initramfs regeneration in
this layer so the file is read at all, plus an `lsinitrd` assertion so a
delivery failure fails the build rather than surfacing after a reboot. The
image carried all three for `RMForceStaticBar1` and dropped them with it,
so no parameter needs that route today and the build runs no dracut.

This subsumes the profiling option added for Nsight/CUPTI, which was
inert for the same reason — `RmProfilingAdminOnly` read back as `1`
despite `NVreg_RestrictProfilingToAdminUsers=0` in `/etc/modprobe.d/`.

Anything added to `/etc/modprobe.d/` for a module the initramfs loads is
silently ineffective. Check `/proc/driver/nvidia/params`, not the file.

### Verification

Historical. Confirmed working on 2026-08-03, kernel 7.1.5-101, driver
610.43.03, and not reproducible on kernel 7.1.10-200 with driver 610.57.04,
where the pool reads empty. The image no longer ships the configuration
(see Backed out); what follows records the state at the point it worked.

The driver registered BAR1 with the kernel P2PDMA layer —
`/sys/bus/pci/devices/0000:41:00.0/p2pmem/` existed *and the pool was
populated*, so AUTO did engage static BAR1 and write-combine was off.
`/proc/driver/nvidia/params` read
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

The `p2pmem/` directory alone is too weak a signal, and this section
originally treated it as sufficient. The directory is created with the
sysfs group and survives a pool that holds nothing: on driver 610.57.04 it
is present while `p2pmem/size`, `p2pmem/available` and `p2pmem/published`
all read `0`. A restored configuration shall be accepted on `p2pmem/size`
greater than zero *and* `gdsio` reporting `XferType: GPUD`, never on the
directory.

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

## Cross-release bootc switch §spec:cross-release-switch

*Status: in progress*

### Problem

`bootc switch` onto this image from Bluefin `:stable` left the machine
with no graphical login and no system bus. Observed on mr-plywood,
2026-08-15, switching from `bluefin-nvidia-open:stable` (Fedora 44)
onto this image while it tracked `base-nvidia:gts` (Fedora 43) — a
switch backwards across a major release.

The image has since moved to `:latest` (§spec:base-image), so the same
switch is now Fedora 44 onto Fedora 44. Whether that alone resolves
this is untested.

`/etc/selinux/targeted` carries the label `semanage_store_t` where
`file_contexts` maps that path to `selinux_config_t`. Nothing can
traverse the policy store, and three failures follow on every boot:

- `dbus-broker` exits 1 on
  `Access denied in /etc/selinux/targeted/contexts/dbus_contexts`,
  retries to its start limit, and leaves the system bus down. Without
  the bus, NetworkManager does not start either, so the machine also
  drops off the network.
- `systemd-logind` logs
  `Failed to initialize SELinux labeling handle: Permission denied`
  and fails to start.
- greetd, in `xdm_t`, is denied `search` on the directory, so
  `pam_selinux` reports `Unable to get valid context` and
  `pam_open_session` returns `SESSION_ERR`. The greeter accepts the
  password and returns to its own prompt.

Authentication itself succeeds throughout — `pam_unix` opens the
session before the session stack fails. A permissive boot confirms the
account is complete: every consequential denial names
`semanage_store_t`, across `greetd`, `dbus-broker`, `systemd-logind`,
`systemd-resolved`, `systemd-localed`, `systemd-hostnamed`,
`sshd-session` and `sshd-auth`. No second cause hides behind the first.

### Established

- The image is not the source. `/usr/etc/selinux/targeted` in the same
  deployment carries the correct label, and a machine installed from
  this image and upgraded within it does not show the defect.
- The `file_contexts` rules are byte-identical between Fedora 43 and
  44, so a changed policy rule does not explain the difference.
- `semanage.conf` sets `store-root=/etc/selinux`, making
  `/etc/selinux/targeted` the libsemanage store directory.
  `semanage_store_t` is the type libsemanage places on a store, while
  `file_contexts` reserves it for `active`, `tmp` and `previous`. The
  two conventions disagree about this path.
- `restorecon` reports relabelling the directory, and the label reads
  `semanage_store_t` immediately afterwards — from a shell, and from a
  oneshot unit ordered ahead of every consumer. The repair does not
  hold.
- The merged `/etc` is written by `ostree-finalize-staged.service` from
  its `ExecStop`, during the shutdown preceding first boot. Until then
  the staged deployment holds the image's own `/etc`, carrying neither
  the local accounts nor the defect, so no pre-boot repair is possible.

### Open questions

- What re-applies `semanage_store_t` after `restorecon`? A pass
  relabelling `mtab`, `os-release`, `resolv.conf`, `credstore`,
  `pam.d`, `polkit-1/rules.d` and `selinux/targeted` lands within one
  coarse-clock tick early in boot, but the writer is unidentified and a
  boot-ordered `restorecon` does not survive it.
- Does this reproduce on a same-release switch? Now that
  §spec:base-image tracks `:latest`, the next attempt answers this
  directly: a clean switch implicates the release gap, a repeat rules
  it out and leaves the relabel writer as the whole story.

### Design

Unresolved, and deliberately unimplemented. A boot-time `restorecon`
unit was tried on the affected machine and did not hold, so shipping
one would encode a repair the evidence does not support.

Retesting the switch on the current image comes first, since the
release gap is the one variable that changed and costs nothing to
retry.

Install media (§spec:install-media) avoids the failure rather than
patching it: a fresh install writes the image's own `/etc` with no
merge from a foreign release. That is the supported path for a new
machine until this is understood. Booting with `enforcing=0` restores
a working system on a machine already in this state, at the cost of
running without SELinux.

## Rootless container enabling config for local Kubernetes §spec:rootless-k8s-enabling

*Status: in progress*

### Problem

Local Kubernetes development with `kind` on rootless podman, and
`podman compose` workflows, fail out of the box. `kind` needs cgroup
v2 controllers (`cpu`, `cpuset`, `io`, `memory`) delegated to the
user's systemd session before it can run rootless on podman; without
delegation, cluster nodes fail to start. `podman compose` requires a
compose provider binary in `$PATH` and finds none.

A second limit bites before `kind` is even installed. The kernel caps
inotify instances per user at 128 by default. Every `conmon` — one per
podman container — holds an instance, alongside editors, direnv, and
file watchers; a `kind` cluster adds one per node container. The cap is
reached under an ordinary development session: podman logs
`conmon: Failed to create inotify fd` and starts containers whose
monitor cannot watch their exit.

The provider and the client tools (`kubectl`, `kind`, `helm`,
`docker-compose`) are CLI dev toolchains — by the image boundary they
belong in userbox, not the image (§spec:image-boundary). But the
host-level enabling config those tools depend on cannot live in a
distrobox: cgroup delegation and kernel sysctls are system state only
the image can set.

Reported in #62. The tooling half of #62 is tracked in
[repentsinner/userbox](https://github.com/repentsinner/userbox); this
section covers only the image-side enabling config.

### Design

The image delivers the host prerequisites for rootless `kind` on podman
and leaves the binaries to userbox:

- **cgroup v2 controller delegation** to the user session, via a
  `systemd` drop-in under `user@.service.d`, so rootless podman (and
  `kind`'s node containers) can create sub-cgroups for `cpu`, `cpuset`,
  `io`, and `memory`.
- **`KIND_EXPERIMENTAL_PROVIDER=podman`** exported system-wide via
  `/etc/environment.d/`, matching the existing electron-wayland pattern
  (§spec:wayland-config), so `kind` selects podman without per-user
  shell config.
- **A raised inotify instance cap** (§spec:inotify-instance-cap) and any
  further sysctls `kind` requires to run rootless on podman, via
  `/usr/lib/sysctl.d/`.

The base image may already delegate cgroup controllers for rootless
podman; if so, this section reduces to verifying and documenting that,
plus the provider env var and any missing sysctls.

The inotify cap is independent of the open questions below — it blocks
podman generally, not just `kind` — so it ships ahead of them.

### Open questions

- Does base-nvidia already ship cgroup v2 delegation for the user
  session, or does the image need to add the `user@.service.d`
  drop-in?
- `kind` exported from userbox runs inside the distrobox. Does it drive
  the host podman cleanly through the exported wrapper, or does the
  nesting force `kind` onto the host `PATH`? This determines whether the
  userbox split is sufficient or the image also carries the binary.

Requirements for cgroup delegation and the provider env var follow once
the cgroup delegation state on base-nvidia and the
kind-in-distrobox-vs-host question resolve via `/plan`.

### Raised inotify instance cap §spec:inotify-instance-cap

`/usr/lib/sysctl.d/90-inotify.conf` sets
`fs.inotify.max_user_instances = 512`, raising the kernel default of
128 to the value `kind` documents for rootless podman. Nothing else
under `/usr/lib/sysctl.d/` or `/etc/sysctl.d/` sets the key, so the
drop-in applies uncontested at boot. Watches
(`fs.inotify.max_user_watches`) are left to the kernel, which scales
them with system memory well above the 524288 `kind` asks for.

## Crash capture §spec:crash-capture

*Status: in progress*

### Problem

molecule froze hard on 2026-08-31 at 00:07:43 and left no evidence. The
journal stops mid-second: no panic, no oops, no OOM kill, no NVIDIA `Xid`,
no MCE, no fatal PCIe AER, no shutdown. The freeze came 81 seconds after an
S3 resume and 71 seconds after Discord — an Electron client, so the first
substantial GPU consumer of that session — started. The last two `phc2sys`
samples show the system clock losing 5.2 ms against both NIC hardware
clocks, a common-mode error that means the machine was already stalling a
second before it went silent. Boots -7 through -2 all ended in clean
shutdowns, so this is not the machine's habit.

None of that is diagnosable after the fact, and the reason is configuration
rather than bad luck. The capture chain is already complete: `pstore`
registers the firmware-backed ERST backend, `/sys/fs/pstore` is mounted,
and the base image enables `systemd-pstore.service`, which copies any
record into `/var/lib/systemd/pstore` on the next boot. What was missing is
anything that converts a hang into a panic for pstore to capture.
`kernel.panic_on_oops`, `kernel.hardlockup_panic` and
`kernel.softlockup_panic` all read `0`, and `kernel.sysrq` read `16` —
emergency sync alone, so the keyboard offered no way to dump task state or
to bring the machine down cleanly. `/var/lib/systemd/pstore` does not
exist, which is consistent: nothing has ever panicked here.

### Design

`/usr/lib/sysctl.d/91-crash-capture.conf` closes that gap, sitting
alongside `90-inotify.conf` (§spec:inotify-instance-cap). No kernel arg and
no new service is involved; the backend and the collector are already
present and only the policy sysctls were absent.

### Crash capture sysctls §spec:crash-capture-sysctls

| Setting | Value | Default | Reason |
| --- | --- | --- | --- |
| `kernel.sysrq` | `1` | `16` | All SysRq functions. `Alt+SysRq+w` dumps blocked tasks and `Alt+SysRq+l` backtraces every CPU into the log while the machine is still wedged; REISUB brings down one that is past saving. |
| `kernel.hardlockup_panic` | `1` | `0` | A CPU that stopped answering the NMI watchdog is already fatal. Panicking records why. |
| `kernel.panic_on_oops` | `1` | `0` | An oops leaves the kernel undefined. Panic while the trace can still be written. |
| `kernel.panic` | `20` | `0` | Reboot 20 s after a panic. `0` leaves the machine dead at the panic screen, and pstore holds the trace either way. |

`kernel.softlockup_panic` stays at `0`. A soft lockup is 20 s in the kernel
without scheduling, which heavy DMA from the DeckLink
(§spec:decklink-capture) or the ConnectX-6 can reach on a machine that is
not wedged, so enabling it trades a silent freeze for spurious reboots. It
should be raised for the duration of a bisect and lowered afterwards.

### Verification

Read the values back after a reboot onto the image:

```console
$ sysctl kernel.sysrq kernel.panic kernel.panic_on_oops kernel.hardlockup_panic
kernel.sysrq = 1
kernel.panic = 20
kernel.panic_on_oops = 1
kernel.hardlockup_panic = 1
```

Whether ERST records a panic on this board is untested — no panic has
occurred since the backend was noticed. `echo c > /proc/sysrq-trigger`
forces one and is the only way to test it, at the cost of a deliberate
crash. Run it on an idle machine, then check `/var/lib/systemd/pstore` on
the next boot.

### Open questions

- Does the 2026-08-31 freeze recur, and what caused it? It is
  unattributed. The S3 resume path, the 610.57.04 driver and 7.1.10-200
  kernel that landed together on 2026-08-28, and the first GPU client
  after resume are all candidates, and no evidence separates them.
  §spec:display-deep-sleep records a related but distinct failure —
  display DPMS cycling killing Electron clients, traced to the monitor
  rather than the GPU. That one lost applications; this one lost the
  machine.
- Is the same day's driver segfault related? `bm_workbench` took SIGSEGV
  inside `libnvidia-eglcore.so.610.57.04` at 13:00 on 2026-08-30, eleven
  hours earlier. Same driver, same GPU stack, no established link.

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
- **Kubernetes/compose client tools**: `kubectl`, `kind`, `helm`, and
  the `docker-compose` provider are CLI dev toolchains and live in
  repentsinner/userbox, not the image. The image-side enabling config
  for rootless `kind` on podman is in scope (S28).
