#!/usr/bin/env bash
# Rofi menu to switch the TLP power profile through tlp-pd (tlpctl)

THEME="$HOME/.config/rofi/menu.rasi"
WIDTH='window { width: 360px; }'

ids=("performance" "balanced" "power-saver")
names=("Performance" "Balanced" "Power Saver")
descriptions=("Maximum speed, more power" "Default trade-off" "Longer battery life")

log() {
    echo "tlp-menu: $1" >&2
}

if ! command -v tlpctl >/dev/null; then
    log "tlpctl not found (is tlp-pd installed?)"
    exit 1
fi

if ! current=$(tlpctl get 2>/dev/null) || [[ -z "$current" ]]; then
    log "tlp-pd is not responding"
    exit 1
fi

labels=()
selected=0
for i in "${!ids[@]}"; do
    printf -v label '%-12s  %s' "${names[$i]}" "${descriptions[$i]}"

    if [[ "${ids[$i]}" == "$current" ]]; then
        label+="  ●"
        selected=$i
    fi

    labels+=("$label")
done

index=$(printf '%s\n' "${labels[@]}" | rofi -dmenu -i -no-custom -format i \
    -p "TLP Profile:" -l "${#labels[@]}" -selected-row "$selected" \
    -theme "$THEME" -theme-str "$WIDTH")

[[ -z "$index" ]] && exit 0

profile=${ids[$index]}

if [[ "$profile" == "$current" ]]; then
    log "already using ${names[$index]}"
    exit 0
fi

if ! tlpctl set "$profile"; then
    log "failed to set ${names[$index]}"
    exit 1
fi

log "profile set to ${names[$index]}"

# Refresh the waybar module right away (fine if waybar is not running)
pkill -RTMIN+8 waybar || true
