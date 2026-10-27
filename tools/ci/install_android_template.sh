#!/usr/bin/env bash
# Installs Godot's Android gradle build template into ./android/build, exactly as the editor's
# "Project > Install Android Build Template" does. Needs the Android export templates to be
# installed already (the android.yml / release-aab.yml jobs do that).
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:?set GODOT_VERSION, e.g. 4.7.2}"
src="$HOME/.local/share/godot/export_templates/${GODOT_VERSION}.stable/android_source.zip"
[ -f "$src" ] || { echo "missing $src (install the Android export templates first)" >&2; exit 1; }

rm -rf android/build
mkdir -p android/build
unzip -q "$src" -d android/build
# The editor checks this file against its own version string before it will use the template.
printf '%s' "${GODOT_VERSION}.stable" > android/.build_version
# Godot never scans the template as project content.
: > android/build/.gdignore
echo "Android build template ${GODOT_VERSION}.stable installed in android/build"
