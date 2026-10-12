#!/usr/bin/env bash
# RAM and zram swap usage for waybar (JSON output)

ICON_RAM="󰍛"
WARN=80
CRIT=90
ZRAM="/sys/block/zram0"

# Below this much stored data, zram's own overhead is larger than the data
# itself and the compression ratio means nothing
ZRAM_MIN=$(( 1024 * 1024 ))

# Bytes to a short human-readable size (e.g. 1.2G) into the variable named
# by $1. Pure bash arithmetic; the decimal is truncated, not rounded
human() {
    local -a units=(B K M G T)
    local -i tenths i=0

    if (( $2 < 1024 )); then
        printf -v "$1" '%dB' "$2"
        return
    fi

    tenths=$(( $2 * 10 ))
    while (( tenths >= 10240 && i < 4 )); do
        tenths=$(( tenths / 1024 ))
        i=$(( i + 1 ))
    done
    printf -v "$1" '%d.%d%s' $(( tenths / 10 )) $(( tenths % 10 )) "${units[i]}"
}

# RAM from /proc/meminfo, in kB
total=0
avail=0
while read -r key value _; do
    case "$key" in
        MemTotal:)     total=$value ;;
        MemAvailable:) avail=$value ;;
    esac
done < /proc/meminfo

# Only digits may reach the arithmetic below, and total must not be zero
if ! [[ "$total" =~ ^[0-9]+$ && "$avail" =~ ^[0-9]+$ ]] || (( total == 0 )); then
    printf '{"text":"%s n/a","tooltip":"Memory info not available","class":"unknown"}\n' "$ICON_RAM"
    exit 0
fi

total=$(( total * 1024 ))
avail=$(( avail * 1024 ))
used=$(( total - avail ))
ram_pct=$(( used * 100 / total ))

# zram: original data, real memory used and device size (bytes)
orig=0
mem_used=0
disksize=0
if [[ -r "$ZRAM/mm_stat" ]]; then
    read -r orig _ mem_used _ < "$ZRAM/mm_stat"
    { read -r disksize < "$ZRAM/disksize"; } 2>/dev/null
fi
[[ "$orig" =~ ^[0-9]+$ ]] || orig=0
[[ "$mem_used" =~ ^[0-9]+$ ]] || mem_used=0
[[ "$disksize" =~ ^[0-9]+$ ]] || disksize=0

text="$ICON_RAM ${ram_pct}%"

if (( ram_pct >= CRIT )); then
    class="critical"
elif (( ram_pct >= WARN )); then
    class="warning"
else
    class="normal"
fi

# Filled in by human()
used_h="" total_h="" orig_h="" disk_h="" real_h=""

human used_h "$used"
human total_h "$total"
tooltip="RAM: $used_h / $total_h (${ram_pct}%)"

if (( disksize > 0 )); then
    human orig_h "$orig"
    human disk_h "$disksize"
    tooltip+="\\nZram: $orig_h / $disk_h"

    if (( orig >= ZRAM_MIN && mem_used > 0 )); then
        # Compression ratio with one decimal, in integer tenths
        ratio=$(( orig * 10 / mem_used ))
        human real_h "$mem_used"
        tooltip+="\\nReal size: $real_h ($(( ratio / 10 )).$(( ratio % 10 ))x)"
    fi
fi

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$class"
