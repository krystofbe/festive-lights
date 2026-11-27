# FestiveLights: Spezifikation

Diese Spezifikation beschreibt Verhalten und Erlebnis aus Nutzersicht. Wie etwas technisch gelöst wird, entscheidet das Implementierungs-Team. Ausnahme sind die Rahmenbedingungen in Abschnitt 9 und die Grafikvorgaben in Abschnitt 8.

## 1. Produktidee

FestiveLights macht den Mac in der Weihnachtszeit festlich: Eine Lichterkette hängt unter der Menüleiste, Schnee rieselt über den Bildschirm. Beides reagiert auf den Mauszeiger und stört nie bei der Arbeit.

Ziel: ein Lächeln innerhalb von 10 Sekunden nach dem ersten Start, und Nutzer lassen die App die ganze Saison über an.

## 2. Gestaltungsprinzipien

1. **Liebe zum Detail vor Feature-Menge.** Wenige Dinge, die sich hochwertig und lebendig anfühlen. Nichts schaltet hart, alles blendet, schwingt oder glimmt.
2. **Nie im Weg.** Klicks, Scrollen und Drag-and-drop gehen immer durch Lichter und Schnee hindurch. Was dem Zeiger nahekommt, weicht sanft aus.
3. **Sofortige Magie.** Nach dem Start leuchtet es sofort, ohne Einrichtung und ohne modale Dialoge.
4. **Respekt vor dem Rechner.** Sparsam mit Energie, besonders im Akkubetrieb.
5. **Ruhig konfigurierbar.** Wenige, verständliche Einstellungen.

## 3. Standardwerte beim ersten Start

| Einstellung | Standard |
|---|---|
| Lichter an der Menüleiste | an |
| Stil (Menüleiste und Dock) | Tanne bunt |
| Farbmodus | bunt |
| Muster | Funkeln |
| Tempo, Größe, Abstand, Durchhang | jeweils Mittelstellung (entspricht `Art/preview.png`) |
| Ebene Lichter | über allen Fenstern |
| Schnee | an, startet 3 s nach dem App-Start mit leichter Menge (siehe Abschnitt 6) |
| Schneemenge, Flockengröße, Tempo, Ausweichen | Mittelstellung |
| Wind | aus |
| Ebene Schnee | über allen Fenstern |
| Lichter am Dock | an, Form "genau am Dock" |
| Schnee bleibt auf Fenstern liegen | an, sobald die Berechtigung erteilt ist |
| Beim Anmelden starten | aus |
| Sparmodus | Automatisch |

Alle Regler haben 5 Stufen. Die Mittelstellung ist der Standard.

## 4. Funktionen, Stufe 1 (ohne jede Berechtigung)

### F1 Lichterkette an der Menüleiste

- Ein Kabel hängt in mehreren gleichmäßigen, flachen Bögen unter der Menüleiste über die volle Bildschirmbreite. Bei Mittelstellung etwa 6 Birnen pro Bogen, Durchhang etwa eine Birnenhöhe, Birnenhöhe etwa wie die Menüleiste.
- Die Kette hängt auf jedem Bildschirm, der eine Menüleiste zeigt. Bei automatisch ausgeblendeter Menüleiste hängt sie an der Bildschirmoberkante und rutscht mit der Menüleiste nach unten, wenn diese erscheint.
- Birnen hängen gleichmäßig verteilt am Kabel, jede mit einer kleinen, zufälligen, aber stabilen Neigung (höchstens ±15 Grad).
- Farben reihum aus der Palette in `Art/README.md`. Alternativ Modus "warmweiß".
- Muster:
  - **Dauerleuchten.**
  - **Funkeln:** ruhig und gemächlich, kein Flackern. Bei Mittelstellung des Tempos sind zu jedem Zeitpunkt etwa 6 % der Birnen gedimmt, jede für 1,5 bis 3 s. Ausglimmen und Wiederaufglimmen dauern jeweils etwa 0,8 s, weich und ohne Sprung. Zwei benachbarte Birnen sind nie gleichzeitig gedimmt.
  - **Lauflicht:** Ein heller Abschnitt wandert von links nach rechts, die übrigen Birnen sind gedimmt.
  - Das Tempo wirkt auf Funkeln und Lauflicht.
- **Ausweichen** (wie bei einer echten Kette, nichts wird durchsichtig): Die Birnen sitzen beweglich am Kabel wie Perlen auf einer Schnur. Kommt der Zeiger der Kette näher als etwa 60 pt (von unten oder seitlich), schiebt er die Birnen in seiner Nähe am Kabel entlang zur Seite, weg vom Zeiger. Um den Zeiger entsteht eine Lücke von etwa zwei Birnenabständen. Die verschobenen Birnen rücken an ihre Nachbarn heran (Mindestabstand etwa eine halbe Birnenbreite), schieben diese ein Stück mit und neigen sich dabei leicht in Bewegungsrichtung. Fährt der Zeiger an der Kette entlang, wandert die Lücke mit. Das Kabel bleibt, wo es ist, die Kette hebt sich nicht. Die Reaktion beginnt innerhalb von 0,1 s, die Bewegung ist weich und träge. Entfernt sich der Zeiger, rutschen die Birnen innerhalb von etwa 0,6 s an ihre Plätze zurück, schwingen leicht über und pendeln kurz nach. Ein schnelles Durchfahren stößt die Birnen an, sie pendeln kräftiger, rutschen aber nicht weiter als bei langsamer Bewegung. Steht der Zeiger in der Menüleiste selbst, passiert nichts.
- **Durchhang (ab 1.2):** Wie tief die Bögen zwischen den Aufhängepunkten durchhängen, in 5 Stufen von "straff" bis "locker" (Englisch "Sag", "Tight" bis "Loose"). Mittelstellung ist der bisherige Durchhang (etwa eine Birnenhöhe). Stufe 1 ist fast gerade (etwa ein Fünftel davon), Stufe 5 etwa doppelt so tief wie die Mittelstellung. Der Abstand der Aufhängepunkte bleibt gleich. Girlande, Zapfen, Kugeln und Schleifen hängen am Kabel und folgen ihm. Die Höchstmaße der Tannen-Stile (Grün endet etwa 30 pt unter der Menüleiste, kein Zweig tiefer als etwa 45 pt) gelten für die Mittelstellung und verschieben sich um den zusätzlichen Durchhang. Ausweichen, Nachpendeln, Einschalt-Animation und die durchgehende Girlande über mehrere Bildschirme (F4a Punkt 8) funktionieren in jeder Stufe gleich. Der Wechsel wirkt sofort, die Kette gleitet in etwa 0,3 s in die neue Form, ohne Sprung.
- **Stil:** "Tanne bunt" (Standard), "Tanne warmgold" oder "klassisch" (wie oben), in der Oberfläche in genau dieser Reihenfolge, Aussehen siehe `Art/README.md`, Abschnitt Stil "Tanne". In den Tannen-Stilen hängt statt des Kabels eine Tannengirlande mit kleinen, runden Tropfenbirnen. "Tanne bunt" ist ein flacher, illustrierter Stil nach `Art/TanneBunt/` (dichte Girlande aus Tannenbüscheln, kleine Birnen in Creme, Rot und Gelb, Zapfen, große gemusterte Kugeln an Goldfäden, die in den Büscheln beginnen, nie am Kabel, nie an Birnen). Für "Tanne bunt" gelten Maße und Tiefe des Zielbilds `Art/TanneBunt/garland-preview.png` (Maßstab 0,3), nicht die schlanken Maße unten. "Tanne warmgold" hat goldene Birnen, Zapfen und rote Schleifen an den Aufhängepunkten. Ab 1.2 wirkt "Tanne warmgold" wie eine echte, von Hand aufgehängte Lichterkette: etwa 40 % weniger Birnen als bisher bei gleicher Einstellung "Abstand", unregelmäßig verteilt (Abstand je Birne zufällig, aber stabil, etwa ±35 % um den Mittelwert, gelegentlich zwei nah beieinander, nie zwei direkt übereinander), leicht unterschiedliche Hängetiefe und Neigung, minimale Unterschiede in Größe und Helligkeit (±10 %) und eine etwas wärmere, weichere Leuchtfarbe. Kein erkennbares Wiederholungsmuster über die Breite. Gilt an Menüleiste und Dock; Ausweichen und Nachpendeln wie bisher. Die Farben stehen durch den Stil fest, der Farbmodus gilt nur für "klassisch". Muster, Tempo, Ausweichen und Nachpendeln wirken in allen Stilen gleich: Beim Ausweichen rutschen Birnen, Zapfen und auch die Zweige samt ihrer Kugeln am Kabel zur Seite wie oben, damit in der Lücke wirklich frei ist und man dahinterliegende Fenster, Titelleisten und Tabs erkennt. In der Lücke ist nur noch das Kabel zu sehen. Die verschobenen Zweige drängen sich an den Rändern der Lücke etwas dichter, biegen sich dabei leicht und federn beim Zurückrutschen nach. Die Schleifen bleiben an den Aufhängepunkten. Beim Nachpendeln schwingen Birnen, Zapfen und Kugeln (an ihrem Faden), die Zweige wippen leicht mit. Größe skaliert die ganze Girlande, Abstand den Birnenabstand. Die Girlande ist schlank, deutlich zurückhaltender als im Zielbild (Praxistest: das Zielbild nimmt zu viel Platz weg): Bei Mittelstellung endet das Grün etwa 30 pt unter der Menüleiste, kein Zweig hängt tiefer als etwa 45 pt. Etwa 40 % der Zweigdichte des Zielbilds, die Zweige rund ein Drittel kleiner, das Kabel darf zwischen den Zweigen öfter sichtbar sein. Die Birnen bleiben gut sichtbar und so groß wie bisher, Zapfen und Schleifen werden mit den Zweigen kleiner. Klicks gehen auch durch das Grün hindurch. Dichte des Grüns und Länge der hängenden Zweige sind im Code an je einer Stelle einstellbar, weil sie nach dem ersten Praxistest noch angepasst werden.
- Ein- und Ausschalten: Die Kette blendet in etwa 0,3 s ein oder aus. Beim App-Start gehen die Birnen innerhalb von etwa 1,5 s nacheinander von links nach rechts an.

### F2 Schnee

- Schneeflocken rieseln über alle Bildschirme. Mehrere Tiefenebenen: Nahe Flocken sind größer, schneller und heller, ferne kleiner, langsamer und blasser.
- Grundregel der Physik: Die Schwerkraft gewinnt immer. Keine Flocke steigt von sich aus oder durch Ausweichen auf; Bewegungen nach oben gibt es nur gedämpft beim Aufstöbern durch einen aufwärts fahrenden Zeiger.
- Flocken pendeln leicht seitlich. Wind (aus, weht nach links, weht nach rechts) treibt sie in eine Richtung, mit gelegentlichen Böen. Bei "Wind aus" gibt es keine Böen, nur das Pendeln.
- **Ausweichen:** Um den Zeiger entsteht eine kleine schneefreie Zone. Die Flocken umströmen den Zeiger seitlich wie Wasser einen Stein: Flocken über dem Zeiger werden langsamer und weichen zur Seite aus, sie werden nie nach oben geschleudert. Die Stärke ist einstellbar.
- **Aufstöbern:** Fährt der Zeiger schnell durch fallenden Schnee, reißt er die Flocken in seiner Nähe mit: Sie werden in Bewegungsrichtung mitgerissen, überwiegend waagerecht, drehen sich, werden langsamer und rieseln nach 1 bis 2 s wieder normal. Nach oben bewegen sie sich nur, wenn der Zeiger selbst nach oben fährt, und auch dann nur kurz und gedämpft, weil die Schwerkraft sofort überwiegt. Je schneller die Bewegung, desto mehr Flocken und desto kräftiger der Wirbel. Langsame Bewegungen lösen nur das normale Ausweichen aus. Das Aufstöbern darf nie aussehen, als würde Schnee am Zeiger kleben. Maßstab ist echter Schnee in der Luft: Der Zeiger wirkt wie eine Hand, die durch Schneetreiben fährt. Er schiebt die Flocken nicht direkt an, sondern bewegt die Luft, und die Flocken folgen dieser Luft träge, mit Luftwiderstand, ohne Sprünge in Tempo oder Richtung. Hinter dem Zeiger entsteht ein kurzer Nachlauf mit kleinen Verwirbelungen, der sich nach etwa einer Sekunde beruhigt. Leichte, kleine Flocken reagieren stärker als große. Eine Flocke kann nie schneller werden als die Luft, die sie mitnimmt.
- Menge, Flockengröße und Fallgeschwindigkeit sind einstellbar. In Mittelstellung sind auf einem Bildschirm von 1470 x 956 pt etwa 80 Flocken gleichzeitig sichtbar, in der höchsten Stufe etwa das Vierfache. Andere Bildschirme bekommen dieselbe Dichte pro Fläche, höchstens aber das 2,5-Fache der Flocken dieses Bezugsbildschirms (Lastgrenzen §10).
- Flocken bleiben auf hellem und dunklem Untergrund sichtbar (dezenter dunkler Schatten, siehe `Art/preview.png`).
- Beim Ausschalten entstehen keine neuen Flocken, die vorhandenen fallen aus dem Bild oder blenden innerhalb von 3 s aus.

**Schneesturm:**
- Etwa dreifache Menge, doppeltes Tempo, kräftiger Wind mit Böen.
- Baut sich in etwa 2 s auf, endet nach 30 s oder bei erneutem Klick und klingt dann in etwa 5 s ab.
- Ist der Schnee aus, schaltet der Sturm ihn für seine Dauer ein.
- Der Sturm wird nicht gespeichert.

### F3 Ebene wählen

Lichter und Schnee lassen sich jeweils "über allen Fenstern" oder "nur auf dem Schreibtisch" (hinter allen Fenstern) anzeigen.
- Liegen Lichter und Schnee auf derselben Ebene, liegt die Kette (Kabel, Birnen, Schein, Girlande, Zapfen, Schleifen, Kugeln) immer vor dem Schnee: Fallende Flocken ziehen hinter der Kette vorbei, nie davor. Das gilt an der Menüleiste und am Dock.

### F4 Bildschirme, Spaces, Vollbild

- Lichter und Schnee sind auf allen Spaces sichtbar.
- Sie erscheinen nicht als eigene Fenster in Mission Control, im App-Umschalter oder in Fensterlisten.
- Sie erscheinen wie normaler Bildschirminhalt in Bildschirmfotos, Bildschirmaufnahmen und Bildschirmfreigaben.

### F4a Mehrere Bildschirme (ab 1.1)

Ziel: Wer zwei oder drei Monitore hat, soll sehen, dass die App dafür gemacht ist, ohne dafür etwas einstellen zu müssen.

1. **Lichter an jeder Menüleiste.** Bei "Monitore verwenden verschiedene Spaces" (Standard von macOS) hat jeder Bildschirm eine Menüleiste, also hängt an jedem eine Kette. Ist die Option aus, hat nur der Hauptbildschirm eine Menüleiste; dann hängt nur dort eine Kette, auf den anderen nicht. Wechselt die Option oder der Hauptbildschirm, passt sich die App ohne Neustart an.
2. **Schnee auf allen Bildschirmen**, auf jedem in gleicher Dichte pro Fläche und gleicher Größe in Punkt, unabhängig von Auflösung und Retina-Faktor.
3. **Scharf überall.** Lichter, Girlande und Schnee werden auf jedem Bildschirm in dessen eigenem Retina-Faktor gezeichnet und sind in Punkt gleich groß (gemischt 1x/2x, verschiedene Größen, gedrehte Bildschirme).
4. **Dock-Kette folgt dem Dock.** Springt das Dock auf einen anderen Bildschirm (bei "Dock unten" folgt es dem Zeiger), wandert die Dock-Kette binnen 1 s mit.
5. **Vollbild pro Bildschirm.** Eine Vollbild-App blendet Lichter und Schnee nur auf ihrem Bildschirm aus; die anderen Bildschirme leuchten weiter. In Allgemein schaltet "Auch in Vollbild-Apps zeigen" (Englisch "Show in full-screen apps", Standard aus, vom Zurücksetzen erfasst) das Ausblenden ab; dann bleiben Lichter und Schnee auch über Vollbild-Apps, die Kette hängt dort an der Bildschirmoberkante. Der Wechsel wirkt sofort. Ist "Auch in Vollbild-Apps zeigen" an, gilt für die Dock-Kette auf einem Bildschirm mit Vollbild-App dasselbe wie bei automatisch ausgeblendetem Dock (F5): Sie ist nur zu sehen, während das Dock dort eingeblendet ist, und fällt dabei nie auf "durchgehend" zurück (ab 1.2). Als Vollbild zählen nur Fenster normaler Apps mit Dock-Symbol. Fenster von Hintergrund- und Overlay-Apps ohne Dock-Symbol (zum Beispiel Werkzeuge, die ein durchsichtiges Fenster über den ganzen Bildschirm legen) blenden nichts aus (ab 1.2). Auf Bildschirmen mit Kerbe (MacBook mit Notch, NSScreen.safeAreaInsets.top > 0) legt macOS ein Vollbild-Fenster nicht an die Oberkante, sondern unter das Kerbenband: Es reicht dann von Oberkante plus diesem Abstand bis zur Unterkante, volle Breite (beobachtet auf macOS 26 mit Firefox-Video im Vollbild, 1728x1117: Fenster bei y 33, Höhe 1084; nur während der Übergangsanimation kurz bildschirmfüllend). Auch so ein Fenster zählt als Vollbild, ebenso Split View aus solchen Fenstern. Damit ein normal maximiertes Fenster bei ausgeblendetem Dock nicht fälschlich als Vollbild gilt, zählt diese Form nur, wenn auf dem Bildschirm zugleich der Vollbild-Hintergrund des Docks liegt: ein Fenster des Dock-Prozesses über den ganzen Bildschirm auf der Ebene -2147483622 (auf macOS 26 nur in Vollbild-Spaces vorhanden, normal liegen dort nur Ebene 20 und -2147483624). Fehlt das Signal auf anderen macOS-Versionen, bleibt es beim bisherigen Verhalten (ab 1.2.1).
6. **Anstecken und Abstecken** werden ohne Neustart und ohne Flackern übernommen, ebenso Auflösungs-, Anordnungs- und Retina-Wechsel. Beim Abstecken verschwindet alles auf dem Bildschirm sauber, ohne Reste, und der Speicher wird freigegeben.
7. **Begrüßung neuer Bildschirme.** Wird ein Bildschirm angesteckt, gehen seine Birnen nacheinander an wie beim ersten Start (F1). Nicht beim App-Start und nicht beim Aufwachen aus dem Ruhezustand.
8. **Durchgehende Girlande.** Liegen zwei Bildschirme laut Anordnung in den Systemeinstellungen nebeneinander und schließen ihre Oberkanten bündig an (höchstens 2 pt Versatz), läuft die Kette an der gemeinsamen Kante ohne Bruch weiter: gleicher Bogenrhythmus, das Kabel endet am rechten Rand des linken Bildschirms auf derselben Höhe, auf der es am linken Rand des rechten beginnt, Stil, Muster und Funkeln laufen im selben Takt. Liegen die Oberkanten nicht bündig, beginnt jede Kette für sich.
9. **Einstellung** in Allgemein: "Bildschirme" (Englisch "Displays") mit "Alle" / "Nur Hauptbildschirm" (Englisch "All" / "Main display only"), Standard "Alle". "Nur Hauptbildschirm" zeigt Lichter und Schnee nur auf dem Bildschirm mit der Hauptmenüleiste; die Dock-Kette bleibt beim Dock.
10. **Später (nicht in 1.1):** Schnee, der über Bildschirmkanten auf den Nachbarbildschirm treibt; automatische Pause auf Bildschirmen, die gerade geteilt oder präsentiert werden.

## 5. Funktionen, Stufe 2 (nach einer optionalen Berechtigung)

F5 und F6 dürfen höchstens eine optionale macOS-Systemberechtigung erfordern. Welche, entscheidet das Team. Die Bildschirmaufnahme-Berechtigung ist ausgeschlossen. Ohne Berechtigung fehlen nur F5 und F6, alles andere läuft. Wird sie erteilt, schalten sich F5 und F6 ohne Neustart ein. Wird sie entzogen, verschwinden F5 und F6 binnen 5 s ohne Dialog.

### F5 Lichterkette am Dock

- Zwei Formen, in den Einstellungen wählbar: **"genau am Dock"** (Standard) und **"durchgehend"**. In der Oberfläche heißt die Einstellung **"Länge"** mit den Optionen **"Dock-Breite"** (= genau am Dock) und **"Bildschirmbreite"** (= durchgehend), Englisch "Length": "Dock width" / "Full width". Darstellung als Segmentschalter im Bereich Dock. Bei seitlichem Dock heißen die Optionen sinngemäß "Dock-Höhe" und "Bildschirmhöhe". Das Wort "Form" taucht in der Oberfläche nicht auf.
- **Durchgehend:** Die Kette läuft über die volle Bildschirmbreite auf Höhe der Dock-Oberkante (bei seitlichem Dock über die volle Bildschirmhöhe an dessen Innenkante), in gleichmäßigen Bögen wie an der Menüleiste. Die Höhe ergibt sich aus dem freien Bildschirmbereich ohne Dock. Ist das Dock ausgeblendet, liegt die Kette am Bildschirmrand. Ausweichen wie an der Menüleiste. Der Dock-Vergrößerung folgt sie nicht. Die übrigen Regeln dieses Abschnitts gelten nur für "genau am Dock".
- **Genau am Dock** soll auch ohne Berechtigung funktionieren, einschließlich der Vergrößerung beim Überfahren. Lage, Breite, Ein- und Ausblenden und die vergrößerte Form des Docks werden dann ohne Bedienungshilfen ermittelt (zum Beispiel, indem der Fensterserver gefragt wird, wo das Dock-Fenster getroffen wird). Mit Berechtigung darf der genauere Weg über die Bedienungshilfen genutzt werden. Liefert die Ermittlung ohne Berechtigung kein plausibles Ergebnis (anderes macOS, ungewöhnliche Anordnung), fällt die Kette sanft auf "durchgehend" zurück, statt falsch zu liegen.
- Performance der Dock-Ermittlung, Teil der Abnahme: Im Ruhezustand (Zeiger nicht über dem Dock, Dock unverändert) keine laufende Abfrage, nur auf Ereignisse reagieren (App gestartet oder beendet, Dock-Einstellungen geändert, Bildschirm geändert). Während der Vergrößerung höchstens 2 ms Arbeit pro Bild auf dem Haupt-Thread, nie ein Aussetzer über 8 ms; reagiert der Fensterserver oder das Dock nicht, bricht die Abfrage sofort ab und die Kette bleibt, wo sie ist. Die Gesamtlast-Grenzen aus Abschnitt 10 gelten unverändert.
- Dock unten: Das Kabel liegt in flachen Bögen auf der Oberkante des Docks über dessen volle Breite. Die Birnen hängen nach unten und überdecken höchstens das obere Viertel der Symbole. Der Durchhang (F1) hat am Dock einen eigenen Wert; bei "genau am Dock" wirkt er nur halb so stark wie an der Menüleiste. Für die Stufen 4 und 5 gilt dort statt des oberen Viertels: Birnen und Zweige verdecken höchstens das obere Drittel der Symbole (bei Standard-Birnengröße sind 4 und 5 also sichtbar tiefer als die Mittelstellung, bei großen Birnen ggf. gleich). Bei "durchgehend" wirkt er wie an der Menüleiste.
- Dock links oder rechts: Das Kabel läuft an der Innenkante entlang, die Birnen zeigen zur Bildschirmmitte.
- Die Kette erscheint nur auf dem Bildschirm, der gerade das Dock zeigt. Ist die Dock-Vergrößerung beim Überfahren eingeschaltet, geht die Kette mit: Der Abschnitt über den vergrößerten Symbolen wölbt sich mit deren Oberkante nach oben (bei seitlichem Dock zur Bildschirmmitte), Birnen und Zweige gehen mit, und beim Verlassen senkt sich die Kette mit dem Dock wieder ab. Die Kette folgt dabei ohne sichtbare Verzögerung, höchstens ein Bild hinter dem Dock, und liegt in jeder Phase auf der Oberkante der Symbole, ohne in sie hineinzuragen oder darüber zu schweben.
- Ändert sich die Dock-Größe (Apps öffnen oder beenden, Dock-Position, Größe), liegt die Kette spätestens 0,5 s nachdem das Dock seine neue Größe erreicht hat, wieder deckungsgleich an. Abweichung höchstens 2 pt.
- Ausgeblendetes Dock: Die Kette erscheint und verschwindet mit dem Dock.
- Alle Einstellungen der Dock-Kette (Stil, Farben, Muster, Tempo, Größe, Abstand, Ebene) sind unabhängig von der Menüleisten-Kette, siehe Abschnitt 7. Bisher gespeicherte gemeinsame Werte werden beim ersten Start der neuen Version für beide Ketten übernommen, ein gespeicherter Dock-Stil "wie Menüleiste" wird zum Stil der Menüleiste. Ab 1.2.2 sieht die Dock-Kette im selben Stil genauso aus wie die Menüleisten-Kette, nur kleiner: dieselben Elemente (bei "Tanne bunt" Tannenbüschel, Birnen in Creme, Rot und Gelb, Zapfen und gemusterte Kugeln an Goldfäden; bei "Tanne warmgold" goldene Birnen, Zapfen und rote Schleifen an den Aufhängepunkten, dieselbe unregelmäßige Verteilung mit weniger Birnen; bei "klassisch" wie bisher), dieselben Verhältnisse von Birnengröße, Birnenabstand, Birnen je Bogen, Bogenform, Zweigdichte und Tiefe des Grüns, also alle stilabhängigen Werte, die bisher nur für die Menüleiste galten. Wer beide Ketten nebeneinander sieht, erkennt sofort denselben Stil. Menüleiste "Tanne bunt" (Krystof, 27.11., nach Sichtung von Varianten auf seiner Menüleiste): Die Mittelstellung des Reglers Größe entspricht der bisherigen Stufe eins kleiner (Variante G), die anderen Stufen rücken entsprechend mit; die übrigen Stile bleiben unverändert. Ausnahme nach Sichtung der Varianten auf dem echten Dock (Krystof, 27.11.): "Tanne bunt" behält am Dock das Aussehen von 1.2.1 (eigene schmale Dock-Darstellung: dichte kleine Birnen, kurze Zweige, keine hängenden Teile, keine Kugeln, Zapfen oder Schleifen, Birnen mindestens so groß wie die klassischen). Für "Tanne warmgold" gilt die gemeinsame Definition mit der Menüleiste wie folgt. Größe am Dock (mit Krystof abgestimmt): Bei Symbolgröße 64 pt und Mittelstellung des Reglers Größe ist jedes Element der Dock-Kette (Birnen, Abstände, Grün, Zapfen, Schleifen, Kugeln, Fäden, hängende Zweige) halb so groß wie bei der Menüleisten-Kette desselben Bildschirms in Mittelstellung. Die Dock-Kette wächst und schrumpft linear mit der Symbolgröße des Docks, der Regler Größe wirkt relativ dazu. Hängende Zweige und Kugeln an Fäden hängen im selben Verhältnis wie oben, sie werden am Dock nicht gekürzt und nicht angehoben und dürfen über die Symbole hängen. Die Regel mit dem oberen Viertel bzw. Drittel der Symbole gilt deshalb für die Tannen-Stile nicht mehr, nur noch für "klassisch". Künftige Änderungen an einem Stil gelten immer für beide Ketten, ein Stil hat genau eine Definition. Bisher war die Dock-Kette eine eigene, abgespeckte Darstellung (nur kurze Zweige, dichte kleine Birnen, keine Zapfen, Schleifen und Kugeln), das entfällt. Die Größe der Dock-Kette richtet sich nach der aktuellen Symbolgröße des Docks (bei Mittelstellung der Größe hängen die Birnen etwa ein Viertel der Symbolhöhe herab, der Regler Größe wirkt relativ dazu), und bei der Vergrößerung wachsen Birnen und Grün über den vergrößerten Symbolen mit. Die Menüleisten-Kette richtet sich dagegen nach der Menüleistenhöhe. Sie muss trotzdem auf einen Blick erkennbar sein: Die Birnen sind am Dock in jedem Stil mindestens so groß wie die der klassischen Dock-Kette, und das Grün ist deutlich sichtbar auf der Dock-Oberkante (bei "Tanne bunt" also nicht im Maßstab 0,3 des Zielbilds, sondern so vergrößert, dass die Birnen diese Mindestgröße erreichen), damit die Regel mit dem oberen Viertel der Symbole gilt. Dock-Lichter haben eine eigene Ein/Aus-Einstellung. Ausweichen wie F1: Die Birnen rutschen am Kabel entlang zur Seite, das Kabel bleibt am Dock.

### F6 Schnee bleibt auf Fenstern liegen

- Fallender Schnee sammelt sich auf den sichtbaren Oberkanten normaler App-Fenster, nicht auf Menüs, Popovers und Vollbild-Fenstern.
- Die Schicht wird höchstens etwa 12 pt hoch, ist weich und unregelmäßig und ist bei Standardmenge nach etwa 5 Minuten voll.
- Die Schicht folgt der sichtbaren Form des Fensters, auch den abgerundeten Ecken: Zur Ecke hin wird sie dünner und schmiegt sich an die Rundung, sie ragt nie über den Fensterrand hinaus in die Luft. Ab und zu rutscht an einer Ecke ein kleines Stück Schnee ab und fällt herunter. Der Eckenradius richtet sich nach dem tatsächlichen Erscheinungsbild der Fenster der jeweiligen macOS-Version.
- Wird ein Fenster bewegt, rieselt etwas Schnee herunter. Wird es geschlossen oder minimiert, fällt sein Schnee herab.
- **Abschütteln:** Schütteln heißt mindestens 3 Richtungswechsel beim Ziehen innerhalb von 1 s. Danach entfernt jeder weitere Richtungswechsel etwa ein Drittel des verbleibenden Schnees, bis das Fenster frei ist. Hört man auf, baut sich die Schicht wieder auf. Normales Verschieben, auch mit Korrekturbewegung, entfernt nichts.
- Herabfallender Schnee zerfällt in feine Flocken, die unterschiedlich schnell fallen und ausblenden.
- **Aufstöbern der Schicht:** Wischt der Zeiger schnell über die Schneeschicht eines Fensters, stiebt an dieser Stelle eine kleine Wolke feiner Pulverflocken auf, höchstens wenige Punkte über die Schicht, wird in Wischrichtung mitgenommen und rieselt sofort wieder herab. In der Schicht bleibt eine kleine Delle, die langsam wieder zuschneit. Langsames Darüberfahren und Klicks auf die Titelleiste stöbern nichts auf.
- Bei Schnee-Ebene "nur auf dem Schreibtisch" oder ausgeschaltetem Schnee ist F6 inaktiv, liegender Schnee schmilzt in etwa 3 s.

Alles, was in den Abschnitten 3 bis 7 nicht genannt ist, gehört nicht zum Umfang.

## 6. Erster Start, Einführung und Berechtigung

1. App startet, die Birnen der Menüleisten-Kette gehen nacheinander an (F1). Nach 3 s beginnt leichter Schnee.
2. Nach 1,5 s öffnet sich einmalig ein Einführungsfenster (normales Fenster, mittig, etwa 560 x 440 pt, nicht modal, die Lichter laufen dahinter weiter, schließbar über den roten Knopf, Esc oder "Überspringen"). Es hat mehrere Schritte mit Punkten für den Fortschritt, "Zurück" und "Weiter", auf dem letzten Schritt "Los geht's" (Englisch "Let's go"). Jeder Schritt: kleine Illustration oder Live-Vorschau oben, eine Überschrift, höchstens zwei kurze Sätze, höchstens ein Bedienelement plus der An/Aus-Schalter für das, was der Schritt vorstellt (ab 1.2). Ton warm und knapp, keine Fachbegriffe.
   - **Willkommen** (Englisch "Welcome"): "Frohe Festtage!" Ein Satz, was FestiveLights macht (Lichter an Menüleiste und Dock, Schnee auf dem Bildschirm). Darunter die drei Stile als anklickbare Karten mit kleiner Vorschau; die Wahl gilt sofort für Menüleiste und Dock.
   - **Menüleiste** (Englisch "Menu bar", ab 1.2): Illustration der Girlande unter der Menüleiste. Text sinngemäß: Die Lichter hängen unter deiner Menüleiste; fährst du mit der Maus darunter, machen sie Platz. Schalter "Lichter an der Menüleiste" (Englisch "Lights on the menu bar"), gleichbedeutend mit dem Menüpunkt, sofort wirksam.
   - **Dock** (Englisch "Dock", ab 1.2): Illustration der Lichter am Dock. Text sinngemäß: Auch dein Dock bekommt eine Lichterkette, sie folgt ihm, wenn es sich verändert. Schalter "Lichter am Dock" (Englisch "Lights on the Dock"), gleichbedeutend mit dem Menüpunkt, sofort wirksam.
   - **Schnee** (Englisch "Snow"): Schnee bleibt auf Fenstern liegen, Schütteln befreit das Fenster, schnelles Durchfahren mit dem Zeiger wirbelt ihn auf. Schalter "Schnee" (Englisch "Snow"), gleichbedeutend mit dem Menüpunkt, sofort wirksam, und Button "Schneesturm starten" (Englisch "Start a snowstorm"), der den Schneesturm aus F2 sofort startet, auch bei ausgeschaltetem Schnee.
   - **Nur Direkt-Variante, Lichter ans Dock und Schnee auf Fenstern** (Englisch "Lights on the Dock, snow on windows"): erklärt in einem Satz, was die App mit der Bedienungshilfen-Freigabe sieht (Position von Dock und Fenstern) und was nicht (keine Inhalte, keine Eingaben). Button öffnet direkt die passende Stelle in den Systemeinstellungen; der Status (erteilt/nicht erteilt) aktualisiert sich live. Der Schritt ist überspringbar.
   - **Fertig** (Englisch "All set"): Illustration der Menüleiste mit hervorgehobenem FestiveLights-Symbol. Text: Über das Symbol pausierst du alles mit einem Klick, zum Beispiel für Präsentationen, und öffnest die Einstellungen; Klicks gehen immer durch Lichter und Schnee hindurch. Schalter "Beim Anmelden starten" (Standard aus, registriert erst beim Einschalten) und Button "Los geht's", der das Fenster schließt. (Ab 1.2 ersetzt dieser Schritt den früheren Schritt "Immer erreichbar".)
3. Die Einführung erscheint nur beim allerersten Start. Im Menüleisten-Menü öffnet "Einführung..." (Englisch "Welcome Guide...") sie jederzeit wieder. "Auf Standard zurücksetzen" setzt nicht zurück, dass sie schon gezeigt wurde.
4. Das frühere Schneesturm-Popover und das zeitversetzte Berechtigungs-Popover entfallen; beides steckt jetzt in der Einführung. Wird die Freigabe in der Einführung übersprungen, fragt die App nie wieder von selbst. Der Weg bleibt über Menü und Einstellungen erreichbar.
5. Gestaltung wie DMG-Fenster und Website, unabhängig vom System-Erscheinungsbild immer in diesem warmen hellen Stil: Hintergrund Creme `#fffaf0`, oben quer über die volle Breite die Girlande aus `Art/onboarding/garland-header.png` (@1x/@2x), am unteren Rand links und rechts je ein Bäumchen (`Art/onboarding/tree.png`) auf einem flachen Schneehügel `#f3ead8`, dazwischen ein paar ruhig fallende hellblaue Schneepunkte `#9cc3dd` (dezent, im Sparmodus statisch). Überschriften in "Mountains of Christmas" Bold, Rot `#d8432f`, etwa 30 pt; Text in "Poppins", Tinte `#2b363f`, Nebentext `#5d6a72`, 13 bis 14 pt. Hauptbutton gefüllt Weinrot `#86241a` mit weißer Schrift, Kapselform; Nebenbuttons als Text in `#5d6a72`. Fortschrittspunkte: aktiv Rot, sonst `#e7dccb`. Stilkarten mit weißem Grund, 12 pt Eckenradius, ausgewählt mit rotem Rand. Die Schriften liegen mit ihren Lizenzen (Poppins OFL, Mountains of Christmas Apache 2.0) in `Art/fonts/` und werden in die App eingebettet. Zielbild: `Art/onboarding/preview.png` (Schritt Willkommen). Bedienbar mit VoiceOver (alle Bedienelemente beschriftet) und Tastatur (Tab, Return für den Hauptbutton, Esc schließt); Kontraste der Texte mindestens 4,5:1.

## 7. Bedienung

**Menüleisten-Symbol** (schwarzweiß wie die System-Symbole, Kabel mit zwei Birnen, dezent animiert, siehe `Art/README.md`) mit Menü:
- Pause (schaltet alles vorübergehend aus und mit erneutem Klick wieder ein, gespeichert bis zum Fortsetzen)
- Lichter an der Menüleiste (an/aus)
- Lichter am Dock (an/aus)
- Schnee (an/aus)
- Schneesturm
- Einführung… (Englisch "Welcome Guide…")
- Einstellungen…
- Beenden

Ein zweiter Start der App öffnet die Einstellungen (wichtig, wenn das Symbol hinter der Kamera-Aussparung verschwindet).

**Einstellungsfenster**, kompakt, vier Bereiche in dieser Reihenfolge: Allgemein, Menüleiste, Dock, Schnee. Beim Öffnen ist "Allgemein" ausgewählt. Es öffnet sich beim ersten Mal mittig auf dem Bildschirm mit der Menüleiste (horizontal mittig, vertikal im oberen Drittel, aber mindestens 120 pt unter der Menüleiste, damit die Girlande die Tabs nicht verdeckt); danach merkt es sich seine Position, solange sie auf einem vorhandenen Bildschirm liegt. Positionen, die eine Version vor 1.0.1 gespeichert hat (auch die automatische Fensterposition von AppKit), werden einmalig verworfen, damit Aktualisierer ebenfalls die mittige Position bekommen. Die Einführung öffnet ebenso mittig. Menüleisten-Kette und Dock-Kette sind vollständig getrennt einstellbar, jede in ihrem eigenen Bereich mit identischem Aufbau, damit immer klar ist, welche Einstellung welche Kette betrifft:
- **Menüleiste:** oben Schalter "Lichter an der Menüleiste", darunter (ausgegraut, wenn aus) Stil, Farben (nur sichtbar bei "klassisch"), Muster, Tempo, Größe (der ganzen Kette samt Girlande, Englisch "Size"), Abstand (der Birnen, Englisch "Spacing"), Durchhang (Englisch "Sag", Regler mit den Enden "straff" und "locker", Englisch "Tight" und "Loose"), Ebene.
- **Dock:** oben Schalter "Lichter am Dock", darunter dieselben Einstellungen wie bei der Menüleiste, eigene Werte, zusätzlich "Länge" (siehe F5). Standardwerte wie bei der Menüleiste.

- **Schnee:** gleicher Aufbau wie Menüleiste und Dock: oben der Schalter "Schnee", darunter (ausgegraut, wenn aus) Menge, Flockengröße, Tempo, Wind, Ausweichen, Ebene, "Schnee bleibt auf Fenstern liegen".
- Einheitliches Muster für alle drei Bereiche Menüleiste, Dock und Schnee: Der An/Aus-Schalter steht immer zuoberst in einer eigenen Gruppe, gleich beschriftet wie im Menü, und alle weiteren Einstellungen folgen darunter mit gleichen Abständen und gleicher Steuerelement-Art für gleiche Arten von Werten (Segmentschalter für zwei bis drei Optionen, Regler für Stufen, Auswahlmenü ab vier Optionen).
- **Allgemein:** Beim Anmelden starten, "Sparmodus" (Englisch "Low Power Mode") als Auswahl mit drei Optionen "Automatisch", "Immer", "Aus" (Englisch "Automatic", "Always", "Off") und einer grauen Erklärzeile darunter, die zur gewählten Option passt: Automatisch: "Weniger Schnee und ruhigere Animation im Stromsparmodus und bei Akkustand unter 20 %." Immer: "Weniger Schnee und ruhigere Animation, auch am Netzteil." Aus: "Volle Darstellung, auch im Akkubetrieb." Ist der Sparmodus gerade aktiv, steht dahinter "(gerade aktiv)". Danach Berechtigungsstatus mit Erklärung und Button zu den Systemeinstellungen. Unten ein Button "Auf Standard zurücksetzen": Nach einer kurzen Rückfrage im Fenster (kein Systemdialog, mit "Abbrechen" als Standard) gelten wieder alle Werte aus Abschnitt 3, sofort sichtbar und ohne Neustart. Nicht zurückgesetzt werden "Beim Anmelden starten", die erteilte Berechtigung und die Info, dass die Einführung schon gezeigt wurde. Die Schneeschichten auf Fenstern bleiben liegen, wenn "Schnee bleibt liegen" danach weiter an ist. Der Status aktualisiert sich live, während das Fenster offen ist.

**Weniger stören, weniger Optionen (ab 1.3, mit Krystof abgestimmt am 27.11.).** Ziel: festlich, aber man kann arbeiten, und der Nutzer trifft pro Bereich nur die Entscheidungen, die ihn wirklich interessieren. Sichtbar sind je Bereich nur noch:
- **Menüleiste:** Schalter, Stil, "Auftritt", Muster (bei "klassisch" zusätzlich Farben).
- **Dock:** Schalter, Stil, "Auftritt" (bei "klassisch" zusätzlich Farben).
- **Schnee:** Schalter, Menge, "Liegt auf Fenstern" (bisher "Schnee bleibt auf Fenstern liegen"), "Nur in Pausen".
- Alles andere steht je Bereich unter einem zugeklappten Abschnitt "Weitere Optionen" (Englisch "More Options"): Menüleiste und Dock Tempo, Größe, Abstand, Durchhang, Ebene, beim Dock zusätzlich Länge; Schnee Flockengröße, Tempo, Wind, Ausweichen, Ebene. Der Abschnitt ist beim Öffnen zugeklappt und merkt sich nichts.

**"Auftritt"** (Englisch "Look"), Segmentschalter "Dezent", "Festlich", "Volle Pracht" (Englisch "Subtle", "Festive", "Lavish"), je Kette eigener Wert. Er bestimmt zusammen, wie tief die Kette hängt, wie viel Schmuck sie trägt und wie groß sie ist:
- Menüleiste: Dezent = kein Teil reicht tiefer als etwa 16 pt unter die Menüleiste, kein Schmuck (keine Kugeln, Zapfen, Schleifen), Fenstertitel und Tabs bleiben frei. Festlich = höchstens etwa 30 pt tief, etwa halb so viel Schmuck (gleichmäßig ausgedünnt). Volle Pracht = Aussehen wie bisher (1.2.2), ohne zusätzliche Grenze. Was tiefer reichen würde, wird angehoben: Fäden und hängende Zweige kürzer, Durchhang flacher; reicht das nicht, entfällt das Teil. Birnen bleiben immer sichtbar.
- Dock: Dezent = verdeckt höchstens etwa ein Sechstel der Symbolhöhe, kein Schmuck. Festlich = höchstens ein Viertel, halb so viel Schmuck (bei "Tanne bunt" wie in 1.2.1, also ohne Kugeln). Volle Pracht = Aussehen wie bisher (1.2.2), bei "Tanne bunt" mit kleinen Kugeln an kurzen Fäden.
- Die genauen Werte je Stil und Stufe stehen in Anhang A am Ende dieser Datei; sie gehen den Tiefenangaben oben vor (die 16-pt- und 30-pt-Werte und "kein Schmuck" bei Dezent gelten nur, soweit Anhang A nichts anderes sagt).
- Grundsatz (Krystof, 27.11., gilt vor allen Angaben oben): Auftritt verkleinert nie. Birnen, Zweige, Kugeln, Zapfen und Schleifen haben in allen drei Auftritten dieselbe Größe wie bei "Volle Pracht". Weniger auffällig wird die Kette so, wie man eine echte Girlande zurücknimmt: weniger Teile (Zweige ausdünnen, Schmuck abnehmen, gegebenenfalls weniger Birnen), hängende Zweige kürzer schneiden, Schmuck an kürzeren Fäden höher hängen, die Kette straffer spannen (flachere Bögen). Die Zahlen für die Tiefe oben sind Richtwerte, die sich daraus ergeben, keine Grenze, für die etwas verkleinert wird.
- Bei "klassisch" wirkt Auftritt nur über Anzahl der Birnen und Durchhang (kein Schmuck vorhanden).
- Die Regler unter "Weitere Optionen" wirken innerhalb des gewählten Auftritts relativ weiter; die Tiefengrenze des Auftritts gilt immer.
- Neue Nutzer starten mit "Festlich" an Menüleiste und Dock. Bestehende Nutzer bekommen beim ersten Start "Volle Pracht", damit ihr Aussehen gleich bleibt.

**Schnee:** Auf dem vordersten Fenster der aktiven App bleibt nie Schnee liegen (kein eigener Schalter). Wird ein Fenster mit Schneeschicht aktiv, rutscht die Schicht innerhalb von etwa einer Sekunde sanft ab wie beim Schütteln; die anderen Fenster sammeln weiter. "Nur in Pausen" (Englisch "Only during breaks"), Schalter, Standard aus: Der Schnee beginnt erst, wenn zwei Minuten lang keine Taste gedrückt und die Maus nicht bewegt wurde (ohne Berechtigung ermittelbar, z. B. über die Zeit seit dem letzten Eingabeereignis). Sobald wieder getippt oder die Maus bewegt wird, kommen keine neuen Flocken; fallende fallen zu Ende, liegender Schnee bleibt. Schneesturm per Klick wirkt immer.

Alle neuen Einstellungen werden vom Zurücksetzen erfasst, sind auf Deutsch und Englisch beschriftet und mit VoiceOver bedienbar. Die Einführung zeigt keine neuen Optionen.

Alle Einstellungen werden sofort sichtbar übernommen und bleiben über Neustarts erhalten. Die Oberfläche ist auf Deutsch und Englisch, je nach Systemsprache, sonst Englisch. Die Einstellungen sind mit VoiceOver bedienbar. Lichter und Schnee sind für VoiceOver unsichtbar.

## 8. Grafik

Alle Grafiken liegen in `Art/` und sind verbindlich. Maßgeblich sind `Art/README.md` und das Zielbild `Art/preview.png`. Birnen sind in jeder Palettenfarbe einfärbbar und bleiben in jeder Größe scharf. Für Elemente ohne Vorgabe (Schneeschicht auf Fenstern, Popovers, Einstellungsfenster) gestaltet das Team selbst, passend zum Stil der Vorgaben und zu macOS.

## 9. Rahmenbedingungen

- Name FestiveLights, Bundle-ID `ms.blackbox.festivelights`, macOS 14 oder neuer, Apple Silicon und Intel.
- Swift mit SwiftUI und AppKit, keine Fremdabhängigkeiten ohne Rücksprache.
- Menüleisten-App ohne Dock-Symbol.
- Kostenlos und Open Source unter der MIT-Lizenz (`LICENSE`). Das Repo ist öffentlich: keine Team-ID, keine Zertifikatsnamen, keine persönlichen Pfade im Repo, Signatur-Einstellungen nur in einer lokalen, nicht versionierten Datei.
- Zwei Varianten aus demselben Code, beide kostenlos, gleiche Bundle-ID:
  - **App Store** (Standard-Build): App Sandbox, keine Bedienungshilfen-API, kein Berechtigungsbereich in den Einstellungen, kein Berechtigungsschritt in der Einführung. Dock-Kette per Treffer-Test, Schnee auf Fenstern über die Fensterliste. Updates über den App Store. Datenschutz-Manifest, Kategorie, Verschlüsselungsangabe. Enthält kein Sparkle und keinen eigenen Update-Code, auch nicht als ungenutztes Framework.
  - **Direkt-Download** (eigenes Target oder eigene Konfiguration, Compile-Schalter `DIRECT`): ohne Sandbox, mit optionaler Bedienungshilfen-Freigabe (Berechtigungsbereich in den Einstellungen und Berechtigungsschritt in der Einführung), Developer ID signiert und notarisiert, ausgeliefert als DMG mit der App und einem Programme-Link zum Hineinziehen.
- Updates der Direkt-Variante über Sparkle 2 (einzige erlaubte Fremdabhängigkeit, per Swift Package, nur im Direkt-Build gelinkt):
  - Feed-URL `https://github.com/krystofbe/festive-lights/releases/latest/download/appcast.xml`. Signatur der Updates per EdDSA; der öffentliche Schlüssel steht in der Info.plist der Direkt-Variante (`SUPublicEDKey`), Wert `W/2EcmmB+6w9na/g6C29/ly+yDyRp7dh/eaBdQBiRwo=`, Sparkle-Schlüsselbund-Konto `festivelights` (generate_keys --account festivelights). Der private Schlüssel liegt nur im Schlüsselbund des Release-Rechners, nie im Repo.
  - Automatische Prüfung einmal täglich, ohne eigenen Dialog beim ersten Start; Sparkle fragt beim zweiten Start wie üblich nach. Im Menüleisten-Menü der Punkt "Nach Updates suchen..." (Englisch "Check for Updates..."), in Allgemein ein Schalter "Automatisch nach Updates suchen" (Englisch "Automatically check for updates"). Beides nur in der Direkt-Variante. Kein Systemprofil (`SUEnableSystemProfiling` aus), keine weiteren Angaben in der Anfrage außer dem üblichen User-Agent mit App-Name und Version.
  - Ein Skript `scripts/release-direct.sh <Version>` baut die Direkt-Variante, exportiert sie mit Developer ID (über das in Xcode angemeldete Konto, `-allowProvisioningUpdates`), lässt sie notarisieren und heftet das Ticket an, baut die DMG, erzeugt mit Sparkles `generate_appcast` die `appcast.xml` und legt DMG und appcast.xml in einem Ausgabeordner ab. Team-ID und Pfade kommen aus `Local.xcconfig` bzw. Umgebungsvariablen. Hochladen als GitHub-Release macht der Koordinator.
  - Jede Direkt-Version ist ein eigenes GitHub-Release mit Tag gleich der Version (zum Beispiel `1.0.1`), als "latest" markiert. Es enthält `FestiveLights-<Version>.dmg`, eine gleiche Kopie `FestiveLights.dmg` (feste Download-URL `releases/latest/download/FestiveLights.dmg`) und die `appcast.xml`.
  - Release Notes: Für jede Version liegt `ReleaseNotes/<Version>.html` im Repo (HTML-Ausschnitt ohne DOCTYPE und body, oben Englisch, darunter Deutsch, je eine Überschrift und eine kurze Liste). Das Skript legt sie als `FestiveLights-<Version>.html` neben die DMG, damit `generate_appcast` sie in die `appcast.xml` einbettet. Fehlt die Datei, bricht das Skript ab.
  - Verlauf: Das Skript lädt vor `generate_appcast` die aktuelle `appcast.xml` von `releases/latest/download/appcast.xml` in den Ausgabeordner (falls vorhanden), damit frühere Einträge erhalten bleiben. Delta-Updates sind nicht nötig.
  - Sparkle zeigt beim Fund eines Updates den Standard-Dialog mit den Release Notes und fragt vor der Installation (kein stilles automatisches Installieren). Nach der Installation startet die App neu; Einstellungen bleiben erhalten, die Einführung erscheint nicht erneut.
- Versionen: `MARKETING_VERSION` folgt Semver (1.0, 1.0.1, 1.1), `CURRENT_PROJECT_VERSION` steigt mit jedem hochgeladenen Build und ist für Store und Direkt gleich. Die Store-Fassung bekommt dieselbe Version, sobald Apple die vorherige freigegeben hat.

## 10. Qualität und Energie

- Referenzgerät: MacBook Air M2, internes Display, Standardwerte. Messung: Mittel über 60 s in der Aktivitätsanzeige.
  - Nur Lichter mit Dauerleuchten, Zeiger weit weg: unter 1 % CPU.
  - Lichter mit Funkeln plus Schnee: unter 5 % CPU mit einer Kette, unter 7 % mit Ketten an Menüleiste und Dock.
  - Schneesturm: unter 10 % CPU.
  - Speicher unter 150 MB.
  - Für Intel gibt es keinen Zielwert, die App muss dort aber flüssig laufen.
- Gesamtkosten zählen, nicht nur der eigene Prozess: Jede sichtbare Bewegung lässt den System-Prozess WindowServer das Bild neu zusammensetzen, das kostet je nach Gerät viel und ist nicht ganz vermeidbar. Maßstab ist deshalb ein Referenzprogramm auf demselben Gerät: ein transparentes Vollbildfenster, in dem 80 Punkte mit 60 Bildern pro Sekunde fallen. Mit Lichtern, Funkeln und Schnee darf die WindowServer-Last höchstens 3 Prozentpunkte über diesem Referenzwert liegen, mit Ketten an Menüleiste und Dock höchstens 6. Im Ruhezustand höchstens 2 Prozentpunkte über dem Wert ohne laufende App. Wo die Bildrate ohne sichtbaren Unterschied sinken kann, soll sie sinken.
- Andere Apps bleiben flüssig: Scrollen und Animationen in Safari und Finder laufen mit laufender App sichtbar genauso flüssig wie ohne, auch auf 120-Hz-Displays. Eingaben (Tippen, Klicken, Ziehen) bekommen keine spürbare Verzögerung.
- Energiebedarf in der Aktivitätsanzeige (Spalte "Energie") im Bereich typischer Hintergrund-Apps: im Ruhezustand nahe 0, mit Schnee niedrig.
- Nur zeichnen, was sich bewegt: Steht alles still (Dauerleuchten, kein Schnee, Zeiger weit weg), wird nichts neu gezeichnet. Bildschirme ohne sichtbare Bewegung und verdeckte Bereiche verursachen keine Arbeit.
- Fensterpositionen für F6 nur so oft ermitteln wie nötig: im Ruhezustand selten, beim Ziehen eines Fensters häufig genug für flüssiges Abschütteln.
- Mit vielen Fenstern (30 offene Fenster) und zwei Bildschirmen gelten dieselben Grenzen.
- Mehrere Bildschirme (ab 1.1): Mit drei Bildschirmen (zum Beispiel zwei 5K plus internes Retina-Display), Ketten an allen Menüleisten und am Dock, Funkeln und Schnee auf allen, liegt die App unter 12 % CPU und der Speicher unter 250 MB. Jeder weitere Bildschirm darf höchstens so viel kosten wie der erste. Bildschirme ohne sichtbare Bewegung (Schnee aus, Dauerleuchten, Zeiger weg) zeichnen nicht neu. Ein Bildschirm, auf dem eine Vollbild-App läuft, zeichnet gar nicht.
- Sparmodus: halbe Flockenzahl und ruhigere Animation. "Automatisch" aktiviert ihn im Stromsparmodus von macOS und im Akkubetrieb unter 20 % Ladung, "Immer" dauerhaft, "Aus" nie. Bisher gespeichertes "Immer Energie sparen = an" wird zu "Immer", "aus" zu "Automatisch". Bei gesperrtem Bildschirm, Ruhezustand oder ausgeschaltetem Display pausiert alles.
- Keine sichtbar ausgelassenen Bilder bei 60 Hz und 120 Hz.
- "Bewegung reduzieren": Muster wird Dauerleuchten, kein Ausweichen, kein Aufstöbern und kein Nachpendeln, Schnee mit halbem Tempo ohne Böen und Pendeln, kein Schneesturm, das Menüleisten-Symbol steht still.
- Die Overlays stehlen nie den Fokus. Keine Abstürze ohne Berechtigung oder beim Wechsel von Bildschirmen.

- Daueraufgabe: Performance ist bei jeder Änderung mitzudenken, nicht erst am Ende. Jede Änderung, die Zeichnen, Abfragen, Timer oder Physik betrifft, wird vor dem Commit auf dem Testrechner gegen den vorherigen Stand gemessen (Ruhezustand und Standard, App und WindowServer). Die Werte kommen mit Datum und Commit in eine fortlaufende Tabelle (`PERF.md`). Verschlechtert sich ein Wert um mehr als 0,3 Prozentpunkte, wird das vor dem Weiterarbeiten behoben oder begründet.

## 11. Abnahme

1. Erster Start: Lichter sichtbar in unter 2 s ohne Interaktion. Einführungsfenster nach 1,5 s, Schnee nach 3 s. Einführung komplett durchklickbar in DE und EN, Stilwahl wirkt sofort, Schneesturm-Button wirkt, "Einführung..." im Menü öffnet sie erneut.
2. Durchklick-Prüfliste, jeweils bei beiden Ebenen: Menüleisten-Extras, Browser-Tabs direkt unter der Kette, Dock-Symbole unter der Dock-Kette, Fenster-Ampel unter der Schneeschicht, Drag-and-drop und Scrollen unter Schnee.
3. Ausweichen: Reaktion binnen 0,1 s, in einer Bildschirmaufnahme kein Sprung, sichtbare Lücke um den Zeiger (bei Tanne auch frei von Zweigen), keine Birne durchsichtig, kein Anheben des Kabels, Rückkehr binnen 1 s.
4. Zwei Bildschirme: Lichter und Schnee auf beiden. 20-mal Anstecken und Abstecken ohne Absturz.
5. Dock: App öffnen und beenden, Dock-Position wechseln, Auto-Hide schalten. Jeweils spätestens 0,5 s danach höchstens 2 pt Abweichung. Mit eingeschalteter Vergrößerung: Zeiger langsam über das Dock fahren, in einer Bildserie liegt die Kette in jedem Bild auf der Oberkante der vergrößerten Symbole (höchstens 3 pt Abweichung).
6. Schneeschicht: nach 5 Minuten Standardmenge sichtbar volle Schicht. 3 Richtungswechsel in 1 s plus ein weiterer entfernen etwa ein Drittel. Anhaltendes Schütteln macht das Fenster frei. Zehnmal normales Verschieben entfernt nichts. In einer vergrößerten Aufnahme einer Fensterecke liegt kein Schnee außerhalb der Fensterform.
7. Aufstöbern: Schnelles Durchfahren des Schnees (Zeigertempo über etwa 1000 pt/s) bewegt in zwei Aufnahmen im Abstand von 0,3 s sichtbar Flocken in Bewegungsrichtung. Nach 2 s fallen alle wieder normal. Beim Ausweichen und beim waagerechten Durchfahren bewegt sich keine Flocke nach oben. Schnelles Wischen über eine Schneeschicht erzeugt eine aufstiebende Wolke und eine Delle, die sich wieder füllt.
8. Berechtigung erteilen und entziehen ohne Neustart, Verhalten wie in Abschnitt 5.
9. "Bewegung reduzieren" wie in Abschnitt 10.
10. Einstellungen überleben einen Neustart.
11. CPU, Speicher, WindowServer-Mehrlast, Energiebedarf und Flüssigkeit anderer Apps wie in Abschnitt 10, auch mit 30 offenen Fenstern.
12. 8 Stunden Dauerlauf ohne nennenswerten Speicherzuwachs.

Mehrere Bildschirme (1.1), geprüft am Rechner mit drei Bildschirmen:
- An allen drei Menüleisten hängt eine Kette, Schnee fällt auf allen drei, überall scharf und gleich groß in Punkt.
- "Monitore verwenden verschiedene Spaces" aus: nur am Hauptbildschirm eine Kette (nur prüfen, wenn der Nutzer die Einstellung dafür selbst umstellt; nie ungefragt ändern).
- Dock auf einen anderen Bildschirm holen: Dock-Kette folgt binnen 1 s.
- Vollbild-App auf einem Bildschirm: dort nichts, auf den anderen weiter Lichter und Schnee.
- Nebeneinanderliegende Bildschirme mit bündigen Oberkanten: Girlande läuft ohne Bruch über die Kante (vergrößerter Ausschnitt der Kante als Beleg).
- "Nur Hauptbildschirm": Lichter und Schnee nur dort.
- Last laut §10 gemessen und in PERF.md eingetragen.

Version 1.2:
- Durchhang an Menüleiste und Dock in allen 5 Stufen, jeweils in allen drei Stilen: Bögen sichtbar flacher bzw. tiefer, Aufhängepunkte unverändert, Ausweichen und Nachpendeln wie bisher, am Dock in den Stufen 1 bis 3 wie bisher, in 4 und 5 höchstens das obere Drittel der Symbole verdeckt. Wechsel ohne Sprung. Auf Standard zurücksetzen stellt die Mittelstellung wieder her, frühere Versionen ohne gespeicherten Wert starten in der Mittelstellung.
- "Tanne warmgold" an Menüleiste und Dock: sichtbar weniger Birnen, unregelmäßige Abstände ohne erkennbares Muster, wirkt in einer Bildschirmaufnahme wie eine echte Lichterkette.
- "Tanne bunt" an der Menüleiste, Regler Größe in Mittelstellung: sieht aus wie Variante G vom 27.11. (bisher eine Stufe kleiner), Fenstertitel und Tabs unter der Menüleiste bleiben besser lesbar.
- "Tanne bunt" am Dock sieht aus wie in 1.2.1. "Tanne warmgold" und "klassisch": Menüleisten- und Dock-Kette im selben Stil nebeneinander aufgenommen (Dock Standardgröße 64): gleiche Elemente, gleiche Abstände im Verhältnis zur Birnengröße, gleiche Bogenform, gleiche Unregelmäßigkeit bei warmgold; das Dock wirkt wie die verkleinerte Menüleisten-Kette. Die Symbole bleiben bis auf das obere Viertel frei.
- Einführung: Schritte Willkommen, Menüleiste, Dock, Schnee, (Direkt: Bedienungshilfen), Fertig. Die Schalter in Menüleiste, Dock und Schnee schalten das jeweilige Feature sofort an und aus; Menü und Einstellungen zeigen danach denselben Zustand und umgekehrt. Alles in DE und EN.
- "Auch in Vollbild-Apps zeigen" an, Browser-Video im Vollbild (Firefox und Safari): keine Dock-Kette, solange das Dock ausgeblendet ist; fährt der Zeiger an den unteren Rand und das Dock erscheint, erscheint die Kette mit ihm und verschwindet wieder mit ihm.
- Ein Hilfsprogramm ohne Dock-Symbol legt ein durchsichtiges Fenster über den ganzen Bildschirm: Lichter und Schnee bleiben sichtbar. Eine echte Vollbild-App blendet weiterhin aus.
- MacBook mit Kerbe, Firefox-Video im Vollbild: Lichter und Schnee verschwinden und bleiben weg, auch nach dem Ende der Übergangsanimation; beim Verlassen kommen sie zurück. Ein maximiertes Fenster (Fenster > Füllen) bei automatisch ausgeblendetem Dock blendet nichts aus.

## Anhang A: Auftritt, Gestaltungskonzept (verbindlich ab 1.3, von Krystof abgenommen am 27.11.)

Stand 27.11., Bezug: Krystofs MacBook mit Notch, Menüleiste 33 pt, Dock-Symbolgröße 58, alle Regler in Mittelstellung. Alle pt-Angaben sind Schätzungen aus Code und Fotos (±2 pt). `h` ist die Bezugs-Birnenhöhe der Kette (Menüleiste: bunt 28 pt, warmgold und klassisch 33 pt; Dock: bunt 14,5 pt, warmgold und klassisch 15 pt). `t` ist die Lage im Bogen, 0 und 1 sind die Aufhängepunkte, 0,5 die tiefste Stelle.

**Gemessene Zonen im Referenzfoto** (unter der Menüleiste, Fenster mit Titelzeile und Tabs):

| Zone | Tiefe unter der Menüleiste |
|---|---|
| frei über dem Titel | 0 bis 11 pt |
| Fenstertitel, Ampelknöpfe | 12 bis 24 pt |
| frei zwischen Titel und Tabs | 25 bis 45 pt |
| Tab-Beschriftung | 46 bis 58 pt |

Am Dock liegen zwischen Dock-Oberkante (dort liegt die Kette) und dem sichtbaren Symbolkörper etwa 19 pt frei, der Symbolkörper ist etwa 50 pt hoch, Badges beginnen etwa 13 pt unter der Kante.

### 1. Leitidee

**Wer echte Deko zurücknimmt, nimmt ab, hängt höher und spannt straffer. Er tauscht höchstens eine große Kugel gegen eine kleine. Er verkleinert nie den Zweig, die Birne oder das ganze Bild.**

Daraus sechs Handgriffe, in dieser Reihenfolge anzuwenden:

1. **Straffer spannen.** Flachere Bögen. Das ist der billigste Handgriff und ändert kein einziges Teil.
2. **Tiefes hängt hoch.** Alles, was lang ist oder am Faden hängt (Kugeln, Zapfen am Kabel, hängende Zweige), sitzt nur noch nahe den Aufhängepunkten, wo die Girlande am höchsten ist. Die Bogenmitte trägt nur Grün und Birnen. So schmückt man auch einen Kaminsims: der Behang sitzt an den Haken, nicht im Durchhang.
3. **Kürzer anbinden.** Fäden kürzer. Zweige werden nie abgeschnitten oder gestaucht (stumpfes Ende sieht falsch aus), sie werden weggelassen, wo sie zu tief reichen würden.
4. **Flacher anbinden** (nur "Tanne warmgold"). Die Zweige der hinteren und mittleren Schicht hängen heute etwa 45 Grad schräg nach unten und reichen 32 pt unter das Kabel, sie sind das tiefste Grün, nicht die Schicht "hängend". Bei einer fest gebundenen Girlande liegen die Zweige am Seil an. Also: Zweig um seinen Ansatzpunkt zum Kabel hin drehen (gespiegelte Zweige in Gegenrichtung). Gleiche Länge, gleiche Nadeln, weniger Tiefe.
5. **Abnehmen.** Weniger Kugeln, Zapfen, Schleifen, bei "klassisch" weniger Birnen. Immer ganze Teile, gleichmäßig verteilt, nie ein Rest.
6. **Kleinere Sorte.** Nur für Kugeln und nur als letztes Mittel: Es gibt genau zwei Sorten, "große Kugel" (100 %) und "kleine Kugel" (60 %), wie im Karton mit zwei Kugelgrößen. Keine Zwischengrößen. Die kleine Kugel nutzt nur die Muster ohne Schleifchen (1, 3, 5), der Goldfaden bleibt so dick wie bei der großen. An der Menüleiste wird sie nicht gebraucht (der Prototyp zeigt, dass große Kugeln an kurzen Fäden reichen), am Dock gibt es sie schon.

**Nie geändert wird:** Größe von Büscheln, Zweigen, Nadeln, Birnen, Schein, Zapfen und Schleifen, Dichte des Grüns bei "Tanne bunt", Farben, Muster, Strichstärken, Birnenabstand der Tannen-Stile. Auch der Größenregler unter "Weitere Optionen" bleibt die einzige Stelle, an der etwas skaliert wird.

**Warum das erkennbar bleibt:**
- Der Maßstab bleibt in allen Stufen gleich. Nadel, Birne und Zapfen sind die Bezugsgrößen, an denen das Auge den Rest misst. Ändern sie sich nicht, liest man "dieselbe Girlande, weniger behängt" statt "dasselbe Bild, kleiner".
- Jedes Teil bleibt über seiner Lesbarkeitsgrenze. Die große Kugel hat 22 pt Durchmesser, die kleine 13 pt, darunter kippt ein Muster in Pixelrauschen (genau das ist bei der Verkleinerung auf 75 % mit allen Teilen gleichzeitig passiert).
- Zwei feste Kugelgrößen wirken wie Absicht. Stufenlos verkleinerte Kugeln wirken wie ein Darstellungsfehler.
- Die Silhouette ändert sich in benennbaren Schritten. Man kann bei jedem Stufenwechsel sagen, was abgenommen wurde.

**Zusätzlicher Handgriff nur für "Dezent" bei "Tanne bunt" an der Menüleiste: auf der Kante liegen.** Strang und Büschel hängen 6 pt höher, der Teil oberhalb der Menüleisten-Unterkante bleibt wie heute abgeschnitten (heute schon so an jedem Aufhängepunkt). Kabel und Birnen wandern nicht mit, keine Birne wird angeschnitten. Wirkung: wie eine Girlande, die auf dem Sims liegt und nur halb über die Kante hängt. Siehe offene Frage 1.

**Für die Umsetzung:** `Look.sizeFactor` entfällt (immer 1), `Look.garlandFit` entfällt (nichts wird auf eine Grenze skaliert). `tbSizeFactor` 0,85 bleibt, das ist das Grundmaß von 1.2.2 und gilt in allen Stufen. Neu nötig: Durchhang je Auftritt, erlaubter Bereich von `t` je Schmuckart, Fadenlänge je Auftritt, Zusatzdrehung der Zweige (warmgold), Anhebung des Strangs (bunt). Die Tiefen unten sind Ergebnis, keine Grenze, auf die hin etwas angepasst wird. Die Regler unter "Weitere Optionen" multiplizieren wie bisher.

### 2. Prüfung der Stufen

Drei Stufen sind richtig, weil es genau drei Zustände echter Deko gibt, die man benennen kann:

| Stufe | Bild aus der Wirklichkeit | Versprechen |
|---|---|---|
| Dezent | Grün und Lichter, straff, ohne Behang | Tabs und Symbolleiste frei, der Fenstertitel wird höchstens von Nadelspitzen berührt |
| Festlich | geschmückt, aber aufgeräumt: Behang an den Haken | Tabs frei, Dock-Symbole frei |
| Volle Pracht | voll behängt, frei durchhängend (1.2.2) | keine Rücksicht |

Eine vierte Stufe wäre nur ein Zwischenwert ohne eigenes Bild, zwei Stufen ließen die wichtigste aus (geschmückt und trotzdem lesbar). Die Namen passen und bleiben. Einzige Änderung: Der Hilfetext sollte das Versprechen nennen, nicht die Technik, zum Beispiel "Festlich: geschmückt, Tabs bleiben frei".

### 3. Werte je Stil und Stufe

Schreibweise: Anzahl, Größe gegenüber "Volle Pracht", Länge, Lage. "100 %" heißt unverändert. "Volle Pracht" ist überall der Stand von 1.2.2.

### Tanne bunt, Menüleiste (Bogen etwa 140 pt, etwa 12 Bögen)

| Element | Dezent | Festlich | Volle Pracht |
|---|---|---|---|
| Büschel | alle, 100 %, Strang 6 pt angehoben | alle, 100 % | alle, 100 % |
| Hängende Zweige | gibt es in diesem Stil nicht | gibt es nicht | gibt es nicht |
| Birnen | alle (5 je Bogen), 100 %, nicht angehoben | alle, 100 % | alle, 100 % |
| Kugeln | keine | halb so viele (alle 340 Einheiten, etwa 1,5 je Bogen), alle groß (100 %), nur bei t unter 0,3 oder über 0,7: fällt eine in die Bogenmitte, rückt sie zum nächsten Büschel außerhalb | etwa 3 je Bogen (alle 170 Einheiten), alle groß, überall |
| Fäden | keine | 15 bis 25 Einheiten (4 bis 7 pt), Fadenstärke 100 % | 45 bis 65 Einheiten (13 bis 18 pt) |
| Zapfen (im Grün) | 1 je Bogen, 100 % | 2 je Bogen, 100 % | 2 je Bogen, 100 % |
| Schleifen | gibt es nicht | gibt es nicht | gibt es nicht |
| Durchhang | 0,12 h (3 pt) | 0,4 h (11 pt) | 0,6 h (17 pt) |
| **Größte Tiefe** | **etwa 12 pt** (Grün) | **etwa 41 pt** (Kugeln), Grün bis 25 pt | **etwa 60 pt** (Kugeln), Grün bis 30 pt |
| Trifft | Oberkante Titel | Titel in den Bogenmitten und an den Kugeln, Tabs frei | Titel und Tabs |

### Tanne warmgold, Menüleiste

| Element | Dezent | Festlich | Volle Pracht |
|---|---|---|---|
| Grün (hintere, mittlere, vordere Zweige) | alle, 100 %, 30 Grad flacher angebunden (reicht etwa 17 pt unter das Kabel) | alle, 100 %, 15 Grad flacher (etwa 24 pt unter das Kabel) | alle, 100 %, Lage wie bisher (etwa 32 pt unter das Kabel) |
| Hängende Zweige (Schicht "hängend") | keine | nur Ansatzpunkte bei t unter 0,2 oder über 0,8, 100 % Länge. Reicht einer tiefer als 34 pt, entfällt er | etwa jeder fünfte Ansatzpunkt, 100 % |
| Birnen | alle, 100 %, unregelmäßige Abstände wie bisher | alle, 100 % | alle, 100 % |
| Kugeln, Fäden | gibt es in diesem Stil nicht | gibt es nicht | gibt es nicht |
| Zapfen (am Kabel) | keine | jeder zweite Bogen, 100 %, bei t 0,12 bis 0,20 | 1 je Bogen, irgendwo bei t 0,2 bis 0,8 |
| Schleifen | keine | alle Aufhängepunkte, 100 % (sie sitzen am höchsten Punkt) | alle Aufhängepunkte |
| Durchhang | 0,12 h (4 pt) | 0,3 h (10 pt) | 0,45 h (15 pt) |
| **Größte Tiefe** | **etwa 26 pt** (Birnen), Grün bis 21 pt | **etwa 34 pt** (Grün), Birnen bis 32 pt | **etwa 47 pt** (Grün), Birnen bis 40 pt |
| Trifft | Titel an jeder Birne | Titel, Tabs frei | Titel, Oberkante der Tabs |

### klassisch, Menüleiste (kein Schmuck, kein Grün)

| Element | Dezent | Festlich | Volle Pracht |
|---|---|---|---|
| Birnen | 4 je Bogen (Abstand × 1,5), 100 % | 6 je Bogen, 100 % | 6 je Bogen, 100 % |
| Durchhang | 0,1 h (3 pt) | 0,3 h (10 pt) | 1,0 h (33 pt) |
| **Größte Tiefe** | **etwa 36 pt** | **etwa 43 pt** | **etwa 66 pt** |
| Trifft | Titel an jeder Birne, Tabs frei | Titel, Tabs frei | Titel und Tabs |

Die C9-Birne ist selbst 33 pt hoch. Tiefer als 36 pt kommt "klassisch" ohne kleinere Birnensorte nicht, siehe offene Frage 2.

### Tanne bunt, Dock (Symbolgröße 58)

| Element | Dezent | Festlich (= 1.2.1) | Volle Pracht |
|---|---|---|---|
| Büschel (schmale Girlande) | alle, 100 % | alle, 100 % | alle, 100 % |
| Birnen | jede zweite (Abstand × 2), 100 % | alle, dicht, 100 % | alle, 100 % |
| Kugeln | keine | keine | nur kleine Dock-Kugeln wie bisher (etwa 9 pt), etwa 1 je 1,5 Symbole, bei t unter 0,35 oder über 0,65 |
| Fäden | keine | keine | 3 bis 5 pt |
| Zapfen | keine | keine | 2 je Bogen |
| Durchhang | 0 (liegt auf der Kante) | 0,3 h (4 pt) | 0,3 h (4 pt) |
| Tiefe unter der Dock-Kante | etwa 15 pt | etwa 19 pt | etwa 24 pt |
| **Verdeckter Anteil der Symbole** | **0 %** | **0 bis 2 %** | **etwa 10 %** |

### Tanne warmgold, Dock (alle Teile halb so groß wie an der Menüleiste, das bleibt in jeder Stufe so)

| Element | Dezent | Festlich | Volle Pracht |
|---|---|---|---|
| Grün | alle, 100 %, 30 Grad flacher | alle, 100 %, 15 Grad flacher | alle, 100 %, Lage wie bisher |
| Hängende Zweige (Schicht "hängend") | keine | nur bei t unter 0,2 oder über 0,8, 100 % | wie Menüleiste, 100 % |
| Birnen | alle, 100 % | alle, 100 % | alle, 100 % |
| Zapfen | keine | jeder zweite Bogen, bei t 0,12 bis 0,20 | 1 je Bogen |
| Schleifen | keine | alle Aufhängepunkte | alle Aufhängepunkte |
| Durchhang | 0,12 h (2 pt) | 0,3 h (4,5 pt) | 0,45 h (7 pt) |
| Tiefe unter der Dock-Kante | etwa 12 pt | etwa 17 pt | etwa 22 pt |
| **Verdeckter Anteil der Symbole** | **0 %** | **0 %** | **etwa 5 %**, Badges berührt |

### klassisch, Dock

| Element | Dezent | Festlich | Volle Pracht |
|---|---|---|---|
| Birnen | 4 je Bogen (Abstand × 1,5), 100 % | 6 je Bogen, 100 % | 6 je Bogen, 100 % |
| Durchhang | 0,1 h (1,5 pt) | 0,3 h (4,5 pt) | wie bisher (0,45 h, 7 pt) |
| Tiefe unter der Dock-Kante | etwa 17 pt | etwa 20 pt | etwa 22 pt |
| **Verdeckter Anteil der Symbole** | **0 %** | **0 bis 2 %** | **etwa 5 %** |

Am Dock unterscheiden sich die Stufen also kaum in der Verdeckung, sondern im Reichtum. Das ist richtig so: Über den Symbolen liegen 19 pt Luft, die reichen für alles außer dem Behang von "Volle Pracht". Die Anteile gelten für Symbolgröße 58, bei kleineren Symbolen wächst die Kette nicht mit hinein, weil sie mit der Symbolgröße skaliert.

### 3a. Bewertung der Prototypen (auftritt2-bunt.png, auftritt2-warmgold.png)

Der Grundsatz stimmt in allen zehn Zeilen: Jedes Teil ist so groß wie in "Volle Pracht" und sofort erkennbar. Im Einzelnen:

| Prototyp | Tanne bunt | Tanne warmgold |
|---|---|---|
| Festlich | **Fast richtig.** Kugeln enden an der Oberkante der Tab-Zeile, alle Tabs lesbar. Zwei Korrekturen: keine Kugel in der Bogenmitte (dort stößt sie an die Tab-Schrift), Fäden noch etwas kürzer | **Reicht nicht.** Die langen dunklen Zweige reichen weiter bis an die Tab-Zeile, weil nur die Schicht "hängend" gekürzt wurde. "Halb so lang" ist außerdem ein gestauchtes Bild und verstößt gegen den Grundsatz. Lösung: flacher anbinden (Handgriff 4). Schleifen nicht halbieren, sie sitzen oben und geben den Takt |
| Dezent 1 (jeder zweite Büschel weg) | **Nein.** Der kahle braune Strang wird sichtbar, die Girlande wirkt gerupft und verliert ihr Merkmal "dicht". Einziger Vorteil: Der Fenstertitel scheint durch die Lücken | **Nein.** Das Grün ist ohnehin locker, halbiert bleibt alle 150 pt ein einzelner Zweig, und der reicht so tief wie vorher |
| Dezent 2 (dazu jede zweite Birne) | **Nein.** Die Birnen sind 6 pt klein und verdecken nichts, ohne sie fehlt das Licht | **Nein.** Im Ausschnitt bleibt eine Birne auf 400 pt, das ist keine Lichterkette mehr |
| Dezent 3 (volles Grün, straff) | **Richtige Basis, aber zu tief.** Das Grün liegt genau auf dem Fenstertitel (etwa 22 pt). Deshalb straffer (0,12 h statt 50 %) und auf die Kante legen, dann etwa 12 pt | **Richtige Basis, aber zu tief.** Zweige reichen bis etwa 36 pt. Mit flacherem Anbinden etwa 21 pt |
| Dock | Festlich ist richtig (= 1.2.1). Dezent 3 ist von Festlich nicht zu unterscheiden, Dezent 1 zeigt Löcher. Empfehlung: volles Grün, jede zweite Birne (am Dock sind die Birnen das große Teil) | Alle Zeilen lassen die Symbole frei. Dezent 3 als Basis, flacher angebunden, damit die Zweigspitzen nicht mehr an die Badges stoßen |

Kurz: "Festlich" bunt aus dem Prototyp übernehmen, "Dezent 3" ist bei beiden Stilen die Basis, Ausdünnen von Grün und Birnen (Dezent 1 und 2) verwerfen. Was fehlt, sind die zwei Handgriffe "Tiefes hängt hoch" und "flacher anbinden".

### 4. Kriterien für Krystofs Abnahme

Auf einem Bildschirmfoto mit drei Stufen untereinander, je Stil, Menüleiste über einem Fenster mit Titelzeile und Tabs, Dock mit Symbolgröße 58:

1. **Deckungsprobe:** Eine Birne, ein Büschel, ein Zweig, ein Zapfen, eine Schleife, eine Kugel aus "Dezent" oder "Festlich" ausgeschnitten und auf "Volle Pracht" gelegt, ist deckungsgleich (Zweige bei warmgold gedreht, nicht gestaucht).
2. **Tabs:** Bei "Dezent" und "Festlich" ist an der Menüleiste jede Tab-Beschriftung vollständig lesbar, nichts reicht tiefer als etwa 42 pt. Bei warmgold endet das Grün in "Festlich" sichtbar über der Tab-Zeile.
3. **Bogenmitte:** Bei "Festlich" hängt in der Mitte keines Bogens eine Kugel, ein Zapfen oder ein langer Zweig. Der Behang sitzt sichtbar an den Aufhängepunkten.
4. **Dezent:** Ampelknöpfe frei, kein Behang. "Tanne bunt" berührt den Fenstertitel nur mit Nadelspitzen.
5. **Lesbarkeit ohne Zoom:** In 100 % Ansicht erkennt man bei jeder Stufe, was es ist: Tannengrün, Birnen mit Schein, bei "Festlich" die Kugelmuster (Punkte, Streifen, Rauten), bei warmgold die Schleifen.
6. **Benennbarer Schritt:** Beim Umschalten kann man in einem Satz sagen, was abgenommen wurde ("Kugeln weg", "Zapfen und lange Zweige nur noch an den Haken"). Wenn man stattdessen "kleiner" sagt, ist es falsch.
7. **Nichts Halbes:** Kein abgeschnittener Zweig, kein Faden ohne Büschel, keine angeschnittene Birne. Einzige Schnittkante ist die Unterkante der Menüleiste.
8. **Dock:** "Tanne bunt" in "Festlich" ist bildgleich mit 1.2.1. In "Dezent" und "Festlich" ist kein Symbolkörper verdeckt, Badges sind lesbar. In "Volle Pracht" ist höchstens das obere Zehntel betroffen.
9. **Bestandsnutzer:** "Volle Pracht" ist bildgleich mit 1.2.2.

### 5. Entscheidungen von Krystof (vormals offene Fragen)

Alle drei Empfehlungen angenommen: (1) Dezent bei Tanne bunt an der Menüleiste: Strang 6 pt angehoben, liegt auf der Kante. (2) klassisch in Dezent mit kleinerer Birnensorte C7 (etwa 70 %), an Menüleiste und Dock. (3) Tanne warmgold: Zweige in Dezent 30 Grad, in Festlich 15 Grad flacher angebunden.

Ursprüngliche Fragen:

1. **Auf der Kante liegen:** Darf bei "Dezent" und "Tanne bunt" die Girlande 6 pt höher hängen, so dass ihr oberer Teil hinter der Menüleisten-Kante verschwindet? Mit Anhebung etwa 12 pt tief (Titel frei), ohne etwa 18 pt (obere Hälfte des Titels im Grün). Empfehlung: ja.
2. **Kleinere Birnensorte:** Bei "klassisch" und "Tanne warmgold" ist die Birne selbst das tiefste Teil, "Dezent" bleibt deshalb bei 36 pt bzw. 26 pt. Soll "Dezent" dort eine echte kleinere Sorte bekommen (klassisch C7 statt C9, 70 %, dann etwa 26 pt), oder bleibt es bei "weniger Birnen, straff"? Empfehlung: bei der Tanne nein, bei "klassisch" ja.
3. **Flacher anbinden:** Dürfen bei "Tanne warmgold" die Zweige in "Dezent" und "Festlich" flacher am Kabel anliegen (gedreht um 30 bzw. 15 Grad)? Das ändert den Charakter leicht von "locker hängend" zu "fest gebunden". Die Alternative wäre, tiefe Zweige ganz wegzulassen, dann wird die Kette kahl (siehe Prototyp Dezent 1). Empfehlung: ja.
