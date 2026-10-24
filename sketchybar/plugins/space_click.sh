#!/bin/sh

apps=$(aerospace list-windows --workspace $1 --format '%{app-name}')
focused=$(aerospace list-workspaces --focused)

if [ "${apps}" = "" ] && [ "${focused}" != "$1" ]; then
 sketchybar --set space.$1 drawing=off
else
 aerospace workspace $1
fi
