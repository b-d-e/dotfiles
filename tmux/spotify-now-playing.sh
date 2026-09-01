#!/usr/bin/env bash
# Print "<icon> <artist>: <track>" only while Spotify is actively playing;
# print nothing when paused/stopped/not running. Replaces the plugin's
# always-on #{music_status} #{artist}: #{track} so the status bar stays clean
# when nothing is playing. One osascript call (vs the plugin's three) keeps the
# per-refresh cost low.
# macOS-only (AppleScript). On Linux / anywhere without osascript this is a
# quiet no-op so it never breaks the status bar. (On a remote SSH box the
# status-right is overridden entirely, so this isn't invoked there anyway.)
command -v osascript >/dev/null 2>&1 || exit 0

app="${MUSIC_APP:-Spotify}"
icon="$(tmux show-option -gqv @spotify_playing_icon)"
icon="${icon:-♫}"

IFS=$'\t' read -r state artist track < <(osascript <<END 2>/dev/null
if application "$app" is running then
  tell application "$app"
    if player state is playing then
      return (player state as string) & "\t" & (artist of current track) & "\t" & (name of current track)
    end if
  end tell
end if
END
)

[ "$state" = "playing" ] && printf '%s %s: %s' "$icon" "$artist" "$track"
