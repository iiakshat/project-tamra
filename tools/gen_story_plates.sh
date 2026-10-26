#!/usr/bin/env bash
# Empty background plates for the animated story: each story panel recreated with
# no characters (they are separate cut-outs animated on top). Skips existing plates.
cd "$(dirname "$0")/.."
while IFS=$'\t' read -r id extra; do
  [ -z "$id" ] && continue
  out=art_src/story/plates/$id.png
  [ -f "$out" ] && continue
  python -I tools/gen_image.py "$out" "Recreate this exact image: same composition, camera, environment, colours and flat 2D style, but completely EMPTY of people and creatures: remove every character and fill the space they covered with the matching background so nothing looks cut out. $extra No text, no glow, no orange or yellow lighting." --ref art_src/story/$id.png --aspect 16:9 --size 2K || echo "FAILED $id"
done < art_src/story/plates.tsv
echo plates done
