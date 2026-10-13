#!/bin/zsh
set -eu
cd "${0:A:h}"
mkdir -p dist/macOS dist/Windows
mkdir -p .tools/editor_data/export_templates/4.7.2.stable
cp .tools/export_templates/macos.zip .tools/export_templates/windows_debug_x86_64.exe .tools/export_templates/windows_release_x86_64.exe .tools/editor_data/export_templates/4.7.2.stable/
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "macOS" dist/macOS/Civilization.app
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Windows Desktop" dist/Windows/Civilization.exe
release_build=$(python3 -c 'import json; print(json.load(open("distribution/release.json"))["build"])')
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-pack "macOS" "dist/Civilization-macOS-${release_build}.pck"
.tools/Godot.app/Contents/MacOS/Godot --headless --path . --export-pack "Windows Desktop" "dist/Civilization-Windows-${release_build}.pck"
python3 scripts/package_archives.py
python3 scripts/sign_release.py
