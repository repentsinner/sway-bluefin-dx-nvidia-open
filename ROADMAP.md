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
