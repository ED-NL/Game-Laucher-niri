#!/bin/sh
# Quiver entry for OCTR / SacredFire (native PC port of CTR Nitro-Fueled).
# The game files come from the user's own CUSA13795 dump merged with the 1.21 update.
#
# - SDL_VIDEODRIVER=wayland: on this NVIDIA + niri setup SDL picks X11 by default and the
#   NVIDIA EGL driver segfaults while creating the Vulkan window (signal 11 in
#   libnvidia-eglcore). The Wayland path works.
# - GSK_RENDERER=cairo: GTK's GL/Vulkan renderers fail here too ("Failed to create EGL display").
cd "$(dirname "$0")" || exit 1

export GSK_RENDERER=cairo
export SDL_VIDEODRIVER=wayland
export BB_GAME_DIR="/run/media/spawnenl/L/game/CTR-Nitro-Fueled"

app=$(ls -1 SacredFire-*-x86_64.AppImage 2>/dev/null | sort -V | tail -n 1)
if [ -z "$app" ]; then
    echo "SacredFire AppImage not found in $PWD" >&2
    exit 1
fi
[ -x "$app" ] || chmod +x "$app" 2>/dev/null

# Launched from Quiver (no arguments): boot straight into the game.
if [ "$#" -eq 0 ]; then
    exec "./$app" --play
fi
exec "./$app" "$@"
