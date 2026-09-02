# [0.8.0](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.7.0...v0.8.0) (2026-09-02)


### Features

* add a compose provider and the Kubernetes clients ([#90](https://github.com/repentsinner/tilefin-nvidia-open/issues/90)) ([e2db41d](https://github.com/repentsinner/tilefin-nvidia-open/commit/e2db41d2a1cfedb770d881c933ed28b1cf61fea9))

# [0.7.0](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.6.0...v0.7.0) (2026-09-02)


### Features

* add libatomic and the lint gates to the host ([#89](https://github.com/repentsinner/tilefin-nvidia-open/issues/89)) ([01f94f3](https://github.com/repentsinner/tilefin-nvidia-open/commit/01f94f35226def08949d95ab4977c1a007fc35ed)), closes [#88](https://github.com/repentsinner/tilefin-nvidia-open/issues/88)

# [0.6.0](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.5.0...v0.6.0) (2026-09-01)


### Features

* ship shell-integration tools in the image ([#88](https://github.com/repentsinner/tilefin-nvidia-open/issues/88)) ([7a7979b](https://github.com/repentsinner/tilefin-nvidia-open/commit/7a7979b5a1977ca76b794288b33ef230118fd957))

# [0.5.0](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.13...v0.5.0) (2026-08-31)


### Bug Fixes

* **bmd:** survive releases that drop the bundled C++ runtime ([#77](https://github.com/repentsinner/tilefin-nvidia-open/issues/77)) ([8e6ac15](https://github.com/repentsinner/tilefin-nvidia-open/commit/8e6ac1543ad5c3b182b0304c3237adf5c28f8c5e))
* **build:** restore a buildable image on Fedora 44 ([#68](https://github.com/repentsinner/tilefin-nvidia-open/issues/68)) ([363c5f0](https://github.com/repentsinner/tilefin-nvidia-open/commit/363c5f04b89bb88fe23cd16be31c35c32c21116c))
* **nvidia:** idiomatic BAR1 and crash capture after the 2026-08-31 freeze ([#82](https://github.com/repentsinner/tilefin-nvidia-open/issues/82)) ([076efa3](https://github.com/repentsinner/tilefin-nvidia-open/commit/076efa31648568b398f2b7e2599a025656228836))
* **session:** create XDG user directories so Flatpak grants resolve ([#71](https://github.com/repentsinner/tilefin-nvidia-open/issues/71)) ([2c93906](https://github.com/repentsinner/tilefin-nvidia-open/commit/2c939064e7ff200e889d53dc06a55f53cbdc83a2))
* **session:** silence login-time diagnostics on tty1 ([#76](https://github.com/repentsinner/tilefin-nvidia-open/issues/76)) ([e2131b7](https://github.com/repentsinner/tilefin-nvidia-open/commit/e2131b7d78fcd4cde5979522d49b8dbfdd37faba))
* **session:** start the session through niri-session so targets activate ([#73](https://github.com/repentsinner/tilefin-nvidia-open/issues/73)) ([4154ad5](https://github.com/repentsinner/tilefin-nvidia-open/commit/4154ad574d64ebd748cc65a65fc4431f79b3d8c9))
* **setup-user:** apply Wayland Flatpak overrides to the user installation ([#72](https://github.com/repentsinner/tilefin-nvidia-open/issues/72)) ([ec4b48b](https://github.com/repentsinner/tilefin-nvidia-open/commit/ec4b48bfedb2e47f38b0e8d8ba1c7994cb8db7ab))
* **vm:** run the test VM through virt-install and fail loudly ([#74](https://github.com/repentsinner/tilefin-nvidia-open/issues/74)) ([1c4b161](https://github.com/repentsinner/tilefin-nvidia-open/commit/1c4b161435c02ff02d93a280de639366e3688024))


### Features

* **image:** raise the inotify instance cap for rootless podman ([#78](https://github.com/repentsinner/tilefin-nvidia-open/issues/78)) ([5d5626a](https://github.com/repentsinner/tilefin-nvidia-open/commit/5d5626a69659ebbbddf5a0686e0c82a400a7ed91)), closes [#62](https://github.com/repentsinner/tilefin-nvidia-open/issues/62)
* **image:** ship tailscale and linuxptp in the image ([#75](https://github.com/repentsinner/tilefin-nvidia-open/issues/75)) ([daca071](https://github.com/repentsinner/tilefin-nvidia-open/commit/daca071175409b8311114c670b38135b620dcba9))
* **install-media:** build an installer ISO ([#70](https://github.com/repentsinner/tilefin-nvidia-open/issues/70)) ([6dab890](https://github.com/repentsinner/tilefin-nvidia-open/commit/6dab8908303ade85a4e307cd35d5c364a57f7158))
* **niri:** bind close-window to Mod+W with repeat disabled ([#81](https://github.com/repentsinner/tilefin-nvidia-open/issues/81)) ([57d50e3](https://github.com/repentsinner/tilefin-nvidia-open/commit/57d50e3c4bf642e123f7b9c76f1db449df5e24a7))
* **session:** add hot-development mode between development and production ([#80](https://github.com/repentsinner/tilefin-nvidia-open/issues/80)) ([658c8cf](https://github.com/repentsinner/tilefin-nvidia-open/commit/658c8cf6ab76e4a82620b8073774dee023d86e0c))
* **setup-user:** prompt for hostname and login shell ([#69](https://github.com/repentsinner/tilefin-nvidia-open/issues/69)) ([0e7514e](https://github.com/repentsinner/tilefin-nvidia-open/commit/0e7514e898d27dbd13e1fa36f1eb858311a750f3))

# Changelog

## [0.4.13](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.12...v0.4.13) (2026-08-03)


### Features

* **nvidia:** allow non-admin access to GPU performance counters ([#61](https://github.com/repentsinner/tilefin-nvidia-open/issues/61)) ([39f6d2b](https://github.com/repentsinner/tilefin-nvidia-open/commit/39f6d2b1867c07774164a5ba0a4368c61be38bb3))
* **nvidia:** enable GPUDirect Storage via PCI P2PDMA (S29) ([#65](https://github.com/repentsinner/tilefin-nvidia-open/issues/65)) ([5744a81](https://github.com/repentsinner/tilefin-nvidia-open/commit/5744a81d2a04e35ef222706aca0628dd0d4e5585))

## [0.4.12](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.11...v0.4.12) (2026-06-09)


### Features

* **suspend:** time-gated auto-suspend in development mode (S26) ([#59](https://github.com/repentsinner/tilefin-nvidia-open/issues/59)) ([1e5478c](https://github.com/repentsinner/tilefin-nvidia-open/commit/1e5478c3d56a5c2fdf9f80b2c56a19fb6ee63f3e))

## [0.4.11](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.10...v0.4.11) (2026-05-08)


### Features

* **updates:** gate idle display-off and lock under production mode ([#55](https://github.com/repentsinner/tilefin-nvidia-open/issues/55)) ([3b6fc9d](https://github.com/repentsinner/tilefin-nvidia-open/commit/3b6fc9d4936332f2a19a113d11a6bc6b06503b69))


### Bug Fixes

* **bmd:** autodetect version from extracted RPM filename ([#53](https://github.com/repentsinner/tilefin-nvidia-open/issues/53)) ([6cf4d75](https://github.com/repentsinner/tilefin-nvidia-open/commit/6cf4d75d081a81e51241939e9de4305fa98e8319))
* **bmd:** install firmware to &lt;bin&gt;/Firmware so the updater finds it ([#56](https://github.com/repentsinner/tilefin-nvidia-open/issues/56)) ([07b71bc](https://github.com/repentsinner/tilefin-nvidia-open/commit/07b71bc326c462960946f899952db4b099d28308))
* **session:** pass --session to niri for systemd env import ([#52](https://github.com/repentsinner/tilefin-nvidia-open/issues/52)) ([27e8d27](https://github.com/repentsinner/tilefin-nvidia-open/commit/27e8d27d1a0afac62bc2321f065e64fc9c7424bf))

## [0.4.10](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.9...v0.4.10) (2026-05-07)


### Features

* **updates:** add S25 production-mode update lock ([#48](https://github.com/repentsinner/tilefin-nvidia-open/issues/48)) ([c0c3e45](https://github.com/repentsinner/tilefin-nvidia-open/commit/c0c3e457d4f2cfa8da24b51686d68837ea08abdb))


### Bug Fixes

* **updates:** refresh waybar immediately on production-mode toggle ([#50](https://github.com/repentsinner/tilefin-nvidia-open/issues/50)) ([c4dca9e](https://github.com/repentsinner/tilefin-nvidia-open/commit/c4dca9e64989502b4286d2c08b78061b71f6e942))

## [0.4.9](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.8...v0.4.9) (2026-04-02)


### Bug Fixes

* **build:** bmd justfile import ([#43](https://github.com/repentsinner/tilefin-nvidia-open/issues/43)) ([f80e3c9](https://github.com/repentsinner/tilefin-nvidia-open/commit/f80e3c9ccd10833e6afb90323a1f1e1359aeed6f))

## [0.4.8](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.7...v0.4.8) (2026-04-02)


### Bug Fixes

* **ci:** trigger release for PR [#38](https://github.com/repentsinner/tilefin-nvidia-open/issues/38) changes ([#40](https://github.com/repentsinner/tilefin-nvidia-open/issues/40)) ([efba9ca](https://github.com/repentsinner/tilefin-nvidia-open/commit/efba9cad93d7c65121761c0d1c36c8b99323e824))

## [0.4.7](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.6...v0.4.7) (2026-03-31)


### Features

* **bmd:** add ujust recipes for DeckLink driver install ([#37](https://github.com/repentsinner/tilefin-nvidia-open/issues/37)) ([4ae604b](https://github.com/repentsinner/tilefin-nvidia-open/commit/4ae604bfa8e843fbe2f1722927540779fdb72837))
* **build:** unlimited memlock + Resizable BAR for GPU/RDMA ([#30](https://github.com/repentsinner/tilefin-nvidia-open/issues/30)) ([647a599](https://github.com/repentsinner/tilefin-nvidia-open/commit/647a599f97a76c50e3a9ab2d8dc8377d40e3718c))


### Bug Fixes

* **ci:** always run CI Gate on PRs regardless of changed paths ([#36](https://github.com/repentsinner/tilefin-nvidia-open/issues/36)) ([772e10b](https://github.com/repentsinner/tilefin-nvidia-open/commit/772e10b2b2419fd3cf116eddedf3c2a94fa98ade))

## [0.4.6](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.5...v0.4.6) (2026-03-20)


### Bug Fixes

* **aja:** use forked libajantv2 with 32-bit DMA mask fix ([#31](https://github.com/repentsinner/tilefin-nvidia-open/issues/31)) ([7dc0081](https://github.com/repentsinner/tilefin-nvidia-open/commit/7dc00814002146403e3dae181997da4c1813f291))

## [0.4.5](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.4...v0.4.5) (2026-03-18)


### Features

* NVIDIA DRM modesetting + suspend button ([#27](https://github.com/repentsinner/tilefin-nvidia-open/issues/27)) ([d61f45e](https://github.com/repentsinner/tilefin-nvidia-open/commit/d61f45ea2b214c5417db64054d1c313e983a4e20))

## [0.4.4](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.3...v0.4.4) (2026-03-17)


### Features

* **aja:** enable GPU Direct RDMA for AJA Corvid44 ([#25](https://github.com/repentsinner/tilefin-nvidia-open/issues/25)) ([551fd82](https://github.com/repentsinner/tilefin-nvidia-open/commit/551fd82c2b074915b687dfda7a9999f19ef783b1))
* **aja:** enable GPU Direct RDMA for ajantv2 ([#23](https://github.com/repentsinner/tilefin-nvidia-open/issues/23)) ([50cd1a9](https://github.com/repentsinner/tilefin-nvidia-open/commit/50cd1a9769d788a85357da813a6df93d165dee72))

## [0.4.3](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.2...v0.4.3) (2026-03-17)


### Features

* **aja:** add AJA Corvid44 kernel module (S19) ([#20](https://github.com/repentsinner/tilefin-nvidia-open/issues/20)) ([7926681](https://github.com/repentsinner/tilefin-nvidia-open/commit/79266810d5719b098c6dd181a4e4ef20f0e7a46b))

## [0.4.2](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.1...v0.4.2) (2026-02-26)


### Bug Fixes

* **build:** add missing gum package to image ([#15](https://github.com/repentsinner/tilefin-nvidia-open/issues/15)) ([a6b7f13](https://github.com/repentsinner/tilefin-nvidia-open/commit/a6b7f13482795cb263498b46ea14ad5c06a8ba7f))
* **setup-user:** add flathub user remote before flatpak install ([#17](https://github.com/repentsinner/tilefin-nvidia-open/issues/17)) ([b4b2afa](https://github.com/repentsinner/tilefin-nvidia-open/commit/b4b2afabd46b6b59b3ad7ed34cb72226fe39324f))
* **shell:** rewrite direnv hook paths for distrobox exports ([#18](https://github.com/repentsinner/tilefin-nvidia-open/issues/18)) ([c9d6473](https://github.com/repentsinner/tilefin-nvidia-open/commit/c9d6473c5c3116d8f9648d690c41636f5249a775))

## [0.4.1](https://github.com/repentsinner/tilefin-nvidia-open/compare/v0.4.0...v0.4.1) (2026-02-26)


### Features

* add additional COPR repositories for enhanced functionality ([7c0291a](https://github.com/repentsinner/tilefin-nvidia-open/commit/7c0291adb639a0b7f20048f29f12c8155939f312))
* add direnv to system utilities and enable rpm-ostreed-automatic.timer for image upgrades ([bd39695](https://github.com/repentsinner/tilefin-nvidia-open/commit/bd396954ba64861be0d7c8281791be1a9adccfff))
* Add virtualization support by installing relevant packages, enabling libvirtd, and configuring IOMMU and verbose boot kernel arguments. ([ed92220](https://github.com/repentsinner/tilefin-nvidia-open/commit/ed9222002b0f7f48fde603ba885e017281c1c509))
* Add Waybar notification indicator and configure mako for silent, history-only notifications. ([be3bcbe](https://github.com/repentsinner/tilefin-nvidia-open/commit/be3bcbe5b1bcc81306d809efd2873df544f65f49))
* **build:** rebase from bluefin-dx to base-nvidia ([2e9641b](https://github.com/repentsinner/tilefin-nvidia-open/commit/2e9641b728d55668abfe3f3d32c0a8ea847e9b67))
* enhance update check module with package summary and styling adjustments ([0c55ea5](https://github.com/repentsinner/tilefin-nvidia-open/commit/0c55ea5bf7d098f4f630de161d9ba1d7d79e5ddf))
* Implement unified compositor exit and power menu, update Hyprland configuration, and add package management guidelines. ([41345e0](https://github.com/repentsinner/tilefin-nvidia-open/commit/41345e0ba51707636e0f32f43151ba65278e66a7))
* **niri:** set VS Code default column width to 1600px ([0424d5e](https://github.com/repentsinner/tilefin-nvidia-open/commit/0424d5e5a513851fca23cce6a543457128dd45df))
* **s12:** move Flatpaks to interactive setup-user recipe with gum ([#13](https://github.com/repentsinner/tilefin-nvidia-open/issues/13)) ([b0719c5](https://github.com/repentsinner/tilefin-nvidia-open/commit/b0719c5580295f4a6cccee3095dd6800f6e14cbb))
* **s12:** move user tools to userbox distrobox container ([6046840](https://github.com/repentsinner/tilefin-nvidia-open/commit/6046840d126116cf1b61c085c43abf260a6b28b5))
* update Waybar configuration and scripts for system-wide access ([587aba3](https://github.com/repentsinner/tilefin-nvidia-open/commit/587aba3bdab0cb26a899b6514078b75d323e3502))


### Bug Fixes

* resolve hypridle crash introduced in  v0.1.3 (PR [#77](https://github.com/repentsinner/tilefin-nvidia-open/issues/77)) and improve lock/keybind config ([ae4e545](https://github.com/repentsinner/tilefin-nvidia-open/commit/ae4e545f5df7f9bdcfa3524a84e713fc5a7b7ee0))
* **shell:** add ~/.local/bin to PATH, fix ujust recipe loading ([#14](https://github.com/repentsinner/tilefin-nvidia-open/issues/14)) ([975f8f3](https://github.com/repentsinner/tilefin-nvidia-open/commit/975f8f3b0ad83c9f960990232125c4dd3b5391dc))
