#!/usr/bin/env bash
# Manda una orden de navegación del mando (up, down, left, right, enter, back,
# options, pageup, pagedown, tabprev, tabnext) al Game Launcher, esté abierta la
# ventana vertical ("original") o la horizontal ("horizontal").
#
# Noctalia entrega los eventos de plugin solo a la entrada indicada, así que se
# envía a las dos; la que no esté abierta simplemente no recibe nada.
#
# Uso:  game-launcher-nav left
set -u
ev="${1:?uso: game-launcher-nav <evento>}"
for entry in original horizontal; do
  noctalia msg plugin "alexander/game-launcher:$entry" all nav "$ev" >/dev/null 2>&1 &
done
wait
