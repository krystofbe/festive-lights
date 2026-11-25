# FestiveLights

**DE:** Eine Lichterkette für die macOS-Menüleiste und das Dock, dazu sanft fallender Schnee, der auf Fenstern liegen bleibt. Kostenlos und Open Source (MIT), Mac App Store, macOS 14 oder neuer. Die App läuft in der Sandbox, sammelt keine Daten und braucht keine Berechtigungen.

**EN:** A string of lights for the macOS menu bar and the Dock, plus gently falling snow that settles on windows. Free and open source (MIT), Mac App Store, macOS 14 or newer. The app is sandboxed, collects no data and needs no permissions.

![Screenshot](Art/preview.png)
<!-- Screenshots folgen / screenshots to follow -->

## Bauen / Build

```sh
cp Local.xcconfig.example Local.xcconfig   # Team und Signatur eintragen / set your team and signing (nicht eingecheckt / not committed)
xcodegen generate
xcodebuild -project FestiveLights.xcodeproj -scheme FestiveLights -configuration Release build
xcodebuild test -scheme FestiveLights -destination 'platform=macOS'
```

Der Standard-Build ist die App-Store-Fassung (Sandbox, ohne Bedienungshilfen). Der Code für die genauere Dock-Erkennung über die Bedienungshilfen steht hinter dem Compile-Schalter `DIRECT` (`SWIFT_ACTIVE_COMPILATION_CONDITIONS = DIRECT`) und wird nicht ausgeliefert.
The default build is the App Store variant (sandboxed, no Accessibility). The code for more precise Dock tracking via Accessibility sits behind the `DIRECT` compile flag and is not shipped.

Entwicklungsbuilds mit Debug-Auslösern: Konfiguration `Test` (`-configuration Test`).

## Lizenz / License

MIT, siehe / see [LICENSE](LICENSE).
