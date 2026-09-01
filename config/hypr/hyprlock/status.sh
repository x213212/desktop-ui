#!/usr/bin/env bash

# Hyprlock calls this only once per minute. Read sysfs directly so the status
# line needs no cat/head pipeline and never leaves helper processes behind.
for battery_path in /sys/class/power_supply/BAT*; do
  [[ -r "$battery_path/capacity" ]] || continue
  read -r capacity < "$battery_path/capacity"
  status=""
  [[ -r "$battery_path/status" ]] && read -r status < "$battery_path/status"
  case "$status" in
    Charging) printf '電量 %s%% · 充電中\n' "$capacity" ;;
    Full) printf '電量 %s%% · 已充滿\n' "$capacity" ;;
    *) printf '電量 %s%%\n' "$capacity" ;;
  esac
  exit 0
done

printf '\n'
