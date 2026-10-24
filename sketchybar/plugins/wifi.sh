#!/bin/sh

# system_profiler and networksetup no longer return the SSID on macOS 15+.
# ipconfig does, once `sudo ipconfig setverbose 1` has been run; until then it says <redacted>.
iface=$(networksetup -listallhardwareports | awk '/Wi-Fi/ { getline; print $2; exit }')
summary=$(ipconfig getsummary "$iface" 2>/dev/null)
SSID=$(printf '%s\n' "$summary" | awk -F ' : ' '$1 ~ /^ *SSID$/ { print $2; exit }')

if ! printf '%s\n' "$summary" | grep -q 'LinkStatusActive : TRUE'; then
 sketchybar --set $NAME icon="􀙈" label="Disconnected"
elif [ -z "$SSID" ] || [ "$SSID" = "<redacted>" ]; then
 sketchybar --set $NAME icon="􀙇" label="Wi-Fi"
else
 sketchybar --set $NAME icon="􀙇" label="$SSID"
fi
