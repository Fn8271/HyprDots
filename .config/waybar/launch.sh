#!/usr/bin/env bash
# Restart waybar; its output goes to the terminal that runs this script

pkill -x waybar

# Wait for the old instance to exit, so both never run at once
for _ in {1..20}; do
    pgrep -x waybar >/dev/null || break
    sleep 0.1
done

# Force it if it did not exit in time
pkill -KILL -x waybar 2>/dev/null

waybar & disown
