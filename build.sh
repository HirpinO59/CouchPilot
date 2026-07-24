#!/bin/bash
# Compila e assembla build/CouchPilot.app, poi firma.
# La firma deve restare la stessa tra le build, altrimenti macOS revoca
# il permesso Accessibilità (vedi README). Identità forzabile con:
#   COUCHPILOT_SIGN_ID="Nome identità" ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

# Icona: generata da Tools/makeicon.swift, rifatta solo se il generatore è
# cambiato (compilare lo script costa più della build stessa).
ICNS="build/AppIcon.icns"
if [ ! -f "$ICNS" ] || [ Tools/makeicon.swift -nt "$ICNS" ]; then
    echo "Genero l'icona…"
    rm -rf build/AppIcon.iconset
    mkdir -p build/AppIcon.iconset
    swift Tools/makeicon.swift build/AppIcon.iconset > /dev/null
    iconutil -c icns build/AppIcon.iconset -o "$ICNS"
    rm -rf build/AppIcon.iconset
fi

APP="build/CouchPilot.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/CouchPilot "$APP/Contents/MacOS/CouchPilot"
cp Info.plist "$APP/Contents/Info.plist"
cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"
# media della guida rapida (welcome1/2/3.gif|png), se presenti
[ -d Resources ] && cp -R Resources/. "$APP/Contents/Resources/" 2>/dev/null || true
printf 'APPL????' > "$APP/Contents/PkgInfo"

IDENTITY="${COUCHPILOT_SIGN_ID:-$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')}"

if [ -n "$IDENTITY" ]; then
    codesign --force --options runtime --sign "$IDENTITY" "$APP"
    echo "Firmato con: $IDENTITY"
else
    codesign --force --sign - "$APP"
    echo "ATTENZIONE: firma ad-hoc — il permesso Accessibilità va ridato a ogni build."
fi

echo "OK: $APP"

# ./build.sh dmg → disco di installazione da allegare alle release
if [ "${1:-}" = "dmg" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Info.plist)
    STAGE=$(mktemp -d)
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"   # la scorciatoia su cui trascinare
    DMG="build/CouchPilot-$VERSION.dmg"
    rm -f "$DMG"
    hdiutil create -volname "CouchPilot" -srcfolder "$STAGE" -ov -format ULFO "$DMG" >/dev/null
    rm -rf "$STAGE"
    echo "Disco di installazione: $DMG ($(du -h "$DMG" | cut -f1))"
fi

# ./build.sh install → copia in /Applications e avvia
if [ "${1:-}" = "install" ]; then
    pkill -x CouchPilot 2>/dev/null || true
    sleep 1
    rm -rf /Applications/CouchPilot.app
    ditto "$APP" /Applications/CouchPilot.app
    echo "Installata in /Applications"
    open /Applications/CouchPilot.app
fi
