system_info() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
  elif [[ "$OSTYPE" == "cygwin"* || "$OSTYPE" == "msys"* || "$OSTYPE" == "win32"* || "$OSTYPE" == "windows"* ]]; then
    echo "Panic: Windows is not supported!"
    exit 1
  else
    echo "Unknown OS: $OSTYPE"
    exit 1
  fi

  if [[ $(uname -m) == "arm64" ]]; then
    ARCH="arm"
  else
    ARCH="x86"
  fi

  echo "$OS $ARCH"
}

system_info 
