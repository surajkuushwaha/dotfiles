#!/bin/bash

source "$CONFIG_DIR/colors.sh"

# Redraws every workspace, not only the visible one, so workspaces that got windows
# while unfocused show up. Shown: workspaces with windows, plus the focused one.

focused="${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}"

# display= needs sketchybar's display number, which is AeroSpace's
# monitor-appkit-nsscreen-screens-id, not its monitor-id.
aerospace list-monitors --format '%{monitor-id}|%{monitor-appkit-nsscreen-screens-id}' |
while IFS='|' read -r monitor display; do
 for sid in $(aerospace list-workspaces --monitor "$monitor"); do
  apps=$(aerospace list-windows --workspace "$sid" --format '%{app-name}' | sort -u)

  if [ -z "$apps" ] && [ "$sid" != "$focused" ]; then
   sketchybar --set space.$sid drawing=off
   continue
  fi

  icon_strip=""
  if [ -n "$apps" ]; then
   while read -r app; do
    icon_strip+=" $($CONFIG_DIR/plugins/icons.sh "$app")"
   done <<<"$apps"
  else
   icon_strip=" —"
  fi

  if [ "$sid" = "$focused" ]; then
   colors=(background.drawing=on background.color=$ACCENT_COLOR label.color=$ITEM_COLOR icon.color=$ITEM_COLOR)
  else
   colors=(background.drawing=off label.color=$ACCENT_COLOR icon.color=$ACCENT_COLOR)
  fi

  sketchybar --set space.$sid drawing=on display=$display label="$icon_strip" "${colors[@]}"
 done
done
