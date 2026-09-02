# ROADMAP

Planned work derived from SPEC.md. Sections in build-dependency order.
Completed work is removed — see CHANGELOG.md for history.

## Dynamic GPU detection §road:gpu-detection

### Detect the Nvidia display in the session wrapper §road:niri-gpu-detect

Move Nvidia env vars from `niri-config.kdl` to `niri-session.sh` behind
a DRM connector detection check. Remove `WLR_NO_HARDWARE_CURSORS`.
Files: `build_files/niri-config.kdl`, `build_files/niri-session.sh`.
§spec:gpu-detection

## Rivermax ST2110 streaming §road:rivermax

### Probe DOCA-RoCE against Fedora kernel-devel §road:doca-roce-fedora-probe

Throwaway Containerfile build stage that attempts to install
`doca-roce` from the Mellanox yum repo against Fedora 42's
kernel-devel. Determines whether DOCA kernel modules compile on kernel
6.19+ with Fedora's glibc. Check `rpm -ql` output for
`nvidia-peermem.ko` and `mlx5_core.ko` to assess coexistence with ublue
`kmod-nvidia`. This gates all subsequent §spec:rivermax work.

## Manual system suspend §road:manual-suspend

### Sleep button in the power menu §road:nwg-bar-sleep-button

Add Sleep button to nwg-bar power menu. Runs `systemctl suspend`. Icon:
`system-suspend.svg` (ships with nwg-bar).
Files: `build_files/nwg-bar.json`.
§spec:nwg-bar-sleep

## Dual-channel image publishing §road:image-channels

### Fix the build_push skip cascade §road:build-needs-fix

Fix `build_push` skip cascade on non-PR events. The `changes` job is
PR-only; `build_push` declares `needs: [changes]` which causes it to
skip on tag pushes, schedule, and workflow_dispatch. Add
`if: always()` to `build_push` and adjust the existing `if` condition to
handle the skipped `changes` output.
Files: `.github/workflows/build.yml`.
§spec:build-push-all-events

**Verify:** A `workflow_dispatch` or tag push runs `build_push`.

### Semver provenance in image tags §road:build-channel-tags

Add a workflow step that reads `version.txt` into a step output. Update
`docker/metadata-action` tags: replace `latest.YYYYMMDD` and bare
`YYYYMMDD` with `latest.v<version>.<YYYYMMDD>`. Add `stable` and
`<version>` tags for `v*` tag builds. Remove `<major>.<minor>` tag. Set
`org.opencontainers.image.version` label to semver. Depends on
§road:build-needs-fix.
Files: `.github/workflows/build.yml`.
§spec:daily-tag-provenance §spec:oci-version-label

### Widen the push and signing gate §road:build-push-gate

Widen the push-to-GHCR and cosign-signing `if` conditions to allow
`refs/tags/v*` in addition to the default branch. Depends on
§road:build-channel-tags.
Files: `.github/workflows/build.yml`.
§spec:tag-builds-stable-channel

## EGL-Wayland platform plugin §road:egl-wayland

### Ship egl-wayland in the image §road:egl-wayland-package

Add `egl-wayland` to the `WAYLAND_CORE` package group in
`build_files/build.sh` so NVIDIA's EGL can handle
`EGL_PLATFORM_WAYLAND` display requests. No dependencies, but does not
reach users until §road:image-channels republishes images.
Files: `build_files/build.sh`.
§spec:egl-wayland-installed

**Verify:** The built image contains
`/usr/lib64/libnvidia-egl-wayland.so.1` and
`/usr/share/egl/egl_external_platform.d/10_nvidia_wayland.json`.

## Sunshine streaming server §road:sunshine

### Research Sunshine on Fedora and Niri §road:sunshine-research

Research Sunshine packaging on Fedora, Niri/Wayland compatibility, and
required system integrations (udev, KMS, NVENC). Write spec
requirements in §spec:sunshine before implementation. Blocked —
requirements not yet specified. Unblocked when the §spec:sunshine
requirements are written.

## Time-gated auto-suspend §road:auto-suspend

### Guard script and idle listener §road:auto-suspend-core

Add the guard script that suspends via `systemctl suspend` unless
production-mode or business hours (Mon–Fri 08:00–18:00), with
clock/flag/suspend-cmd overridable for tests (§spec:auto-suspend-guard);
add a decision-matrix test covering the production, weekday, weekend,
and boundary cases; wire a 1800s hypridle listener to the guard,
replacing the commented-out auto-suspend block
(§spec:idle-suspend-listener).
Files: `build_files/auto-suspend.sh`, `test/auto-suspend.test.sh`,
`build_files/hypridle-niri.conf`, `build_files/build.sh`.

### hypridle as a systemd user service §road:hypridle-user-service

Run hypridle as a systemd `--user` service, started by niri
`spawn-at-startup "systemctl" "--user" "start" "hypridle.service"` (not
bound to `graphical-session.target`, which `niri --session` does not
activate), so the daemon is restartable
(§spec:hypridle-user-service).
Files: `build_files/hypridle.service`, `build_files/niri-config.kdl`,
`build_files/build.sh`.

**Verify:** Idle dim, lock, and display-off still fire after the
conversion.

### Weekday re-arm timer §road:hypridle-rearm-timer

Add a systemd `--user` timer (`OnCalendar=Mon-Fri 18:00`) and a
timer-triggered service that `try-restart`s hypridle to re-arm idle
detection at the business-hours boundary, enabling the timer image-wide
via `systemctl --global enable` (§spec:weekday-rearm). Depends on
§road:hypridle-user-service.
Files: `build_files/tilefin-hypridle-rearm.timer`,
`build_files/tilefin-hypridle-rearm.service`, `build_files/build.sh`.

**Verify:** Run `test/auto-suspend.test.sh` — all decision-matrix cases
pass. On the running image in development mode (no
`/etc/tilefin/production-mode`): `systemctl --user is-active hypridle`
reports active under the niri session; `systemctl --user list-timers`
shows `tilefin-hypridle-rearm` scheduled for the next Mon–Fri 18:00;
idle dim/lock/display-off still fire; nwg-bar Sleep and `Mod+Shift+L`
suspend on demand at any time. Enable production mode and confirm the
idle listener no longer suspends.

## Cross-release bootc switch §road:cross-release-switch

### Identify what re-applies the store label §road:selinux-relabel-writer

Establish what writes `semanage_store_t` onto `/etc/selinux/targeted`
after `restorecon` has corrected it. A relabel pass touching `mtab`,
`os-release`, `resolv.conf`, `credstore`, `pam.d`, `polkit-1/rules.d`
and `selinux/targeted` runs within a single coarse-clock tick early in
boot; no systemd unit in the image invokes `semodule`, `semanage`,
`setsebool`, `restorecon` or `fixfiles`, so the writer is elsewhere.
Candidates not yet excluded: PID 1's own early relabel, libsemanage
recovery of the interrupted transaction whose `tmp` and `final`
directories are present, and the ostree deployment path.
§spec:cross-release-switch

Retest the switch first. §spec:base-image now tracks `:latest`, so a
switch from Bluefin `:stable` is Fedora 44 onto Fedora 44 rather than
backwards across a release. That costs one reboot on mr-plywood and
may retire this workstream outright.

**Verify:** If the same-release switch still mislabels the store, an
audit watch (`-w /etc/selinux/targeted -p a`) or equivalent names the
writing process across a boot. The finding either identifies a repair
that survives, or establishes that switching onto this image is
unsupportable and install media is the only path.

## GPUDirect Storage over network filesystems §road:gpudirect-storage

### Build and ship nvidia-fs.ko §road:nvfs-network-fs

Build and ship `nvidia-fs.ko` so the `nvfs` path is available for
distributed filesystems — Lustre, WekaFS, EXAScaler, GPFS, NFS over
RDMA. The `p2pdma` path §spec:gpudirect-storage once shipped cannot reach
them: it covers NVMe block devices only, and NVIDIA scopes the no-module
exemption to "mounts of NVMe (local or with NVIDIA DOCA SNAP)". No amount
of tuning that setup substitutes, which is part of why it was backed out
on 2026-08-31 rather than maintained against a workload it cannot serve.

Blocked — no such workload yet. The build recipe (one driver header,
symbol CRCs from the shipped `nvidia.ko`, `kernel-devel` from
`updates-archive`) and the three standing costs are recorded under
§spec:gpudirect-storage. Likely coupled to the DOCA-on-Fedora blocker
that gates §spec:rivermax; verify that before planning around it.

## Rootless container enabling config §road:rootless-k8s-enabling

### Probe cgroup delegation on base-nvidia §road:cgroup-delegation-probe

Determine whether base-nvidia already delegates cgroup v2 controllers
(`cpu`, `cpuset`, `io`, `memory`) to the user session. On a running
image, check
`cat /sys/fs/cgroup/user.slice/user-$(id -u).slice/.../cgroup.controllers`
and `systemctl cat user@.service`. If delegation is absent, add a
`user@.service.d` drop-in. This gates the rest of the section.
Files: `build_files/build.sh` (and a drop-in conf if needed).
§spec:rootless-k8s-enabling

**Verify:** The delegated controllers appear in the user slice's
`cgroup.controllers` on a booted image.

### Select podman as the kind provider §road:kind-podman-enabling

Export `KIND_EXPERIMENTAL_PROVIDER=podman` system-wide via
`/etc/environment.d/`, matching the electron-wayland pattern
(§spec:wayland-config), and add any further sysctls `kind` needs beyond
the inotify cap (§spec:inotify-instance-cap) under
`/usr/lib/sysctl.d/`. Depends on §road:cgroup-delegation-probe.
Files: `build_files/build.sh`, new `kind-provider.conf`,
new sysctl `.conf`.
§spec:rootless-k8s-enabling

**Verify:** With the Kubernetes clients installed by `setup-user`
(§spec:k8s-clients), `kind create cluster` succeeds rootless on podman
and `kubectl get nodes` reports Ready. `printenv
KIND_EXPERIMENTAL_PROVIDER` reads `podman` in a fresh shell. The compose
provider is no longer part of this workstream — it ships in the image
(§spec:compose-provider).
