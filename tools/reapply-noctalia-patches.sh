#!/usr/bin/env bash
# Restaura los parches locales de los plugins de Noctalia.
#
# Noctalia corre con auto_update = "all", asi que la carpeta materializada se
# sobrescribe en cada actualizacion. Este script copia de vuelta las copias
# fijadas en ~/.local/state/noctalia/patches/<plugin>.
#
# Plugins parcheados:
#
#   game-launcher (alexander/game-launcher)
#     1) Heroic Flatpak - scan_heroic() usa XDG_CONFIG_HOME, asi que solo lee
#        ~/.config/heroic (instalacion nativa) e ignora la version Flatpak en
#        ~/.var/app/<app>/config/heroic. El parche escanea ambas.
#     2) Rueda del raton - la lista estaba paginada, asi que ui.scroll nunca
#        desbordaba. Los paneles NO reciben el hook onScroll (es exclusivo de
#        los widgets de barra), asi que la lista se renderiza entera dentro de
#        ui.scroll y su prop onScroll(offset, maxOffset) mapea el
#        desplazamiento sobre la seleccion. Requiere plugin_api = 21.
#     3) Atajos Steam/Heroic en Flatpak - los iconos de la cabecera del panel
#        "original" lanzan flatpak run com.valvesoftware.Steam y
#        flatpak run com.heroicgameslauncher.hgl en lugar de la instalacion
#        nativa: Flatpak exporta el mismo id de .desktop, asi que gio launch
#        sobre /usr/share/applications acabaria siempre en la version nativa.
#     4) Mando - el evento IPC "nav" traduce up/down/left/right/enter/back/
#        pageup/pagedown sobre la seleccion de la vitrina y de "Examinar"
#        (left/right ciclan pestaña con cycleTab). Lo alimenta
#        ~/.local/bin/gamepad-noctalia.py, que ademas abre/cierra el panel
#        con Start (equivalente a Mod+Z).
#     5) Hover - onCardHover ya no mueve la seleccion; solo anima. Con la
#        vitrina animada el cursor quieto re-evaluaba hover en cada repintado
#        y pisaba el desplazamiento del teclado y del mando.
#
#   wallpaper-widget (ashur-d/wallpaper-widget)
#     Rueda del raton en el panel - igual que arriba: los paneles no reciben
#     onScroll, y ui.scroll es solo vertical mientras el carrusel es
#     horizontal. El scroll se deja con un espaciador guia que sigue al offset
#     (así las tarjetas quedan ancladas y la rueda sirve en las dos
#     direcciones) y su onScroll pasa el delta a stepSelection().
#     Requiere plugin_api = 21 y el panel agrandado a 1260x560.
set -euo pipefail

PATCH_ROOT="$HOME/.local/state/noctalia/patches"
MAT_ROOT="$HOME/.local/state/noctalia/plugins/materialized/community"
SRC_ROOT="$HOME/.local/state/noctalia/plugins/sources"

# Cada entrada es: plugin|binario a recompilar (vacio = no compilar)
PLUGINS=(
    "game-launcher|gamelauncher"
    "wallpaper-widget|"
)

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

fail=0

# Noctalia reconstruye la carpeta materializada desde repos git locales
# (sources/<fuente>/repo) EN CADA ARRANQUE, asi que ademas de restaurar los
# archivos materializados hay que dejar los parches commiteados en la fuente;
# si no, el proximo reinicio los revierte. Se recompone un commit local
# encima del HEAD actual (funciona tambien con clones parciales y sin red).
commit_pin_to_sources() {
    local plugin="$1" patch_dir="$2" repo br tree new sha rel f changed
    for repo in "$SRC_ROOT"/*/repo; do
        [[ -d "$repo" ]] || continue
        git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || continue
        git -C "$repo" ls-tree -d --name-only HEAD "$plugin" 2>/dev/null | grep -qx "$plugin" || continue
        git -C "$repo" read-tree HEAD 2>/dev/null || continue
        changed=0
        while IFS= read -r -d '' f; do
            rel="${f#"$patch_dir"/}"
            sha="$(git -C "$repo" hash-object -w "$f" 2>/dev/null)" || continue
            git -C "$repo" update-index --add --cacheinfo "100644,$sha,$plugin/$rel" 2>/dev/null || continue
            changed=1
        done < <(find "$patch_dir" -type f -print0)
        [[ "$changed" -eq 1 ]] || continue
        tree="$(git -C "$repo" write-tree --missing-ok 2>/dev/null)" || continue
        [[ "$tree" != "$(git -C "$repo" rev-parse 'HEAD^{tree}' 2>/dev/null)" ]] || continue
        new="$(git -C "$repo" -c user.name='parches locales' -c user.email='local@localhost' \
                commit-tree "$tree" -p HEAD -m "local: parches $plugin" 2>/dev/null)" || continue
        br="$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null)" || continue
        if git -C "$repo" update-ref "refs/heads/$br" "$new" 2>/dev/null; then
            echo "[$plugin] fuente fijada (commit ${new:0:7}, rama $br)"
        fi
    done
    return 0
}

for entry in "${PLUGINS[@]}"; do
    plugin="${entry%%|*}"
    binary="${entry#*|}"

    PATCH_DIR="$PATCH_ROOT/$plugin"
    DIR="$MAT_ROOT/$plugin"

    if [[ ! -d "$PATCH_DIR" ]]; then
        echo "AVISO: no hay parches fijados para $plugin ($PATCH_DIR)." >&2
        fail=1
        continue
    fi

    if [[ ! -d "$DIR" ]]; then
        echo "AVISO: $plugin no esta instalado, se omite ($DIR)." >&2
        fail=1
        continue
    fi

    # Los archivos fijados son de una version concreta. Si el plugin upstrean
    # avanzo de version, copiarlos encima tiraria arreglos o funciones nuevas.
    pinned="$(awk -F'"' '/^version/{print $2; exit}' "$PATCH_DIR/plugin.toml" || true)"
    current="$(awk -F'"' '/^version/{print $2; exit}' "$DIR/plugin.toml" || true)"
    if [[ -n "$pinned" && -n "$current" && "$pinned" != "$current" ]]; then
        echo "AVISO: parches de $plugin fijados para v$pinned pero el instalado es v$current." >&2
        echo "Copiarlos encima podria tirar arreglos o funciones nuevas de v$current." >&2
        if [[ "$FORCE" -eq 0 ]]; then
            echo "Si aun asi quieres continuar: reapply-noctalia-patches.sh --force" >&2
            echo "(o extrae los cambios de nuevo sobre v$current y actualiza $PATCH_DIR)" >&2
            fail=1
            continue
        fi
        echo "Continuando igualmente por --force."
    fi

    echo "[$plugin] restaurando archivos parcheados:"
    # Relative paths, so a pin can also carry files in subfolders
    # (translations/, ...). Anything missing in the pin is left alone.
    while IFS= read -r src; do
        rel="${src#"$PATCH_DIR"/}"
        mkdir -p "$DIR/$(dirname "$rel")"
        cp -f "$src" "$DIR/$rel"
        echo "  $rel"
    done < <(find "$PATCH_DIR" -type f | sort)

    if [[ -n "$binary" ]]; then
        echo -n "[$plugin] recompilando el escaner... "
        cc -O2 -o "$DIR/$binary" "$DIR/$binary.c" "$DIR/sqlite_reader.c"
        echo "OK"
    fi

    commit_pin_to_sources "$plugin" "$PATCH_DIR"

    echo
done

if [[ "$fail" -ne 0 ]]; then
    echo "Terminado con avisos (revisa arriba)." >&2
fi

echo "Listo. Recarga los plugins con: noctalia msg config-reload"
