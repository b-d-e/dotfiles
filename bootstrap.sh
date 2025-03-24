#!/bin/bash

echo "Setting up new machine..."

# Run validation checks (this assumes validate.sh is in the same directory)
echo "Running pre-requisite validation checks..."
sh pre-requisites.sh

echo "Installing brew packages"
brew bundle

echo "Installing rust via rustup"
curl https://sh.rustup.rs -sSf | sh -s -- -y
. "$HOME/.cargo/env"