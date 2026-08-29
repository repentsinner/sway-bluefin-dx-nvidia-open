# Blackmagic Design Desktop Video driver management
#
# These recipes build and install the BMD kernel modules, firmware, and
# userspace tools on a Fedora Atomic host. The BMD tarball is not
# redistributable — download it from blackmagicdesign.com and pass the
# path to bmd-install.

export bmd_install_dir := "/var/lib/blackmagic"
export bmd_module_dir := "/var/lib/blackmagic/modules"
export bmd_lib_dir := "/var/lib/blackmagic/lib"
export bmd_bin_dir := "/var/lib/blackmagic/bin"

# Build and install Blackmagic DeckLink kernel modules, firmware, and userspace
[group('Blackmagic')]
bmd-install tarball:
    #!/usr/bin/env bash
    set -euo pipefail

    KERNEL_RELEASE="$(uname -r)"
    BUILD_DIR="$(mktemp -d /tmp/bmd-build.XXXXXXXXXX)"
    trap 'rm -rf "${BUILD_DIR}"' EXIT

    echo "==> Building Blackmagic modules for kernel ${KERNEL_RELEASE}"
    echo "  Working in ${BUILD_DIR}"

    # Extract tarball
    echo "  Extracting tarball..."
    tar xzf "{{ tarball }}" -C "${BUILD_DIR}" --strip-components=1

    # Detect BMD version from the extracted RPM filename. Tarballs ship
    # rpm/x86_64/desktopvideo-<ver>.x86_64.rpm; the same <ver> appears in
    # usr/src/blackmagic{,-io}-<ver>/, so SRC_IO/SRC_BM follow naturally.
    # The leading [0-9] excludes the desktopvideo-gui-<ver>.x86_64.rpm sibling.
    shopt -s nullglob
    candidates=("${BUILD_DIR}"/rpm/x86_64/desktopvideo-[0-9]*.x86_64.rpm)
    shopt -u nullglob
    case ${#candidates[@]} in
        0) echo "Error: no desktopvideo-<ver>.x86_64.rpm found under ${BUILD_DIR}/rpm/x86_64/"; exit 1 ;;
        1) RPM="${candidates[0]}" ;;
        *) echo "Error: multiple desktopvideo RPMs in tarball:"; printf '  %s\n' "${candidates[@]}"; exit 1 ;;
    esac
    BMD_VERSION="$(basename "${RPM}" .x86_64.rpm)"
    BMD_VERSION="${BMD_VERSION#desktopvideo-}"
    echo "  Detected BMD version: ${BMD_VERSION}"

    echo "  Extracting RPM..."
    RPM_ROOT="${BUILD_DIR}/rpm-root"
    mkdir -p "${RPM_ROOT}"
    cd "${RPM_ROOT}"
    rpm2cpio "${RPM}" | cpio -idm --quiet
    cd - > /dev/null

    # Build kernel modules in a Fedora container
    echo "  Building kernel modules in container..."
    SRC_IO="${RPM_ROOT}/usr/src/blackmagic-io-${BMD_VERSION}"
    SRC_BM="${RPM_ROOT}/usr/src/blackmagic-${BMD_VERSION}"

    # Parse kernel release into Koji URL components.
    # KERNEL_RELEASE is e.g. 6.19.8-100.fc42.x86_64
    KERN_VER="${KERNEL_RELEASE%%.fc*}"          # 6.19.8-100
    KERN_VER="${KERN_VER%-*}"                    # 6.19.8
    KERN_REL="${KERNEL_RELEASE%%.x86_64}"        # 6.19.8-100.fc42
    KERN_REL="${KERN_REL#*-}"                    # 100.fc42
    KOJI_URL="https://kojipkgs.fedoraproject.org/packages/kernel/${KERN_VER}/${KERN_REL}/x86_64/kernel-devel-${KERNEL_RELEASE}.rpm"

    podman run --rm \
        -v "${SRC_IO}:/build/blackmagic-io:Z" \
        -v "${SRC_BM}:/build/blackmagic:Z" \
        "registry.fedoraproject.org/fedora:$(rpm -E %fedora)" \
        bash -c "
            set -euo pipefail

            # Try the repos first; fall back to Koji for older kernels.
            if ! dnf install -y --setopt=install_weak_deps=False \
                    kernel-devel-${KERNEL_RELEASE} 2>/dev/null; then
                echo
                echo \"  WARNING: kernel-devel-${KERNEL_RELEASE} not in Fedora repos.\"
                echo '  Falling back to Koji (Fedora build system).'
                echo
                echo '  Your running kernel is behind the repo. Consider rebooting'
                echo '  to pick up the latest kernel before rebuilding:'
                echo '    rpm-ostree upgrade && systemctl reboot'
                echo
                dnf install -y --setopt=install_weak_deps=False \
                    ${KOJI_URL}
            fi
            dnf install -y --setopt=install_weak_deps=False \
                gcc make elfutils-libelf-devel

            # kernel-devel installs source to /usr/src/kernels/ but the
            # /lib/modules/<ver>/build symlink requires kernel-core which
            # is too heavy for a build container. Create it manually.
            mkdir -p /lib/modules/${KERNEL_RELEASE}
            ln -sf /usr/src/kernels/${KERNEL_RELEASE} /lib/modules/${KERNEL_RELEASE}/build
            cd /build/blackmagic-io
            make KERNELRELEASE=${KERNEL_RELEASE}
            cd /build/blackmagic
            make KERNELRELEASE=${KERNEL_RELEASE}
        "

    # Install to host
    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }

    echo "==> Installing to host"

    # Stop existing services before overwriting binaries/modules.
    # On a fresh install these units don't exist yet — guard with is-active.
    if systemctl is-active --quiet DesktopVideoHelper.service 2>/dev/null; then
        echo "  Stopping existing services..."
        sudoif systemctl stop DesktopVideoHelper.service
    fi
    if systemctl is-active --quiet blackmagic-io.service 2>/dev/null; then
        sudoif systemctl stop blackmagic-io.service
    fi

    # Kernel modules
    echo "  Installing kernel modules..."
    sudoif mkdir -p {{ bmd_module_dir }}
    sudoif cp "${SRC_IO}/blackmagic-io.ko" {{ bmd_module_dir }}/
    sudoif cp "${SRC_IO}/snd_blackmagic-io.ko" {{ bmd_module_dir }}/
    sudoif cp "${SRC_BM}/blackmagic.ko" {{ bmd_module_dir }}/

    # SELinux: label directories so confined domains can access them.
    #   modules → modules_object_t (kmod_t loads at boot)
    #   lib     → lib_t            (ldconfig_t reads; ld.so maps at runtime)
    #   bin     → bin_t            (systemd/udev executes)
    echo "  Configuring SELinux file contexts..."
    sudoif semanage fcontext -a -t modules_object_t '{{ bmd_module_dir }}(/.*)?'  2>/dev/null \
        || sudoif semanage fcontext -m -t modules_object_t '{{ bmd_module_dir }}(/.*)?' 2>/dev/null \
        || true
    sudoif restorecon -Rv {{ bmd_module_dir }}
    sudoif semanage fcontext -a -t lib_t '{{ bmd_lib_dir }}(/.*)?'  2>/dev/null \
        || sudoif semanage fcontext -m -t lib_t '{{ bmd_lib_dir }}(/.*)?' 2>/dev/null \
        || true
    sudoif semanage fcontext -a -t bin_t '{{ bmd_bin_dir }}(/.*)?'  2>/dev/null \
        || sudoif semanage fcontext -m -t bin_t '{{ bmd_bin_dir }}(/.*)?' 2>/dev/null \
        || true

    # Firmware blobs must live at <bin_dir>/Firmware/ — DesktopVideoUpdateTool
    # (and its BlackmagicFirmwareUpdater symlink) resolves /proc/self/exe and
    # appends "/Firmware" to locate them. Any other path is invisible, even
    # though BlackmagicFirmwareUpdater status still reports OK.
    echo "  Installing firmware..."
    sudoif mkdir -p {{ bmd_bin_dir }}/Firmware
    sudoif cp "${RPM_ROOT}"/usr/lib64/blackmagic/DesktopVideo/Firmware/*.bin {{ bmd_bin_dir }}/Firmware/

    # SDK libraries (public — on ld.so search path for application linking)
    echo "  Installing SDK libraries..."
    sudoif mkdir -p {{ bmd_lib_dir }}
    sudoif cp "${RPM_ROOT}"/usr/lib64/libDeckLinkAPI.so {{ bmd_lib_dir }}/
    sudoif cp "${RPM_ROOT}"/usr/lib64/libDeckLinkPreviewAPI.so {{ bmd_lib_dir }}/

    # Userspace binaries + private runtime libs (co-located so RUNPATH $ORIGIN works)
    echo "  Installing userspace binaries and runtime libraries..."
    DV_SRC="${RPM_ROOT}/usr/lib64/blackmagic/DesktopVideo"
    sudoif mkdir -p {{ bmd_bin_dir }}
    for f in DesktopVideoHelper DesktopVideoNotifier DesktopVideoUpdateTool \
             libDVUpdate.so libusb-1.0.so.0; do
        sudoif cp "${DV_SRC}/${f}" {{ bmd_bin_dir }}/
    done
    sudoif ln -sf DesktopVideoUpdateTool {{ bmd_bin_dir }}/BlackmagicFirmwareUpdater

    # Bundled C++ runtime. Shipped up to 16.0.1a2; dropped in 16.1a3, which links
    # against the system libstdc++ instead. Copy only what the release ships, and
    # delete stragglers from an earlier version: these sit on libDeckLinkAPI.so's
    # RUNPATH, where a stale libgcc_s.so.1 would shadow the system one and pair a
    # new binary with an old ABI.
    BUNDLED_LIBS=()
    for lib in libc++.so.1 libc++abi.so.1 libgcc_s.so.1; do
        if [[ -e "${DV_SRC}/${lib}" ]]; then
            sudoif cp "${DV_SRC}/${lib}" {{ bmd_bin_dir }}/
            BUNDLED_LIBS+=("${lib}")
        else
            sudoif rm -f {{ bmd_bin_dir }}/"${lib}"
        fi
    done
    if (( ${#BUNDLED_LIBS[@]} > 0 )); then
        echo "    Bundled C++ runtime: ${BUNDLED_LIBS[*]}"
    else
        echo "    No bundled C++ runtime in ${BMD_VERSION}; using system libstdc++."
    fi
    sudoif restorecon -Rv {{ bmd_bin_dir }}

    # SDK RUNPATH symlinks: libDeckLinkAPI.so has RUNPATH $ORIGIN/blackmagic/DesktopVideo
    # so it looks for the bundled libs relative to itself. Symlink to the bin dir
    # copies. Clear the directory first — a release that bundles nothing must leave
    # no symlinks behind, or they would resolve to the deleted files above.
    echo "  Creating SDK RUNPATH symlinks..."
    SDK_RUNPATH_DIR="{{ bmd_lib_dir }}/blackmagic/DesktopVideo"
    sudoif mkdir -p "${SDK_RUNPATH_DIR}"
    for lib in libc++.so.1 libc++abi.so.1 libgcc_s.so.1; do
        sudoif rm -f "${SDK_RUNPATH_DIR}/${lib}"
    done
    for lib in "${BUNDLED_LIBS[@]}"; do
        sudoif ln -sf {{ bmd_bin_dir }}/"${lib}" "${SDK_RUNPATH_DIR}/${lib}"
    done

    # Apply lib_t labels before ldconfig runs — ldconfig_t cannot read var_lib_t.
    sudoif restorecon -Rv {{ bmd_lib_dir }}

    # Only SDK libraries are discoverable via ld.so (DeckLinkAPIDispatch.cpp uses dlopen).
    # Private runtime libs stay in bin/ — not on the search path, found via RUNPATH only.
    echo "/var/lib/blackmagic/lib" | sudoif tee /etc/ld.so.conf.d/blackmagic.conf > /dev/null
    sudoif ldconfig

    # PATH wrappers. The same binary dispatches on basename(argv[0]):
    #   BlackmagicFirmwareUpdater → stripped positional CLI (status / update <dev>)
    #   DesktopVideoUpdateTool    → full CLI (--list, --device, --all, --update)
    # Expose both: the vendor name is what BMD's docs reference; the underlying
    # tool surfaces real diagnostics (e.g. "Firmware is not found") that the
    # wrapper hides.
    sudoif mkdir -p /usr/local/bin
    for name in BlackmagicFirmwareUpdater DesktopVideoUpdateTool; do
        printf '%s\n' \
            '#!/usr/bin/env bash' \
            "exec /var/lib/blackmagic/bin/${name} \"\$@\"" \
            | sudoif tee /usr/local/bin/${name} > /dev/null
        sudoif chmod 755 /usr/local/bin/${name}
    done

    # Udev rules — notify DesktopVideoHelper on device hotplug
    echo "  Installing udev rules..."
    BIN_DIR="{{ bmd_bin_dir }}"
    printf '%s\n' \
        '# Blackmagic Design DeckLink device permissions and hotplug notification' \
        "ACTION==\"add\", KERNEL==\"blackmagic/dv[0-9]*\", MODE=\"0666\", RUN+=\"${BIN_DIR}/DesktopVideoNotifier add /dev/%k\"" \
        "ACTION==\"remove\", KERNEL==\"blackmagic/dv[0-9]*\", RUN+=\"${BIN_DIR}/DesktopVideoNotifier del /dev/%k\"" \
        'ACTION=="add", KERNEL=="blackmagic/ttydv[0-9]*", SYMLINK+="blackmagic/serial%n", MODE="0666"' \
        '' \
        "ACTION==\"add\", KERNEL==\"blackmagic/io[0-9]*\", MODE=\"0666\", RUN+=\"${BIN_DIR}/DesktopVideoNotifier add /dev/%k\"" \
        "ACTION==\"remove\", KERNEL==\"blackmagic/io[0-9]*\", RUN+=\"${BIN_DIR}/DesktopVideoNotifier del /dev/%k\"" \
        'ACTION=="add", KERNEL=="blackmagic/ttyio[0-9]*", MODE="0666"' \
        | sudoif tee /etc/udev/rules.d/55-blackmagic.rules > /dev/null

    # Systemd: kernel module loader
    # Uses bash -c with lsmod guard so insmod is skipped if already loaded
    # (e.g. re-running bmd-install without rebooting).
    echo "  Installing systemd services..."
    MODULE_DIR="{{ bmd_module_dir }}"
    printf '%s\n' \
        '[Unit]' \
        'Description=Load Blackmagic DeckLink kernel modules' \
        'After=local-fs.target' \
        '' \
        '[Service]' \
        'Type=oneshot' \
        'RemainAfterExit=yes' \
        "ExecStart=/bin/bash -c 'lsmod | grep -q ^blackmagic\\ || /sbin/insmod ${MODULE_DIR}/blackmagic.ko'" \
        "ExecStart=/bin/bash -c 'lsmod | grep -q ^blackmagic_io\\ || /sbin/insmod ${MODULE_DIR}/blackmagic-io.ko'" \
        "ExecStart=/bin/bash -c 'lsmod | grep -q ^snd_blackmagic_io\\ || /sbin/insmod ${MODULE_DIR}/snd_blackmagic-io.ko'" \
        'ExecStop=-/sbin/rmmod snd_blackmagic-io' \
        'ExecStop=-/sbin/rmmod blackmagic-io' \
        'ExecStop=-/sbin/rmmod blackmagic' \
        '' \
        '[Install]' \
        'WantedBy=multi-user.target' \
        | sudoif tee /etc/systemd/system/blackmagic-io.service > /dev/null

    # Systemd: DesktopVideo helper daemon (device enumeration for SDK)
    # On Fedora Atomic, rpm-ostree rebuilds ld.so.cache during deployment,
    # dropping our /etc/ld.so.conf.d/blackmagic.conf entry.  Rebuild the
    # cache before starting so libDeckLinkAPI.so is discoverable via dlopen.
    printf '%s\n' \
        '[Unit]' \
        'Description=Blackmagic DesktopVideo helper daemon' \
        'After=blackmagic-io.service' \
        'Requires=blackmagic-io.service' \
        '' \
        '[Service]' \
        'Type=simple' \
        'ExecStartPre=/sbin/ldconfig' \
        "ExecStart=${BIN_DIR}/DesktopVideoHelper -n" \
        'Restart=on-failure' \
        '' \
        '[Install]' \
        'WantedBy=multi-user.target' \
        | sudoif tee /etc/systemd/system/DesktopVideoHelper.service > /dev/null

    sudoif systemctl daemon-reload
    sudoif systemctl enable blackmagic-io.service
    sudoif systemctl enable DesktopVideoHelper.service
    sudoif udevadm control --reload-rules

    # Start services
    echo "  Starting services..."
    sudoif systemctl start blackmagic-io.service
    sudoif systemctl start DesktopVideoHelper.service

    echo ""
    echo "==> Installation complete."
    systemctl status blackmagic-io.service --no-pager
    echo ""
    systemctl status DesktopVideoHelper.service --no-pager
    echo ""
    echo "Verify with: BlackmagicFirmwareUpdater status"

# Uninstall Blackmagic modules, firmware, and tools from the host
[group('Blackmagic')]
[confirm("This will remove all BMD drivers and tools from the host. Continue?")]
bmd-uninstall:
    #!/usr/bin/env bash
    set -euo pipefail

    function sudoif(){
        if [[ "${UID}" -eq 0 ]]; then
            "$@"
        elif [[ "$(command -v sudo)" && -n "${SSH_ASKPASS:-}" ]] && [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
            /usr/bin/sudo --askpass "$@" || exit 1
        elif [[ "$(command -v sudo)" ]]; then
            /usr/bin/sudo "$@" || exit 1
        else
            exit 1
        fi
    }

    echo "==> Uninstalling Blackmagic Design Desktop Video driver"

    # Stop and disable services (may not exist on a partial or repeated uninstall)
    echo "  Stopping services..."
    if systemctl is-active --quiet DesktopVideoHelper.service 2>/dev/null; then
        sudoif systemctl stop DesktopVideoHelper.service
    fi
    if systemctl is-enabled --quiet DesktopVideoHelper.service 2>/dev/null; then
        sudoif systemctl disable DesktopVideoHelper.service
    fi
    if systemctl is-active --quiet blackmagic-io.service 2>/dev/null; then
        sudoif systemctl stop blackmagic-io.service
    fi
    if systemctl is-enabled --quiet blackmagic-io.service 2>/dev/null; then
        sudoif systemctl disable blackmagic-io.service
    fi

    # Remove systemd services
    echo "  Removing systemd services..."
    sudoif rm -f /etc/systemd/system/DesktopVideoHelper.service
    sudoif rm -f /etc/systemd/system/blackmagic-io.service
    sudoif systemctl daemon-reload

    # Remove udev rules
    echo "  Removing udev rules..."
    sudoif rm -f /etc/udev/rules.d/55-blackmagic.rules
    sudoif udevadm control --reload-rules

    # Remove SELinux file contexts (may not exist on a fresh or repeated uninstall)
    echo "  Removing SELinux file contexts..."
    semanage fcontext -l 2>/dev/null | grep -q '{{ bmd_module_dir }}' \
        && sudoif semanage fcontext -d '{{ bmd_module_dir }}(/.*)?' || true
    semanage fcontext -l 2>/dev/null | grep -q '{{ bmd_lib_dir }}' \
        && sudoif semanage fcontext -d '{{ bmd_lib_dir }}(/.*)?' || true
    semanage fcontext -l 2>/dev/null | grep -q '{{ bmd_bin_dir }}' \
        && sudoif semanage fcontext -d '{{ bmd_bin_dir }}(/.*)?' || true

    # Remove ld.so config
    echo "  Removing library config..."
    sudoif rm -f /etc/ld.so.conf.d/blackmagic.conf
    sudoif ldconfig

    # Remove wrapper scripts
    echo "  Removing firmware updater wrappers..."
    sudoif rm -f /usr/local/bin/BlackmagicFirmwareUpdater
    sudoif rm -f /usr/local/bin/DesktopVideoUpdateTool

    # Remove install directory
    echo "  Removing {{ bmd_install_dir }}..."
    sudoif rm -rf {{ bmd_install_dir }}

    echo ""
    echo "==> Uninstall complete."
