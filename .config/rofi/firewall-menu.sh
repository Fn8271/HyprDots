#!/usr/bin/env bash
# Rofi menu to choose the firewalld zone of the active connection
# Zones are read from config files and set through NetworkManager

THEME="$HOME/.config/rofi/menu.rasi"
WIDTH='window { width: 360px; }'
MAX_LINES=10
FIREWALLD_CONF="/etc/firewalld/firewalld.conf"

declare -A DESCRIPTIONS=(
    [public]="Untrusted networks"
    [home]="Home network"
    [work]="Work network"
    [internal]="Internal network"
    [trusted]="Allow all traffic"
    [external]="External, with masquerading"
    [dmz]="Demilitarized zone"
    [block]="Reject incoming"
    [drop]="Drop incoming silently"
)

log() {
    echo "firewall-menu: $1" >&2
}

# Undo nmcli terse escaping ("\:" and "\\")
unescape() {
    local s=${1//\\:/:}
    printf '%s' "${s//\\\\/\\}"
}

if ! systemctl is-active --quiet firewalld; then
    log "firewalld is not running"
    exit 1
fi

# First active Wi-Fi or Ethernet connection. UUID, type and device never
# contain ":", so splitting the terse output is safe
IFS=: read -r uuid dev < <(nmcli -t -f UUID,TYPE,DEVICE connection show --active 2>/dev/null |
    awk -F: '$2 == "802-11-wireless" || $2 == "802-3-ethernet" {print $1 ":" $3; exit}')

if [[ -z "$uuid" ]]; then
    log "no active connection"
    exit 1
fi

# Name and zone of the connection, one value per line
{
    read -r name
    read -r current
} < <(nmcli -g connection.id,connection.zone connection show uuid "$uuid" 2>/dev/null)

name=$(unescape "$name")

default=$(awk -F= '/^[[:space:]]*DefaultZone[[:space:]]*=/ {
    gsub(/[[:space:]]/, "", $2); print $2; exit
}' "$FIREWALLD_CONF" 2>/dev/null)
default=${default:-public}

# Built-in zones plus custom ones in /etc, skipping those used by other tools
found=()
for f in /usr/lib/firewalld/zones/*.xml /etc/firewalld/zones/*.xml; do
    [[ -f "$f" ]] || continue
    z=${f##*/}
    z=${z%.xml}
    case "$z" in
        nm-shared|docker|libvirt*) continue ;;
    esac
    found+=("$z")
done

if (( ${#found[@]} == 0 )); then
    log "no firewalld zones found"
    exit 1
fi

mapfile -t available < <(printf '%s\n' "${found[@]}" | sort -u)

# First option: no explicit zone, follow the default one
zones=("")
printf -v label '%-10s  %s' "default" "Follow default ($default)"
[[ -z "$current" ]] && label+="  ●"
labels=("$label")
selected=0

for z in "${available[@]}"; do
    printf -v label '%-10s  %s' "$z" "${DESCRIPTIONS[$z]}"

    if [[ "$z" == "$current" ]]; then
        label+="  ●"
        selected=${#zones[@]}
    fi

    zones+=("$z")
    labels+=("$label")
done

count=${#labels[@]}
lines=$(( count < MAX_LINES ? count : MAX_LINES ))

index=$(printf '%s\n' "${labels[@]}" | rofi -dmenu -i -no-custom -format i \
    -p "Zone ($name):" -l "$lines" -selected-row "$selected" \
    -theme "$THEME" -theme-str "$WIDTH")

[[ -z "$index" ]] && exit 0

zone=${zones[$index]}

if [[ "$zone" == "$current" ]]; then
    log "$name is already in zone: ${zone:-default ($default)}"
    exit 0
fi

if ! nmcli connection modify uuid "$uuid" connection.zone "$zone"; then
    log "failed to change the zone of $name"
    exit 1
fi

# Apply without disconnecting; reconnect only if reapply is not possible
nmcli device reapply "$dev" >/dev/null 2>&1 ||
    nmcli connection up uuid "$uuid" >/dev/null 2>&1

log "$name is now in zone: ${zone:-default ($default)}"

# Refresh the waybar indicator right away (fine if waybar is not running)
pkill -RTMIN+10 waybar || true
