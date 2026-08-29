# Tilefin custom recipes

# Provision user environment: native CLI tools, Flatpaks, userbox container (optional: override image)
setup-user image="":
    #!/usr/bin/env bash
    set -euo pipefail

    # Static hostname. The installer never asks: Anaconda keeps the hostname
    # field inside the Network spoke, which the ISO kickstart already
    # satisfies, so the spoke is never flagged and the field is never seen.
    # Without a static hostname the greeter falls back to the kernel default
    # and announces the machine as "fedora", and the only name it answers to
    # comes from a DHCP lease rather than from the machine itself.
    CURRENT_STATIC=$(hostnamectl --static 2>/dev/null || true)
    CURRENT_TRANSIENT=$(hostnamectl --transient 2>/dev/null | cut -d. -f1 || true)
    HOSTNAME_NEW=$(gum input --header="Static hostname" \
        --value="${CURRENT_STATIC:-${CURRENT_TRANSIENT:-tilefin}}")
    if [ -n "$HOSTNAME_NEW" ] && [ "$HOSTNAME_NEW" != "$CURRENT_STATIC" ]; then
        echo "==> Setting static hostname to ${HOSTNAME_NEW} (needs sudo)..."
        sudo hostnamectl set-hostname "$HOSTNAME_NEW"
    fi

    # Login shell. Anaconda creates the account with /bin/bash, but the image
    # ships fish and carries fish-specific integration (tool-aliases.fish,
    # local-path.fish), so the choice belongs here rather than being
    # rediscovered on every machine. /bin and /usr/bin are the same directory
    # on Fedora; normalise so the current shell matches an offered option.
    CURRENT_SHELL=$(getent passwd "$USER" | cut -d: -f7)
    CURRENT_SHELL_NORM=${CURRENT_SHELL/#\/bin\//\/usr\/bin\/}
    SHELL_NEW=$(grep -E '^/usr/bin/(bash|fish|zsh)$' /etc/shells | sort -u \
        | gum choose --header="Login shell" --selected="$CURRENT_SHELL_NORM")
    if [ -n "$SHELL_NEW" ] && [ "$SHELL_NEW" != "$CURRENT_SHELL_NORM" ]; then
        echo "==> Setting login shell to ${SHELL_NEW} (needs sudo)..."
        sudo usermod -s "$SHELL_NEW" "$USER"
        echo "    Takes effect at next login."
    fi

    echo ""
    echo "Select components to install (space to toggle, enter to confirm):"
    echo ""

    # Native CLI tools selection
    NATIVE_TOOLS=$(gum choose --no-limit --selected="Claude Code,uv,mise" \
        "Claude Code" \
        "uv" \
        "mise")

    # Flatpak apps selection
    FLATPAK_APPS=$(gum choose --no-limit --selected="Firefox,Bitwarden" \
        "Firefox" \
        "Bitwarden" \
        "Slack" \
        "Discord" \
        "Signal" \
        "Proton VPN" \
        "Trayscale")

    # Userbox
    INSTALL_USERBOX=$(gum choose --selected="Yes" "Yes" "No" \
        --header="Assemble userbox container?")

    # Install selected native CLI tools
    if [ -n "$NATIVE_TOOLS" ]; then
        echo ""
        echo "==> Installing native CLI tools to ~/.local/bin..."
        if echo "$NATIVE_TOOLS" | grep -q "Claude Code"; then
            echo "  Claude Code..."
            curl -fsSL https://claude.ai/install.sh | bash
        fi
        if echo "$NATIVE_TOOLS" | grep -q "uv"; then
            echo "  uv..."
            curl -LsSf https://astral.sh/uv/install.sh | sh
        fi
        if echo "$NATIVE_TOOLS" | grep -q "mise"; then
            echo "  mise..."
            curl -fsSL https://mise.run | sh
        fi
    fi

    # Install selected Flatpak apps
    if [ -n "$FLATPAK_APPS" ]; then
        echo ""
        echo "==> Installing Flatpak apps..."
        flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        FLATPAK_IDS=()
        echo "$FLATPAK_APPS" | grep -q "Firefox"   && FLATPAK_IDS+=("org.mozilla.firefox")
        echo "$FLATPAK_APPS" | grep -q "Bitwarden" && FLATPAK_IDS+=("com.bitwarden.desktop")
        echo "$FLATPAK_APPS" | grep -q "Slack"     && FLATPAK_IDS+=("com.slack.Slack")
        echo "$FLATPAK_APPS" | grep -q "Discord"    && FLATPAK_IDS+=("com.discordapp.Discord")
        echo "$FLATPAK_APPS" | grep -q "Signal"     && FLATPAK_IDS+=("org.signal.Signal")
        echo "$FLATPAK_APPS" | grep -q "Proton VPN" && FLATPAK_IDS+=("com.protonvpn.www")
        echo "$FLATPAK_APPS" | grep -q "Trayscale"  && FLATPAK_IDS+=("dev.deedles.Trayscale")
        if [ ${#FLATPAK_IDS[@]} -gt 0 ]; then
            flatpak install --user --noninteractive flathub "${FLATPAK_IDS[@]}"
        fi
    fi

    # Wayland overrides for the user Flatpak installation (§spec:flatpak-override-scope).
    # build.sh writes the same overrides to /var/lib/flatpak/overrides/global,
    # but Flatpak reads overrides from the installation an app belongs to, and
    # everything here installs --user. Unconditional: the overrides apply to
    # apps installed later too. flatpak override merges into an existing
    # global file, so re-running setup-user preserves per-user grants.
    echo ""
    echo "==> Applying Wayland Flatpak overrides (user installation)..."
    flatpak override --user --socket=wayland
    flatpak override --user --env=ELECTRON_ENABLE_WAYLAND=1
    flatpak override --user --env=ELECTRON_OZONE_PLATFORM_HINT=wayland

    # Assemble userbox container
    if [ "$INSTALL_USERBOX" = "Yes" ]; then
        echo ""
        echo "==> Assembling userbox container..."
        INI="$HOME/.config/distrobox/userbox.ini"
        if [ ! -f "$INI" ]; then
            echo "Error: $INI not found."
            echo "Expected at account creation via /etc/skel."
            exit 1
        fi
        if [ -n "{{image}}" ]; then
            echo "  Overriding image to: {{image}}"
            sed -i 's|^image=.*|image={{image}}|' "$INI"
        fi
        distrobox assemble create --replace --file "$INI"
    fi

    echo ""
    echo "==> Done. Restart your shell or run: source ~/.bashrc"

# Toggle production-mode update lock (--start | --stop | --start-from-current)
production-mode mode="--start":
    #!/usr/bin/env bash
    set -euo pipefail

    FLAG_DIR="/etc/tilefin"
    FLAG_FILE="${FLAG_DIR}/production-mode"

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

    case "{{ mode }}" in
        --start|--start-from-current)
            STAGED_VERSION=$(rpm-ostree status --json 2>/dev/null \
                | jq -r '[.deployments[] | select(.staged)][0].version // empty')

            UNSTAGE="no"
            if [ -n "${STAGED_VERSION}" ]; then
                if [ "{{ mode }}" = "--start-from-current" ]; then
                    UNSTAGE="yes"
                else
                    echo "A deployment is already staged: ${STAGED_VERSION}"
                    echo ""
                    CHOICE=$(gum choose --selected="Keep staged deployment" \
                        --header="Production mode blocks future staging. What about the existing one?" \
                        "Keep staged deployment" \
                        "Unstage (next reboot keeps current image)")
                    if [ "${CHOICE}" = "Unstage (next reboot keeps current image)" ]; then
                        UNSTAGE="yes"
                    fi
                fi
            fi

            if [ "${UNSTAGE}" = "yes" ]; then
                echo "==> Unstaging deployment ${STAGED_VERSION}..."
                sudoif rpm-ostree cleanup -p
            fi

            echo "==> Enabling production mode..."
            sudoif install -d -m 755 "${FLAG_DIR}"
            sudoif touch "${FLAG_FILE}"
            echo "Flag created: ${FLAG_FILE}"
            echo "rpm-ostreed-automatic.service is now blocked at the timer."
            echo "Manual updates (bootc upgrade, rpm-ostree update, ujust update) still work."
            pkill -RTMIN+8 waybar 2>/dev/null || true
            ;;
        --stop)
            if [ -e "${FLAG_FILE}" ]; then
                echo "==> Disabling production mode..."
                sudoif rm -f "${FLAG_FILE}"
                echo "Flag removed: ${FLAG_FILE}"
                echo "Auto-staging resumes on the next rpm-ostreed-automatic.timer firing."
                pkill -RTMIN+8 waybar 2>/dev/null || true
            else
                echo "Production mode is already off (${FLAG_FILE} does not exist)."
            fi
            ;;
        *)
            echo "Usage: ujust production-mode [--start | --stop | --start-from-current]"
            echo ""
            echo "  --start                Enable update lock. Interactive if a deployment is staged."
            echo "  --start-from-current   Enable update lock and unstage any staged deployment."
            echo "  --stop                 Disable update lock; auto-staging resumes."
            exit 1
            ;;
    esac

# Toggle hot-development mode: idle display sleep and lock, no auto-suspend (--start | --stop)
hot-development mode="--start":
    #!/usr/bin/env bash
    set -euo pipefail

    FLAG_DIR="/etc/tilefin"
    FLAG_FILE="${FLAG_DIR}/hot-development"

    case "{{ mode }}" in
        --start)
            echo "==> Enabling hot-development mode..."
            sudo install -d -m 755 "${FLAG_DIR}"
            sudo touch "${FLAG_FILE}"
            echo "Flag created: ${FLAG_FILE}"
            echo "Idle display-off and lock still fire; the machine no longer auto-suspends."
            if [ -e "${FLAG_DIR}/production-mode" ]; then
                echo "Note: production mode is on and takes precedence — idle display-off and lock stay off."
            fi
            pkill -RTMIN+8 waybar 2>/dev/null || true
            ;;
        --stop)
            if [ -e "${FLAG_FILE}" ]; then
                echo "==> Disabling hot-development mode..."
                sudo rm -f "${FLAG_FILE}"
                echo "Flag removed: ${FLAG_FILE}"
                echo "Time-gated auto-suspend resumes outside business hours."
                pkill -RTMIN+8 waybar 2>/dev/null || true
            else
                echo "Hot-development mode is already off (${FLAG_FILE} does not exist)."
            fi
            ;;
        *)
            echo "Usage: ujust hot-development [--start | --stop]"
            echo ""
            echo "  --start   Hold auto-suspend so background work survives idle periods."
            echo "  --stop    Resume time-gated auto-suspend (§spec:auto-suspend)."
            exit 1
            ;;
    esac
