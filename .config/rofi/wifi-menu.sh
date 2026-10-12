#!/usr/bin/env bash
# Rofi menu to manage Wi-Fi with NetworkManager (nmcli)

ICON_LOCK=""
THEME="$HOME/.config/rofi/menu.rasi"
WIDTH='window { width: 300px; }'
MAX_LINES=10
MAX_SSID=28
LOCK="${XDG_RUNTIME_DIR:-/tmp}/wifi-menu.lock"

# Separator for "security + SSID" keys; it never appears in either
US=$'\x1f'

log() {
    echo "wifi-menu: $1" >&2
}

# Undo nmcli terse escaping ("\:" and "\\")
unescape() {
    local s=${1//\\:/:}
    printf '%s' "${s//\\\\/\\}"
}

# Run a command without the lock descriptor, so no child process
# (or anything it leaves running) can keep the lock held
run() {
    "$@" 9>&-
}

# Show a menu from stdin and print the index of the chosen option
rofi_menu() {
    run rofi -dmenu -i -no-custom -format i \
        -p "$1" -l "$2" \
        -theme "$THEME" -theme-str "$WIDTH"
}

# UUIDs of all saved Wi-Fi profiles (UUID and type never contain ":")
wifi_uuids() {
    nmcli -t -f UUID,TYPE connection show 2>/dev/null |
        awk -F: '$2 == "802-11-wireless" {print $1}'
}

# Split a "security + SSID" key into its parts
key_ssid() {
    printf '%s' "${1#*"$US"}"
}

key_security() {
    printf '%s' "${1%%"$US"*}"
}

is_secure() {
    [[ -n "$1" && "$1" != "--" ]]
}

# Only one Wi-Fi operation at a time: connecting takes a few seconds
if ! exec 9>"$LOCK"; then
    log "cannot open lock file $LOCK"
    exit 1
fi

if ! flock -n 9; then
    log "another Wi-Fi operation is still running"
    exit 0
fi

# Wi-Fi off: only offer to turn it on
if [[ "$(nmcli radio wifi 2>/dev/null)" != "enabled" ]]; then
    choice=$(printf 'Turn Wi-Fi on\n' | rofi_menu "Wi-Fi:" 1)
    [[ "$choice" == "0" ]] && nmcli radio wifi on
    exit 0
fi

# Use cached scan results by default (fast); rescan only when asked
rescan="no"
[[ "$1" == "--rescan" ]] && rescan="yes"

# Networks are keyed by security and SSID, so an open "evil twin" with the
# same name as a secured network shows up as a separate entry
declare -A signal_of
order=()
active=""

# Terse output: IN-USE:SIGNAL:SECURITY:SSID. The first three fields never
# contain ":", so everything after the third one is the (escaped) SSID
while IFS=: read -r inuse signal security ssid; do
    ssid=${ssid//\\:/:}
    ssid=${ssid//\\\\/\\}

    # Hidden networks have no SSID
    [[ -z "$ssid" ]] && continue

    [[ "$signal" =~ ^[0-9]+$ ]] || signal=0
    key="$security$US$ssid"
    [[ "$inuse" == *"*"* ]] && active=$key

    # Same network from several access points: keep the strongest signal.
    # Never use the key inside (( )): array keys there are evaluated as
    # expressions, and an SSID is untrusted text anyone nearby can choose
    if [[ -z "${signal_of[$key]+x}" ]]; then
        order+=("$key")
        signal_of[$key]=$signal
    else
        best=${signal_of[$key]}
        (( signal > best )) && signal_of[$key]=$signal
    fi
done < <(nmcli -t -f IN-USE,SIGNAL,SECURITY,SSID device wifi list --rescan "$rescan" 2>/dev/null)

# Saved profiles by their real SSID (the profile name can differ from it)
declare -A saved_uuid
while read -r uuid; do
    s=$(unescape "$(nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null)")
    [[ -n "$s" && -z "${saved_uuid[$s]+x}" ]] && saved_uuid[$s]=$uuid
done < <(wifi_uuids)

connect() {
    local key=$1 ssid security pw uuid before
    ssid=$(key_ssid "$key")
    security=$(key_security "$key")

    if [[ "$key" == "$active" ]]; then
        log "already connected to $ssid"
        return
    fi

    # Known network: bring its saved profile up. NetworkManager only uses
    # access points that match the security of the profile
    if [[ -n "${saved_uuid[$ssid]+x}" ]]; then
        if run nmcli connection up uuid "${saved_uuid[$ssid]}" >/dev/null 2>&1; then
            log "connected to $ssid"
        else
            log "failed to connect to $ssid (if its password changed, forget it with: nmcli connection delete uuid ${saved_uuid[$ssid]})"
        fi
        return
    fi

    # Enterprise networks need a username and often a certificate
    if [[ "$security" == *802.1X* ]]; then
        log "$ssid uses 802.1X (enterprise); set it up with nmtui"
        return
    fi

    # New open network
    if ! is_secure "$security"; then
        if run nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
            log "connected to $ssid"
        else
            log "failed to connect to $ssid"
        fi
        return
    fi

    # New secured network: ask for the password
    pw=$(run rofi -dmenu -password -p "Password for $ssid:" -l 0 \
        -theme "$THEME" -theme-str "$WIDTH" < /dev/null)
    [[ -z "$pw" ]] && return

    # WPA passwords are 8 to 63 characters long
    if [[ "$security" == *WPA* ]] && (( ${#pw} < 8 || ${#pw} > 63 )); then
        log "invalid password for $ssid: WPA needs 8 to 63 characters"
        return
    fi

    # Remember existing profiles, to clean up only the one created below
    before=" $(wifi_uuids | tr '\n' ' ') "

    # Note: the password is visible in the process list while nmcli runs
    if run nmcli device wifi connect "$ssid" password "$pw" >/dev/null 2>&1; then
        log "connected to $ssid"
    else
        # Remove the half-created profile so the password is asked again
        while read -r uuid; do
            [[ "$before" == *" $uuid "* ]] || run nmcli connection delete uuid "$uuid" >/dev/null 2>&1
        done < <(wifi_uuids)
        log "failed to connect to $ssid (wrong password?)"
    fi
}

# Column width for the SSIDs, capped so long names do not stretch the menu.
# Widths count bytes, so names with emoji may be slightly misaligned
width=0
for key in "${order[@]}"; do
    ssid=$(key_ssid "$key")
    len=${#ssid}
    (( len > width )) && width=$len
done
(( width > MAX_SSID )) && width=$MAX_SSID

options=()
actions=()

if [[ -n "$active" ]]; then
    options+=("Disconnect from $(key_ssid "$active")")
    actions+=("disconnect")
fi

options+=("Rescan")
actions+=("rescan")

options+=("Turn Wi-Fi off")
actions+=("off")

for key in "${order[@]}"; do
    ssid=$(key_ssid "$key")
    shown=$ssid
    (( ${#shown} > MAX_SSID )) && shown="${shown:0:MAX_SSID-1}~"

    printf -v line '%-*s  %3s%%' "$width" "$shown" "${signal_of[$key]}"
    is_secure "$(key_security "$key")" && line+="  $ICON_LOCK"
    [[ "$key" == "$active" ]] && line+="  ●"

    options+=("$line")
    actions+=("net:$key")
done

count=${#options[@]}
lines=$(( count < MAX_LINES ? count : MAX_LINES ))

index=$(printf '%s\n' "${options[@]}" | rofi_menu "Wi-Fi:" "$lines")
[[ -z "$index" ]] && exit 0

action=${actions[$index]}

case "$action" in
    disconnect)
        dev=$(nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2 == "wifi" {print $1; exit}')
        run nmcli device disconnect "$dev" >/dev/null 2>&1 && log "disconnected"
        ;;
    rescan)
        # Release the lock before restarting this script
        exec 9>&-
        exec "$0" --rescan
        ;;
    off)
        nmcli radio wifi off
        ;;
    net:*)
        connect "${action#net:}"
        ;;
esac

# The network module updates by itself, but the firewall indicator shows
# the zone of the active connection, which may have just changed
pkill -RTMIN+10 waybar || true
