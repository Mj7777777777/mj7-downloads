#!/bin/bash
# Construit un installateur .pkg par plugin, plus un installateur pour toute la suite.
# Entree : zips/*-macOS.zip et versions.txt ("MJ7-Tune 1.0.3"). Sortie : out/*.pkg
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
chmod +x "$here/scripts/postinstall"
rm -rf work out && mkdir -p work/parts out
suite_args=()
for z in zips/*-macOS.zip; do
  base="$(basename "$z" -macOS.zip)"                       # ex. MJ7-Tune
  ver="$(awk -v b="$base" '$1 == b { print $2 }' versions.txt)"; ver="${ver:-1.0.0}"
  id="com.mj7.$(echo "$base" | tr 'A-Z' 'a-z')"
  root="work/root-$base"; ext="work/x-$base"
  mkdir -p "$root/Library/Audio/Plug-Ins/VST3" "$root/Library/Audio/Plug-Ins/Components" "$ext"
  ditto -x -k "$z" "$ext"
  cp -R "$ext"/*.vst3 "$root/Library/Audio/Plug-Ins/VST3/"
  cp -R "$ext"/*.component "$root/Library/Audio/Plug-Ins/Components/"
  xattr -cr "$root"
  pkgbuild --analyze --root "$root" "work/$base.plist"
  python3 "$here/non_relocalisable.py" "work/$base.plist"
  pkgbuild --root "$root" --component-plist "work/$base.plist" --identifier "$id" --version "$ver" \
           --install-location / --scripts "$here/scripts" "work/parts/$base.pkg"
  productbuild --package "work/parts/$base.pkg" "out/$base-Mac-Installateur.pkg"
  suite_args+=(--package "work/parts/$base.pkg")
done
productbuild "${suite_args[@]}" "out/MJ7-Suite-Mac-Installateur.pkg"
ls -la out
