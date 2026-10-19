#!/bin/bash
# Construit deux installateurs : le Vocal Pack (5 plugins) et la Suite complete (les 7).
# Entree : zips/*-macOS.zip et versions.txt ("MJ7-Tune 1.0.3"). Sortie : out/*.pkg
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
chmod +x "$here/scripts/postinstall"
rm -rf work out && mkdir -p work/parts out
suite_args=(); pack_args=()
PACK="MJ7-Vocal-Chain MJ7-Backs-Adlibs MJ7-Vocal-Booth MJ7-Tune MJ7-Live-Monitor"
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
  suite_args+=(--package "work/parts/$base.pkg")
  case " $PACK " in *" $base "*) pack_args+=(--package "work/parts/$base.pkg");; esac
done
[ ${#pack_args[@]} -eq 10 ] || { echo "Vocal Pack incomplet"; exit 1; }
productbuild "${pack_args[@]}" "out/MJ7-Vocal-Pack-Mac-Installateur.pkg"
productbuild "${suite_args[@]}" "out/MJ7-Suite-Mac-Installateur.pkg"
ls -la out
