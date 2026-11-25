#!/bin/zsh
# Baut die Direkt-Variante (Developer ID, notarisiert, Sparkle) und legt DMG und appcast.xml in einem Ausgabeordner ab.
#
#   scripts/release-direct.sh <Version> [Build]
#
# Umgebungsvariablen:
#   SPARKLE_BIN      Ordner mit generate_appcast (Sparkle-Werkzeuge), Pflicht
#   OUT_DIR          Ausgabeordner (Standard: release/<Version> im Repo)
#   NOTARY_PROFILE   optional: Name eines notarytool-Profils im Schlüsselbund (xcrun notarytool store-credentials).
#                    Ohne Profil notarisiert Xcode über das angemeldete Konto (Export mit destination upload, dann exportNotarizedApp).
#   AUTH_KEY_PATH, AUTH_KEY_ID, AUTH_ISSUER_ID   optional: App-Store-Connect-API-Schlüssel statt Xcode-Konto
#   DRY_RUN=1        Archiv, DMG und appcast mit der Entwicklungssignatur, ohne Export und Notarisierung (nur zum Prüfen der Kette)
# Team-ID und Signatur kommen aus Local.xcconfig (DEVELOPMENT_TEAM), nichts davon steht im Repo.
set -euo pipefail

VERSION=${1:?Aufruf: release-direct.sh <Version> [Build]}
BUILD=${2:-2}
ROOT=${0:A:h:h}
: "${SPARKLE_BIN:?SPARKLE_BIN setzen (Ordner mit generate_appcast)}"
OUT=${OUT_DIR:-$ROOT/release/$VERSION}
TEAM=$(sed -n 's/^DEVELOPMENT_TEAM *= *//p' "$ROOT/Local.xcconfig" | tr -d ' ')
[[ -n $TEAM ]] || { echo "DEVELOPMENT_TEAM fehlt in Local.xcconfig" >&2; exit 1; }
DOWNLOAD_PREFIX="https://github.com/krystofbe/festive-lights/releases/download/$VERSION/"

AUTH=()
[[ -n ${AUTH_KEY_PATH:-} ]] && AUTH=(-authenticationKeyPath "$AUTH_KEY_PATH" -authenticationKeyID "$AUTH_KEY_ID" -authenticationKeyIssuerID "$AUTH_ISSUER_ID")

rm -rf "$OUT"; mkdir -p "$OUT/dmg"
echo "== Projekt erzeugen"
command -v xcodegen >/dev/null && (cd "$ROOT" && xcodegen generate >/dev/null) || echo "(xcodegen nicht gefunden, vorhandenes Projekt wird genutzt)"

echo "== Archiv"
xcodebuild archive -project "$ROOT/FestiveLights.xcodeproj" -scheme FestiveLights-Direct -configuration Release \
  -archivePath "$OUT/FestiveLights.xcarchive" -allowProvisioningUpdates "${AUTH[@]}" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" | tail -3

APP="$OUT/export/FestiveLights.app"
if [[ -n ${DRY_RUN:-} ]]; then
  echo "== DRY_RUN: kein Export, keine Notarisierung"
  mkdir -p "$OUT/export"; cp -R "$OUT/FestiveLights.xcarchive/Products/Applications/FestiveLights.app" "$APP"
else
  DEST=upload; [[ -n ${NOTARY_PROFILE:-} ]] && DEST=export   # mit notarytool nur exportieren, sonst lädt Xcode zur Notarisierung hoch
  cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>developer-id</string>
<key>teamID</key><string>$TEAM</string>
<key>signingStyle</key><string>automatic</string>
<key>destination</key><string>$DEST</string>
</dict></plist>
PLIST
  if [[ -n ${NOTARY_PROFILE:-} ]]; then
    echo "== Export (Developer ID)"
    xcodebuild -exportArchive -archivePath "$OUT/FestiveLights.xcarchive" -exportOptionsPlist "$OUT/ExportOptions.plist" \
      -exportPath "$OUT/export" -allowProvisioningUpdates "${AUTH[@]}" | tail -3
    echo "== Notarisierung (notarytool)"
    ditto -c -k --keepParent "$APP" "$OUT/FestiveLights-notarize.zip"
    xcrun notarytool submit "$OUT/FestiveLights-notarize.zip" --keychain-profile "$NOTARY_PROFILE" --wait
    rm -f "$OUT/FestiveLights-notarize.zip"
  else
    echo "== Export und Notarisierung über Xcode"
    xcodebuild -exportArchive -archivePath "$OUT/FestiveLights.xcarchive" -exportOptionsPlist "$OUT/ExportOptions.plist" \
      -exportPath "$OUT/upload" -allowProvisioningUpdates "${AUTH[@]}" | tail -3
    echo "   (Notarisierung läuft bei Apple, warte auf das Ergebnis)"
    until xcodebuild -exportNotarizedApp -archivePath "$OUT/FestiveLights.xcarchive" -exportPath "$OUT/export" "${AUTH[@]}" >/dev/null 2>&1; do sleep 30; done
  fi
  echo "== Ticket anheften"
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
fi

echo "== DMG"
STAGE="$OUT/dmg-stage"; rm -rf "$STAGE"; mkdir -p "$STAGE"
ditto "$APP" "$STAGE/FestiveLights.app"
DMG="$OUT/dmg/FestiveLights-$VERSION.dmg"
if command -v create-dmg >/dev/null; then
  # Gestaltetes Fenster mit Hintergrund aus Art/dmg (660 x 420, @1x/@2x als TIFF)
  create-dmg --volname "FestiveLights" --background "$ROOT/Art/dmg/background.tiff" --window-pos 200 120 --window-size 660 448 \
    --icon-size 96 --text-size 13 --icon "FestiveLights.app" 175 140 --hide-extension "FestiveLights.app" \
    --app-drop-link 485 140 --no-internet-enable "$DMG" "$STAGE" >/dev/null
else
  echo "(create-dmg fehlt, schlichte DMG: brew install create-dmg)"
  ln -s /Applications "$STAGE/Programme"
  hdiutil create -volname "FestiveLights" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
fi
rm -rf "$STAGE"

echo "== appcast.xml"
"$SPARKLE_BIN/generate_appcast" --account festivelights --download-url-prefix "$DOWNLOAD_PREFIX" -o "$OUT/appcast.xml" "$OUT/dmg"
mv "$DMG" "$OUT/"; rmdir "$OUT/dmg"
cp "$OUT/FestiveLights-$VERSION.dmg" "$OUT/FestiveLights.dmg"   # feste URL releases/latest/download/FestiveLights.dmg

echo "== Prüfung"
spctl -a -vv "$APP" 2>&1 || true
xcrun stapler validate "$APP" 2>&1 || true
echo "Ausgabeordner: $OUT"
echo "DMG: $OUT/FestiveLights-$VERSION.dmg"
echo "Appcast: $OUT/appcast.xml"
