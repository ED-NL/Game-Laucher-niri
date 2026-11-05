#!/bin/sh
# Quiver entry for the native PC port of inFAMOUS Second Son (HayatoG/iss_pc).
# The game files come from the user's own PS4 dump (base 1.00 + update 1.07).
#
# - GSK_RENDERER=cairo: GTK's GL/Vulkan renderers fail on this NVIDIA + COSMIC setup.
# - SDL_VIDEO_DRIVER=wayland: SDL defaulting to X11 can hit NVIDIA EGL problems.
# - gamescope: the port's own Fullscreen path aborts with "Swapchain ... NotReady"
#   on this driver; a nested compositor gives a reliable fullscreen window.
cd "$(dirname "$0")" || exit 1

export GSK_RENDERER=cairo
export SDL_VIDEO_DRIVER=wayland
export SDL_VIDEODRIVER=wayland

# gamescope talks to the compositor through Wayland; a stale DISPLAY from
# Xwayland makes the swapchain die with ErrorSurfaceLostKHR.
unset DISPLAY

export ISS_GAME_DIR="/run/media/spawnenl/L/game/ISS-SecondSon-CUSA00004"
export ISS_USER_DIR="/home/spawnenl/.local/share/infamous-pc"

# Entitlement labels of the add-ons (they live inside the base game; a license
# just unlocks them). Read from the .pkg headers in <user dir>/dlc.
dlc_labels="UNLOCKCOLEJACKET,UNLOCKCOLEMISSIO,UNLOCKVESTHANDPR,UNLOCKVESTEXIST0,UNLOCKVESTJOS000,UNLOCKVESTPENNYA,UNLOCKVESTSKELET"
export ISS_ADDCONT_LABELS="$dlc_labels"
export TLG_ADDCONT_LABELS="$dlc_labels"

# Already running? Bring the existing window up instead of starting a second copy.
if pgrep -f 'inFAMOUS Second Son --play' >/dev/null 2>&1; then
    exit 0
fi

gs_args="-f -W 1920 -H 1080"

# Arguments from the desktop entry are passed straight through.
if [ "$#" -gt 0 ]; then
    exec gamescope $gs_args -- "./inFAMOUS Second Son" "$@"
fi

# Launched from Quiver: boot straight into the game, and show the port's error
# instead of closing silently if it refuses to start.
log=$(mktemp "${TMPDIR:-/tmp}/infamous-launch-XXXXXX.log")
trap 'rm -f "$log" "$log.txt"' EXIT INT TERM

gamescope $gs_args -- "./inFAMOUS Second Son" --play >"$log" 2>&1
code=$?
if [ "$code" -ne 0 ]; then
    msg="No se pudo abrir inFAMOUS Second Son (código $code)."
    cp -f "$log" "$PWD/last-launch-error.log" 2>/dev/null
    {
        printf '%s\n\n' "$msg"
        printf '%s\n' "Últimas líneas del registro:"
        printf '%s\n' "----------------------------"
        grep -av -i "fontconfig" "$log" | tail -n 15
        printf '\n%s\n' "Registro completo: $PWD/last-launch-error.log"
    } >"$log.txt"
    zenity --text-info --title="inFAMOUS Second Son" \
        --filename="$log.txt" --width=820 --height=420 2>/dev/null
fi
exit "$code"
