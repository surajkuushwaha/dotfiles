#!/bin/bash

sketchybar --add event aerospace_workspace_change \
 --add event aerospace_monitor_change

# Hidden item that redraws every workspace (plugins/spaces.sh) on each event.
# front_app_switched catches windows opened on another workspace by on-window-detected,
# system_woke/display_change catch sleep and monitor changes.
sketchybar --add item aerospace_dummy left \
 --set aerospace_dummy drawing=off \
 script="$PLUGIN_DIR/spaces.sh" \
 --subscribe aerospace_dummy aerospace_workspace_change aerospace_monitor_change \
 front_app_switched system_woke display_change

# Plain items, not `--add space`: space items are bound to native Mission Control
# spaces, and sketchybar hides them whenever it re-reads those (wake, monitor change),
# leaving only the workspace that matches native space 1.
for sid in $(aerospace list-workspaces --all); do
 sketchybar --add item space.$sid left \
 --set space.$sid \
 icon=$sid \
 drawing=off \
 background.color=$TRANSPARENT \
 label.color=$ACCENT_COLOR \
 icon.color=$ACCENT_COLOR \
 label.font="sketchybar-app-font:Regular:12.0" \
 icon.font="SF Pro:Semibold:12.0" \
 label.padding_right=10 \
 label.y_offset=-1 \
 click_script="$PLUGIN_DIR/space_click.sh $sid"
done
# Initial state is drawn by plugins/spaces.sh when sketchybarrc runs `sketchybar --update`.
