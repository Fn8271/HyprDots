#!/usr/bin/env bash
# Proton VPN status for waybar (JSON output), read from NetworkManager

ICON_ON="󰌾"
ICON_OFF="󰿆"

# Undo nmcli terse escaping ("\:" and "\\")
unescape() {
    local s=${1//\\:/:}
    printf '%s' "${s//\\\\/\\}"
}

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

# Active Proton VPN connection as TYPE:DEVICE:STATE:NAME. The first three
# fields never contain ":", so everything after the third one is the name
line=$(nmcli -t -f TYPE,DEVICE,STATE,NAME connection show --active 2>/dev/null |
    awk -F: '$1 == "wireguard" && $4 ~ /^ProtonVPN/ {print; exit}')

# Icon-only states end with a space: these icons are drawn wider than
# the room the font gives them and would touch the next module
if [[ -z "$line" ]]; then
    printf '{"text":"%s ","tooltip":"VPN: Disconnected","class":"off"}\n' "$ICON_OFF"
    exit 0
fi

IFS=: read -r _ dev state name <<<"$line"
name=$(unescape "$name")

# "ProtonVPN US-FL#337" -> "US-FL#337" -> "US".
# For Secure Core servers ("IS-US#1") this is the entry country
server=${name#ProtonVPN }
country=${server%%[-#]*}

case "$state" in
    activated)
        ;;
    deactivating)
        printf '{"text":"%s ","tooltip":"VPN: Disconnecting from %s","class":"connecting"}\n' \
            "$ICON_ON" "$(escape "$server")"
        exit 0
        ;;
    *)
        printf '{"text":"%s ","tooltip":"VPN: Connecting to %s","class":"connecting"}\n' \
            "$ICON_ON" "$(escape "$server")"
        exit 0
        ;;
esac

# Address of the tunnel, read from the kernel (lighter than asking nmcli)
vpn_ip=$(ip -4 -o addr show dev "$dev" 2>/dev/null | awk '{print $4; exit}')

tooltip="VPN: Connected\\nServer: $(escape "$server")\\nCountry: $(escape "$country")\\nInterface: $dev"
[[ -n "$vpn_ip" ]] && tooltip+="\\nVPN IP: ${vpn_ip%/*}"

printf '{"text":"%s  %s","tooltip":"%s","class":"on"}\n' "$ICON_ON" "$(escape "$country")" "$tooltip"
