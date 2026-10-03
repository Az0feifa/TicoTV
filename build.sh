#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Az0feifa <https://github.com/Az0feifa>
# Compila TicoTV.app (firmada con App Sandbox + Hardened Runtime)
#   ./build.sh                 -> solo la app
#   ./build.sh --instaladores  -> app + .dmg + .pkg + SHA256SUMS en ./Instalador
set -euo pipefail
setopt null_glob
cd "$(dirname "$0")"
export COPYFILE_DISABLE=1          # sin archivos ._* (AppleDouble)
APP="TicoTV.app"
VER="5.0"

rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
SRC=(TicoTV.swift Pluto.swift Model.swift Components.swift Views.swift Providers.swift Features.swift Prov_*.swift)
swiftc -parse-as-library -O "${SRC[@]}" -o "$APP/Contents/MacOS/TicoTV" -framework SwiftUI -framework AVKit -framework MediaPlayer

# Ícono: se regenera si cambia el logo (assets/logo-original.png) o icon.swift
if [ ! -f AppIcon.icns ] || [ assets/logo-original.png -nt AppIcon.icns ] || [ icon.swift -nt AppIcon.icns ]; then
  T=$(mktemp -d); swiftc -O icon.swift -o "$T/mkicon" -framework AppKit && "$T/mkicon" assets/logo-original.png "$T/icon.png"
  cp "$T/icon.png" assets/icon-1024.png
  mkdir -p "$T/AppIcon.iconset"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$T/icon.png" --out "$T/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$T/icon.png" --out "$T/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$T/AppIcon.iconset" -o AppIcon.icns; rm -rf "$T"
fi
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
 <key>CFBundleName</key><string>TicoTV</string>
 <key>CFBundleDisplayName</key><string>TicoTV</string>
 <key>CFBundleIdentifier</key><string>com.az0feifa.ticotv</string>
 <key>CFBundleExecutable</key><string>TicoTV</string>
 <key>CFBundleIconFile</key><string>AppIcon</string>
 <key>CFBundlePackageType</key><string>APPL</string>
 <key>CFBundleShortVersionString</key><string>$VER</string>
 <key>NSHumanReadableCopyright</key><string>Creado por Az0feifa · github.com/Az0feifa</string>
 <key>CFBundleVersion</key><string>40</string>
 <key>LSMinimumSystemVersion</key><string>14.0</string>
 <key>NSHighResolutionCapable</key><true/>
 <key>LSApplicationCategoryType</key><string>public.app-category.entertainment</string>
 <key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoadsForMedia</key><true/></dict>
</dict></plist>
EOF

# Limpieza y permisos del bundle
xattr -cr "$APP"
find "$APP" \( -name '.DS_Store' -o -name '*.bak' -o -name '*.swift' \) -delete
chmod -R u=rwX,go=rX "$APP"

# Entitlements mínimos: App Sandbox + solo red saliente
cat > TicoTV.entitlements <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
 <key>com.apple.security.app-sandbox</key><true/>
 <key>com.apple.security.network.client</key><true/>
</dict></plist>
EOF
plutil -lint TicoTV.entitlements >/dev/null

# Firma ad-hoc con Hardened Runtime (sin --deep: no hay código anidado)
codesign --force --sign - --options runtime --timestamp=none --entitlements TicoTV.entitlements "$APP"
codesign --verify --strict --verbose=1 "$APP"
codesign -d --entitlements - "$APP" 2>/dev/null | grep -q app-sandbox
echo "Listo: $(pwd)/$APP"

if [ "${1:-}" = "--instaladores" ]; then
  mkdir -p Instalador
  rm -f Instalador/TicoTV-*.dmg Instalador/TicoTV-*.pkg Instalador/SHA256SUMS

  # DMG de solo lectura (UDZO), firmado ad-hoc (sello de integridad)
  T=$(mktemp -d); chmod 755 "$T"
  ditto --norsrc --noextattr "$APP" "$T/$APP"
  ln -s /Applications "$T/Aplicaciones"
  hdiutil create -volname "TicoTV" -srcfolder "$T" -ov -format UDZO "Instalador/TicoTV-$VER.dmg" >/dev/null 2>&1
  hdiutil verify "Instalador/TicoTV-$VER.dmg" >/dev/null 2>&1
  codesign --force --sign - --timestamp=none "Instalador/TicoTV-$VER.dmg"
  rm -rf "$T"

  # PKG: raíz 0755, root:wheel, NO reubicable, destino fijo /Applications, sin scripts
  P=$(mktemp -d); chmod 755 "$P"
  ditto --norsrc --noextattr "$APP" "$P/$APP"
  CPD=$(mktemp -d); CP="$CPD/component.plist"
  pkgbuild --analyze --root "$P" "$CP" >/dev/null
  /usr/libexec/PlistBuddy -c 'Delete :0:BundleIsRelocatable' "$CP" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c 'Add :0:BundleIsRelocatable bool false' \
                          -c 'Set :0:BundleIsVersionChecked true' \
                          -c 'Set :0:BundleHasStrictIdentifier true' \
                          -c 'Set :0:BundleOverwriteAction upgrade' "$CP"
  pkgbuild --root "$P" --component-plist "$CP" \
    --install-location /Applications --ownership recommended \
    --identifier com.az0feifa.ticotv --version "$VER" \
    "Instalador/TicoTV-$VER.pkg" >/dev/null
  rm -rf "$P" "$CPD"

  # Comprobaciones automáticas del pkg
  # Nota: macOS agrega el atributo protegido com.apple.provenance a todo archivo creado localmente
  # (no se puede borrar). pkgbuild lo guarda como entradas ._*; el Instalador las vuelve a unir como
  # atributo y NO crea archivos ._ en disco. Se verifica que el contenido sea solo ese atributo.
  XA=$(mktemp -d); pkgutil --expand-full "Instalador/TicoTV-$VER.pkg" "$XA/x" >/dev/null
  for f in $(cd "$XA/x/Payload" && find . -name '._*'); do
    strings "$XA/x/Payload/$f" | grep -v -E '^(Mac OS X|ATTR|com\.apple\.provenance)' | grep -q . && { echo "ERROR: atributo inesperado en $f"; exit 1; }
  done
  rm -rf "$XA"
  XD=$(mktemp -d); pkgutil --expand "Instalador/TicoTV-$VER.pkg" "$XD/x"
  [ ! -d "$XD/x/Scripts" ] || { echo "ERROR: el pkg tiene scripts"; exit 1; }
  lsbom "$XD/x/Bom" | head -1 | grep -q $'^\\.\t40755\t0/0' || { echo "ERROR: raíz del pkg no es 0755 root"; exit 1; }
  grep -q 'relocatable="false"' "$XD/x/PackageInfo" || { echo "ERROR: pkg reubicable"; exit 1; }
  rm -rf "$XD"

  # Sumas SHA-256 para verificar los instaladores
  ( cd Instalador && shasum -a 256 "TicoTV-$VER.dmg" "TicoTV-$VER.pkg" > SHA256SUMS && shasum -a 256 -c SHA256SUMS )
  echo "Instaladores en: $(pwd)/Instalador"
  echo "Instalar (queda como root, con recibo):  sudo installer -pkg Instalador/TicoTV-$VER.pkg -target /"
fi
