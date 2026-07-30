# dotfiles

`b-d-e`'s dotfiles

### Pre-Requisites

Installed:
- `zsh` shell
- `homebrew` 
- `github` creds setup

### Installation

```bash
git clone --recursive git@github.com:b-d-e/dotfiles.git ~/.dotfiles
cd .dotfiles && sh bootstrap.sh
```

### Shells

`fish` is the default login shell (bootstrap runs `chsh`). `zsh` and `nushell`
are installed and configured too — `zsh`'s config is kept as a fallback
(`chsh -s "$(command -v zsh)"`); try `nushell` by just typing `nu`.

All three share the [starship](https://starship.rs) prompt (`starship.toml`)
and, where supported, [atuin](https://atuin.sh) history. The prompt needs a
Nerd Font — `font-jetbrains-mono-nerd-font` (Brewfile on macOS; auto-downloaded
on Linux) — which the tracked `ghostty/config` selects for the terminal.

- `fastfetch` shows a system-info banner on new shells (`fastfetch/config.jsonc`).

