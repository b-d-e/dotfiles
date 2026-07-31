#!/usr/bin/env bash
# Install the CLI stack into ~/.cargo and ~/.local WITHOUT root. Driven by
# `bootstrap.sh --no-sudo`, but safe to run standalone. Idempotent and
# best-effort: every tool warns and continues on failure, and skips if the
# binary is already on PATH.
#
# Coverage:
#   - Rust tools via `cargo install`  : starship eza bat ripgrep fd zoxide atuin nushell
#   - prebuilt tarballs -> ~/.local   : neovim, fastfetch
#   - fish + tmux                     : detect-or-instruct (no clean no-root binary)
set -u

LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"
os="$(uname -s)"
arch="$(uname -m)"

echo "== userspace CLI install ($os/$arch) =="

# --- ensure cargo (userspace rustup) ---
if ! command -v cargo >/dev/null 2>&1; then
  echo "Installing rustup (userspace)..."
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path \
    || { echo "Error: rustup install failed; cannot build the Rust tools."; }
fi
# shellcheck disable=SC1091
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# --- Rust CLI tools (compiled from source; no root needed) ---
# crate -> installed binary name (differs for fd-find/ripgrep/nu)
if command -v cargo >/dev/null 2>&1; then
  echo "-- cargo install (this compiles from source; first run is slow) --"
  for crate in starship eza bat ripgrep fd-find zoxide atuin nu; do
    case "$crate" in
      fd-find) bin=fd ;;
      ripgrep) bin=rg ;;
      *)       bin="$crate" ;;
    esac
    if command -v "$bin" >/dev/null 2>&1; then
      echo "  $bin already present, skipping"
    else
      echo "  cargo install --locked $crate"
      cargo install --locked "$crate" || echo "  Warning: cargo install $crate failed."
    fi
  done
else
  echo "Warning: cargo unavailable; skipping the Rust CLI tools."
fi

# --- neovim (prebuilt tarball; keeps its runtime dir, symlink the binary) ---
install_neovim() {
  command -v nvim >/dev/null 2>&1 && { echo "  nvim already present, skipping"; return; }
  local asset
  case "$os/$arch" in
    Linux/x86_64)              asset="nvim-linux-x86_64.tar.gz" ;;
    Linux/aarch64|Linux/arm64) asset="nvim-linux-arm64.tar.gz" ;;
    Darwin/arm64)              asset="nvim-macos-arm64.tar.gz" ;;
    Darwin/x86_64)             asset="nvim-macos-x86_64.tar.gz" ;;
    *) echo "  Warning: no neovim prebuilt for $os/$arch"; return ;;
  esac
  local tmp; tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/$asset" -o "$tmp/nvim.tgz"; then
    rm -rf "$HOME/.local/nvim"; mkdir -p "$HOME/.local/nvim"
    if tar -xzf "$tmp/nvim.tgz" -C "$HOME/.local/nvim" --strip-components=1; then
      ln -sf "$HOME/.local/nvim/bin/nvim" "$LOCAL_BIN/nvim"
      echo "  neovim -> $LOCAL_BIN/nvim"
    else
      echo "  Warning: neovim extract failed."
    fi
  else
    echo "  Warning: neovim download failed."
  fi
  rm -rf "$tmp"
}

# --- fastfetch (prebuilt; the binary is self-contained) ---
install_fastfetch() {
  command -v fastfetch >/dev/null 2>&1 && { echo "  fastfetch already present, skipping"; return; }
  local asset
  case "$os/$arch" in
    Linux/x86_64)              asset="fastfetch-linux-amd64.tar.gz" ;;
    Linux/aarch64|Linux/arm64) asset="fastfetch-linux-aarch64.tar.gz" ;;
    Darwin/*) echo "  (macOS: install fastfetch via Homebrew)"; return ;;
    *) echo "  Warning: no fastfetch prebuilt for $os/$arch"; return ;;
  esac
  local tmp; tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/$asset" -o "$tmp/ff.tgz" \
     && tar -xzf "$tmp/ff.tgz" -C "$tmp"; then
    local bin; bin="$(find "$tmp" -type f -name fastfetch | head -1)"
    if [ -n "$bin" ]; then
      chmod +x "$bin"; cp "$bin" "$LOCAL_BIN/fastfetch"
      echo "  fastfetch -> $LOCAL_BIN/fastfetch"
    else
      echo "  Warning: fastfetch binary not found in archive."
    fi
  else
    echo "  Warning: fastfetch download failed."
  fi
  rm -rf "$tmp"
}

echo "-- prebuilt binaries -> ~/.local --"
install_neovim
install_fastfetch

# --- fish + tmux: no reliable no-root binary; use conda-forge when available ---
# fish v4 is Rust but is not published to crates.io as the shell, and there is
# no official prebuilt tarball. conda-forge is the cleanest no-root source, so
# install from there automatically if conda is present; otherwise instruct.
# The exec-fish guard (added by bootstrap.sh) activates once fish is on PATH.
echo "-- fish + tmux --"
missing=""
for tool in fish tmux; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  $tool already present ($(command -v "$tool"))"
  else
    missing="$missing $tool"
  fi
done
if [ -n "$missing" ]; then
  if command -v conda >/dev/null 2>&1; then
    echo "  installing via conda-forge into the active env:$missing"
    # shellcheck disable=SC2086
    conda install -y -c conda-forge $missing \
      || echo "  Warning: conda install failed for:$missing"
  else
    echo "  NOTE: no conda found. Install$missing via one of:"
    echo "        - conda:  conda install -c conda-forge$missing"
    echo "        - module: module load <tool>   (on HPC clusters)"
    echo "        - source build into ~/.local"
  fi
fi

echo "== done. Ensure ~/.local/bin and ~/.cargo/bin are on PATH =="
echo "   (fish/config.fish and the bootstrap exec-guard add both automatically)"
