#!/bin/bash

echo "Setting up new machine..."

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
# Install oh-my-zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  # Install oh-my-zsh using the official installer script
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi


# Install Homebrew and packages based on OS
if [ "$OS" = "Darwin" ]; then
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
  echo "Running on Linux. Installing brew packages from Brewfile.linux..."

  # Install Homebrew on Linux if not already installed
  if ! command -v brew >/dev/null 2>&1; then
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
  brew bundle --file=~/.dotfiles/homebrew/Brewfile.linux

  echo "Installing Linux-specific GUI applications and other tools..."
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

echo "Installing rust via rustup"
# The rustup installer handles different OSes correctly
curl https://sh.rustup.rs -sSf | sh -s -- -y
# Source the cargo environment for the current session
. "$HOME/.cargo/env"

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

# Install TPM plugins (for tmux)
echo "Installing TPM plugins..."
# Check if TPM is cloned before trying to install plugins
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  # Ensure tmux is installed before running tpm, though brew should handle it
  if command -v tmux >/dev/null 2>&1; then
    ~/.tmux/plugins/tpm/bin/install_plugins
  else
    echo "Warning: tmux not found. Cannot install TPM plugins without tmux."
  fi
else
  echo "TPM not found. Please ensure TPM is cloned to ~/.tmux/plugins/tpm (e.g., via a symlink from your dotfiles) before running this script if you want TPM plugins installed."
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

# Register fish and nushell as valid login shells, then make fish the default.
# (zsh config stays in place as a fallback: `chsh -s "$(command -v zsh)"`.)
for candidate in fish nu; do
  sh_path="$(command -v "$candidate" 2>/dev/null)"
  if [ -n "$sh_path" ] && ! grep -qxF "$sh_path" /etc/shells 2>/dev/null; then
    echo "Registering $sh_path in /etc/shells (needs sudo)..."
    echo "$sh_path" | sudo tee -a /etc/shells >/dev/null
  fi
done

fish_path="$(command -v fish 2>/dev/null)"
if [ -n "$fish_path" ] && [ "$SHELL" != "$fish_path" ]; then
  echo "Setting fish as the default login shell..."
  chsh -s "$fish_path" || echo "Warning: chsh failed; run 'chsh -s $fish_path' manually."
fi

echo "All done!"
echo "Please restart your terminal to see the changes."