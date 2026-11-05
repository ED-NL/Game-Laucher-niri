#!/bin/sh
# Opens the inFAMOUS Second Son port launcher (settings, fixes, saves, controls).
cd "$(dirname "$0")" || exit 1

export GSK_RENDERER=cairo
export SDL_VIDEO_DRIVER=wayland
export SDL_VIDEODRIVER=wayland

export ISS_GAME_DIR="/run/media/spawnenl/L/game/ISS-SecondSon-CUSA00004"
export ISS_USER_DIR="/home/spawnenl/.local/share/infamous-pc"

exec "./inFAMOUS Second Son"
