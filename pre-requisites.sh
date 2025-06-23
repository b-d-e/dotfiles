#!/bin/bash

# Function to get OS information (copied from system_info.sh for self-containment if needed)
get_os() {
  local os_name
  case "$(uname -s)" in
    Linux*)     os_name="Linux";;
    Darwin*)    os_name="Darwin";;
    CYGWIN*)    os_name="Cygwin";;
    MINGW*)     os_name="MinGw";;
    *)          os_name="UNKNOWN"
  esac
  echo "$os_name"
}

# Function to check GitHub credentials
check_github_creds() {
  echo "Checking GitHub credentials..."
  # Run the SSH command to test the connection
  response=$(ssh -T git@github.com 2>&1)

  # Check if the response indicates successful authentication
  # We use a case-insensitive match for flexibility
  if echo "$response" | grep -iq "You've successfully authenticated"; then
    echo "GitHub credentials are valid."
  else
    echo "Error: GitHub credentials invalid or SSH connection failed."
    echo "Response from GitHub: $response"
    exit 1
  fi
}

# Function to check if Homebrew is installed (only on macOS)
check_homebrew() {
  local os=$(get_os)
  if [ "$os" = "Darwin" ]; then
    echo "Checking for Homebrew installation..."
    if command -v brew >/dev/null 2>&1; then
      echo "Homebrew is installed."
    else
      echo "Error: Homebrew is not installed. Please install Homebrew."
      exit 1
    fi
  else
    echo "Skipping Homebrew check on $os."
  fi
}

# Function to check if the shell is Zsh
check_zsh() {
  echo "Checking for Zsh shell..."
  # Using simple string comparison for SHELL variable
  if [[ "$SHELL" == *"/zsh"* ]]; then
    echo "Zsh shell is being used."
  else
    echo "Error: This script requires Zsh shell. Please switch to Zsh and try again."
    exit 1
  fi
}

# Function to check all pre-requisites before proceeding
validate_pre_requisites() {
  echo "Running pre-requisite validation checks..."

  # Check GitHub credentials
  check_github_creds

  # Check if Homebrew is installed (conditional on OS)
  check_homebrew

  # Check if the shell is Zsh
  check_zsh

  echo "All pre-requisites validated successfully."
}

# Run validation
validate_pre_requisites