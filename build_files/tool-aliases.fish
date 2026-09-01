# Aliases and shell hooks for CLI tools (userbox exports and native installers)
# All entries guarded with command -sq — silently skipped when tool is absent

# bat: syntax-highlighting pager (replaces cat for interactive use)
if command -sq bat
    alias cat 'bat --style=plain --pager=never'
end

# eza: modern ls replacement
if command -sq eza
    alias ls 'eza'
    alias ll 'eza -l'
    alias la 'eza -la'
    alias lt 'eza --tree'
end

# zoxide: smarter cd (replaces cd with fuzzy matching)
if status is-interactive; and command -sq zoxide
    zoxide init fish --cmd cd | source
end

# starship: modern prompt
if status is-interactive; and command -sq starship
    starship init fish | source
end

# direnv: per-directory environment variables
if status is-interactive; and command -sq direnv
    direnv hook fish | source
end

# mise: per-project runtime version manager (activates when .mise.toml exists)
if status is-interactive; and command -sq mise
    mise activate fish | source
end
