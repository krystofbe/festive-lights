# FestiveLights: Grafiken

Alle Grafiken sind eigene, mit dem Auftraggeber abgestimmte Entwürfe. Maßgeblich für das Aussehen ist das Zielbild `preview.png`. Die Angaben hier beschreiben, wie die Teile zusammengehören.

## Farbpalette (sRGB, vom Auftraggeber freigegeben)

| Name | Hex |
|---|---|
| Rot | #ED453D |
| Gelb | #FABD33 |
| Grün | #45C76B |
| Blau | #4099F2 |
| Lila | #A866ED |
| Warmweiß (Modus "warmweiß") | #FFE7B8 |

Reihenfolge an der Kette: rot, gelb, grün, blau, lila, dann von vorn.

## Glühbirne (klassische C9-Form)

Vier Vektor-Ebenen, jeweils 24 × 40 pt auf derselben Leinwand. Koordinatenursprung links oben, der Aufhängepunkt am Kabel ist die Mitte der Fassungsoberkante bei (12, 0).

| Datei | Inhalt | Darstellung |
|---|---|---|
| `bulb-socket.pdf` | Fassung | dunkelgrau; auf dunklem Untergrund mit feiner heller Kante wie im Zielbild |
| `bulb-body.pdf` | Glaskörper als Form | in der Birnenfarbe gefüllt |
| `bulb-outline.pdf` | Kontur des Glaskörpers | sichtbar dunkler als die Birnenfarbe |
| `bulb-highlight.pdf` | Glanzlicht | weiß, halbtransparent |

Leuchten: weicher, runder Schein in der Birnenfarbe um den Glaskörper, er reicht etwa eine Birnenhöhe weit und läuft nach außen aus (siehe Zielbild). Eine gedimmte Birne verliert den Schein und wird deutlich dunkler, bleibt aber erkennbar.

Die Birne darf beliebig skaliert und um den Aufhängepunkt gedreht werden. Das Kabel ist eine schlichte Linie, auf dunklem Untergrund hellgrau, auf hellem dunkelgrau. Maßgeblich ist das System-Erscheinungsbild (hell/dunkel).

## Schnee

- Überwiegend weiche, runde Flocken, gezeichnet: weißer Kern mit leichtem weißen Schein. Größe und Deckkraft wachsen mit der Nähe (nah groß und hell, fern klein und blass).
- Nur einzelne der vordersten, größten Flocken sind Kristalle: `snowflake-crystal.pdf` (weiß, 20 × 20 pt), skaliert und leicht gedreht, langsam rotierend.
- Immer mit dezentem dunklen Schatten, damit sie auch auf hellem Untergrund sichtbar bleiben (siehe unterer Streifen im Zielbild).

## App-Icon

`AppIcon-1024.png` (macOS-Raster, Form und Schatten enthalten). Daraus alle benötigten Größen erzeugen.

## Menüleisten-Symbol (bunt, dezent animiert)

18 × 18 pt, als Ebenen jeweils für helle und dunkle Menüleiste:

- `menubar-cable-light.pdf` / `menubar-cable-dark.pdf`: das Kabel
- `menubar-bulb1-*.pdf` (rot), `menubar-bulb2-*.pdf` (grün), `menubar-bulb3-*.pdf` (blau): die drei Birnen samt Schein. Die `-dark`-Varianten haben einen hellen Rand an der Fassung.
- `menubar-icon-light@2x.png` / `menubar-icon-dark@2x.png`: zusammengesetzte Vorschau.

Das Symbol bleibt farbig und wird vom System nicht einfarbig umgefärbt. Die Variante (hell oder dunkel) folgt dem Erscheinungsbild der Menüleiste. Animation: Die drei Birnen glimmen nacheinander sanft etwas heller und dunkler, ein ruhiger Durchgang dauert einige Sekunden. Bei "Bewegung reduzieren" steht das Symbol still.
