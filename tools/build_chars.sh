#!/usr/bin/env bash
# Cut the Gemini character sheets in art_src/chars into game-ready strips in
# assets/chars/<actor>/<anim>.png (+ .json). Re-run after regenerating any sheet.
# Sheets and prompts: ASSETS.md. Strip format: tools/slice_sheet.py.
set -e
cd "$(dirname "$0")/.."
S=art_src/chars
O=assets/chars
cut() { python -I tools/slice_sheet.py "$@" > /dev/null; }

H=250  # standing hero height in px (the game draws him at ~0.47 scale)
cut $S/hero_run.png     $O/hero/run.png    --grid 4x2 --height 232 --calib 1 --anchor head --even
cut $S/hero_actions.png $O/hero/idle.png   --grid 4x2 --height $H --calib 1 --pick 1 --anchor torso --pad 24
cut $S/hero_actions.png $O/hero/jump.png   --grid 4x2 --height $H --calib 1 --pick 2,3,4 --anchor torso
cut $S/hero_actions.png $O/hero/fall.png   --grid 4x2 --height $H --calib 1 --pick 7 --anchor torso
cut $S/hero_actions.png $O/hero/land.png   --grid 4x2 --height $H --calib 1 --pick 5 --anchor torso
cut $S/hero_actions.png $O/hero/hurt.png   --grid 4x2 --height $H --calib 1 --pick 6 --anchor torso
cut $S/hero_actions.png $O/hero/pant.png   --grid 4x2 --height $H --calib 1 --pick 8 --anchor torso --pad 24
cut $S/hero_strike.png  $O/hero/strike.png --grid 4x2 --height $H --calib 1 --pick 2,3,4 --anchor torso
cut $S/hero_strike.png  $O/hero/cast.png   --grid 4x2 --height $H --calib 1 --pick 5,6 --anchor torso
cut $S/hero_strike.png  $O/hero/death.png  --grid 4x2 --height $H --calib 1 --pick 7,8 --anchor mass

if [ -f $S/soldier_sheet.png ]; then
  E=330  # soldiers stand ~1.3x the hero
  cut $S/soldier_sheet.png $O/soldier/idle.png   --grid 4x2 --height $E --calib 1 --pick 1 --anchor torso --pad 24
  cut $S/soldier_sheet.png $O/soldier/run.png    --grid 4x2 --height $E --calib 1 --pick 2,3,4,5 --anchor head
  cut $S/soldier_sheet.png $O/soldier/windup.png --grid 4x2 --height $E --calib 1 --pick 6 --anchor torso
  cut $S/soldier_sheet.png $O/soldier/thrust.png --grid 4x2 --height $E --calib 1 --pick 7 --anchor torso
  cut $S/soldier_sheet.png $O/soldier/hurt.png   --grid 4x2 --height $E --calib 1 --pick 8 --anchor torso
fi
if [ -f $S/archer_sheet.png ]; then
  # The model drew 4 poses on the top row and 3 below, so figures are found as blobs:
  # 1 idle, 2 nock, 3 full draw, 4 full draw, 5 release, 6 hurt, 7 hop back.
  E=320
  cut $S/archer_sheet.png $O/archer/idle.png   --grid auto --height $E --calib 1 --pick 1 --anchor torso --pad 24
  cut $S/archer_sheet.png $O/archer/windup.png --grid auto --height $E --calib 1 --pick 2,3 --anchor torso
  cut $S/archer_sheet.png $O/archer/thrust.png --grid auto --height $E --calib 1 --pick 5 --anchor torso
  cut $S/archer_sheet.png $O/archer/hurt.png   --grid auto --height $E --calib 1 --pick 6 --anchor torso
  cut $S/archer_sheet.png $O/archer/run.png    --grid auto --height $E --calib 1 --pick 7 --anchor torso
fi
if [ -f $S/brute_sheet.png ]; then
  E=400
  cut $S/brute_sheet.png $O/brute/idle.png   --grid 4x2 --height $E --calib 1 --pick 1 --anchor torso --pad 24
  cut $S/brute_sheet.png $O/brute/run.png    --grid 4x2 --height $E --calib 1 --pick 2,3,4,5 --anchor head
  cut $S/brute_sheet.png $O/brute/windup.png --grid 4x2 --height $E --calib 1 --pick 6 --anchor torso
  cut $S/brute_sheet.png $O/brute/thrust.png --grid 4x2 --height $E --calib 1 --pick 7 --anchor torso
  cut $S/brute_sheet.png $O/brute/hurt.png   --grid 4x2 --height $E --calib 1 --pick 8 --anchor torso
fi
# Story cast: one standing figure each.
cut $S/king_ref.png $O/king/idle.png --grid 1x1 --height 600 --calib 1 --anchor torso --pad 24 --flip
[ -f $S/maa_ref.png ] && cut $S/maa_ref.png $O/maa/idle.png --grid 1x1 --height 270 --calib 1 --anchor torso --pad 24 --key magenta
echo "characters cut into $O"
python -I tools/actors_manifest.py
