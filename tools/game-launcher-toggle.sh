#!/usr/bin/env bash
# Abre/cierra el Game Launcher en la última vista usada (horizontal o vertical).
# El plugin guarda la vista en <datos del plugin>/last_layout al abrirse.
# Antes de abrir deja en open_entry qué ventana va a abrir, para que el plugin
# sepa cuál es (panel-toggle no admite contexto).
# Atajo en niri:  Mod+Z { spawn "game-launcher-toggle"; }
set -euo pipefail

DATA="${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/plugins/data/alexander/game-launcher"
mkdir -p "$DATA"
layout="$(tr -d '[:space:]' < "$DATA/last_layout" 2>/dev/null || true)"

if [[ "$layout" == "horizontal" ]]; then
  entry="horizontal"
else
  entry="original"
fi
printf '%s' "$entry" > "$DATA/open_entry"
exec noctalia msg panel-toggle "alexander/game-launcher:$entry"
