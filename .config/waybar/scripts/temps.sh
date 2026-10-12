#!/usr/bin/env bash
# CPU, GPU, SSD and board temperatures for waybar (JSON output)

ICON_LOW="󱃃"
ICON_MID="󰔏"
ICON_HIGH="󱃂"
ICON_UNKNOWN="󱔱"

# Below COOL the icon shows a low thermometer; WARN and CRIT also set the
# color of the module through its class
COOL=50
WARN=80
CRIT=90
GPU_PCI="/sys/bus/pci/devices/0000:01:00.0"

# Map sensor names to their hwmon directories in a single pass.
# hwmon numbers can change on reboot; sensor names do not
declare -A hwmon
for d in /sys/class/hwmon/hwmon*; do
    name=""
    { read -r name < "$d/name"; } 2>/dev/null || continue
    [[ -z "${hwmon[$name]+x}" ]] && hwmon[$name]=$d
done

# Read a sensor (in millidegrees) into the variable named by $1, in whole
# degrees. Leaves it empty if the file is missing or not a number
read_temp() {
    local v=""
    printf -v "$1" '%s' ""
    { read -r v < "$2"; } 2>/dev/null
    [[ "$v" =~ ^-?[0-9]+$ ]] && printf -v "$1" '%d' $(( v / 1000 ))
}

read_temp cpu "${hwmon[coretemp]}/temp1_input"
read_temp ssd "${hwmon[nvme]}/temp1_input"
read_temp board "${hwmon[acpitz]}/temp1_input"

# GPU: only query when awake, so RTD3 keeps it powered off. The timeout
# keeps a stuck driver from blocking the whole module
gpu_str="Off"
gpu_status=""
{ read -r gpu_status < "$GPU_PCI/power/runtime_status"; } 2>/dev/null
if [[ "$gpu_status" == "active" ]]; then
    gpu=$(timeout 3 nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
    if [[ "$gpu" =~ ^[0-9]+$ ]]; then
        gpu_str="${gpu}°C"
    else
        gpu_str="?"
    fi
fi

# Bar text, icon and state, based on the CPU package
if [[ -z "$cpu" ]]; then
    text="$ICON_UNKNOWN n/a"
    class="unknown"
else
    if (( cpu >= CRIT )); then
        icon=$ICON_HIGH
        class="critical"
    elif (( cpu >= WARN )); then
        icon=$ICON_HIGH
        class="warning"
    elif (( cpu >= COOL )); then
        icon=$ICON_MID
        class="normal"
    else
        icon=$ICON_LOW
        class="normal"
    fi
    text="$icon ${cpu}°C"
fi

tooltip="CPU: ${cpu:-?}°C"
tooltip+="\\nGPU: ${gpu_str}"
[[ -n "$ssd" ]] && tooltip+="\\nSSD: ${ssd}°C"
[[ -n "$board" ]] && tooltip+="\\nBoard: ${board}°C"

printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$text" "$tooltip" "$class"
