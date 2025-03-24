#!/bin/bash

echo "Setting up new machine..."

# get system info from utils/system_info.sh and assign to variables
OS=$(sh ~/.dotfiles/utils/system_info.sh | awk '{print $1}')
ARCH=$(sh ~/.dotfiles/utils/system_info.sh | awk '{print $2}')

echo "Running on $OS $ARCH"

# Run validation checks (this assumes validate.sh is in the same directory)
echo "Running pre-requisite validation checks..."
sh ~/.dotfiles/pre-requisites.sh

echo "Installing brew packages"
brew bundle --file=~/.dotfiles/homebrew/Brewfile

echo "Installing rust via rustup"
curl https://sh.rustup.rs -sSf | sh -s -- -y
. "$HOME/.cargo/env"

# symlinks
sh ~/.dotfiles/symlinks.sh

# astro nvim - shouldn't need, the dotfiles should cache it all?
# mv ~/.config/nvim ~/.config/nvim.bak
# git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim
# rm -rf ~/.config/nvim/.git
# nvim
