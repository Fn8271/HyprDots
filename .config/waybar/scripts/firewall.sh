#!/usr/bin/env bash
# firewalld state and zone of the active connection for waybar (JSON output)
# Reads systemd, NetworkManager and config files, so no polkit permission is needed

ICON_ON="󰕥"
ICON_OFF="󰦞"
FIREWALLD_CONF="/etc/firewalld/firewalld.conf"

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

if ! systemctl is-active --quiet firewalld; then
    printf '{"text":"%s","tooltip":"Firewall: Not running","class":"off"}\n' "$ICON_OFF"
    exit 0
fi

# First active Wi-Fi or Ethernet connection. UUID, type and device never
# contain ":", so splitting the terse output is safe
IFS=: read -r uuid dev < <(nmcli -t -f UUID,TYPE,DEVICE connection show --active 2>/dev/null |
    awk -F: '$2 == "802-11-wireless" || $2 == "802-3-ethernet" {print $1 ":" $3; exit}')

default=$(awk -F= '/^[[:space:]]*DefaultZone[[:space:]]*=/ {
    gsub(/[[:space:]]/, "", $2); print $2; exit
}' "$FIREWALLD_CONF" 2>/dev/null)
default=${default:-public}

# Name and zone of the connection, one value per line
name=""
zone=""
if [[ -n "$uuid" ]]; then
    {
        read -r name
        read -r zone
    } < <(nmcli -g connection.id,connection.zone connection show uuid "$uuid" 2>/dev/null)
    name=$(unescape "$name")
fi

[[ -z "$zone" ]] && zone="$default (default)"

tooltip="Firewall: Running\\nZone: $zone"
[[ -n "$name" ]] && tooltip+="\\nConnection: $(escape "$name") ($dev)"
tooltip+="\\nDefault zone: $default"

printf '{"text":"%s","tooltip":"%s","class":"on"}\n' "$ICON_ON" "$tooltip"
