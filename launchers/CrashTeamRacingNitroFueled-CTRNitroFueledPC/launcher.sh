#!/bin/sh
# SacredFire settings launcher (game folder, controller, patches, DLC, online...).
cd "$(dirname "$0")" || exit 1
export GSK_RENDERER=cairo
export SDL_VIDEODRIVER=wayland
export BB_GAME_DIR="/run/media/spawnenl/L/game/CTR-Nitro-Fueled"
app=$(ls -1 SacredFire-*-x86_64.AppImage 2>/dev/null | sort -V | tail -n 1)
[ -z "$app" ] && { echo "SacredFire AppImage not found in $PWD" >&2; exit 1; }
exec "./$app" "$@"
