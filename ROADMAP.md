# ROADMAP

Planned work derived from SPEC.md. Sections in build-dependency order.
Completed work is removed — see CHANGELOG.md for history.

## Dynamic GPU detection (S16)

- **niri-gpu-detect**: Move Nvidia env vars from `niri-config.kdl` to
  `niri-session.sh` behind a DRM connector detection check. Remove
  `WLR_NO_HARDWARE_CURSORS`.
  Files: `build_files/niri-config.kdl`, `build_files/niri-session.sh`.

## Rivermax ST2110 streaming (S20)

- **doca-roce-fedora-probe**: Throwaway Containerfile build stage that
  attempts to install `doca-roce` from the Mellanox yum repo against
  Fedora 42's kernel-devel. Determines whether DOCA kernel modules
  compile on kernel 6.19+ with Fedora's glibc. Check `rpm -ql` output
  for `nvidia-peermem.ko` and `mlx5_core.ko` to assess coexistence
  with ublue `kmod-nvidia`. This gates all subsequent S20 work.

## Manual system suspend (S22)

- **manual-suspend**: Add Sleep button to nwg-bar power menu. Runs
  `systemctl suspend`. Icon: `system-suspend.svg` (ships with nwg-bar).
  Files: `build_files/nwg-bar.json`.

## Dual-channel image publishing (S23)

- **build-needs-fix**: Fix `build_push` skip cascade on non-PR events.
  The `changes` job is PR-only; `build_push` declares `needs: [changes]`
  which causes it to skip on tag pushes, schedule, and workflow_dispatch.
  Add `if: always()` to `build_push` and adjust the existing `if`
  condition to handle the skipped `changes` output. Verify with a
  `workflow_dispatch` or tag push that `build_push` runs.
  Files: `.github/workflows/build.yml`.

- **build-channel-tags**: Add a workflow step that reads `version.txt`
  into a step output. Update `docker/metadata-action` tags: replace
  `latest.YYYYMMDD` and bare `YYYYMMDD` with
  `latest.v<version>.<YYYYMMDD>`. Add `stable` and `<version>` tags
  for `v*` tag builds. Remove `<major>.<minor>` tag. Set
  `org.opencontainers.image.version` label to semver.
  Depends on **build-needs-fix**.
  Files: `.github/workflows/build.yml`.

- **build-push-gate**: Widen the push-to-GHCR and cosign-signing `if`
  conditions to allow `refs/tags/v*` in addition to the default
  branch. Depends on **build-channel-tags**.
  Files: `.github/workflows/build.yml`.

## EGL-Wayland platform plugin (S24)

- **egl-wayland-package**: Add `egl-wayland` to the `WAYLAND_CORE`
  package group in `build_files/build.sh` so NVIDIA's EGL can handle
  `EGL_PLATFORM_WAYLAND` display requests. Verifiable when the built
  image contains `/usr/lib64/libnvidia-egl-wayland.so.1` and
  `/usr/share/egl/egl_external_platform.d/10_nvidia_wayland.json`.
  No dependencies, but won't reach users until S23 republishes images.
  Files: `build_files/build.sh`.

## Sunshine streaming server (S13)

- **sunshine-research**: Research Sunshine packaging on Fedora, Niri/
  Wayland compatibility, and required system integrations (udev, KMS,
  NVENC). Write spec requirements in S13 before implementation.
  Blocked — requirements not yet specified. Unblocked when S13 spec
  is written.

## Time-gated auto-suspend (S26)

- **auto-suspend-core**: Add the guard script that suspends via
  `systemctl suspend` unless production-mode or business hours (Mon–Fri
  08:00–18:00), with clock/flag/suspend-cmd overridable for tests
  (R26.1); add a decision-matrix test covering the production, weekday,
  weekend, and boundary cases; wire a 1800s hypridle listener to the
  guard, replacing the commented-out auto-suspend block (R26.2).
  Files: `build_files/auto-suspend.sh`, `test/auto-suspend.test.sh`,
  `build_files/hypridle-niri.conf`, `build_files/build.sh`.

- **hypridle-user-service**: Run hypridle as a systemd `--user` service,
  started by niri `spawn-at-startup "systemctl" "--user" "start"
  "hypridle.service"` (not bound to `graphical-session.target`, which
  `niri --session` does not activate), so the daemon is restartable
  (R26.3). Verify idle dim/lock/display-off still fire after the
  conversion.
  Files: `build_files/hypridle.service`, `build_files/niri-config.kdl`,
  `build_files/build.sh`.

- **hypridle-rearm-timer**: Add a systemd `--user` timer
  (`OnCalendar=Mon-Fri 18:00`) and a timer-triggered service that
  `try-restart`s hypridle to re-arm idle detection at the business-hours
  boundary, enabling the timer image-wide via `systemctl --global enable`
  (R26.4). Depends on **hypridle-user-service**.
  Files: `build_files/tilefin-hypridle-rearm.timer`,
  `build_files/tilefin-hypridle-rearm.service`, `build_files/build.sh`.

  **Verify:** Run `test/auto-suspend.test.sh` — all decision-matrix
  cases pass. On the running image in development mode (no
  `/etc/tilefin/production-mode`): `systemctl --user is-active hypridle`
  reports active under the niri session; `systemctl --user list-timers`
  shows `tilefin-hypridle-rearm` scheduled for the next Mon–Fri 18:00;
  idle dim/lock/display-off still fire; nwg-bar Sleep and `Mod+Shift+L`
  suspend on demand at any time. Enable production mode and confirm the
  idle listener no longer suspends.

## GPUDirect Storage (S29)

- **gds-static-bar1**: Set
  `nvidia.NVreg_RegistryDwords=RMForceStaticBar1=2;RmForceDisableIomapWC=1`
  so the kernel PCI P2PDMA allocator can hand NVMe the GPU's BAR1
  addresses (R29.1). Both keys are required: the driver skips P2PDMA
  registration unless static BAR1 is enabled *and* not write-combined.
  AUTO rather than ENABLE, to leave BAR1 headroom for GPUDirect RDMA
  (S20). Ships as a kernel arg in
  `/usr/lib/bootc/kargs.d/40-nvidia-params.toml`, not `modprobe.d`, which
  is inert for initramfs-loaded modules (R29.3); the same file carries
  `NVreg_EnableResizableBar` and the Nsight/CUPTI profiling option, both
  of which were previously inert for that reason.
  Files: `build_files/build.sh`.

  **Verify:** after a reboot onto the rebuilt image, in this order.
  First that the parameters arrived — `/proc/driver/nvidia/params` should
  show `RegistryDwords: "RMForceStaticBar1=2;RmForceDisableIomapWC=1"`,
  `EnableResizableBar: 1`, `RmProfilingAdminOnly: 0`. Then the decisive
  kernel-side signal: `/sys/bus/pci/devices/0000:41:00.0/p2pmem/` must
  exist, which means the driver cleared both gates and registered BAR1
  with the P2PDMA layer. Only then does userspace matter — `gdscheck -p`
  with `use_pci_p2pdma` enabled should report NVMe as something other
  than `compat`, and a 1 MiB `cuFileRead` against `/var/mnt/shuttle` with
  `allow_compat_mode: false` should return matching data. Check
  `nvidia-smi -q` still reports a 65536 MiB BAR1 and the session starts.

  If `p2pmem/` is still absent with the parameters confirmed present, the
  remaining gate is `static_bar1_size` — escalate `RMForceStaticBar1` from
  `2` (AUTO, which declines when it judges BAR1 headroom insufficient) to
  `1` (ENABLE, which forces it and accepts the BAR1 exhaustion risk that
  S20's GPUDirect RDMA mappings would otherwise be protected from).

- **gds-iommu-pt-restore**: One-time `sudo rpm-ostree kargs --append=iommu=pt`
  on this machine. `iommu=pt` is in `10-iommu.toml` but was deleted
  locally for the AJA Corvid44 (S19), and a local deletion outranks
  `kargs.d`, so no image change restores it (R29.2). Verify with
  `grep -o 'iommu=pt' /proc/cmdline` after reboot. Independent of
  **gds-static-bar1**; can share the same reboot.

- **gds-mode-confirm**: Re-run `gdscheck -p` and record which modes
  libcufile reports. The tooling is not installed on the host or in the
  image (S29 Out of scope): `gdscheck` and `libcufile` come from the
  `gds-tools-13-2` and `libcufile-13-2` RPMs in NVIDIA's `fedora43` CUDA
  repo, which need only `libnuma`/`libstdc++`/`openssl` and can be
  extracted and run without installing anything. Long term they belong in
  userbox alongside the other CUDA userspace. Depends on
  **gds-static-bar1**.

  Use matched versions. Running the 1.17 `gdscheck` against the pip
  wheel's older `libcufile` (GDS 1.15.1.6) reports a different and
  misleading driver-configuration table. Also set `use_pci_p2pdma: true`
  in `cufile.json` — the shipped default is `false`, so the p2pdma path
  is never attempted and every storage row reads `compat`.

  Baseline for comparison: `NVMe P2PDMA: Unsupported`, `NVMe:
  Unsupported`, GPU "supports GDS" at `bar size (MiB):65536`, `Platform
  verification succeeded`.

  If `cuFileDriverOpen` still fails once the parameters are confirmed
  present, the fallbacks in order are: `iommu=off` (third S29 open
  question — costs VFIO passthrough), then `nokaslr` (a security
  regression), then reopening the rejected `nvidia-fs.ko` build.

  Test both kargs transiently first — edit the entry at the GRUB menu
  (`e`, append, Ctrl-X). They persist to `kargs.d` only once proven
  necessary. Changing one variable per boot costs nothing but the boot
  itself, and a passing test with two variables changed proves neither.
