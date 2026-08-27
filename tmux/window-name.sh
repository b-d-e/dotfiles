#!/bin/sh
# automatic-rename-format helper.
#
# Wraps tmux-nerd-font-window-name (which turns a command into "<icon> cmd")
# and, for ssh panes, appends the destination host so the window reads
# "<icon> ssh:<host>" instead of a bare "<icon> ssh". The host is recovered
# live from the running ssh process's args, so it tracks -p, user@, jump
# hosts, etc. Any failure degrades gracefully to the plugin's plain output.
#
# Args (supplied by automatic-rename-format):
#   $1 pane_current_command   $2 window_panes   $3 pane_pid

cmd="$1"; panes="$2"; pane_pid="$3"

plugin="$HOME/.tmux/plugins/tmux-nerd-font-window-name/bin/tmux-nerd-font-window-name"
if [ -x "$plugin" ]; then
    base=$("$plugin" "$cmd" "$panes" 2>/dev/null)   # e.g. "<icon> ssh"
fi
[ -n "$base" ] || base="$cmd"                       # plugin missing -> plain

# Only ssh panes get the host suffix; everything else is the plugin output.
[ "$cmd" = ssh ] || { printf '%s' "$base"; exit 0; }
[ -n "$pane_pid" ] || { printf '%s' "$base"; exit 0; }

# Depth-first search of the process tree under $1 for an ssh process; echoes
# its pid. POSIX sh, no arrays; relies on pgrep (present on macOS and Linux).
find_ssh() {
    for pid in $(pgrep -P "$1" 2>/dev/null); do
        case "$(ps -o comm= -p "$pid" 2>/dev/null)" in
            *ssh) echo "$pid"; return 0 ;;
        esac
        find_ssh "$pid" && return 0
    done
    return 1
}

ssh_pid=$(find_ssh "$pane_pid") || { printf '%s' "$base"; exit 0; }

# Full argv of the ssh process, e.g. "ssh -p 2222 user@box.example".
# shellcheck disable=SC2046  # deliberate word-splitting of argv into "$@"
set -- $(ps -o args= -p "$ssh_pid" 2>/dev/null)
shift 2>/dev/null   # drop the leading "ssh"

# Walk argv, skipping options; the destination is the first non-option token.
# ssh options that take a value: -b -c -D -E -e -F -I -i -J -L -l -m -O -o -p
# -Q -R -S -W -w. When passed detached (exactly "-p", not "-p2222") the value
# is the next token, so skip one extra.
host=
while [ $# -gt 0 ]; do
    case "$1" in
        -[bcDEeFIiJLlmOopQRSWw]) shift 2 2>/dev/null || shift ;;
        -*)                       shift ;;
        *)                        host="$1"; break ;;
    esac
done
host="${host#*@}"   # strip any user@ prefix

[ -n "$host" ] && printf '%s:%s' "$base" "$host" || printf '%s' "$base"
