#!/usr/bin/env bash
# Volume and output device for waybar (JSON, event-driven)

ICON_LOW="󰕿"
ICON_MED="󰖀"
ICON_HIGH="󰕾"
ICON_MUTED="󰖁"

sink_alias() {
    case "$1" in
        easyeffects_sink)        echo "EasyEffects" ;;
        *MOONDROP*)              echo "Echo B" ;;
        *Headphones*|*Jackpot*)  echo "Jackpot" ;;
        *Speaker*)               echo "Speaker" ;;
        *HDMI1*)                 echo "HDMI 1" ;;
        *HDMI2*)                 echo "HDMI 2" ;;
        *HDMI3*)                 echo "HDMI 3" ;;
        *bluez*)                 echo "BT" ;;
        *)                       echo "Audio" ;;
    esac
}

print_status() {
    local sink volume muted name icon class text status

    sink=$(pactl get-default-sink 2>/dev/null)
    volume=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk '{print $5; exit}')
    muted=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')
    name=$(sink_alias "$sink")

    # Only digits may reach the arithmetic below
    volume=${volume%\%}
    [[ "$volume" =~ ^[0-9]+$ ]] || volume=0

    if [[ "$muted" == "yes" ]]; then
        icon=$ICON_MUTED
        class="muted"
        text="Muted"
        status="Muted"
    else
        if (( volume < 34 )); then
            icon=$ICON_LOW
            class="low"
        elif (( volume < 67 )); then
            icon=$ICON_MED
            class="medium"
        else
            icon=$ICON_HIGH
            class="high"
        fi
        text="${volume}%"
        status="On"
    fi

    printf '{"text":"%s %s","tooltip":"Output: %s\\nVolume: %s%%\\nStatus: %s","class":"%s"}\n' \
        "$icon" "$text" "$name" "$volume" "$status" "$class"
}

# Run the event listener in the main shell so it dies with the script
exec 3< <(pactl subscribe 2>/dev/null)
sub_pid=$!

trap 'kill "$sub_pid" 2>/dev/null' EXIT
trap 'exit 0' TERM INT HUP

print_status || exit 0

while read -r event <&3; do
    # Only the output devices and the default device matter. "on sink #"
    # does not match "on sink-input", which are the streams of each app
    case "$event" in
        *"on sink #"*|*"on server"*) ;;
        *) continue ;;
    esac

    # Events come in bursts (e.g. scrolling the volume): skip the rest
    # of the burst and update once
    while read -r -t 0.05 _ <&3; do :; done

    print_status || exit 0
done
