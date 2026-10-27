#!/usr/bin/env bash
# Installs the "Godotx Firebase" plugin (MIT, github.com/godot-x/firebase) for the release build
# only: the editor addon, the Android modules we use (core, analytics, crashlytics), and the
# gradle edits its README requires. Run after install_android_template.sh. Nothing from here is
# committed (see .gitignore), so debug builds and tests are unaffected.
set -euo pipefail

TAG="3.1.0"
SHA256="da7273def2ff744efacaab70e2ad863d65a4225ec401f5335de40a19df8170c1"
url="https://github.com/godot-x/firebase/releases/download/${TAG}/godotx_firebase.zip"

work="$(mktemp -d)"
curl -fsSL -o "$work/plugin.zip" "$url"
echo "${SHA256}  $work/plugin.zip" | sha256sum -c -
# The iOS half is most of the 73 MB; skip it.
unzip -q "$work/plugin.zip" -x 'godotx_firebase/ios/*' -d "$work/x"
root="$work/x/godotx_firebase"

mkdir -p addons android
rm -rf addons/godotx_firebase
cp -r "$root/addons/godotx_firebase" addons/
for module in firebase_core firebase_analytics firebase_crashlytics; do
  rm -rf "android/$module"
  cp -r "$root/android/$module" android/
done
cp "$root/LICENSE" addons/godotx_firebase/LICENSE

# Enable the editor plugin (its export plugin adds the dependencies and the privacy-safe manifest defaults).
if grep -q '^\[editor_plugins\]' project.godot; then
  echo "project.godot already has [editor_plugins]; edit it by hand" >&2
  exit 1
fi
printf '\n[editor_plugins]\n\nenabled=PackedStringArray("res://addons/godotx_firebase/plugin.cfg")\n' >> project.godot

# Gradle edits from the plugin README: the classpaths go in the first buildscript block, the
# plugins are applied at the very end.
gradle="android/build/build.gradle"
[ -f "$gradle" ] || { echo "missing $gradle (run install_android_template.sh first)" >&2; exit 1; }
python3 - "$gradle" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
classpaths = ("        classpath 'com.google.gms:google-services:4.4.4'\n"
              "        classpath 'com.google.firebase:firebase-crashlytics-gradle:3.0.6'\n")
if "com.google.gms:google-services" not in text:
    m = re.search(r"buildscript\s*\{.*?dependencies\s*\{\n", text, re.S)
    if not m:
        sys.exit("no buildscript { dependencies { block found in build.gradle")
    text = text[:m.end()] + classpaths + text[m.end():]
text = text.rstrip("\n") + ("\n\napply plugin: 'com.google.gms.google-services'\n"
                            "apply plugin: 'com.google.firebase.crashlytics'\n")
open(path, "w", encoding="utf-8").write(text)
PY
echo "Firebase plugin ${TAG} installed (core, analytics, crashlytics)"
