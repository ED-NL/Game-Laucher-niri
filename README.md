# Game Launcher (Noctalia + niri) — copia de respaldo

Respaldo local **completo** del panel Game Launcher tal como funciona en este equipo:
la versión **v1.5.1 parcheada** (vitrina de portadas, animación de disco, badges PS4,
juegos de escritorio y juegos externos). No es el panel de la v1.6.0, que reescribió
la interfaz.

- Fecha de la copia: ver `VERSION.txt`
- Plugin: `alexander/game-launcher`
- Host: Noctalia sobre niri
- `auto_update = "none"` en `~/.local/state/noctalia/settings.toml`, para que no se
  vuelva a actualizar solo y pise los parches.
- Incluye la biblioteca completa del panel, las portadas de Steam/Heroic, las
  portadas propias y **los discos generados** (21 juegos con sus fotogramas).

## Contenido

| Carpeta | Qué guarda | Destino original |
| --- | --- | --- |
| `plugin/` | Plugin materializado que carga Noctalia (Lua, C, binario, etc.) | `~/.local/state/noctalia/plugins/materialized/community/game-launcher/` |
| `patches/game-launcher/` | Parches fijados que usa el script de reapply | `~/.local/state/noctalia/patches/game-launcher/` |
| `plugin-data/` | Juegos externos de Faugus, portadas propias guardadas por el plugin y `build_command` | `~/.local/state/noctalia/plugins/data/alexander/game-launcher/` |
| `cache/` | Biblioteca (`games.json`), portadas de Steam/Heroic y discos generados (`disc/`) | `~/.cache/gamelauncher/` |
| `assets/game-covers/` | Portadas 2:3 propias de CTR e inFAMOUS | `~/.local/share/noctalia/game-covers/` |
| `assets/game-platforms/` | Logo de PlayStation (`ps4.png`) | `~/.local/share/noctalia/game-platforms/` |
| `launchers/InFAMOUSSecondSon-IssPc/` | `launch.sh`, `launcher.sh` e icono del port de inFAMOUS | `~/.local/bin/Apps/InFAMOUSSecondSon-IssPc/` |
| `launchers/CrashTeamRacingNitroFueled-CTRNitroFueledPC/` | `launch.sh` y `launcher.sh` del port de CTR | `~/.local/bin/Apps/CrashTeamRacingNitroFueled-CTRNitroFueledPC/` |
| `config/infamous-launcher/settings.json` | Ajustes del port (carpeta de juego en L) | `~/.config/infamous-launcher/` |
| `config/sacredfire-launcher/settings.json` | Ajustes del port (carpeta de juego en L) | `~/.config/sacredfire-launcher/` |
| `config/applications/*.desktop` | Accesos directos de todos los juegos del panel | `~/.local/share/applications/` |
| `config/noctalia-plugins.toml` | Sección `[plugins]` de Noctalia (`auto_update`, plugins activos) | `~/.local/state/noctalia/settings.toml` |
| `history/game-launcher/` | Versiones anteriores de `original.luau` (historial) | `~/.local/state/noctalia/backups/game-launcher/` |
| `tools/reapply-noctalia-patches.sh` | Restaura los parches y los fija en la fuente | `~/.local/bin/` |
| `tools/restore.sh` | Restauración automática de esta copia | — |
| `niri/keybind-game-launcher.txt` | Atajo del panel (Mod+Z) | `~/.config/niri/cfg/keybinds.kdl` |

Los juegos en sí (los datos de PS4/PC) **no** están aquí: viven en el disco **L** y
pueden ocupar cientos de GB. Lo que se respalda es todo lo que muestra y usa el panel.

## Restaurar

La forma rápida:

```sh
cd ~/Documentos/Game-Laucher-niri
./tools/restore.sh --restart
```

Sin `--restart`, copia todo y ejecuta el reapply, pero deja que reinicies Noctalia a mano.

La forma manual:

```sh
# 1. Plugin materializado
cp -a ~/Documentos/Game-Laucher-niri/plugin/. \
  ~/.local/state/noctalia/plugins/materialized/community/game-launcher/

# 2. Parches fijados
cp -a ~/Documentos/Game-Laucher-niri/patches/game-launcher/. \
  ~/.local/state/noctalia/patches/game-launcher/

# 3. Datos del plugin (juegos externos, portadas propias, build_command)
cp -a ~/Documentos/Game-Laucher-niri/plugin-data/. \
  ~/.local/state/noctalia/plugins/data/alexander/game-launcher/

# 4. Biblioteca, portadas de tiendas y discos
cp -a ~/Documentos/Game-Laucher-niri/cache/. ~/.cache/gamelauncher/

# 5. Portadas propias y logo PS4
cp -a ~/Documentos/Game-Laucher-niri/assets/game-covers/. ~/.local/share/noctalia/game-covers/
cp -a ~/Documentos/Game-Laucher-niri/assets/game-platforms/. ~/.local/share/noctalia/game-platforms/

# 6. Lanzadores, configs y accesos directos
cp -a ~/Documentos/Game-Laucher-niri/launchers/. ~/.local/bin/Apps/
cp -a ~/Documentos/Game-Laucher-niri/config/infamous-launcher/. ~/.config/infamous-launcher/
cp -a ~/Documentos/Game-Laucher-niri/config/sacredfire-launcher/. ~/.config/sacredfire-launcher/
cp -a ~/Documentos/Game-Laucher-niri/config/applications/. ~/.local/share/applications/

# 7. Reapply (fija los parches en la fuente del plugin)
bash ~/.local/bin/reapply-noctalia-patches.sh --force

# 8. Reiniciar Noctalia
kill "$(pgrep -x noctalia | head -1)"; nohup noctalia -d >/dev/null 2>&1 &
```

## Juegos

Los dos ports propios se abren desde el disco **L** (debe estar montado):

- inFAMOUS Second Son → `/run/media/spawnenl/L/game/ISS-SecondSon-CUSA00004`
- Crash Team Racing Nitro-Fueled → `/run/media/spawnenl/L/game/CTR-Nitro-Fueled`

Si cambia el punto de montaje, hay que actualizar `GAME_DIR` en los `launch.sh` y
`game_dir` en los `settings.json` de `config/`.

## Qué incluye el parche

- Los dos juegos de escritorio: `ctr-nitro-fueled` e `infamous-second-son`.
- Portada propia desde `~/.local/share/noctalia/game-covers/<id>.jpg`.
- Cabecera con logo de PlayStation + **PS4** solo en esos dos juegos.
- Lanzamiento mediante `desktop://` + `gio launch`.
- Ajuste `desktop_enabled` para mostrar/ocultar los juegos del menú de aplicaciones.

## Notas

- Este repo es **local**: no tiene remoto ni se ha subido a ningún sitio.
- `cache/disc/` contiene 21 discos con sus fotogramas (`base.png`, `f0..fN.png`) y
  `make-disc.sh`; se restauran tal cual y el panel los reutiliza.
- Las copias de seguridad de los estados anteriores están en
  `~/.local/state/noctalia/patches-backup/`.
- Si Noctalia o el plugin se actualizan, hay que volver a ejecutar el reapply o
  restaurar esta copia.
