# Entscheidungen

Wo SPEC.md offen lässt, gilt Folgendes.

## Berechtigung (Stufe 2)
- Gewählt: Bedienungshilfen (Accessibility). Damit wird der Rahmen der Dock-Symbolleiste über `AXList` des Docks gelesen. Bildschirmaufnahme wird nie verwendet.
- Fensterpositionen für F6 kommen aus `CGWindowListCopyWindowInfo` (nur Geometrie, ohne Titel). Das braucht technisch keine Berechtigung, F6 wird aber wie in der Spezifikation gemeinsam mit F5 an die Berechtigung gebunden.
- Der Button "Systemeinstellungen öffnen" löst die Systemabfrage aus (damit die App in der Liste erscheint) und öffnet die Bedienungshilfen-Seite. Beides nur auf Klick, nie von selbst.
- Berechtigungsstatus wird alle 1,5 s geprüft, im offenen Einstellungsfenster alle 0,5 s.

## Lichterkette
- Birnenhöhe in Mittelstellung = Menüleistenhöhe (mindestens 22 pt), Durchhang = eine Birnenhöhe, Birnenabstand 1,95 Birnenhöhen. Bogenzahl = Breite / (6 Birnen), Bogenlänge wird so angepasst, dass alle Bögen gleich sind.
- Skalierung der Regler: Birnengröße 0,7 bis 1,4, Abstand 0,75 bis 1,45, Tempo 0,5 bis 2,2 (jeweils Mittelstellung 1,0).
- Ausweichen: Gewicht über Abstand zu Kabel und oberem Birnenteil (smoothstep, Radius 60 pt). Zwei Federn: schnelles Heben (kritisch gedämpft, unter 0,1 s) und Senken in etwa 0,5 s mit leichtem Nachschwingen. Birnen pendeln über eine eigene schwach gedämpfte Feder.
- Deckkraft von Birne samt Schein sinkt linear mit dem Gewicht bis 30 %.
- Menüleiste automatisch ausgeblendet: Position wird über die Fensterliste (Menüleisten-Fenster) verfolgt. Bildschirme ohne Menüleiste (zum Beispiel ohne getrennte Spaces) bekommen keine Kette.
- Dunkel/hell richtet sich nach dem Erscheinungsbild des Systems. Die Fassungen bekommen im dunklen Modus eine feine helle Kante, die Gestaltung der Birnen kommt ausschließlich aus den PDF-Ebenen. Konturfarbe = dunklere Birnenfarbe, gedimmte Birne = stark abgedunkelte Farbe, Glanzlicht auf 30 %.
- Die Schein-Größe beträgt 2 Birnenhöhen Durchmesser, Mitte auf dem Glaskörper.

## Dock
- Kabel über die Breite der Symbolleiste plus 6 pt je Seite. Kante: Innenkante aus `visibleFrame`, bei automatisch ausgeblendetem Dock aus dem Symbolleistenrahmen.
- Birnenhöhe am Dock höchstens ein Viertel der Symbolgröße.
- Bei eingeschalteter Vergrößerung wird der Rahmen eingefroren, solange der Zeiger im Dock ist.
- Ein neuer Rahmen wird übernommen, sobald er 0,15 s unverändert blieb (`DockFrameStabilizer`). Abfrage 5 Hz, nach Starten oder Beenden von Apps, Bildschirm- und Dock-Einstellungsänderungen 30 Hz für 2,5 s.
- Seitliches Dock: Ausweichen hebt in Richtung Bildschirmmitte um 1,8 Birnenhöhen.

## Schnee
- Mengenstufen pro Bildschirm: 30, 55, 80, 170, 320 Flocken. Sturm: dreifach, höchstens 520 je Bildschirm.
- "Leichte Menge" beim Start: Die Menge steigt in 25 s von 30 % auf den eingestellten Wert.
- Ausweichen (Schwerkraft gewinnt immer): Flocken im Umkreis (30 bis 140 pt) werden nur seitlich verschoben (bis 0,55 Radius, glatt eingeblendet, 90 ms Trägheit), Flocken über dem Zeiger fallen langsamer (bis auf 35 %). Es gibt keine senkrechte Verschiebung und keine radiale Abstoßung (`Dodge.flow`).
- Aufstöbern (F2): Der Zeiger bewegt die Luft, nicht die Flocken (`AirField`, `Stir.Drift`). Das Zeigertempo wird aus Mausereignissen und aus dem Zeigerstand je Bild geglättet gemessen (`PointerVelocityTracker`), ein Satz von über 150 pt aus dem Stand gilt als versetzter Zeiger und zählt nicht. Ab 350 pt/s entstehen entlang der Bahn Luftpakete (Radius 45 bis 90 pt, Abstand 0,75 Radien, höchstens 40), ab 1600 pt/s mit voller Stärke. Jedes Paket ist ein Wirbelpaar (Strahl in Bewegungsrichtung mit 70 % des Zeigertempos, höchstens 1400 pt/s, seitliche Verdrängung davor, Rückströmung an den Flanken) plus ein kleiner Einzelwirbel, abwechselnd links und rechts der Bahn. Der Strahl ist ein kurzer Schwall (0,12 s), danach bleibt ein schwacher Nachlauf, der wächst, langsam weiterwandert und nach 1 s verschwunden ist. Jede Flocke nähert ihre Geschwindigkeit der Luft plus ihrem Sinken an, mit einer Relaxationszeit von 0,08 s (kleinste) bis 0,24 s (größte). Sie ist damit nie schneller als die Luft, und es gibt keine Sprünge. Aufwind hebt nur, wenn der Zeiger beim Erzeugen des Pakets deutlich aufwärts fuhr (ab etwa 20 Grad über der Waagerechten, voll ab etwa 55 Grad), dann zu 40 % und mit 0,3 s Abklingzeit. Jeder andere Aufwind bremst das Sinken höchstens auf 15 %. Kristalle drehen sich mit der halben lokalen Wirbelstärke. Bei schneller Fahrt blendet das Ausweichen aus, weil die Luftströmung die Verdrängung übernimmt. Das Feld wird nur ausgewertet, solange Pakete leben, und nur für Flocken in deren Umkreis. Mit "Bewegung reduzieren" aus.
- Aufstöbern (F6): Fährt der Zeiger schnell über die sichtbare Schneeschicht (Band 18 pt über bis 8 pt unter der Fensterkante, keine Maustaste gedrückt), entsteht pro 14 pt Bahn eine Delle (40 bis 70 % der Höhe auf 28 pt Breite) und eine kleine Wolke feiner Flocken. Die Wolke bekommt nur einen kleinen Hüpfer nach oben, mitgenommen wird sie von derselben Luftströmung wie der fallende Schnee (Relaxationszeit 0,08 s). Die Delle füllt sich durch normalen Schneefall wieder.
- Entwicklerhilfe: Im Debug-Build protokolliert `--stir-log <Datei>` je Bild den Zeiger (Zeilen `P`) und alle aufgestöberten Flocken (Zeilen `F`: Zeit, Nummer, x, y, Tiefe, Sinken, Abweichung x und y, senkrechte Geschwindigkeit, Luft x und y).
- Fallrichtung: Die Simulation rechnet mit y nach unten, die Layer der Overlays haben den Ursprung unten (`ScreenCoords`). Die Wurzel-Ebene wird nicht gespiegelt, weil das auf macOS am Hauptlayer eines Fensters nicht greift.
- Wind: 38 pt/s mit Böen. Sturm bei "Wind aus" weht nach rechts.
- Etwa 70 % der vordersten Flocken (Tiefe über 0,9) sind Kristalle.
- Sturm: Hülle in `StormEnvelope`, nicht gespeichert, Menüeintrag als Schalter.
- Mit "Bewegung reduzieren" ist der Sturm nicht startbar (Menüeintrag deaktiviert).

## Schneeschicht (F6)
- Ecken: Die Schicht folgt der sichtbaren Fensterform. Der Eckenradius ist pro macOS-Version festgelegt (`WindowCorners`): 26 pt ab macOS 26, sonst 10 pt. Der Wert 26 stammt aus einer Messung am Testrechner (Fensterecke, Pixelprofil: Kante liegt bei 4 pt Seitenabstand 12 pt, bei 14 pt 3 pt neben der geraden Kante). Die Schicht liegt auf der Rundung und wird zur Ecke hin dünn (smoothstep bis 1,4 Radien). Alle 15 bis 45 s rutscht an einer sichtbaren Ecke Schnee ab (55 % der Höhe auf 1,6 Radien, 14 Flocken).
- Höhenprofil in 4-pt-Spalten, maximal 12 pt. Jeder Treffer einer Flocke erhöht einen weichen Hügel, die Wirkung wird zum Maximum hin schwächer. Der Wert pro Treffer ist auf die Bildschirmgröße normiert, sodass bei Standardmenge nach etwa 5 Minuten die Schicht voll ist.
- Sichtbare Kanten: Oberkante abzüglich Abschnitte, die von Fenstern davor verdeckt sind. Fenster ohne Ebene 0, kleiner als 140 x 80, Vollbild-Fenster und Fenster unterhalb der Menüleiste-Kante ("maximiert") bekommen keinen Schnee.
- Schütteln: Richtungswechsel bei mindestens 30 pt Ausschlag, 3 in 1 s schärfen, danach nimmt jeder weitere Wechsel ein Drittel weg (`ShakeDetector`).
- Verschieben lässt nur kosmetisch Flocken rieseln und entfernt keine Höhe.
- Fenster, die länger als 3 Abfragen fehlen (geschlossen, minimiert, anderer Space), lassen ihre Schicht herabfallen.

## Energie und System
- Energiesparen: halbe Flockenzahl, Tempo 0,8 (Schnee) beziehungsweise 0,7 (Lichter), Bildrate 30 Hz.
- Bei "Bewegung reduzieren": Dauerleuchten, kein Ausweichen und Pendeln, Schnee mit halbem Tempo ohne Böen und Pendeln (Ausweichen des Schnees bleibt), kein Sturm, Symbol steht still.
- Pause, Sperre, Ruhezustand und ausgeschaltetes Display blenden alle Fenster aus und halten die Bildschleifen an. Die Sperre wird auch beim Start aus der Sitzung gelesen.
- Bildschleife pro Bildschirm (`CADisplayLink`). Sie pausiert, wenn nichts zu animieren ist (Dauerleuchten ohne Zeigernähe, kein Schnee). Ein globaler Mausmonitor weckt sie bei Zeigernähe.
- Muster ohne Bewegung laufen mit 20 bis 30 Hz, Bewegung und Schnee mit der Bildrate des Bildschirms.

## Fenster
- Lichter und Schnee laufen in getrennten Fenstern. Die Lichterkette hat ein Fenster nur in der Größe der Kette, nicht in Bildschirmgröße.
- Ebenen: "über allen Fenstern" liegt knapp unter der Menüleiste, "nur auf dem Schreibtisch" knapp über dem Schreibtischhintergrund.
- Overlays sind für Bildschirmfotos unsichtbar (`sharingType = .none`). Für Entwicklertests schaltet `defaults write ms.blckbox.FestiveLights debugCapture -bool YES` das ab. Im Debug-Build rendert `--render-snapshots <Ordner>` die Ebenen ohne Bildschirm in PNG-Dateien.
- Ein zweiter Start öffnet über eine verteilte Benachrichtigung die Einstellungen der laufenden Instanz und beendet sich.

## Erster Start
- Willkommens-Popover und Schnee nach 3 s, nur beim allerersten Start (Willkommens-Popover). Das zweite Popover erscheint 62 s später einmalig und nur ohne Berechtigung, 45 s sichtbar.
- Popovers sind `applicationDefined`, schließen per Zeitgeber und globalem Klickmonitor und aktivieren die App nicht.

## Grafik
- App-Icon: Größen 16 bis 1024 per `sips` aus `Art/AppIcon-1024.png`.
- Menüleisten-Symbol: Ebenen aus `Art/`, 24 Bilder in 6 s (4 Bilder pro Sekunde), pro Birne ein sanfter Helligkeitsdurchgang. `menubar-icon.pdf` und die PNG-Vorschauen werden nicht verwendet.
- Flocken sind ein einziges weiches Sprite (weißer Kern, Schein, Schatten), Kristalle aus `snowflake-crystal.pdf`.

## Performance (Messung am Testrechner, Release-Build, 60 s, Mac mini 1920x1080 mit 60 Hz)
Ohne Fernsteuerung (RustDesk beendet), Mittel über 60 s in `top`:

| Zustand | WindowServer | FestiveLights |
|---|---|---|
| ohne App | 0,1 % | - |
| Lichter + Funkeln + Schnee (Standard) | 47,0 % | 3,8 % |
| Ruhezustand (Dauerleuchten, kein Schnee) | 1,7 % | 0,8 % |
| Schneesturm | 47,1 % | 5,7 % |
| 30 Fenster, mit App Standard | 44,9 % | 4,3 % |
| 30 Fenster, ohne App | 17,2 % | - |

Mit laufender RustDesk-Sitzung und dem Stand davor waren es App 7,3 % (Standard) und 6,7 % (Sturm). Die Last der App sank durch: Fensterliste nur 2 Mal pro Sekunde (60 Mal nur beim Ziehen), Muster mit etwa 22 Bildern pro Sekunde, Schnellpfad ohne Neuberechnung der Kette im Stillstand, Menüleisten-Symbol in 3 Helligkeitsstufen mit Bildwechsel nur bei echter Änderung, Bildrate nach Bedarf (Schneefall höchstens 60 Hz, 120 Hz nur bei Zeigerinteraktion).

Die WindowServer-Last bleibt über dem Ziel von 5 Prozentpunkten. Sie hängt nicht an unserem Code: Referenzmessungen mit einem winzigen Testprogramm (reine Core-Animation, keine App-Logik) ergaben auf diesem Rechner WindowServer 16,4 % für ein 10 x 10 pt großes Quadrat in einem 120 x 120 pt Fenster bei 60 Hz, 26,8 % für ein fallendes Quadrat in einem Vollbild-Fenster, 43,8 % für 80 fallende Quadrate in einem Vollbild-Fenster. Unser Schnee (47 %) liegt auf dem Niveau dieser Referenz. Die Kosten entstehen pro angezeigtem Bild und wachsen mit der veränderten Fläche, nicht mit der Flockenzahl (30 und 80 Flocken kosten gleich viel). Ob der Testrechner (vermutlich ohne GPU-beschleunigten Bildschirm) typisch ist, ist offen, auf einem MacBook mit GPU-Compositing ist deutlich weniger zu erwarten. Der Ruhezustand kostet etwa 1,6 Punkte WindowServer (Menüleisten-Symbol).

Abgleich mit SPEC §10 (Stand 8c35142, WindowServer relativ zum Referenzprogramm auf demselben Gerät, höchstens +3 Punkte, Ruhezustand höchstens +2 Punkte gegenüber ohne App): Referenz (Vollbildfenster, 80 fallende Punkte, 60 Bilder pro Sekunde) 43,8 %. Standard 47,0 % ergibt +3,2 Punkte und liegt damit knapp über dem Grenzwert, Schneesturm 47,1 % ebenso. Ruhezustand 1,7 % gegen 0,1 % ohne App ergibt +1,6 Punkte und erfüllt die Grenze. Die Messwerte wurden in getrennten Läufen genommen und schwanken um etwa einen Punkt, eine Wiederholung mit Referenz und App direkt hintereinander steht aus.

## Popover
NSPopover erschien auf macOS 26 etwa 230 pt unter dem Menüleisten-Symbol (Pfeil an richtiger x-Position). Statt dessen zeigt ein eigenes nichtaktivierendes Panel (`PopoverPanel`, Material "popover", 12 pt Ecken, Ebene "popUpMenu") den Hinweis direkt unter dem Symbol, bei Bedarf in den Bildschirm geschoben. Es nimmt keinen Fokus (geprüft: vorderste App unverändert), schließt nach 20 s bzw. 45 s oder bei Klick daneben.

## Stile "Tanne bunt" und "Tanne warmgold"
- Einstellung `chainStyle` (klassisch, firColor, firGold), Standard klassisch. Der Farbmodus erscheint nur bei klassisch. Ein Startargument `-chainStyle firGold` überschreibt die Einstellung, ohne sie zu speichern.
- Platzierung (`Garland.plan`, getestet): Ansatzpunkte alle 22 pt mal Skalierung (Skalierung = Birnenhöhe / 24). Hintere Zweige an jedem Ansatzpunkt abwechselnd gespiegelt, mittlere an 75 %, hängende an jedem fünften, vordere an 22 %. Sprite, Spiegelung und Drehung kommen aus stabilem Pseudozufall. Ein Zapfen pro Bogen, Schleifen nur bei firGold an allen Bogenenden und Aufhängepunkten.
- Zentrale Stellschrauben in `Garland`: `density` (Dichte des Grüns), `hangLength` (Länge der hängenden Zweige), `branchScale` und `hangScale`. Bei Mittelstellung ist das geschlossene Grün etwa 60 pt tief (Zweige mal 0,8) und die hängenden reichen etwa 150 pt herab (mal 0,9).
- Der Durchhang ist bei Tanne nur 0,3 Birnenhöhen (das Zielbild zeigt eine fast gerade Girlande). Das Ausweichen hebt dadurch weniger weit, Zweige, Zapfen und Schleifen blenden wie die Birnen auf 30 % ab.
- Reihenfolge von hinten nach vorn über die Einfügereihenfolge der Layer: hinten, Mitte und hängend, Kabel, vorn, Birnen, Zapfen, Schleifen.
- Mini-Birne: Glas in der Birnenfarbe, Kontur dunkler, die Ebene "shine" liegt mit 50 % Deckkraft darüber (bei voller Deckkraft verdeckt der weiße Verlauf die Farbe), gedimmt 12 %. Schein: Radius eine Birnenlänge, Mitte 60 % der Länge unterhalb der Fassung.
- Dock: schmale Girlande mit hinteren, mittleren und vorderen Zweigen (Skalierung 0,2), ohne hängende Zweige, Zapfen und Schleifen. Die Birnen sind die kleinen Mini-Birnen im üblichen Dock-Maß.
- Performance: Alle Zweige sind Layer mit geteilten Bildern und werden nur neu positioniert, wenn sich Federn bewegen. Im Stillstand kostet die Girlande nichts. Ruhezustand mit Tanne warmgold gemessen: WindowServer 1,7 %, App 0,8 % (gleich wie klassisch).

Nach dem Praxistest schlanker (SPEC Commit 4843b35): `Garland.density` 0,4, `branchScale` 0,45, `hangScale` 0,21, Zapfen und Schleifen mit 0,6, Durchhang bei Tanne 0,2 Birnenhöhen, Birnen unverändert. Gemessen am Testrechner (Tanne warmgold, Mittelstellung, dunkler Grund): dichtes Grün (mindestens 10 % der Spalten belegt) bis 22 pt unter der Menüleiste, tiefste Zweigspitzen 48 pt. Am Dock sind Ansatzpunkte fest alle 16 pt.

## Funkeln ruhiger (SPEC Commit 5aee61b)
Phasen von 6 s: In geraden Phasen dürfen nur Birnen mit gerader Nummer dimmen, in ungeraden nur die ungeraden. Benachbarte Birnen dimmen dadurch nie gleichzeitig (getestet über 150 Birnen und 150 s). Jede Birne dimmt in ihrer Phase mit Wahrscheinlichkeit 0,5 einmal für 1,5 bis 3 s, Aus- und Aufglimmen je 0,8 s mit smoothstep (bei kurzen Ereignissen kürzer). Das ergibt im Test im Mittel etwa 6 % gedimmte Birnen. Bildrate fürs Muster bleibt 22 pro Sekunde: Bei 0,8 s Übergang ändert sich die Deckkraft je Bild um höchstens etwa 8 %, das wirkt nicht stufig.

## Ausweichen als Perlenkette (SPEC Commit 32350ce)
`BeadChain` (getestet): Birnen sind Perlen mit Position entlang des Kabels (u), Feder zur Ruheposition. Zielpositionen: Perlen im Bereich der Lücke (halbe Breite = ein Birnenabstand, skaliert mit der Zeigernähe) werden an die Ränder geschoben, Nachbarn rücken mit Mindestabstand 1,5 Birnenbreiten heran und werden ein Stück mitgeschoben. An den Kettenenden stauen sich die Perlen. Wegschieben straff (24 rad/s, Dämpfung 0,8), Zurückrutschen mit 11 rad/s und Dämpfung 0,5 (Überschwingen, binnen 1 s zurück). Ein hartes Verbot von Überholen und Überlappen läuft nach jedem Feder-Schritt. Die Neigung folgt der Perlengeschwindigkeit (in Bewegungsrichtung), das Pendeln übernimmt die bestehende Pendelfeder. Das Kabel bleibt unverändert, nichts wird durchsichtig.
- Zapfen sind eine eigene Perlenkette mit größerem Mindestabstand. Schleifen bleiben an den Aufhängepunkten. Zweige biegen sich in Zeigernähe bis 0,55 rad vom Zeiger weg und federn zurück (10 rad/s, Dämpfung 0,4).
- Beim Entlangfahren wandert die Lücke mit. Eine Perle, über deren Ruheplatz der Zeiger fährt, wechselt dabei von der einen auf die andere Seite der Lücke und kommt dem Zeiger kurz nahe. Das ist so gewollt, damit die Kette nicht endlos vor dem Zeiger hergeschoben wird.
- Der Ruhezustand ist unverändert (Schnellpfad ohne Bewegung).

Zweige rutschen mit (SPEC Commit 816f73b): Die Ansatzpunkte jeder Zweigschicht sind eine eigene `BeadChain` mit Mindestabstand 8 pt. Jede Perle hat eine Ausdehnung nach links und rechts (aus den Zweig-Bildern gemessen, `Garland.extent`, mal Skalierung mal 1,2, bei gespiegelten Zweigen vertauscht). Die Zielposition hält die Nadelspitzen aus der Lücke heraus, in der Lücke ist nur das Kabel zu sehen. Verschobene Zweige drängen sich an den Rändern dichter, neigen sich nach der Rutschgeschwindigkeit und federn beim Zurückrutschen nach. Schleifen bleiben stehen.

## Menüleisten-Symbol als Vorlage (Commit d85cb19)
Das Symbol ist schwarzweiß und als Template gesetzt, das System färbt es passend ein (am Testrechner auf dunkler Menüleiste hell). Das Kabel steht, die beiden Birnen dunkeln abwechselnd in drei Stufen (100, 78, 55 %) ab, ein Durchgang dauert 8 s (32 Bilder bei 4 pro Sekunde). Ein Bild wird nur gesetzt, wenn sich die Stufen ändern (etwa ein Wechsel pro Sekunde). Bei "Bewegung reduzieren" steht das Symbol still. Eine helle Menüleiste ließ sich am Testrechner nicht schalten, ohne die Systemeinstellungen zu ändern, die helle Darstellung ist deshalb nur offscreen eingefärbt gerendert (`--render-snapshots`).

## Dock-Vergrößerung (SPEC Commit b754935)
`DockTracker` liest nur, solange der Zeiger über dem Dock ist (Bereich 140 pt um die Symbolleiste) und die Vergrößerung an ist, die Rahmen aller Symbole über die Bedienungshilfen-Schnittstelle mit 60 Hz (`AXFrame` der Kinder der Dock-Liste). Die Ruherahmen werden bei jeder Übernahme eines stabilen Dock-Rahmens gelesen. Die sichtbare Symbolgröße ergibt sich aus der Größe des Eintrags (`DockProfile.visibleSize`, am Testrechner gemessen: Eintrag 77 pt entspricht Symbol 64 pt, Eintrag 99,9 pt entspricht 78 pt, Exponent 0,75). Die Anhebung ist die sichtbare Oberkante über der Dock-Linie. Die Kette folgt der oberen Hüllkurve der Symbole (nie im Symbol, daneben mit Steigung 1,2 abfallend). Ohne Zeiger über dem Dock kostet das nichts. Die Kette endet an den Rändern der Ruhe-Symbolleiste, auch wenn das vergrößerte Dock etwas breiter wird.

## Tanne bunt neu (SPEC Commit 0240440)
Birnen reihum rot, gold, cremeweiß, gold. Statt Zapfen hängen rote und goldene Christbaumkugeln (bis zu 4 je Bogen). Jede Kugel ist ein Kind-Layer ihres Zweigs an dessen Aufhängepunkt nahe der Spitze (`Garland.tip`, 85 % des Wegs zur entferntesten Nadel, aus den Bildern gemessen, nur Zweige der Schichten hinten, Mitte, vorn), rutscht und biegt sich mit ihm und pendelt an ihrem Faden (Pendelfeder, hängt immer senkrecht). Die Platzierung hält zu jeder Birne mehr als eine Kugelbreite Abstand und zu anderen Kugeln das 1,6-fache. Am Dock gibt es keine Kugeln. "Tanne warmgold" bleibt mit Zapfen und Schleifen.

## Fenster verschwindet: Schnee bricht sofort weg
Die Schneeschicht reagierte erst nach 1,5 s (2 Abfragen pro Sekunde, drei fehlende Abfragen als Beweis). Jetzt: Klicks (Maustaste runter und hoch), App-Wechsel, Ausblenden, Beenden und Space-Wechsel lösen 2 s lang eine Abfrage mit 30 Hz aus, beim Ziehen bleibt es bei 60 Hz. Ein Fenster gilt nach zwei fehlenden schnellen Abfragen (etwa 70 ms) als weg, bei der langsamen Abfrage schon nach einer. Gemessen am Testrechner: Nach dem Klick auf den roten Knopf sind die Flocken rund 0,3 s später in der Luft. Die Schicht verschwindet sofort und bricht in bis zu 320 Flocken auseinander (jede achte ein Brocken), die aus der Form der Schicht mit eigener Schwerkraft (550 bis 950 pt/s²) unterschiedlich schnell nach unten fallen und ausblenden.

## Lichter an der Menüleiste und am Dock sind getrennt
Das Ausschalten der Menüleisten-Lichter blendete auch die Dock-Lichter aus, weil die Dock-Kette an `lightsOn` hing. Sie hängt jetzt nur noch an ihrem eigenen Schalter, der Pause, der Berechtigung und einem sichtbaren Dock.

Mini-Birnen: Die Glasröhre wird nicht mehr aus minibulb-glass.pdf und minibulb-outline.pdf gerendert (spitze Unterseite), sondern als Pfad mit gleichen Maßen (1,4 bis 6,55 pt breit, 8,5 bis 27 pt lang) und halbrundem Boden. Der Glühfaden-Verlauf (`minibulb-shine.pdf`) wird auf die runde Form beschnitten, die Fassung bleibt aus der PDF (Praxistest: Kerzen zu spitz).

## Eigener Stil für die Dock-Kette (SPEC Commit c765e84)
Einstellung `dockStyle` (wie Menüleiste, klassisch, Tanne bunt, Tanne warmgold), Standard "wie Menüleiste". `DockStyle.resolve(bar:)` liefert den Stil der Dock-Kette (getestet). Die Auswahl steht in den Lichter-Einstellungen unter dem Dock-Schalter und ist ohne Berechtigung oder bei ausgeschalteten Dock-Lichtern gesperrt. Der Farbmodus erscheint, sobald eine der beiden Ketten klassisch ist. Am Dock gelten die schmalen Tannen-Regeln unabhängig vom Stil der Menüleiste.

Runde Tannen-Birnen (Commit 36e94c7): Die Ebenen `minibulb-*.pdf` (10 x 21 pt) werden wieder direkt gerendert, die eigene Pfad-Form ist entfernt. Die Breite der Bilder folgt exakt dem Seitenverhältnis 10 zu 21, Layer und Bilder sind gleich proportioniert, es wird nicht gestreckt. Der Schein sitzt in der Mitte des Glaskörpers (14 pt unter der Fassungsoberkante) mit Radius 1,5 Birnenlängen. Kugeln halten zu jeder Birne mehr als eine halbe Kugelbreite plus eine halbe Birnenbreite plus 2 pt Abstand, der Mindestabstand der Perlen beim Ausweichen ist weiter 1,5 Birnenbreiten und wächst damit mit der neuen Breite. Klassisch ist unverändert.
