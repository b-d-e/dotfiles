#!/bin/bash

# Function to check GitHub credentials
check_github_creds() {
  # Run the SSH command to test the connection
  response=$(ssh -T git@github.com 2>&1)

  # Check if the response contains "b-d-e"
  if [[ ! "$response" =~ "b-d-e" ]]; then
    echo "Invalid GitHub response. Aborting."
    exit 1
  fi
  echo "GitHub credentials are valid."
}

# Function to check if Homebrew is installed
check_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    echo "Homebrew is installed."
  else
    echo "Homebrew is not installed. Please install Homebrew."
    exit 1
  fi
}

# Function to check if the shell is Zsh
check_zsh() {
  if [[ "$SHELL" == "/bin/zsh" || "$SHELL" == "/usr/bin/zsh" || "$SHELL" == *"zsh"* ]]; then
    echo "Zsh shell is being used."
  else
    echo "This script requires Zsh shell. Please switch to Zsh and try again."
    exit 1
  fi
}

# Function to check all pre-requisites before proceeding
validate_pre_requisites() {
  # Check GitHub credentials
  check_github_creds

  # Check if Homebrew is installed
  check_homebrew

  # Check if the shell is Zsh
  check_zsh

  echo "All pre-requisites validated successfully."
}

# Run validation
validate_pre_requisites