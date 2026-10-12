#!/usr/bin/env bash
# Night light toggle and status for waybar (hyprsunset)
# Usage: nightlight.sh [toggle]  (without arguments, prints the status)

ICON_ON="󱩌"
TEMP=4000
STATE="${XDG_RUNTIME_DIR:-/tmp}/nightlight"

log() {
    echo "nightlight: $1" >&2
}

# PID of the running hyprsunset, empty if it is not running
sunset_pid() {
    pgrep -x hyprsunset | head -n 1
}

# The state file holds the PID of the hyprsunset instance that got the warm
# temperature. A restarted hyprsunset starts neutral again, so a state file
# from another instance means the night light is actually off
is_on() {
    local saved current
    [[ -f "$STATE" ]] || return 1

    read -r saved < "$STATE"
    current=$(sunset_pid)

    if [[ -n "$current" && "$saved" == "$current" ]]; then
        return 0
    fi

    rm -f "$STATE"
    return 1
}

status() {
    if is_on; then
        printf '{"text":"%s","tooltip":"Night Light: On (%sK)","class":"on"}\n' "$ICON_ON" "$TEMP"
    else
        printf '{"text":"","tooltip":"Night Light: Off","class":"off"}\n'
    fi
}

toggle() {
    local pid
    pid=$(sunset_pid)

    if [[ -z "$pid" ]]; then
        log "hyprsunset is not running"
        exit 1
    fi

    if is_on; then
        hyprctl hyprsunset identity >/dev/null
        rm -f "$STATE"
    else
        hyprctl hyprsunset temperature "$TEMP" >/dev/null
        printf '%s\n' "$pid" > "$STATE"
    fi

    # Refresh the waybar indicator right away (fine if waybar is not running)
    pkill -RTMIN+9 waybar || true
}

case "$1" in
    toggle) toggle ;;
    *)      status ;;
esac
