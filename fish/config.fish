# ~/.dotfiles/fish/config.fish  (symlinked to ~/.config/fish/config.fish)

# --- PATH / environment (runs for every fish, incl. non-interactive) ---

# Homebrew: macOS (/opt/homebrew or /usr/local) or Linux (linuxbrew).
for brew_path in /home/linuxbrew/.linuxbrew/bin/brew /opt/homebrew/bin/brew /usr/local/bin/brew
    if test -x $brew_path
        $brew_path shellenv fish | source
        break
    end
end

# Tools that append to PATH in POSIX shells, done the fish way.
fish_add_path -g "$HOME/.cargo/bin"      # rust / cargo
fish_add_path -g "$HOME/.local/bin"      # uv and other pip-installed tools
fish_add_path -g "$HOME/.lmstudio/bin"   # LM Studio CLI (lms)

# --- Interactive-only setup ---
if status is-interactive
    # System-info banner first, so it paints immediately.
    command -q fastfetch && fastfetch

    # Aliases
    alias vim nvim

    # Modern CLI replacements (only if installed; fall back silently otherwise).
    if command -q eza
        alias ls "eza --icons --group-directories-first"
        alias ll "eza -l --icons --git --group-directories-first"
        alias la "eza -la --icons --git --group-directories-first"
        alias lt "eza --tree --level=2 --icons"
    end
    command -q bat && alias cat bat

    # Shell integrations (only if the tool is installed).
    command -q starship && starship init fish | source
    command -q zoxide && zoxide init fish | source
    # atuin's fish init still emits the pre-fish-4 `bind -k up` syntax; rewrite
    # it to `bind up` on the fly. No-op once atuin fixes it upstream.
    command -q atuin && atuin init fish | string replace -ra -- ' -k (\S+)' ' $1' | source
end
