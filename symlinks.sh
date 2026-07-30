#!/bin/bash
# Symlink dotfiles into place. Safe to re-run (idempotent).

DOTFILES="$HOME/.dotfiles"

# Home-level files
ln -s -f "$DOTFILES/homebrew/Brewfile" ~/Brewfile
ln -s -f "$DOTFILES/homebrew/Brewfile.linux" ~/Brewfile.linux
ln -s -f "$DOTFILES/git/.gitconfig" ~/.gitconfig
ln -s -f "$DOTFILES/tmux/.tmux.conf" ~/.tmux.conf

# zsh (still the login shell; fish/nushell are opt-in via `fish`/`nu`)
ln -s -f "$DOTFILES/zsh/.zshrc" ~/.zshrc
ln -s -f "$DOTFILES/zsh/.zshenv" ~/.zshenv

# ~/.config apps.
# Note: symlink individual files into real dirs (not whole-dir symlinks) — an
# `ln -sf` of a directory onto an existing dir-symlink nests inside it instead
# of replacing it, which breaks re-runs.
mkdir -p ~/.config
ln -s -f "$DOTFILES/nvim" ~/.config/nvim
ln -s -f "$DOTFILES/starship.toml" ~/.config/starship.toml

# fastfetch
mkdir -p ~/.config/fastfetch
ln -s -f "$DOTFILES/fastfetch/config.jsonc" ~/.config/fastfetch/config.jsonc

# ghostty terminal
mkdir -p ~/.config/ghostty
ln -s -f "$DOTFILES/ghostty/config" ~/.config/ghostty/config

# fish — symlink only config.fish (fish writes its own state into ~/.config/fish)
mkdir -p ~/.config/fish
ln -s -f "$DOTFILES/fish/config.fish" ~/.config/fish/config.fish

# nushell — config dir differs by OS (macOS: Library/Application Support;
# Linux: ~/.config), so ask nu where it wants its files. Symlink individual
# files (nu writes history etc. into that dir).
if command -v nu >/dev/null 2>&1; then
  NU_CFG="$(nu --no-config-file -c '$nu.default-config-dir' 2>/dev/null)"
  if [ -n "$NU_CFG" ]; then
    mkdir -p "$NU_CFG"
    ln -s -f "$DOTFILES/nushell/config.nu" "$NU_CFG/config.nu"
    ln -s -f "$DOTFILES/nushell/env.nu" "$NU_CFG/env.nu"
    # Generate starship + atuin init into nushell's vendor autoload dir.
    nu "$DOTFILES/nushell/gen-integrations.nu" 2>/dev/null || true
  fi
else
  echo "nushell not installed yet; skipping nu config symlinks (re-run after 'brew bundle')."
fi
