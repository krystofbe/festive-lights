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

## Menüleisten-Symbol (schwarzweiß, dezent animiert)

18 × 18 pt, schwarz als Vorlage (Template): Das System färbt es passend zur Menüleiste ein, wie die übrigen System-Symbole. Motiv: ein Kabelbogen mit zwei gefüllten Birnen.

- `menubar-icon.pdf`: das komplette Symbol
- `menubar-cable.pdf`, `menubar-bulb-left.pdf`, `menubar-bulb-right.pdf`: dieselben Teile als Ebenen für die Animation

Animation: Die beiden Birnen glimmen abwechselnd sanft etwas schwächer (Deckkraft bis etwa 55 %) und wieder voll, ein ruhiger Durchgang dauert einige Sekunden. Das Kabel bleibt stehen. Bei "Bewegung reduzieren" steht das Symbol still.

## Stil "Tanne" (Ordner `Tanne/`)

Zwei weitere Stile neben dem klassischen: **"Tanne bunt"** und **"Tanne warmgold"**. Zielbild ist `Tanne/garland-preview.png`. Statt des schlichten Kabels hängt eine natürliche Tannengirlande, das Kabel ist dunkelgrün und nur stellenweise zwischen den Zweigen zu sehen. Die Birnen sind schlanke Mini-Kerzenbirnen wie bei einer klassischen Innen-Lichterkette.

**Zweige** (PNG @2x, Leinwand 150 × 175 pt, Ansatzpunkt (40, 12), der Zweig wächst nach rechts unten; für die Gegenrichtung waagerecht spiegeln, leicht drehen erlaubt):

| Dateien | Schicht | Verwendung |
|---|---|---|
| `fir-back-1…4.png` | hinten, dunkel | dicht entlang der ganzen Girlande, abwechselnd nach links und rechts |
| `fir-mid-1…4.png` | Mitte | entlang der Girlande, etwas weniger dicht |
| `fir-hang-1…3.png` | Mitte, lang hängend | etwa jeder fünfte Ansatzpunkt, gibt der Girlande die unregelmäßige Unterkante |
| `fir-front-1…3.png` | vorn, hell mit frischen Spitzen | sparsam, zwischen den Birnen |

Reihenfolge von hinten nach vorn: hintere Zweige, mittlere und hängende Zweige, Kabel, vordere Zweige, Birnen, Zapfen, Schleifen. Die Birnen liegen vor dem Grün, damit sie gut sichtbar bleiben. Zufällige, aber stabile Auswahl, Spiegelung und Drehung je Ansatzpunkt, damit sich nichts sichtbar wiederholt.

**Mini-Birne** (8 × 28 pt, Aufhängepunkt Mitte oben (4, 0), Spitze unten):

| Datei | Inhalt | Darstellung |
|---|---|---|
| `minibulb-socket.pdf` | Fassung | dunkelgrün, unverändert |
| `minibulb-glass.pdf` | Glasröhre als Form | in der Birnenfarbe gefüllt |
| `minibulb-outline.pdf` | Kontur | Birnenfarbe deutlich dunkler |
| `minibulb-shine.pdf` | Glühfaden, Lichtverlauf, Glanzlinie | darüber, unverändert |

Leuchten: weicher Schein in der Schein-Farbe, Mitte etwa 60 % der Birnenlänge unterhalb der Fassung, Radius etwa eine Birnenlänge.

**Farben:**

| Stil | Birne | Schein |
|---|---|---|
| Tanne warmgold | #FFC766 | #FFB547 |
| Tanne bunt, reihum | rot #E8432F, gelb #F5A623, blau #7FB4D8, grün #5FC25A | rot #FF6A3D, gelb #FFB547, blau #BFE0FF, grün #9CF08A |

**Zapfen** `pinecone.pdf` (24 × 40 pt, Aufhängepunkt (12, 6)): in beiden Tannen-Stilen, etwa einer pro Bogen, hängt knapp unter der Girlande.

**Schleife** `bow.pdf` (40 × 34 pt, Mitte des Knotens bei (20, 12)): nur bei "Tanne warmgold", an jedem Aufhängepunkt der Bögen.
