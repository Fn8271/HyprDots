#!/usr/bin/env bash
# Scrolling media info for waybar (JSON output, event-driven via playerctl)
# Usage: media.sh [play-pause|next|previous]
#   Without arguments, follows the players and prints the module.
#   With an action, controls the player currently shown in the bar.

MAX=30          # visible characters
DELAY=0.3       # seconds per scroll step
GAP="   "       # space between the end and the start when looping
STATE="${XDG_RUNTIME_DIR:-/tmp}/waybar-media-player"

ICON_PLAYING=""
ICON_PAUSED="󰏥"

# Count and slice by characters, not bytes, however waybar was started.
# C.UTF-8 is built into glibc, so it is always available
export LC_ALL=C.UTF-8

# Clicks act on the player shown in the bar; fall back to playerctl's
# default player if that one is gone
case "$1" in
    play-pause|next|previous)
        instance=""
        { read -r instance < "$STATE"; } 2>/dev/null
        if [[ -n "$instance" ]]; then
            playerctl -p "$instance" "$1" 2>/dev/null || playerctl "$1"
        else
            playerctl "$1"
        fi
        exit
        ;;
esac

# Field separator: ASCII "unit separator". Unlike a tab, it is not
# whitespace, so read keeps empty fields (e.g. a missing artist)
US=$'\x1f'
FORMAT="{{status}}${US}{{playerName}}${US}{{playerInstance}}${US}{{title}}${US}{{artist}}${US}{{album}}"

# Escape text for Pango markup, then for a JSON string, into the variable
# named by $1. Newlines become \n; other control characters, which are not
# allowed in JSON strings, are removed
escape_to() {
    local s=${2//&/&amp;}
    s=${s//</&lt;}
    s=${s//>/&gt;}
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    s=${s//$'\n'/\\n}
    s=${s//[[:cntrl:]]/}
    printf -v "$1" '%s' "$s"
}

# Parse one line of player metadata. The tooltip only changes with the
# track, so it is built and escaped here, once per event
parse() {
    local tip
    IFS=$US read -r status player instance title artist album <<<"$1"

    full=$title
    [[ -n "$artist" ]] && full+=" - $artist"
    offset=0

    tip=$title
    [[ -n "$artist" ]] && tip+=$'\n'"$artist"
    [[ -n "$album" ]] && tip+=$'\n'"$album"
    tip+=$'\n\n'"Player: $player"
    escape_to tooltip "$tip"

    # Remember which player is shown, so clicks act on it
    [[ -n "$instance" ]] && printf '%s\n' "$instance" > "$STATE"
}

# Player events in the main shell, so they die with the script
exec 3< <(playerctl --follow metadata --format "$FORMAT" 2>/dev/null)
sub_pid=$!

trap 'kill "$sub_pid" 2>/dev/null' EXIT
trap 'exit 0' TERM INT HUP

status="" player="" instance="" title="" artist="" album=""
full="" tooltip="" text="" out=""
offset=0
last=""

# Initial state, before any event arrives
parse "$(playerctl metadata --format "$FORMAT" 2>/dev/null)"

while true; do
    # Wait for a player event, but never longer than one scroll step
    if read -r -t "$DELAY" line <&3; then
        parse "$line"
        # Browsers send empty events now and then: ask for the real state
        [[ -z "$title" ]] && parse "$(playerctl metadata --format "$FORMAT" 2>/dev/null)"
    elif (( $? <= 128 )); then
        exit 0   # event stream closed; waybar restarts the script
    fi

    # No player: empty text hides the module
    if [[ -z "$title" ]]; then
        out='{"text":""}'
    else
        # Scroll only long titles, and only while playing
        if (( ${#full} > MAX )); then
            loop="$full$GAP"
            shown="$loop$loop"
            shown=${shown:offset:MAX}
            [[ "$status" == "Playing" ]] && offset=$(( (offset + 1) % ${#loop} ))
        else
            shown=$full
        fi

        if [[ "$status" == "Playing" ]]; then
            icon=$ICON_PLAYING
            class="playing"
        else
            icon=$ICON_PAUSED
            class="paused"
        fi

        escape_to text "$icon  $shown"
        printf -v out '{"text":"%s","tooltip":"%s","class":"%s"}' "$text" "$tooltip" "$class"
    fi

    # Only print when something changed
    if [[ "$out" != "$last" ]]; then
        printf '%s\n' "$out" || exit 0
        last=$out
    fi
done
