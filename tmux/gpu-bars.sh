#!/bin/sh
# Coarse, at-a-glance GPU utilisation for the tmux status bar.
#
# Prints one vertical bar per GPU (height = utilisation, colour = load band)
# followed by aggregate memory use, e.g.  GPU ▁▃▆█ 47% mem
#
# Silent (exit 0, no output) when there is no NVIDIA GPU to report on, so the
# same status-right works on CPU-only login nodes and clusters alike.

command -v nvidia-smi >/dev/null 2>&1 || exit 0

# Don't let a wedged driver leave a query hanging around every status refresh.
if command -v timeout >/dev/null 2>&1; then
    TIMEOUT="timeout 2"
else
    TIMEOUT=""
fi

stats=$($TIMEOUT nvidia-smi \
    --query-gpu=utilization.gpu,memory.used,memory.total \
    --format=csv,noheader,nounits 2>/dev/null) || exit 0
[ -n "$stats" ] || exit 0

printf '%s\n' "$stats" | awk -F'[,[:space:]]+' '
BEGIN {
    # Eighth-blocks, low -> high. Split on space so this stays portable
    # across awk implementations (mawk cannot split on "").
    split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █", bar, " ")
    max_shown = 8
}
{
    util = $1 + 0            # "[N/A]" (e.g. MIG devices) coerces to 0
    n++
    # Headroom on the emptiest single GPU: pooled memory hides imbalance
    # (one full card + three idle ones looks the same as four quarter-full
    # ones), and what actually decides whether a job fits is the largest
    # free block on any one device.
    free = $3 - $2
    if (free > best_free) { best_free = free; best_total = $3 }
    if (n <= max_shown) {
        lvl = int(util * 8 / 100) + 1
        if (lvl > 8) lvl = 8
        if      (util < 20) c = "#a6e3a1"   # green   - idle / free
        else if (util < 60) c = "#f9e2af"   # yellow  - moderate
        else if (util < 90) c = "#fab387"   # peach   - busy
        else                c = "#f38ba8"   # red     - saturated
        bars = bars sprintf("#[fg=%s]%s", c, bar[lvl])
    }
}
END {
    if (n == 0) exit 0
    extra = (n > max_shown) ? sprintf("+%d", n - max_shown) : ""
    # Floor the GiB figure -- it is a "will my job fit" number, so round down.
    gib = int(best_free / 1024)
    frac = (best_total > 0) ? best_free / best_total : 0
    if      (frac >= 0.5)  c = "#a6e3a1"   # green - plenty of room
    else if (frac >= 0.25) c = "#f9e2af"   # yellow - tight
    else                   c = "#f38ba8"   # red - effectively full
    printf "GPU %s#[default]%s #[fg=%s]%dG free#[default] |", bars, extra, c, gib
}
'
