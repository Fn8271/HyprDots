#!/usr/bin/env bash
# Active TLP profile and charge thresholds for waybar (JSON output)
# The profile comes from tlp-pd (tlpctl); everything else from sysfs

ICON_PERF="󰓅"
ICON_BAL="󰗑"
ICON_SAVE="󰌪"
ICON_UNKNOWN="󰘥"

AC="/sys/class/power_supply/AC/online"
BAT="/sys/class/power_supply/BAT0"

# Prepare text for the tooltip. Waybar first parses the JSON and then
# renders the result as Pango markup, so escape for Pango first and for
# JSON last. Control characters are not allowed in JSON strings
escape() {
    local s=${1//[[:cntrl:]]/}
    s=${s//&/&amp;}
    s=${s//</&lt;}
    s=${s//>/&gt;}
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    printf '%s' "$s"
}

if ! profile=$(tlpctl get 2>/dev/null) || [[ -z "$profile" ]]; then
    printf '{"text":"%s  n/a","tooltip":"TLP not available","class":"unknown"}\n' "$ICON_UNKNOWN"
    exit 0
fi

case "$profile" in
    performance) icon=$ICON_PERF;    label="Performance"; class="performance" ;;
    balanced)    icon=$ICON_BAL;     label="Balanced";    class="balanced" ;;
    power-saver) icon=$ICON_SAVE;    label="Power Saver"; class="power-saver" ;;
    *)           icon=$ICON_UNKNOWN; label=$(escape "${profile^}"); class="unknown" ;;
esac

# Read sysfs files with the read builtin, without starting a process.
# The braces send the error of a missing file to /dev/null too
online="" start="" end=""
{ read -r online < "$AC"; } 2>/dev/null
{ read -r start < "$BAT/charge_control_start_threshold"; } 2>/dev/null
{ read -r end < "$BAT/charge_control_end_threshold"; } 2>/dev/null

case "$online" in
    1) power="AC" ;;
    0) power="Battery" ;;
    *) power="" ;;
esac

tooltip="TLP Profile: $label"
[[ -n "$power" ]] && tooltip+="\\nPower Source: $power"
if [[ "$start" =~ ^[0-9]+$ && "$end" =~ ^[0-9]+$ ]]; then
    tooltip+="\\nCharge Thresholds: ${start}-${end}%"
fi

printf '{"text":"%s  %s","tooltip":"%s","class":"%s"}\n' "$icon" "$label" "$tooltip" "$class"
