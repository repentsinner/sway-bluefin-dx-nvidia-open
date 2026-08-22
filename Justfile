export image_name := env("IMAGE_NAME", "tilefin-nvidia-open") # output image name, usually same as repo name, change as needed
export default_tag := env("DEFAULT_TAG", "latest")
export bib_image := env("BIB_IMAGE", "quay.io/centos-bootc/bootc-image-builder:latest")

# Local test VM (§spec:vm-test-harness). qemu:///session keeps the domain
# rootless so it can read images from the work tree without relabelling.
export vm_name := env("VM_NAME", "tilefin-test")
export vm_connect := env("VM_CONNECT", "qemu:///session")
# niri has no software-EGL fallback, so a virtio-gpu without 3D renders
# nothing. Set VM_GL=off if the host lacks virgl.
export vm_gl := env("VM_GL", "on")
export vm_ram := env("VM_RAM", "8192")
export vm_cpus := env("VM_CPUS", "4")

alias build-vm := build-qcow2
alias rebuild-vm := rebuild-qcow2
alias run-vm := run-vm-qcow2

[private]
default:
    @just --list

# Check Just Syntax
[group('Just')]
check:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt --check -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt --check -f Justfile

# Fix Just Syntax
[group('Just')]
fix:
    #!/usr/bin/bash
    find . -type f -name "*.just" | while read -r file; do
    	echo "Checking syntax: $file"
    	just --unstable --fmt -f $file
    done
    echo "Checking syntax: Justfile"
    just --unstable --fmt -f Justfile || { exit 1; }

# Clean Repo
[group('Utility')]
clean:
    #!/usr/bin/bash
    set -eoux pipefail
    touch _build
    find *_build* -exec rm -rf {} \;
    rm -f previous.manifest.json
    rm -f changelog.md
    rm -f output.env
    rm -f output/

# Sudo Clean Repo
[group('Utility')]
[private]
sudo-clean:
    just sudoif just clean

# sudoif bash function
[group('Utility')]
[private]
sudoif command *args:
    #!/usr/bin/bash
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
    sudoif {{ command }} {{ args }}

# This Justfile recipe builds a container image using Podman.
#
# Arguments:
#   $target_image - The tag you want to apply to the image (default: $image_name).
#   $tag - The tag for the image (default: $default_tag).
#
# The script constructs the version string using the tag and the current date.
# If the git working directory is clean, it also includes the short SHA of the current HEAD.
#
# just build $target_image $tag
#
# Example usage:
#   just build aurora lts
#
# This will build an image 'aurora:lts' with DX and GDX enabled.
#

# Build the image using the specified parameters
build $target_image=image_name $tag=default_tag:
    #!/usr/bin/env bash

    BUILD_ARGS=()
    if [[ -z "$(git status -s)" ]]; then
        BUILD_ARGS+=("--build-arg" "SHA_HEAD_SHORT=$(git rev-parse --short HEAD)")
    fi

    podman build \
        "${BUILD_ARGS[@]}" \
        --pull=newer \
        --tag "${target_image}:${tag}" \
        .

# Command: _rootful_load_image
# Description: This script checks if the current user is root or running under sudo. If not, it attempts to resolve the image tag using podman inspect.
#              If the image is found, it loads it into rootful podman. If the image is not found, it pulls it from the repository.
#
# Parameters:
#   $target_image - The name of the target image to be loaded or pulled.
#   $tag - The tag of the target image to be loaded or pulled. Default is 'default_tag'.
#
# Example usage:
#   _rootful_load_image my_image latest
#
# Steps:
# 1. Check if the script is already running as root or under sudo.
# 2. Check if target image is in the non-root podman container storage)
# 3. If the image is found, load it into rootful podman using podman scp.
# 4. If the image is not found, pull it from the remote repository into reootful podman.

_rootful_load_image $target_image=image_name $tag=default_tag:
    #!/usr/bin/bash
    set -eoux pipefail

    # Check if already running as root or under sudo
    if [[ -n "${SUDO_USER:-}" || "${UID}" -eq "0" ]]; then
        echo "Already root or running under sudo, no need to load image from user podman."
        exit 0
    fi

    # Try to resolve the image tag using podman inspect
    set +e
    resolved_tag=$(podman inspect -t image "${target_image}:${tag}" | jq -r '.[].RepoTags.[0]')
    return_code=$?
    set -e

    USER_IMG_ID=$(podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")

    if [[ $return_code -eq 0 ]]; then
        # If the image is found, load it into rootful podman
        ID=$(just sudoif podman images --filter reference="${target_image}:${tag}" --format "'{{ '{{.ID}}' }}'")
        if [[ "$ID" != "$USER_IMG_ID" ]]; then
            # If the image ID is not found or different from user, copy the image from user podman to root podman
            COPYTMP=$(mktemp -p "${PWD}" -d -t _build_podman_scp.XXXXXXXXXX)
            just sudoif TMPDIR=${COPYTMP} podman image scp ${UID}@localhost::"${target_image}:${tag}" root@localhost::"${target_image}:${tag}"
            rm -rf "${COPYTMP}"
        fi
    else
        # If the image is not found, pull it from the repository
        just sudoif podman pull "${target_image}:${tag}"
    fi

# Build a bootc bootable image using Bootc Image Builder (BIB)
# Converts a container image to a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (default: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_build-bib $target_image $tag $type $config: (_rootful_load_image target_image tag)
    #!/usr/bin/env bash
    set -euo pipefail

    args="--type ${type} "
    args+="--use-librepo=True "
    args+="--rootfs=btrfs"

    BUILDTMP=$(mktemp -p "${PWD}" -d -t _build-bib.XXXXXXXXXX)

    # BIB reads the image from container storage and no longer pulls it.
    # Mount the graphroot podman actually uses rather than the default
    # path: /etc/containers/storage.conf may relocate it, and mounting
    # the wrong directory yields "image not known" for an image that is
    # demonstrably present.

    sudo podman run \
      --rm \
      -it \
      --privileged \
      --pull=newer \
      --net=host \
      --security-opt label=type:unconfined_t \
      -v $(pwd)/${config}:/config.toml:ro \
      -v $BUILDTMP:/output \
      -v "$(sudo podman info --format '{{{{.Store.GraphRoot}}')":/var/lib/containers/storage \
      "${bib_image}" \
      ${args} \
      "${target_image}:${tag}"

    mkdir -p output
    sudo mv -f $BUILDTMP/* output/
    sudo rmdir $BUILDTMP
    sudo chown -R $USER:$USER output/

# Podman builds the image from the Containerfile and creates a bootable image
# Parameters:
#   target_image: The name of the image to build (ex. localhost/fedora)
#   tag: The tag of the image to build (ex. latest)
#   type: The type of image to build (ex. qcow2, raw, iso)
#   config: The configuration file to use for the build (deafult: disk_config/disk.toml)

# Example: just _rebuild-bib localhost/fedora latest qcow2 disk_config/disk.toml
_rebuild-bib $target_image $tag $type $config: (build target_image tag) && (_build-bib target_image tag type config)

# Build a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
build-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "qcow2" "disk_config/disk.toml")

# Build a RAW virtual machine image
[group('Build Virtal Machine Image')]
build-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "raw" "disk_config/disk.toml")

# Build an ISO virtual machine image
[group('Build Virtal Machine Image')]
build-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_build-bib target_image tag "anaconda-iso" "disk_config/iso.toml")

# Rebuild a QCOW2 virtual machine image
[group('Build Virtal Machine Image')]
rebuild-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "qcow2" "disk_config/disk.toml")

# Rebuild a RAW virtual machine image
[group('Build Virtal Machine Image')]
rebuild-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "raw" "disk_config/disk.toml")

# Rebuild an ISO virtual machine image
[group('Build Virtal Machine Image')]
rebuild-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_rebuild-bib target_image tag "anaconda-iso" "disk_config/iso.toml")

# Run a virtual machine with the specified image type and configuration
_run-vm $target_image $tag $type $config:
    #!/usr/bin/bash
    set -eou pipefail

    # Locate the artifact the matching build recipe produces.
    image_file="output/${type}/disk.${type}"
    if [[ $type == *iso ]]; then
        image_file="output/bootiso/install.iso"
    fi
    if [[ ! -f "${image_file}" ]]; then
        just "build-${type}" "$target_image" "$tag"
    fi

    # Refuse an absent or unreadable image rather than letting the hypervisor
    # improvise. The qemux/qemu recipe this replaced fell back to downloading
    # and booting Alpine Linux when it could not parse the disk, so a broken
    # build presented as a working VM of an entirely different OS.
    if [[ ! -s "${image_file}" ]]; then
        echo "ERROR: ${image_file} is missing or empty. Run: just build-${type}" >&2
        exit 1
    fi
    # qemu-img guesses "raw" for anything it cannot parse, so an unpinned
    # `qemu-img info` accepts a text file. Pin the format to make it a check.
    if [[ $type == qcow2 ]] && command -v qemu-img >/dev/null; then
        if ! qemu-img info -f qcow2 "${image_file}" >/dev/null 2>&1; then
            echo "ERROR: ${image_file} is not a valid qcow2 image." >&2
            exit 1
        fi
    fi
    # A raw disk has no header to validate, so look for the GPT signature that
    # bootc-image-builder writes at LBA 1.
    if [[ $type == raw ]]; then
        if ! printf 'EFI PART' | cmp -s - <(dd if="${image_file}" bs=1 skip=512 count=8 status=none); then
            echo "ERROR: ${image_file} has no GPT header; it is not a bootable disk." >&2
            exit 1
        fi
    fi

    if virsh --connect "$vm_connect" dominfo "$vm_name" >/dev/null 2>&1; then
        echo "ERROR: domain '$vm_name' already exists. Remove it with: just clean-vm" >&2
        exit 1
    fi

    args=(
        --connect "$vm_connect"
        --name "$vm_name"
        --memory "$vm_ram"
        --vcpus "$vm_cpus"
        --boot uefi
        --osinfo "detect=on,name=fedora-unknown"
        --network user
        # swtpm cannot execute under a rootless session and nothing in the
        # image needs a TPM; virt-install would otherwise attach one and fail.
        --tpm none
        # virt-viewer is not in the image, so let virt-manager open the console.
        --noautoconsole
    )

    if [[ $type == *iso ]]; then
        args+=(--cdrom "${PWD}/${image_file}")
        args+=(--disk "size=64,format=qcow2")
    else
        args+=(--import)
        args+=(--disk "path=${PWD}/${image_file},format=${type},bus=virtio")
    fi

    # niri skips software EGL renderers, so without 3D the compositor starts
    # but draws nothing. Set VM_GL=off when the host cannot provide virgl.
    if [[ "$vm_gl" == "on" ]]; then
        args+=(--video "virtio,accel3d=on")
        args+=(--graphics "spice,gl.enable=yes,listen=none")
    else
        args+=(--video virtio --graphics spice)
        echo "NOTE: VM_GL=off — niri will start but render nothing." >&2
    fi

    if ! virt-install "${args[@]}"; then
        echo "" >&2
        echo "virt-install failed. If it objected to 3D acceleration, retry with:" >&2
        echo "  VM_GL=off just run-vm-${type}" >&2
        exit 1
    fi

    echo "Domain '$vm_name' started on $vm_connect."
    if command -v virt-manager >/dev/null; then
        virt-manager --connect "$vm_connect" --show-domain-console "$vm_name" &
    else
        echo "Open the console with:" >&2
        echo "  virt-manager --connect $vm_connect --show-domain-console $vm_name" >&2
    fi

# Destroy and undefine the local test VM
[group('Run Virtal Machine')]
clean-vm:
    #!/usr/bin/bash
    set -eou pipefail
    virsh --connect "$vm_connect" destroy "$vm_name" >/dev/null 2>&1 || true
    virsh --connect "$vm_connect" undefine --nvram "$vm_name" >/dev/null 2>&1 || true
    echo "Removed domain '$vm_name' from $vm_connect (if it existed)."

# Run a virtual machine from a QCOW2 image
[group('Run Virtal Machine')]
run-vm-qcow2 $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "qcow2" "disk_config/disk.toml")

# Run a virtual machine from a RAW image
[group('Run Virtal Machine')]
run-vm-raw $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "raw" "disk_config/disk.toml")

# Run a virtual machine from an ISO
[group('Run Virtal Machine')]
run-vm-iso $target_image=("localhost/" + image_name) $tag=default_tag: && (_run-vm target_image tag "anaconda-iso" "disk_config/iso.toml")

# Run a virtual machine using systemd-vmspawn
[group('Run Virtal Machine')]
spawn-vm rebuild="0" type="qcow2" ram="6G":
    #!/usr/bin/env bash

    set -euo pipefail

    [ "{{ rebuild }}" -eq 1 ] && echo "Rebuilding the ISO" && just build-vm {{ rebuild }} {{ type }}

    systemd-vmspawn \
      -M "bootc-image" \
      --console=gui \
      --cpus=2 \
      --ram=$(echo {{ ram }}| /usr/bin/numfmt --from=iec) \
      --network-user-mode \
      --vsock=false --pass-ssh-key=false \
      -i ./output/**/*.{{ type }}


# Runs shell check on all Bash scripts
lint:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shellcheck is installed
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shellcheck on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shellcheck "{}" ';'

# Runs shfmt on all Bash scripts
format:
    #!/usr/bin/env bash
    set -eoux pipefail
    # Check if shfmt is installed
    if ! command -v shfmt &> /dev/null; then
        echo "shellcheck could not be found. Please install it."
        exit 1
    fi
    # Run shfmt on all Bash scripts
    /usr/bin/find . -iname "*.sh" -type f -exec shfmt --write "{}" ';'
