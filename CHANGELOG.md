# Changelog

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
