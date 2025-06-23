#!/bin/bash

# Function to get OS information
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

# Function to get Architecture information
get_arch() {
  local arch_name
  case "$(uname -m)" in
    x86_64)     arch_name="x86_64";;
    arm64)      arch_name="arm64";; # For Apple Silicon Macs
    aarch64)    arch_name="aarch64";; # For ARM-based Linux systems
    i386)       arch_name="i386";;
    i686)       arch_name="i686";;
    *)          arch_name="UNKNOWN"
  esac
  echo "$arch_name"
}

# Output OS and Architecture
echo "$(get_os) $(get_arch)"