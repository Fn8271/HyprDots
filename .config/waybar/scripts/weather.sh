#!/usr/bin/env bash
# Weather from wttr.in for waybar (JSON output), with retries and an offline cache
# Usage: weather.sh [--open]  (--open shows the full forecast in kitty)

LOCATION="Arequipa"   # use "+" for spaces, e.g. "Buenos+Aires"
URL="https://wttr.in/${LOCATION}?format=j1&lang=en"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-weather.json"
RETRIES=3

ICON_CLEAR_DAY="󰖙"
ICON_CLEAR_NIGHT="󰖔"
ICON_PARTLY="󰖕"
ICON_CLOUDY="󰖐"
ICON_FOG="󰖑"
ICON_RAIN="󰖗"
ICON_THUNDER="󰙾"
ICON_SNOW="󰖘"
ICON_UNKNOWN="󰼯"

# Separator for the values extracted with jq. Unlike a tab, it is not
# whitespace, so read keeps empty fields in place
US=$'\x1f'

log() {
    echo "weather: $1" >&2
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

# A response is usable when it has the current conditions
is_valid() {
    jq -e '.current_condition[0]' >/dev/null 2>&1 <<<"$1"
}

if [[ "$1" == "--open" ]]; then
    exec kitty --hold curl -s "https://wttr.in/${LOCATION}?F"
fi

mkdir -p "${CACHE%/*}"

# Fetch with retries, logging why each attempt fails
fetch() {
    local attempt out rc http
    for (( attempt = 1; attempt <= RETRIES; attempt++ )); do
        # Append the HTTP code on its own last line, then split it off
        out=$(curl -s --max-time 15 -w '\n%{http_code}' "$URL")
        rc=$?
        http=${out##*$'\n'}
        out=${out%$'\n'*}

        if (( rc != 0 )); then
            log "attempt $attempt: curl exit code $rc"
        elif [[ "$http" != "200" ]]; then
            log "attempt $attempt: HTTP $http"
        elif ! is_valid "$out"; then
            log "attempt $attempt: invalid JSON (starts with: ${out:0:60})"
        else
            printf '%s' "$out"
            return 0
        fi

        (( attempt < RETRIES )) && sleep 2
    done
    return 1
}

stale=0

if data=$(fetch); then
    # Write to a temporary file and rename it, so a reader never sees a
    # half-written cache. Remove the temporary file if anything fails
    if tmp=$(mktemp "$CACHE.XXXXXX"); then
        { printf '%s' "$data" > "$tmp" && mv -f "$tmp" "$CACHE"; } || rm -f "$tmp"
    fi
elif [[ -s "$CACHE" ]] && data=$(<"$CACHE") && is_valid "$data"; then
    stale=1
else
    printf '{"text":"%s  n/a","tooltip":"Weather unavailable","class":"unavailable"}\n' "$ICON_UNKNOWN"
    exit 0
fi

# Extract everything in one jq call. Missing values become empty strings
IFS=$US read -r code desc temp feels humidity wind \
    min max sunrise sunset next_min next_max next_desc < <(jq -r '
    .current_condition[0] as $c
    | .weather[0] as $today
    | .weather[1] as $tomorrow
    | [
        $c.weatherCode, $c.weatherDesc[0].value, $c.temp_C, $c.FeelsLikeC,
        $c.humidity, $c.windspeedKmph,
        $today.mintempC, $today.maxtempC,
        $today.astronomy[0].sunrise, $today.astronomy[0].sunset,
        $tomorrow.mintempC, $tomorrow.maxtempC,
        $tomorrow.hourly[4].weatherDesc[0].value
      ]
    | map(. // "" | tostring)
    | join("\u001f")' <<<"$data")

# Sunrise and sunset in epoch seconds and as 24h times. An empty value must
# not reach date: "date -d ''" returns midnight instead of failing
rise="" dusk="" rise_24="?" dusk_24="?"
if [[ -n "$sunrise" ]]; then
    rise=$(date -d "$sunrise" +%s 2>/dev/null)
    rise_24=$(date -d "$sunrise" +%H:%M 2>/dev/null || echo "?")
fi
if [[ -n "$sunset" ]]; then
    dusk=$(date -d "$sunset" +%s 2>/dev/null)
    dusk_24=$(date -d "$sunset" +%H:%M 2>/dev/null || echo "?")
fi

# Day or night; without both times, assume day
now=$(date +%s)
is_day=1
if [[ -n "$rise" && -n "$dusk" ]] && (( now < rise || now > dusk )); then
    is_day=0
fi

# Icon from the wttr.in weather code
case "$code" in
    113)
        if (( is_day )); then icon=$ICON_CLEAR_DAY; else icon=$ICON_CLEAR_NIGHT; fi ;;
    116)
        icon=$ICON_PARTLY ;;
    119|122)
        icon=$ICON_CLOUDY ;;
    143|248|260)
        icon=$ICON_FOG ;;
    200|386|389|392|395)
        icon=$ICON_THUNDER ;;
    176|263|266|281|284|293|296|299|302|305|308|311|314|353|356|359)
        icon=$ICON_RAIN ;;
    179|182|185|227|230|317|320|323|326|329|332|335|338|350|362|365|368|371|374|377)
        icon=$ICON_SNOW ;;
    *)
        icon=$ICON_UNKNOWN ;;
esac

# Every value below comes from wttr.in, so all of it is escaped
tooltip="$(escape "${LOCATION//+/ }"): $(escape "$desc")"
tooltip+="\\nTemperature: $(escape "$temp")°C (feels $(escape "$feels")°C)"
tooltip+="\\nHumidity: $(escape "$humidity")%"
tooltip+="\\nWind: $(escape "$wind") km/h"
tooltip+="\\n\\nToday: $(escape "$min")°C / $(escape "$max")°C"
tooltip+="\\nSunrise: $rise_24  ·  Sunset: $dusk_24"
tooltip+="\\nTomorrow: $(escape "$next_min")°C / $(escape "$next_max")°C, $(escape "$next_desc")"

class="normal"
if (( stale )); then
    updated=$(date -r "$CACHE" '+%a %H:%M' 2>/dev/null)
    tooltip+="\\n\\nOffline: data from ${updated:-an earlier update}"
    class="stale"
fi

printf '{"text":"%s  %s°C","tooltip":"%s","class":"%s"}\n' "$icon" "$(escape "${temp:-?}")" "$tooltip" "$class"
