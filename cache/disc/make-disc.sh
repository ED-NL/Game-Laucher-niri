# Fotogramas pre-rotados del disco de un juego.
# $1 = carátula (puede no existir)   $2 = carpeta de salida
cover="$1"
out="$2"
mkdir -p "$out" || exit 1

# Marca de con qué portada se generó este disco: si cambia, el plugin tira
# los fotogramas y los vuelve a hacer.
printf '%s' "$cover" > "$out/src"

if [ ! -f "$out/base.png" ]; then
  if [ -n "$cover" ] && [ -f "$cover" ]; then
    magick "$cover" -resize "256x256^" -gravity center -extent 256x256 \
      \( -size 256x256 xc:black -fill white -draw "circle 128,128 128,6" \) \
      -alpha off -compose CopyOpacity -composite \
      -fill none -stroke "rgba(255,255,255,0.85)" -strokewidth 3 -draw "circle 128,128 124,128" \
      -fill none -stroke "rgba(0,0,0,0.30)" -strokewidth 2 -draw "circle 128,128 112,128" \
      -stroke none -fill "#080a0d" -draw "circle 128,128 128,116" \
      "$out/base.png" || exit 1
  else
    magick -size 256x256 xc:none \
      -fill "#1b2028" -stroke "rgba(255,255,255,0.45)" -strokewidth 2 \
      -draw "circle 128,128 128,6" \
      -stroke none -fill "#080a0d" -draw "circle 128,128 128,116" \
      "$out/base.png" || exit 1
  fi
fi

i=0
while [ "$i" -lt 24 ]; do
  if [ ! -f "$out/f$i.png" ]; then
    magick "$out/base.png" -background none -rotate $((i * 15)) \
      -gravity center -extent 256x256 "$out/f$i.png" || exit 1
  fi
  i=$((i + 1))
done
