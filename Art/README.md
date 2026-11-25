# FestiveLights: Grafiken

Alle Grafiken sind eigene Entwürfe für FestiveLights und mit dem Auftraggeber abgestimmt. `preview.png` zeigt, wie alles zusammen aussehen soll.

## Farbpalette (sRGB)

| Name | Hex |
|---|---|
| Rot | #ED453D |
| Gelb | #FABD33 |
| Grün | #45C76B |
| Blau | #4099F2 |
| Lila | #A866ED |
| Warmweiß (Modus "warmweiß") | #FFE7B8 |

Reihenfolge an der Kette: rot, gelb, grün, blau, lila, dann von vorn.

## Glühbirne (Stil "Retro-Glas", C9-Form)

Vier Vektor-Ebenen, jeweils 24 × 40 pt, gleiche Leinwand, Fassungsmitte oben mittig (Aufhängepunkt am Kabel = Punkt (12, 0)):

| Datei | Inhalt | Darstellung |
|---|---|---|
| `bulb-socket.pdf` | Fassung | unverändert (dunkelgrau) |
| `bulb-body.pdf` | Glaskörper als Maske | in der Birnenfarbe füllen |
| `bulb-outline.pdf` | Kontur des Glaskörpers | Birnenfarbe 35 % Richtung Schwarz abgedunkelt |
| `bulb-highlight.pdf` | Glanzlicht | weiß, ca. 55 % Deckkraft |

Leuchten: weicher radialer Schein in der Birnenfarbe um die Mitte des Glaskörpers, Radius etwa 1,3-mal die Birnenhöhe, innen ca. 55 % Deckkraft, nach außen auf 0. Eine "aus" gedimmte Birne verliert den Schein und wird deutlich dunkler, bleibt aber erkennbar.

Die Birne darf beliebig skaliert und gedreht werden (Drehpunkt = Aufhängepunkt). Das Kabel ist eine schlichte Linie, auf dunklem Hintergrund hellgrau, auf hellem dunkelgrau.

## Schnee (Stil "Mix")

- Überwiegend weiche, runde Flocken: weißer Kern mit leichtem weißen Schein. Größe und Deckkraft wachsen mit der Nähe (nah: groß und hell, fern: klein und blass).
- Nur die vordersten, größten Flocken (etwa jede zehnte) sind Kristalle: `snowflake-crystal.pdf` (weiß, 20 × 20 pt), skaliert und leicht gedreht, langsam rotierend.
- Auf hellem Hintergrund bekommen Flocken einen dezenten dunklen Schatten, damit sie sichtbar bleiben.

## App-Icon

`AppIcon-1024.png` (macOS-Raster, Squircle mit Schatten bereits enthalten). Daraus alle benötigten Größen erzeugen.

## Menüleisten-Symbol (bunt, dezent animiert)

18 × 18 pt, jeweils als Ebenen für helle und dunkle Menüleiste:

- `menubar-cable-light.pdf` / `menubar-cable-dark.pdf`: das Kabel
- `menubar-bulb1-*.pdf` (rot), `menubar-bulb2-*.pdf` (grün), `menubar-bulb3-*.pdf` (blau): die drei Birnen samt Schein. Die `-dark`-Varianten haben einen hellen Rand an der Fassung.
- `menubar-icon-light@2x.png` / `menubar-icon-dark@2x.png`: zusammengesetzte Vorschau.

Animation: Die drei Birnen glimmen nacheinander sanft etwas heller und dunkler (ruhiger Rhythmus, mehrere Sekunden pro Durchgang). Bei "Bewegung reduzieren" steht das Symbol still. Das Symbol ist kein Template-Bild, die passende Variante (hell oder dunkel) richtet sich nach dem Erscheinungsbild der Menüleiste.
