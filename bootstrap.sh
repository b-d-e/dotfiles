#!/bin/bash

echo "Setting up new machine..."

# --- flags ---------------------------------------------------------------
# --no-sudo: install everything in userspace (~/.cargo, ~/.local), skip
# Homebrew, and make fish the interactive shell via an rc guard instead of
# chsh. For locked-down hosts (shared clusters, managed Macs) without root.
NO_SUDO=0
for arg in "$@"; do
  case "$arg" in
    --no-sudo) NO_SUDO=1 ;;
  esac
done
# Auto-fall back to userspace mode if sudo isn't even available.
if [ "$NO_SUDO" -eq 0 ] && ! command -v sudo >/dev/null 2>&1; then
  echo "No 'sudo' found — switching to userspace (--no-sudo) mode."
  NO_SUDO=1
fi
[ "$NO_SUDO" -eq 1 ] && echo "Running in --no-sudo (userspace) mode."

# Make fish the interactive shell without chsh/root: append a guard to the
# login rc files that exec's fish for interactive sessions once it's on PATH.
# Skips ~/.zshrc on purpose (that's our tracked fallback config). Idempotent.
add_fish_exec_guard() {
  local marker="__DOTFILES_FISH_LAUNCHED" block rc
  block="$(cat <<'EOS'

# >>> dotfiles: launch fish for interactive shells (no chsh needed) >>>
if [ -z "${__DOTFILES_FISH_LAUNCHED:-}" ]; then
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  case "$-" in
    *i*)
      if [ -z "${FISH_VERSION:-}" ] && command -v fish >/dev/null 2>&1; then
        export __DOTFILES_FISH_LAUNCHED=1
        exec fish
      fi
      ;;
  esac
fi
# <<< dotfiles: launch fish for interactive shells <<<
EOS
)"
  _append_guard() {  # $1 = rc file
    if grep -q "$marker" "$1" 2>/dev/null; then
      echo "  fish exec guard already in $(basename "$1")"
    else
      printf '%s\n' "$block" >> "$1"
      echo "  added fish exec guard to $(basename "$1")"
    fi
  }
  # .bashrc: interactive non-login bash. .profile: POSIX login fallback.
  for rc in "$HOME/.bashrc" "$HOME/.profile"; do
    [ -e "$rc" ] || touch "$rc"
    _append_guard "$rc"
  done
  # A bash login shell reads .bash_profile INSTEAD of .profile/.bashrc when it
  # exists — so the guard MUST go there too, or SSH logins never reach fish.
  # (Don't create it when absent: that would shadow .profile.)
  [ -e "$HOME/.bash_profile" ] && _append_guard "$HOME/.bash_profile"
}

# get system info from utils/system_info.sh and assign to variables
echo "Getting system info..."
# Ensure these scripts are executed with bash for proper syntax support
if ! OS=$(bash ~/.dotfiles/utils/system_info.sh | awk '{print $1}'); then
  echo "Error: Could not determine OS from system_info.sh"
  exit 1
fi

if ! ARCH=$(bash ~/.dotfiles/utils/system_info.sh | awk '{print $2}'); then
  echo "Error: Could not determine Architecture from system_info.sh"
  exit 1
fi

echo "Running on $OS $ARCH"

# Run validation checks (this assumes pre-requisites.sh is in the .dotfiles directory)
echo "Running pre-requisite validation checks..."
# Ensure pre-requisites.sh is executed with bash
if ! bash ~/.dotfiles/pre-requisites.sh; then
  echo "Error: Pre-requisite validation failed!"
  exit 1
fi


echo "Installing oh-my-zsh..."
# Install oh-my-zsh only if zsh exists and it isn't already installed. Pass
# RUNZSH=no/CHSH=no --unattended so the installer never tries to switch shells
# (fish is our default; this keeps zsh purely as a fallback).
if command -v zsh >/dev/null 2>&1 && [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
elif ! command -v zsh >/dev/null 2>&1; then
  echo "zsh not found; skipping oh-my-zsh (fish is the default shell anyway)."
fi


# True iff Homebrew is on PATH AND its prefix is writable by us, i.e. `brew
# bundle` can actually symlink the kegs it pours. On many remote hosts Linuxbrew
# is a shared/pre-existing install owned by another user: bottles still pour but
# the link step fails ("<dir> is not writable"), leaving tools half-installed.
# We treat that as unusable and fall back to the userspace stack instead.
brew_prefix_writable() {
  command -v brew >/dev/null 2>&1 || return 1
  local prefix; prefix="$(brew --prefix 2>/dev/null)" || return 1
  [ -n "$prefix" ] || return 1
  # Check the prefix root and the subdirs brew links into. A dir that doesn't
  # exist yet is fine (brew creates it); one that exists but isn't writable is not.
  local d
  for d in "$prefix" "$prefix/bin" "$prefix/lib" "$prefix/etc" "$prefix/opt" \
           "$prefix/Cellar" "$prefix/share" "$prefix/share/man" \
           "$prefix/share/zsh/site-functions" \
           "$prefix/share/fish/vendor_completions.d"; do
    if [ -e "$d" ] && [ ! -w "$d" ]; then return 1; fi
  done
  return 0
}

# Install packages. In --no-sudo mode, skip Homebrew entirely and install the
# CLI stack into userspace (~/.cargo, ~/.local); otherwise use Homebrew.
if [ "$NO_SUDO" -eq 1 ]; then
  echo "Installing CLI stack in userspace (skipping Homebrew)..."
  bash ~/.dotfiles/utils/install-userspace.sh
elif [ "$OS" = "Darwin" ]; then
  echo "Running on macOS. Installing brew packages and casks from Brewfile..."
  # Check for Homebrew installation on macOS
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add Homebrew to PATH for the current session (will be permanent after restart)
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  brew bundle --file=~/.dotfiles/homebrew/Brewfile
elif [ "$OS" = "Linux" ]; then
  echo "Running on Linux."

  # Install Homebrew on Linux only if it's entirely absent. If a brew is already
  # present (e.g. a shared Linuxbrew on a remote host), don't touch it — we test
  # its usability below. Installing needs sudo for the build deps; if that isn't
  # available the guard below routes us to the userspace stack instead.
  if ! command -v brew >/dev/null 2>&1 && command -v sudo >/dev/null 2>&1; then
    echo "Homebrew (Linuxbrew) not found. Installing Homebrew..."
    sudo apt update # Ensure apt is up-to-date for dependencies
    sudo apt install build-essential procps curl file git -y # Essential dependencies for Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add Homebrew to PATH for the current session (will be permanent after restart)
    # Adjust path if different, /home/linuxbrew/.linuxbrew is common
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    # Add to shell config for future sessions (e.g., .bashrc or .zshrc)
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.zshrc # Assuming Zsh is preferred
    # Or for bash: echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
  fi

  # Guard: only use brew if its prefix is actually writable by us. Otherwise
  # (shared/non-writable Linuxbrew, or brew never installed above) fall back to
  # the userspace CLI stack, which installs into ~/.cargo + ~/.local and skips
  # anything already on PATH — including apt-provided tools — so it never fights
  # a package the system already has.
  if brew_prefix_writable; then
    echo "Homebrew prefix is writable; installing from Brewfile.linux..."
    # Tolerate partial failures so a single link collision doesn't abort the
    # rest of bootstrap; NO_ENV_HINTS quietens sandbox/hint noise on remotes.
    HOMEBREW_NO_ENV_HINTS=1 brew bundle --file=~/.dotfiles/homebrew/Brewfile.linux \
      || echo "Warning: some brew packages failed to install/link; continuing."
  else
    echo "Homebrew unusable here (missing, or a non-writable shared prefix on this remote)."
    echo "Falling back to the userspace CLI stack (~/.cargo, ~/.local)..."
    bash ~/.dotfiles/utils/install-userspace.sh
  fi

  # Linux GUI applications are not installed here — add them manually via
  # apt/snap/flatpak or a .deb download. Examples:
  # IMPORTANT: Cask applications are macOS-specific.
  # You need to manually add installations for your desired GUI apps on Linux here.
  # Examples using apt, snap, or flatpak:

  # Chrome
  # wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  # sudo dpkg -i google-chrome-stable_current_amd64.deb
  # rm google-chrome-stable_current_amd64.deb

  # VS Code (if not installing via Homebrew or if you prefer snap)
  # sudo snap install code --classic

  # Spotify
  # sudo snap install spotify

  # Slack
  # sudo snap install slack --classic

  # Obsidian (check official installation methods, often AppImage or snap)
  # sudo snap install obsidian --classic

  # Add other Linux GUI application installations as needed
  # Remember to use the appropriate package manager (apt, snap, flatpak)
  # for each application.
else
  echo "Skipping Homebrew installation on unknown OS: $OS."
fi

# Install rust via rustup (userspace). Skip if cargo already exists — the
# --no-sudo path installs it earlier, and re-running is pointless.
if ! command -v cargo >/dev/null 2>&1; then
  echo "Installing rust via rustup"
  curl https://sh.rustup.rs -sSf | sh -s -- -y
fi
# Source the cargo environment for the current session
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Ensure git submodules are present (e.g. the CLAUDE.md global-memory repo).
# No-op if already initialised or if cloned with --recursive.
echo "Initialising git submodules..."
git -C ~/.dotfiles submodule update --init --recursive || \
  echo "Warning: submodule init failed; ~/.claude/CLAUDE.md may be missing."

# symlinks
echo "Creating symlinks..."
# Ensure symlinks.sh is executed with bash
bash ~/.dotfiles/symlinks.sh

# AstroNvim setup (commented out as per your original script's comment)
# If you want to automate AstroNvim setup, uncomment and ensure it aligns with your dotfiles
# mv ~/.config/nvim ~/.config/nvim.bak
# git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim
# rm -rf ~/.config/nvim/.git
# nvim

# Ensure TPM (tmux plugin manager) is present. Clone it if missing — userspace
# git clone, so this works with or without Homebrew/root.
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "Cloning TPM (tmux plugin manager)..."
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm" \
    || echo "Warning: TPM clone failed; tmux plugins won't be installed."
fi

# Install TPM plugins (for tmux)
echo "Installing TPM plugins..."
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  if command -v tmux >/dev/null 2>&1; then
    # install_plugins reads TMUX_PLUGIN_MANAGER_PATH from the tmux *server*,
    # which is only set once a server has sourced the config (the tpm run-hook).
    # So spin up a throwaway session first. We only kill the session we start.
    tmux start-server 2>/dev/null
    tmux new-session -d -s __tpm_install 2>/dev/null || true
    ~/.tmux/plugins/tpm/bin/install_plugins || echo "Warning: TPM plugin install failed."
    tmux kill-session -t __tpm_install 2>/dev/null || true
  else
    echo "Warning: tmux not found. Cannot install TPM plugins without tmux."
  fi
else
  echo "TPM not found at ~/.tmux/plugins/tpm; skipping plugin install."
fi

# Install VS Code Extensions (cross-platform, assumes 'code' command is available)
echo "Installing VS Code extensions..."
if command -v code >/dev/null 2>&1; then
  # Ensure VS Code is installed and in your PATH before this runs.
  # If you install VS Code via snap or deb on Linux, it should be available.
  code --install-extension github.copilot
  code --install-extension github.copilot-chat
  code --install-extension ms-python.debugpy
  code --install-extension ms-python.python
  code --install-extension ms-python.vscode-pylance
  code --install-extension ms-toolsai.jupyter-keymap
  code --install-extension ms-vscode-remote.remote-ssh
  code --install-extension ms-vscode-remote.remote-ssh-edit
  code --install-extension ms-vscode.remote-explorer
else
  echo "Warning: VS Code 'code' command not found. Skipping VS Code extension installation."
  echo "Please install VS Code and ensure 'code' is in your PATH to install extensions."
fi

# fastfetch runs on shell startup via the tracked zsh/.zshrc (symlinked above),
# and its config lives in fastfetch/config.jsonc (symlinked to ~/.config/fastfetch).
# fish and nushell get their configs + starship/atuin wiring from symlinks.sh.

# Nerd Font (needed for the starship prompt glyphs).
# macOS installs it via the Brewfile cask; Linux has no font cask, so fetch it.
if [ "$OS" = "Linux" ]; then
  if ! fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
    echo "Installing JetBrainsMono Nerd Font..."
    mkdir -p ~/.local/share/fonts
    tmp_font_zip="$(mktemp -d)/JetBrainsMono.zip"
    if curl -fsSL -o "$tmp_font_zip" \
        "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"; then
      unzip -o "$tmp_font_zip" -d ~/.local/share/fonts >/dev/null
      fc-cache -f >/dev/null 2>&1 || true
      echo "JetBrainsMono Nerd Font installed. Select it in your terminal's font settings."
    else
      echo "Warning: could not download the Nerd Font. Install one manually for starship glyphs."
    fi
  fi
fi

# Make fish the default interactive shell.
# (zsh config stays in place as a fallback.)
fish_path="$(command -v fish 2>/dev/null)"
if [ "$NO_SUDO" -eq 1 ]; then
  # No root: don't touch /etc/shells or chsh — exec fish from the login rc.
  echo "Setting fish as the interactive shell via rc guard (no chsh/root)..."
  add_fish_exec_guard
elif [ -n "$fish_path" ]; then
  # Register fish/nushell in /etc/shells (needs sudo), then chsh to fish.
  for candidate in fish nu; do
    sh_path="$(command -v "$candidate" 2>/dev/null)"
    if [ -n "$sh_path" ] && ! grep -qxF "$sh_path" /etc/shells 2>/dev/null; then
      echo "Registering $sh_path in /etc/shells (needs sudo)..."
      echo "$sh_path" | sudo tee -a /etc/shells >/dev/null 2>&1 \
        || echo "Warning: couldn't write /etc/shells (need sudo)."
    fi
  done
  if [ "$SHELL" != "$fish_path" ]; then
    echo "Setting fish as the default login shell..."
    if ! chsh -s "$fish_path" 2>/dev/null; then
      # chsh often fails on managed/enterprise hosts even with the right
      # password; fall back to the no-root rc guard so fish still launches.
      echo "Warning: chsh failed (managed host?). Falling back to an rc guard."
      add_fish_exec_guard
    fi
  fi
else
  echo "fish not found; skipping default-shell setup."
fi

echo "All done!"
echo "Please restart your terminal to see the changes."