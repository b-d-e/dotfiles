#!/bin/sh
# Keep dotfiles current on new interactive sessions, cheaply.
#
# Fast-forward-pulls ~/.dotfiles and, ONLY if that moved HEAD, re-runs the
# idempotent symlinks.sh so newly-tracked files get linked. It deliberately
# does NOT run bootstrap.sh / brew / any installer -- nothing is reinstalled,
# links are just refreshed and new shells pick up the changed configs.
#
# Designed to be launched backgrounded/disowned from a shell rc, so it never
# blocks or hangs the prompt. Safe guards:
#   * skipped entirely if the working tree is dirty (won't clobber your WIP);
#   * --ff-only, so it never creates merge commits or rewrites anything;
#   * throttled to at most once per $DOTFILES_SYNC_INTERVAL seconds (default
#     600; set 0 to disable) -- new tabs don't each hit the network;
#   * network step time-bounded when a `timeout`/`gtimeout` is available.
#
# Env: DOTFILES (default ~/.dotfiles), DOTFILES_SYNC_INTERVAL (seconds).
set -eu

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
INTERVAL="${DOTFILES_SYNC_INTERVAL:-600}"
[ -d "$DOTFILES/.git" ] || exit 0

stamp="$DOTFILES/.git/.last-sync"
now=$(date +%s 2>/dev/null || echo 0)

# Throttle: bail if we synced recently.
if [ "$INTERVAL" -gt 0 ] && [ -f "$stamp" ]; then
    last=$(cat "$stamp" 2>/dev/null || echo 0)
    [ $((now - last)) -lt "$INTERVAL" ] && exit 0
fi
# Claim this window immediately so concurrent new tabs don't all pull.
echo "$now" > "$stamp" 2>/dev/null || true

cd "$DOTFILES" 2>/dev/null || exit 0

# Never touch a dirty tree -- leave work-in-progress (and un-pushed commits
# that aren't fast-forwardable) alone.
[ -z "$(git status --porcelain 2>/dev/null)" ] || exit 0

# Bound the network call if a timeout helper exists (macOS ships neither by
# default; gtimeout comes with coreutils). Backgrounded anyway, so a missing
# timeout only risks a lingering pull, never a blocked prompt.
if command -v timeout >/dev/null 2>&1; then TO="timeout 20"
elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout 20"
else TO=""; fi

before=$(git rev-parse HEAD 2>/dev/null || echo none)
$TO git pull --ff-only --quiet 2>/dev/null || exit 0
after=$(git rev-parse HEAD 2>/dev/null || echo none)

# Re-link only when something actually changed.
if [ "$before" != "$after" ] && [ -x "$DOTFILES/symlinks.sh" ]; then
    "$DOTFILES/symlinks.sh" >/dev/null 2>&1 || true
fi
