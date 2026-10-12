#!/usr/bin/env bash
# Rofi menu to connect and disconnect Proton VPN

THEME="$HOME/.config/rofi/menu.rasi"
WIDTH='window { width: 200px; }'
MAX_LINES=10
LOCK="${XDG_RUNTIME_DIR:-/tmp}/vpn-menu.lock"

# Countries shown in the menu, in order: "CODE:Name"
# Codes are the ones accepted by "protonvpn connect --country"
COUNTRIES=(
    "US:United States"
    "CA:Canada"
    "MX:Mexico"
    "BR:Brazil"
    "AR:Argentina"
    "CL:Chile"
    "ES:Spain"
    "NL:Netherlands"
    "CH:Switzerland"
    "JP:Japan"
)

log() {
    echo "vpn-menu: $1" >&2
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

# Only one VPN operation at a time: connecting takes a few seconds
if ! exec 9>"$LOCK"; then
    log "cannot open lock file $LOCK"
    exit 1
fi

if ! flock -n 9; then
    log "another VPN operation is still running"
    exit 0
fi

# Active Proton VPN connection. The type never contains ":", so everything
# after the first ":" is the (escaped) connection name
active=$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null |
    awk '/^wireguard:ProtonVPN/ {sub(/^wireguard:/, ""); print; exit}')
active=$(unescape "$active")

server=${active#ProtonVPN }

# Country code from the server name, e.g. "US-FL#337" -> "US".
# For Secure Core servers ("IS-US#1") this is the entry country
current_country=""
[[ -n "$active" ]] && current_country=${server%%[-#]*}

options=()
actions=()

if [[ -n "$active" ]]; then
    options+=("Disconnect ($server)")
    actions+=("disconnect")
fi

options+=("Fastest server")
actions+=("fastest")

for entry in "${COUNTRIES[@]}"; do
    code=${entry%%:*}
    name=${entry#*:}

    printf -v label '%-15s  %s' "$name" "$code"
    [[ "$code" == "$current_country" ]] && label+="  ●"

    options+=("$label")
    actions+=("country:$code")
done

options+=("Other country...")
actions+=("other")

count=${#options[@]}
lines=$(( count < MAX_LINES ? count : MAX_LINES ))

index=$(printf '%s\n' "${options[@]}" | run rofi -dmenu -i -no-custom -format i \
    -p "Proton VPN:" -l "$lines" \
    -theme "$THEME" -theme-str "$WIDTH")

[[ -z "$index" ]] && exit 0

action=${actions[$index]}

case "$action" in
    disconnect)
        run protonvpn disconnect >&2 || log "failed to disconnect"
        ;;
    fastest)
        run protonvpn connect >&2 || log "failed to connect"
        ;;
    country:*)
        code=${action#country:}
        run protonvpn connect --country "$code" >&2 || log "failed to connect to $code"
        ;;
    other)
        input=$(run rofi -dmenu -p "Country (code or name):" -l 0 \
            -theme "$THEME" -theme-str "$WIDTH" < /dev/null)

        # Trim surrounding spaces
        input=${input#"${input%%[![:space:]]*}"}
        input=${input%"${input##*[![:space:]]}"}
        [[ -z "$input" ]] && exit 0

        # Two letters is a country code; anything longer is a country name
        [[ "$input" =~ ^[A-Za-z]{2}$ ]] && input=${input^^}

        run protonvpn connect --country "$input" >&2 || log "failed to connect to $input"
        ;;
esac

# Refresh the waybar indicator right away (fine if waybar is not running)
pkill -RTMIN+11 waybar || true
