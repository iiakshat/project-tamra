#!/usr/bin/env bash
# Generate the motion-comic story paintings listed in art_src/story/prompts.tsv
# (id, cast, scene). Cast names pick the reference images that keep faces consistent.
# Skips panels that already exist; delete one to regenerate it.
cd "$(dirname "$0")/.."
C=art_src/chars
declare -A REF=([hero]=$C/hero_ref2.png [maa]=$C/maa_ref.png [king]=$C/king_ref.png [soldier]=$C/soldier_ref.png)
STYLE="Story cutscene panel for a 2D mobile game. Art style: FLAT 2D illustration like a hand-made 2D animated film (paper-cut / flat vector look, like the style reference image): bold flat colour shapes, crisp clean silhouettes, layered planes, limited palette of deep indigo, violet, dusty teal and muted crimson, subtle paper grain. The characters keep the exact designs, faces, costumes and colours of the character reference images but are drawn as clean flat 2D animation characters that sit naturally in the scene, with clear emotional expressions and poses. Strictly NO realistic lighting, NO glow, NO bloom, NO light rays, NO orange or yellow lighting, NO 3D rendering, NO photorealism. Fire, if any, is drawn as flat stylised crimson-magenta shapes. Widescreen composition. No text, no speech bubbles, no panel borders."
while IFS=$'\t' read -r id cast scene; do
  [ -z "$id" ] && continue
  out=art_src/story/$id.png
  [ -f "$out" ] && continue
  refs=(--ref art_src/env/c1_far.png)
  IFS=',' read -ra names <<< "$cast"
  for n in "${names[@]}"; do refs+=(--ref "${REF[$n]}"); done
  python -I tools/gen_image.py "$out" "$scene $STYLE" "${refs[@]}" --aspect 16:9 --size 2K || echo "FAILED $id"
done < art_src/story/prompts.tsv
echo panels done
