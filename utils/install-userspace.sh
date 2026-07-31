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

# --- fish + tmux: no reliable no-root binary; get them from conda-forge ---
# fish v4 is Rust but is not published to crates.io as the shell, and there is
# no official prebuilt tarball. conda-forge is the cleanest no-root source. We
# reuse an existing conda/mamba/micromamba, else bootstrap micromamba (a single
# static binary, no Python, no shell hook) into ~/.local. The exec-fish guard
# (added by bootstrap.sh) activates once fish is on PATH.

MAMBA_ROOT="${MAMBA_ROOT_PREFIX:-$HOME/.local/micromamba}"

install_micromamba() {
  local mm="$LOCAL_BIN/micromamba" plat
  [ -x "$mm" ] && return 0
  case "$os/$arch" in
    Linux/x86_64)              plat="linux-64" ;;
    Linux/aarch64|Linux/arm64) plat="linux-aarch64" ;;
    Darwin/arm64)              plat="osx-arm64" ;;
    Darwin/x86_64)             plat="osx-64" ;;
    *) echo "  Warning: no micromamba build for $os/$arch"; return 1 ;;
  esac
  echo "  installing micromamba ($plat) into ~/.local/bin ..."
  if curl -Ls "https://micro.mamba.pm/api/micromamba/$plat/latest" \
       | tar -xj -C "$HOME/.local" bin/micromamba 2>/dev/null; then
    chmod +x "$mm"; return 0
  fi
  echo "  Warning: micromamba download failed."; return 1
}

# Echo the name of a usable conda-family tool, installing micromamba if needed.
resolve_conda_tool() {
  local c
  for c in conda mamba micromamba; do
    command -v "$c" >/dev/null 2>&1 && { echo "$c"; return 0; }
  done
  install_micromamba && { echo "$LOCAL_BIN/micromamba"; return 0; }
  return 1
}

print_manual_conda_steps() {
  local plat="linux-64|linux-aarch64|osx-arm64|osx-64"
  echo "  Could not obtain conda/mamba/micromamba automatically. To finish by hand (no root):"
  echo "    1) curl -Ls https://micro.mamba.pm/api/micromamba/<$plat>/latest | tar -xj -C ~/.local bin/micromamba"
  echo "    2) ~/.local/bin/micromamba create -y -p ~/.local/micromamba -c conda-forge$1"
  echo "    3) ln -sf ~/.local/micromamba/bin/{${1// /,}} ~/.local/bin/"
  echo "    (or with an existing conda:  conda install -c conda-forge$1 )"
}

echo "-- fish + tmux (via conda-forge) --"
missing=""
for tool in fish tmux; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  $tool already present ($(command -v "$tool"))"
  else
    missing="$missing $tool"
  fi
done

if [ -n "$missing" ]; then
  conda_tool="$(resolve_conda_tool)"
  if [ -n "$conda_tool" ]; then
    echo "  installing via $(basename "$conda_tool") (conda-forge):$missing"
    case "$(basename "$conda_tool")" in
      micromamba)
        # Self-contained prefix + symlink the binaries onto PATH (no activation,
        # no rc hook). fish/tmux resolve their data + libs via the prefix.
        # Use `create` for a fresh prefix, `install` if one already exists.
        mm_cmd=create; [ -d "$MAMBA_ROOT/conda-meta" ] && mm_cmd=install
        # shellcheck disable=SC2086
        if "$conda_tool" "$mm_cmd" -y -p "$MAMBA_ROOT" -c conda-forge $missing; then
          for t in $missing; do
            [ -x "$MAMBA_ROOT/bin/$t" ] && ln -sf "$MAMBA_ROOT/bin/$t" "$LOCAL_BIN/$t" \
              && echo "  $t -> $LOCAL_BIN/$t"
          done
        else
          echo "  Warning: micromamba install failed."; print_manual_conda_steps "$missing"
        fi
        ;;
      *)
        # shellcheck disable=SC2086
        "$conda_tool" install -y -c conda-forge $missing \
          || { echo "  Warning: $conda_tool install failed."; print_manual_conda_steps "$missing"; }
        ;;
    esac
  else
    print_manual_conda_steps "$missing"
  fi
fi

echo "== done. Ensure ~/.local/bin and ~/.cargo/bin are on PATH =="
echo "   (fish/config.fish and the bootstrap exec-guard add both automatically)"
