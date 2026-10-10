#!/usr/bin/env bash
mode="${1:-drun}"
rofi -show "$mode" -modi "$mode" -theme ~/.config/rofi/"$mode".rasi
