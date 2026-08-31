# shellcheck shell=bash
# Sourced, not executed, so it carries a shell directive rather than a shebang.
# Add ~/.local/bin to PATH for native-installer CLIs (e.g., Claude Code)
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
