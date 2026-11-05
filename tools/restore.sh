#!/usr/bin/env bash
# Restaura la copia local completa del Game Launcher (Noctalia + niri)
# guardada en ~/Documentos/Game-Laucher-niri.
#
# Uso:
#   ./tools/restore.sh              # copia todo y reaplica parches
#   ./tools/restore.sh --restart    # además reinicia Noctalia
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESTART=0
[[ "${1:-}" == "--restart" ]] && RESTART=1

MAT="$HOME/.local/state/noctalia/plugins/materialized/community/game-launcher"
PATCH="$HOME/.local/state/noctalia/patches/game-launcher"
PDATA="$HOME/.local/state/noctalia/plugins/data/alexander/game-launcher"
CACHE="$HOME/.cache/gamelauncher"
COVERS="$HOME/.local/share/noctalia/game-covers"
PLATFORMS="$HOME/.local/share/noctalia/game-platforms"
APPS="$HOME/.local/bin/Apps"
APPLICATIONS="$HOME/.local/share/applications"

if [[ ! -d "$MAT" ]]; then
  echo "No encuentro el plugin instalado en: $MAT" >&2
  echo "Instala/activa alexander/game-launcher en Noctalia y vuelve a ejecutar." >&2
  exit 1
fi

echo "[1/9] plugin materializado"
cp -a "$ROOT/plugin/." "$MAT/"

echo "[2/9] parches fijados"
mkdir -p "$PATCH"
cp -a "$ROOT/patches/game-launcher/." "$PATCH/"

echo "[3/9] datos del plugin (juegos externos y portadas propias)"
mkdir -p "$PDATA"
cp -a "$ROOT/plugin-data/." "$PDATA/"

echo "[4/9] biblioteca, portadas de tiendas y discos"
mkdir -p "$CACHE"
cp -a "$ROOT/cache/." "$CACHE/"

echo "[5/9] portadas propias y logo de plataforma"
mkdir -p "$COVERS" "$PLATFORMS"
cp -a "$ROOT/assets/game-covers/." "$COVERS/"
cp -a "$ROOT/assets/game-platforms/." "$PLATFORMS/"

echo "[6/9] lanzadores e iconos de los ports"
mkdir -p "$APPS"
cp -a "$ROOT/launchers/." "$APPS/"

echo "[7/9] configuración de los ports"
mkdir -p "$HOME/.config/infamous-launcher" "$HOME/.config/sacredfire-launcher"
cp -a "$ROOT/config/infamous-launcher/." "$HOME/.config/infamous-launcher/"
cp -a "$ROOT/config/sacredfire-launcher/." "$HOME/.config/sacredfire-launcher/"

echo "[8/9] accesos directos y script de reapply"
mkdir -p "$APPLICATIONS" "$HOME/.local/bin"
cp -a "$ROOT/config/applications/." "$APPLICATIONS/"
cp -a "$ROOT/tools/reapply-noctalia-patches.sh" "$HOME/.local/bin/"
chmod +x "$HOME/.local/bin/reapply-noctalia-patches.sh"

echo "[9/9] fijando parches en la fuente del plugin"
if [[ -x "$HOME/.local/bin/reapply-noctalia-patches.sh" ]]; then
  bash "$HOME/.local/bin/reapply-noctalia-patches.sh" --force || {
    echo "Aviso: el reapply terminó con errores; revisa la salida de arriba." >&2
  }
fi

if [[ "$RESTART" -eq 1 ]]; then
  echo "Reiniciando Noctalia…"
  pid="$(pgrep -x noctalia | head -1 || true)"
  [[ -n "$pid" ]] && kill "$pid"
  sleep 3
  nohup noctalia -d >/dev/null 2>&1 &
  sleep 2
fi

echo "Listo. Panel restaurado (v1.5.1 parcheada, con biblioteca, portadas y discos)."
