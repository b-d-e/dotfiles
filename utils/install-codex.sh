#!/bin/sh
# Install (or update) the OpenAI Codex CLI from the official standalone
# installer: https://chatgpt.com/codex/install.sh
#
# Userspace only — no root, no package manager — so this works in --no-sudo
# mode and on managed hosts just as well as on a normal Mac.
#
# Install dir: ~/.local/bin (override with CODEX_INSTALL_DIR). Every shell we
# configure already puts that on PATH (zsh/.zshenv, fish/config.fish,
# nushell/env.nu), so no shell config needs touching. We export it into PATH
# *before* running the installer on purpose: seeing the dir already on PATH,
# the installer skips its own PATH setup instead of appending an
# `export PATH=...` block to ~/.zshrc — which is a symlink into this repo, so
# the write would dirty the tree and silently stop utils/sync.sh.
#
# CODEX_NON_INTERACTIVE=1 declines the installer's prompts ("Start Codex now?",
# and, where another codex is already installed, "Uninstall the existing
# brew/npm-managed Codex?"), so bootstrap never blocks on a question. A
# pre-existing brew/npm codex is left alone; PATH order then decides which runs
# (~/.local/bin wins in our configs). Remove it yourself if you want one copy.
#
# Skip entirely with DOTFILES_SKIP_CODEX=1. Never fatal: a failure here warns
# and returns 0 so bootstrap carries on.
set -u

INSTALLER_URL="https://chatgpt.com/codex/install.sh"

if [ "${DOTFILES_SKIP_CODEX:-0}" = "1" ]; then
  echo "DOTFILES_SKIP_CODEX=1 — skipping the Codex CLI."
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Warning: curl not found; skipping the Codex CLI install." >&2
  exit 0
fi

CODEX_INSTALL_DIR="${CODEX_INSTALL_DIR:-$HOME/.local/bin}"
mkdir -p "$CODEX_INSTALL_DIR" || {
  echo "Warning: cannot create $CODEX_INSTALL_DIR; skipping the Codex CLI." >&2
  exit 0
}
# Keep the pre-install PATH so we can spot an *other* codex further down.
PATH_BEFORE="$PATH"
PATH="$CODEX_INSTALL_DIR:$PATH"
CODEX_NON_INTERACTIVE=1
export PATH CODEX_INSTALL_DIR CODEX_NON_INTERACTIVE

# Fetch to a file rather than `curl | sh`, so a failed download is reported as
# a download failure instead of silently feeding an empty script to sh.
tmp_installer="$(mktemp "${TMPDIR:-/tmp}/codex-install.XXXXXX")" || exit 0
trap 'rm -f "$tmp_installer"' EXIT INT TERM

if ! curl -fsSL "$INSTALLER_URL" -o "$tmp_installer"; then
  echo "Warning: could not download $INSTALLER_URL; skipping the Codex CLI." >&2
  exit 0
fi

if ! sh "$tmp_installer"; then
  echo "Warning: the Codex installer failed; continuing without the Codex CLI." >&2
  exit 0
fi

# Verify rather than trust the exit code: confirm the binary is there and runs.
codex_bin="$CODEX_INSTALL_DIR/codex"
if [ -x "$codex_bin" ] && codex_version="$("$codex_bin" --version 2>/dev/null)"; then
  echo "Codex CLI ready: $codex_version ($codex_bin)"
else
  echo "Warning: no working codex at $codex_bin after install." >&2
  exit 0
fi

# Sign-in is an interactive browser flow and the token is machine-local, so it
# can't be scripted or tracked here — just point at it when it's missing.
if [ ! -f "${CODEX_HOME:-$HOME/.codex}/auth.json" ]; then
  echo "  Not signed in yet — run 'codex login' once (opens a browser)."
fi

# Flag a second, differently-managed codex: whichever comes first on PATH wins,
# which makes version skew confusing.
other_codex="$(PATH="$PATH_BEFORE" command -v codex 2>/dev/null || true)"
if [ -n "$other_codex" ] && [ "$other_codex" != "$codex_bin" ]; then
  echo "  Note: another codex is also installed at $other_codex (PATH order decides which runs)."
fi
