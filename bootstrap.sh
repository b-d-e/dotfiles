#!/bin/bash

echo "Setting up new machine..."

# get system info from utils/system_info.sh and assign to variables
echo "Getting system info..."
if ! OS=$(sh ~/.dotfiles/utils/system_info.sh | awk '{print $1}'); then
  exit 1
fi

if ! ARCH=$(sh ~/.dotfiles/utils/system_info.sh | awk '{print $2}'); then
  exit 1
fi

echo "Running on $OS $ARCH"

# Run validation checks (this assumes validate.sh is in the same directory)
echo "Running pre-requisite validation checks..."
if ! sh ~/.dotfiles/pre-requisites.sh; then
  echo "Error: Pre-requisite validation failed!"
  exit 1
fi


echo "Installing brew packages"
brew bundle --file=~/.dotfiles/homebrew/Brewfile

echo "Installing rust via rustup"
curl https://sh.rustup.rs -sSf | sh -s -- -y
. "$HOME/.cargo/env"

# symlinks
echo "Creating symlinks..."
sh ~/.dotfiles/symlinks.sh

# astro nvim - shouldn't need, the dotfiles should cache it all?
# mv ~/.config/nvim ~/.config/nvim.bak
# git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim
# rm -rf ~/.config/nvim/.git
# nvim

# Install TPM plugins
echo "Installing TPM plugins..."
~/.tmux/plugins/tpm/bin/install_plugins

echo "All done!"
echo "Please restart your terminal to see the changes."