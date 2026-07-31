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

# --- Rust toolchain upgrade (for crates whose MSRV exceeds a pre-existing rustc) ---
# A rustc that's already on PATH can be too old to build a crate ("requires rustc
# 1.NN or newer, while the currently active rustc version is ..."). When that
# happens we upgrade the toolchain and retry, at most once per run:
#   - rustup-managed rustc   -> `rustup update stable`
#   - distro/system rustc    -> install a userspace rustup and prefer it this run
rust_upgrade_state="untried"   # untried | ok | failed

upgrade_rust() {
  if command -v rustup >/dev/null 2>&1; then
    echo "  upgrading Rust toolchain via rustup..."
    rustup update stable && rustup default stable
    return $?
  fi
  echo "  system rustc is not rustup-managed; installing a userspace rustup..."
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path || return 1
  # shellcheck disable=SC1091
  [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
  export PATH="$HOME/.cargo/bin:$PATH"   # prefer the fresh toolchain over the old system one
  command -v rustup >/dev/null 2>&1 && rustup default stable >/dev/null 2>&1
  return 0
}

# Upgrade the toolchain once per run; cache the outcome so later crates that hit
# the same too-old rustc don't each re-attempt (and re-fail) the upgrade.
maybe_upgrade_rust() {
  case "$rust_upgrade_state" in
    ok)     return 0 ;;
    failed) return 1 ;;
  esac
  if upgrade_rust; then rust_upgrade_state="ok"; else rust_upgrade_state="failed"; fi
  [ "$rust_upgrade_state" = "ok" ]
}

# cargo install with an MSRV-aware retry. Streams output live (compiles are slow,
# silence looks like a hang) while teeing it so we can detect a "rustc too old"
# failure, upgrade the toolchain, and retry the build once.
cargo_install_crate() {
  local crate="$1" log status
  log="$(mktemp)"
  cargo install --locked "$crate" 2>&1 | tee "$log"; status=${PIPESTATUS[0]}
  if [ "$status" -ne 0 ] \
     && grep -qiE 'requires rustc|cannot be built because it requires|currently active rustc' "$log"; then
    echo "  $crate needs a newer rustc than is installed; upgrading toolchain and retrying..."
    if maybe_upgrade_rust; then
      cargo install --locked "$crate"; status=$?
    else
      echo "  Could not upgrade the Rust toolchain."
    fi
  fi
  rm -f "$log"
  return "$status"
}

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
      cargo_install_crate "$crate" || echo "  Warning: cargo install $crate failed."
    fi
  done
else
  echo "Warning: cargo unavailable; skipping the Rust CLI tools."
fi

# Packages to fall back to conda-forge for when their prebuilt won't run here
# (e.g. host glibc too old). Filled in by the installers below.
CONDA_QUEUE=""

# --- neovim (prebuilt; runtime-checked, with an older-glibc fallback) ---
# Prebuilts are the primary path — they work on most machines. Only if the
# binary won't run here (older host glibc) do we drop to an older release. The
# newest neovim that runs on glibc 2.31 is v0.10.4. conda-forge is NOT an option
# for nvim (its `neovim` package is the Python client, not the editor).
install_neovim() {
  command -v nvim >/dev/null 2>&1 && { echo "  nvim already present, skipping"; return; }
  local asset asset_old
  case "$os/$arch" in
    Linux/x86_64)              asset="nvim-linux-x86_64.tar.gz"; asset_old="nvim-linux-x86_64.tar.gz" ;;
    Linux/aarch64|Linux/arm64) asset="nvim-linux-arm64.tar.gz";  asset_old="nvim-linux-arm64.tar.gz" ;;
    Darwin/arm64)              asset="nvim-macos-arm64.tar.gz";  asset_old="" ;;
    Darwin/x86_64)             asset="nvim-macos-x86_64.tar.gz"; asset_old="" ;;
    *) echo "  Warning: no neovim prebuilt for $os/$arch"; return ;;
  esac
  # Try (latest) then (v0.10.4, newest that runs on glibc 2.31).
  local spec
  for spec in "latest/download/$asset" "download/v0.10.4/$asset_old"; do
    [ "$spec" = "download/v0.10.4/" ] && continue   # no old asset (macOS)
    local tmp; tmp="$(mktemp -d)"
    if curl -fsSL "https://github.com/neovim/neovim/releases/$spec" -o "$tmp/nvim.tgz" \
       && rm -rf "$HOME/.local/nvim" && mkdir -p "$HOME/.local/nvim" \
       && tar -xzf "$tmp/nvim.tgz" -C "$HOME/.local/nvim" --strip-components=1 \
       && "$HOME/.local/nvim/bin/nvim" --version >/dev/null 2>&1; then
      ln -sf "$HOME/.local/nvim/bin/nvim" "$LOCAL_BIN/nvim"
      echo "  neovim ($(basename "$spec" | sed 's/\.tar\.gz//; s/nvim-//')) -> $LOCAL_BIN/nvim"
      rm -rf "$tmp"; return
    fi
    rm -rf "$tmp"
    echo "  neovim prebuilt ($spec) unavailable or won't run here; trying older..."
  done
  echo "  Warning: no working neovim prebuilt (host glibc too old). Build from source or 'module load'."
}

# --- fastfetch (prebuilt; runtime-checked, conda-forge fallback) ---
install_fastfetch() {
  command -v fastfetch >/dev/null 2>&1 && { echo "  fastfetch already present, skipping"; return; }
  local asset
  case "$os/$arch" in
    Linux/x86_64)              asset="fastfetch-linux-amd64.tar.gz" ;;
    Linux/aarch64|Linux/arm64) asset="fastfetch-linux-aarch64.tar.gz" ;;
    Darwin/*) echo "  (macOS: install fastfetch via Homebrew)"; return ;;
    *) echo "  Warning: no fastfetch prebuilt for $os/$arch"; return ;;
  esac
  local tmp bin; tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/fastfetch-cli/fastfetch/releases/latest/download/$asset" -o "$tmp/ff.tgz" \
     && tar -xzf "$tmp/ff.tgz" -C "$tmp"; then
    bin="$(find "$tmp" -type f -name fastfetch | head -1)"
    if [ -n "$bin" ] && "$bin" --version >/dev/null 2>&1; then
      chmod +x "$bin"; cp "$bin" "$LOCAL_BIN/fastfetch"
      echo "  fastfetch -> $LOCAL_BIN/fastfetch"
      rm -rf "$tmp"; return
    fi
  fi
  rm -rf "$tmp"
  echo "  fastfetch prebuilt unavailable or won't run here; queuing conda-forge fallback."
  CONDA_QUEUE="$CONDA_QUEUE fastfetch"
}

echo "-- prebuilt binaries -> ~/.local (conda-forge only as fallback) --"
install_neovim
install_fastfetch

# --- fish + tmux: no reliable no-root binary; get them from conda-forge ---
# fish v4 is Rust but is not published to crates.io as the shell, and there is
# no official prebuilt tarball. conda-forge is the cleanest no-root source. We
# reuse an existing conda/mamba/micromamba, else bootstrap micromamba (a single
# static binary, no Python, no shell hook) into ~/.local. The exec-fish guard
# (added by bootstrap.sh) activates once fish is on PATH.

MAMBA_ROOT="${MAMBA_ROOT_PREFIX:-$HOME/.local/micromamba}"
TOOLS_ENV="$MAMBA_ROOT/envs/tools"

# NOTE: install_micromamba and resolve_conda_tool run inside $(...) command
# substitution, so their ONLY stdout must be the resolved tool path — every
# human-readable message goes to stderr (>&2), or it pollutes the captured path.
install_micromamba() {
  local mm="$LOCAL_BIN/micromamba" plat
  [ -x "$mm" ] && return 0
  case "$os/$arch" in
    Linux/x86_64)              plat="linux-64" ;;
    Linux/aarch64|Linux/arm64) plat="linux-aarch64" ;;
    Darwin/arm64)              plat="osx-arm64" ;;
    Darwin/x86_64)             plat="osx-64" ;;
    *) echo "  Warning: no micromamba build for $os/$arch" >&2; return 1 ;;
  esac
  echo "  installing micromamba ($plat) into ~/.local/bin ..." >&2
  if curl -Ls "https://micro.mamba.pm/api/micromamba/$plat/latest" \
       | tar -xj -C "$HOME/.local" bin/micromamba; then
    chmod +x "$mm"; return 0
  fi
  echo "  Warning: micromamba download failed." >&2; return 1
}

# Echo the name/path of a usable conda-family tool, installing micromamba if
# needed. Only the tool path reaches stdout; branch on the RETURN CODE.
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
  echo "    2) ~/.local/bin/micromamba create -y -p ~/.local/micromamba/envs/tools -c conda-forge$1"
  echo "    3) for t in$1; do ln -sf ~/.local/micromamba/envs/tools/bin/\$t ~/.local/bin/; done"
  echo "    (or with an existing conda:  conda install -c conda-forge$1 )"
}

# fish + tmux have no clean no-root binary, so they always go through
# conda-forge; fastfetch joins them only if its prebuilt failed (CONDA_QUEUE).
echo "-- fish + tmux (+ any prebuilt fallbacks) via conda-forge --"
for tool in fish tmux; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "  $tool already present ($(command -v "$tool"))"
  else
    CONDA_QUEUE="$CONDA_QUEUE $tool"
  fi
done

if [ -n "$CONDA_QUEUE" ]; then
  echo "  conda-forge packages needed:$CONDA_QUEUE"
  # Branch on resolve_conda_tool's exit status; conda_tool holds only the path.
  if conda_tool="$(resolve_conda_tool)" && [ -n "$conda_tool" ]; then
    echo "  installing via $(basename "$conda_tool"):$CONDA_QUEUE"
    case "$(basename "$conda_tool")" in
      micromamba)
        # Install into a self-contained env prefix, then symlink the binaries
        # onto PATH (no activation, no rc hook). Binaries resolve their data +
        # libs via the prefix through the symlink. `create` fresh, else `install`.
        export MAMBA_ROOT_PREFIX="$MAMBA_ROOT"
        mm_cmd=create; [ -d "$TOOLS_ENV/conda-meta" ] && mm_cmd=install
        # shellcheck disable=SC2086
        if "$conda_tool" "$mm_cmd" -y -p "$TOOLS_ENV" -c conda-forge $CONDA_QUEUE; then
          for t in $CONDA_QUEUE; do
            if [ -x "$TOOLS_ENV/bin/$t" ]; then
              ln -sf "$TOOLS_ENV/bin/$t" "$LOCAL_BIN/$t"; echo "  $t -> $LOCAL_BIN/$t"
            fi
          done
        else
          echo "  Warning: micromamba install failed."; print_manual_conda_steps "$CONDA_QUEUE"
        fi
        ;;
      *)
        # shellcheck disable=SC2086
        "$conda_tool" install -y -c conda-forge $CONDA_QUEUE \
          || { echo "  Warning: install failed."; print_manual_conda_steps "$CONDA_QUEUE"; }
        ;;
    esac
  else
    print_manual_conda_steps "$CONDA_QUEUE"
  fi
fi

echo "== done. Ensure ~/.local/bin and ~/.cargo/bin are on PATH =="
echo "   (fish/config.fish and the bootstrap exec-guard add both automatically)"
