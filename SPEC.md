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
| Stil | klassisch |
| Farbmodus | bunt |
| Muster | Funkeln |
| Tempo, Birnengröße, Abstand | jeweils Mittelstellung (entspricht `Art/preview.png`) |
| Ebene Lichter | über allen Fenstern |
| Schnee | an, startet 3 s nach dem App-Start mit leichter Menge (siehe Abschnitt 6) |
| Schneemenge, Flockengröße, Tempo, Ausweichen | Mittelstellung |
| Wind | aus |
| Ebene Schnee | über allen Fenstern |
| Lichter am Dock | an, sobald die Berechtigung erteilt ist |
| Schnee bleibt auf Fenstern liegen | an, sobald die Berechtigung erteilt ist |
| Beim Anmelden starten | aus |
| Immer Energie sparen | aus |

Alle Regler haben 5 Stufen. Die Mittelstellung ist der Standard.

## 4. Funktionen, Stufe 1 (ohne jede Berechtigung)

### F1 Lichterkette an der Menüleiste

- Ein Kabel hängt in mehreren gleichmäßigen, flachen Bögen unter der Menüleiste über die volle Bildschirmbreite. Bei Mittelstellung etwa 6 Birnen pro Bogen, Durchhang etwa eine Birnenhöhe, Birnenhöhe etwa wie die Menüleiste.
- Die Kette hängt auf jedem Bildschirm, der eine Menüleiste zeigt. Bei automatisch ausgeblendeter Menüleiste hängt sie an der Bildschirmoberkante und rutscht mit der Menüleiste nach unten, wenn diese erscheint.
- Birnen hängen gleichmäßig verteilt am Kabel, jede mit einer kleinen, zufälligen, aber stabilen Neigung (höchstens ±15 Grad).
- Farben reihum aus der Palette in `Art/README.md`. Alternativ Modus "warmweiß".
- Muster:
  - **Dauerleuchten.**
  - **Funkeln:** Zu jedem Zeitpunkt sind etwa 10 % der Birnen für 0,3 bis 1 s gedimmt, sie glimmen weich aus und wieder an.
  - **Lauflicht:** Ein heller Abschnitt wandert von links nach rechts, die übrigen Birnen sind gedimmt.
  - Das Tempo wirkt auf Funkeln und Lauflicht.
- **Ausweichen:** Kommt der Zeiger dem Kabel näher als etwa 60 pt (von unten oder seitlich), hebt sich der betroffene Abschnitt samt Birnen weich nach oben, bis knapp unter die Menüleiste. Birnen und Schein blenden in Zeigernähe auf etwa 30 % Deckkraft ab. Die Reaktion beginnt innerhalb von 0,1 s. Entfernt sich der Zeiger, senkt sich die Kette innerhalb von etwa 0,5 s wieder, und die Birnen pendeln kurz nach. Steht der Zeiger in der Menüleiste selbst, passiert nichts.
- **Stil:** "klassisch" (wie oben), "Tanne bunt" oder "Tanne warmgold", Aussehen siehe `Art/README.md`, Abschnitt Stil "Tanne". In den Tannen-Stilen hängt statt des Kabels eine Tannengirlande mit Mini-Kerzenbirnen und Zapfen, bei "Tanne warmgold" zusätzlich rote Schleifen an den Aufhängepunkten. Die Farben stehen durch den Stil fest, der Farbmodus gilt nur für "klassisch". Muster, Tempo, Ausweichen und Nachpendeln wirken in allen Stilen gleich: Beim Ausweichen hebt sich die Girlande samt Zweigen, Birnen, Zapfen und Schleifen, beim Nachpendeln schwingen Birnen und Zapfen, die Zweige wippen leicht mit. Birnengröße skaliert die ganze Girlande, Abstand den Birnenabstand. Bei Mittelstellung endet die geschlossene Girlande etwa 60 pt unter der Menüleiste, nur einzelne lange Zweige hängen wie im Zielbild bis etwa 150 pt herab. Klicks gehen auch durch das Grün hindurch. Beim Ausweichen blenden Zweige, Zapfen und Schleifen in Zeigernähe wie die Birnen auf etwa 30 % ab, damit darunterliegende Titelleisten und Tabs lesbar werden. Dichte des Grüns und Länge der hängenden Zweige sind im Code an je einer Stelle einstellbar, weil sie nach dem ersten Praxistest noch angepasst werden.
- Ein- und Ausschalten: Die Kette blendet in etwa 0,3 s ein oder aus. Beim App-Start gehen die Birnen innerhalb von etwa 1,5 s nacheinander von links nach rechts an.

### F2 Schnee

- Schneeflocken rieseln über alle Bildschirme. Mehrere Tiefenebenen: Nahe Flocken sind größer, schneller und heller, ferne kleiner, langsamer und blasser.
- Grundregel der Physik: Die Schwerkraft gewinnt immer. Keine Flocke steigt von sich aus oder durch Ausweichen auf; Bewegungen nach oben gibt es nur gedämpft beim Aufstöbern durch einen aufwärts fahrenden Zeiger.
- Flocken pendeln leicht seitlich. Wind (aus, weht nach links, weht nach rechts) treibt sie in eine Richtung, mit gelegentlichen Böen. Bei "Wind aus" gibt es keine Böen, nur das Pendeln.
- **Ausweichen:** Um den Zeiger entsteht eine kleine schneefreie Zone. Die Flocken umströmen den Zeiger seitlich wie Wasser einen Stein: Flocken über dem Zeiger werden langsamer und weichen zur Seite aus, sie werden nie nach oben geschleudert. Die Stärke ist einstellbar.
- **Aufstöbern:** Fährt der Zeiger schnell durch fallenden Schnee, reißt er die Flocken in seiner Nähe mit: Sie werden in Bewegungsrichtung mitgerissen, überwiegend waagerecht, drehen sich, werden langsamer und rieseln nach 1 bis 2 s wieder normal. Nach oben bewegen sie sich nur, wenn der Zeiger selbst nach oben fährt, und auch dann nur kurz und gedämpft, weil die Schwerkraft sofort überwiegt. Je schneller die Bewegung, desto mehr Flocken und desto kräftiger der Wirbel. Langsame Bewegungen lösen nur das normale Ausweichen aus. Das Aufstöbern darf nie aussehen, als würde Schnee am Zeiger kleben. Maßstab ist echter Schnee in der Luft: Der Zeiger wirkt wie eine Hand, die durch Schneetreiben fährt. Er schiebt die Flocken nicht direkt an, sondern bewegt die Luft, und die Flocken folgen dieser Luft träge, mit Luftwiderstand, ohne Sprünge in Tempo oder Richtung. Hinter dem Zeiger entsteht ein kurzer Nachlauf mit kleinen Verwirbelungen, der sich nach etwa einer Sekunde beruhigt. Leichte, kleine Flocken reagieren stärker als große. Eine Flocke kann nie schneller werden als die Luft, die sie mitnimmt.
- Menge, Flockengröße und Fallgeschwindigkeit sind einstellbar. In Mittelstellung sind etwa 80 Flocken pro Bildschirm gleichzeitig sichtbar, in der höchsten Stufe etwa das Vierfache.
- Flocken bleiben auf hellem und dunklem Untergrund sichtbar (dezenter dunkler Schatten, siehe `Art/preview.png`).
- Beim Ausschalten entstehen keine neuen Flocken, die vorhandenen fallen aus dem Bild oder blenden innerhalb von 3 s aus.

**Schneesturm:**
- Etwa dreifache Menge, doppeltes Tempo, kräftiger Wind mit Böen.
- Baut sich in etwa 2 s auf, endet nach 30 s oder bei erneutem Klick und klingt dann in etwa 5 s ab.
- Ist der Schnee aus, schaltet der Sturm ihn für seine Dauer ein.
- Der Sturm wird nicht gespeichert.

### F3 Ebene wählen

Lichter und Schnee lassen sich jeweils "über allen Fenstern" oder "nur auf dem Schreibtisch" (hinter allen Fenstern) anzeigen.

### F4 Bildschirme, Spaces, Vollbild

- Schnee erscheint auf allen Bildschirmen, Lichter auf jedem Bildschirm mit Menüleiste.
- Anstecken, Abstecken und Auflösungswechsel werden ohne Neustart übernommen.
- Lichter und Schnee sind auf allen Spaces sichtbar. In Vollbild-Apps sind sie ausgeblendet.
- Sie erscheinen nicht als eigene Fenster in Mission Control, im App-Umschalter oder in Fensterlisten.
- Sie erscheinen nicht in Bildschirmfotos, Bildschirmaufnahmen und Bildschirmfreigaben.

## 5. Funktionen, Stufe 2 (nach einer optionalen Berechtigung)

F5 und F6 dürfen höchstens eine optionale macOS-Systemberechtigung erfordern. Welche, entscheidet das Team. Die Bildschirmaufnahme-Berechtigung ist ausgeschlossen. Ohne Berechtigung fehlen nur F5 und F6, alles andere läuft. Wird sie erteilt, schalten sich F5 und F6 ohne Neustart ein. Wird sie entzogen, verschwinden F5 und F6 binnen 5 s ohne Dialog.

### F5 Lichterkette am Dock

- Dock unten: Das Kabel liegt in flachen Bögen auf der Oberkante des Docks über dessen volle Breite. Die Birnen hängen nach unten und überdecken höchstens das obere Viertel der Symbole.
- Dock links oder rechts: Das Kabel läuft an der Innenkante entlang, die Birnen zeigen zur Bildschirmmitte.
- Die Kette erscheint nur auf dem Bildschirm, der gerade das Dock zeigt. Die Vergrößerung beim Überfahren wird ignoriert.
- Ändert sich die Dock-Größe (Apps öffnen oder beenden, Dock-Position, Größe), liegt die Kette spätestens 0,5 s nachdem das Dock seine neue Größe erreicht hat, wieder deckungsgleich an. Abweichung höchstens 2 pt.
- Ausgeblendetes Dock: Die Kette erscheint und verschwindet mit dem Dock.
- Stil, Farbe, Muster, Größe und Abstand gelten für beide Ketten gemeinsam. Am Dock ist die Girlande der Tannen-Stile schmal: nur kurze Zweige, keine hängenden, keine Zapfen, damit die Regel mit dem oberen Viertel der Symbole gilt. Dock-Lichter haben eine eigene Ein/Aus-Einstellung. Ausweichen wie F1, nur hebt sich das Kabel hier vom Dock weg zur Bildschirmmitte.

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

## 6. Erster Start und Berechtigung

1. App startet, die Birnen der Menüleisten-Kette gehen nacheinander an (F1). Kein modaler Dialog, kein Fenster.
2. Nach 3 s beginnt leichter Schnee. Gleichzeitig öffnet sich am Menüleisten-Symbol ein kleines Popover: "Frohe Festtage! ❄️ Lust auf einen Schneesturm?" mit einem Button, der den Schneesturm startet. Das Popover nimmt keinen Fokus und schließt sich nach 20 s oder bei Klick daneben.
3. Einmalig und frühestens 60 s nach Schritt 2 erscheint ein zweites Popover: "Lichter auch ans Dock und Schnee, der auf Fenstern liegen bleibt?" Es erklärt in einem Satz, was die App dafür sieht (Position von Dock und Fenstern) und was nicht (keine Inhalte, keine Eingaben), und bietet einen Button, der direkt zur passenden Stelle in den Systemeinstellungen führt.
4. Wird das Popover übersprungen, fragt die App nie wieder von selbst. Der Weg bleibt über Menü und Einstellungen erreichbar.

## 7. Bedienung

**Menüleisten-Symbol** (bunt, drei Birnen am Kabel, dezent animiert, siehe `Art/README.md`) mit Menü:
- Pause (schaltet alles vorübergehend aus und mit erneutem Klick wieder ein, gespeichert bis zum Fortsetzen)
- Lichter an der Menüleiste (an/aus)
- Lichter am Dock (an/aus; ohne Berechtigung mit Hinweis "Berechtigung nötig", Klick führt zu den Systemeinstellungen)
- Schnee (an/aus)
- Schneesturm
- Einstellungen…
- Beenden

Ein zweiter Start der App öffnet die Einstellungen (wichtig, wenn das Symbol hinter der Kamera-Aussparung verschwindet).

**Einstellungsfenster**, kompakt, drei Bereiche:
- **Lichter:** Stil, Farbmodus (nur bei "klassisch"), Muster, Tempo, Birnengröße, Abstand, Ebene, Lichter am Dock an/aus.
- **Schnee:** Menge, Flockengröße, Tempo, Wind, Ausweichen, Ebene, "Schnee bleibt auf Fenstern liegen".
- **Allgemein:** Beim Anmelden starten, Immer Energie sparen, Berechtigungsstatus mit Erklärung und Button zu den Systemeinstellungen. Der Status aktualisiert sich live, während das Fenster offen ist.

Alle Einstellungen werden sofort sichtbar übernommen und bleiben über Neustarts erhalten. Die Oberfläche ist auf Deutsch und Englisch, je nach Systemsprache, sonst Englisch. Die Einstellungen sind mit VoiceOver bedienbar. Lichter und Schnee sind für VoiceOver unsichtbar.

## 8. Grafik

Alle Grafiken liegen in `Art/` und sind verbindlich. Maßgeblich sind `Art/README.md` und das Zielbild `Art/preview.png`. Birnen sind in jeder Palettenfarbe einfärbbar und bleiben in jeder Größe scharf. Für Elemente ohne Vorgabe (Schneeschicht auf Fenstern, Popovers, Einstellungsfenster) gestaltet das Team selbst, passend zum Stil der Vorgaben und zu macOS.

## 9. Rahmenbedingungen

- Name FestiveLights, Bundle-ID `ms.blckbox.FestiveLights` (Präfix so beabsichtigt), macOS 14 oder neuer, Apple Silicon und Intel.
- Swift mit SwiftUI und AppKit, keine Fremdabhängigkeiten ohne Rücksprache.
- Menüleisten-App ohne Dock-Symbol.
- Vertrieb direkt (signiert und notarisiert), nicht über den App Store.

## 10. Qualität und Energie

- Referenzgerät: MacBook Air M2, internes Display, Standardwerte. Messung: Mittel über 60 s in der Aktivitätsanzeige.
  - Nur Lichter mit Dauerleuchten, Zeiger weit weg: unter 1 % CPU.
  - Lichter mit Funkeln plus Schnee: unter 5 % CPU.
  - Schneesturm: unter 10 % CPU.
  - Speicher unter 150 MB.
  - Für Intel gibt es keinen Zielwert, die App muss dort aber flüssig laufen.
- Gesamtkosten zählen, nicht nur der eigene Prozess: Jede sichtbare Bewegung lässt den System-Prozess WindowServer das Bild neu zusammensetzen, das kostet je nach Gerät viel und ist nicht ganz vermeidbar. Maßstab ist deshalb ein Referenzprogramm auf demselben Gerät: ein transparentes Vollbildfenster, in dem 80 Punkte mit 60 Bildern pro Sekunde fallen. Mit Lichtern, Funkeln und Schnee darf die WindowServer-Last höchstens 3 Prozentpunkte über diesem Referenzwert liegen. Im Ruhezustand höchstens 2 Prozentpunkte über dem Wert ohne laufende App. Wo die Bildrate ohne sichtbaren Unterschied sinken kann, soll sie sinken.
- Andere Apps bleiben flüssig: Scrollen und Animationen in Safari und Finder laufen mit laufender App sichtbar genauso flüssig wie ohne, auch auf 120-Hz-Displays. Eingaben (Tippen, Klicken, Ziehen) bekommen keine spürbare Verzögerung.
- Energiebedarf in der Aktivitätsanzeige (Spalte "Energie") im Bereich typischer Hintergrund-Apps: im Ruhezustand nahe 0, mit Schnee niedrig.
- Nur zeichnen, was sich bewegt: Steht alles still (Dauerleuchten, kein Schnee, Zeiger weit weg), wird nichts neu gezeichnet. Bildschirme ohne sichtbare Bewegung und verdeckte Bereiche verursachen keine Arbeit.
- Fensterpositionen für F6 nur so oft ermitteln wie nötig: im Ruhezustand selten, beim Ziehen eines Fensters häufig genug für flüssiges Abschütteln.
- Mit vielen Fenstern (30 offene Fenster) und zwei Bildschirmen gelten dieselben Grenzen.
- Energiesparen: Im Akkubetrieb unter 20 % Ladung, im Stromsparmodus oder mit "Immer Energie sparen" halbe Flockenzahl und ruhigere Animation. Bei gesperrtem Bildschirm, Ruhezustand oder ausgeschaltetem Display pausiert alles.
- Keine sichtbar ausgelassenen Bilder bei 60 Hz und 120 Hz.
- "Bewegung reduzieren": Muster wird Dauerleuchten, kein Ausweichen, kein Aufstöbern und kein Nachpendeln, Schnee mit halbem Tempo ohne Böen und Pendeln, kein Schneesturm, das Menüleisten-Symbol steht still.
- Die Overlays stehlen nie den Fokus. Keine Abstürze ohne Berechtigung oder beim Wechsel von Bildschirmen.

## 11. Abnahme

1. Erster Start: Lichter sichtbar in unter 2 s ohne Interaktion. Schnee und Popover nach 3 s.
2. Durchklick-Prüfliste, jeweils bei beiden Ebenen: Menüleisten-Extras, Browser-Tabs direkt unter der Kette, Dock-Symbole unter der Dock-Kette, Fenster-Ampel unter der Schneeschicht, Drag-and-drop und Scrollen unter Schnee.
3. Ausweichen: Reaktion binnen 0,1 s, in einer Bildschirmaufnahme kein Sprung, Rückkehr binnen 1 s.
4. Zwei Bildschirme: Lichter und Schnee auf beiden. 20-mal Anstecken und Abstecken ohne Absturz.
5. Dock: App öffnen und beenden, Dock-Position wechseln, Auto-Hide schalten. Jeweils spätestens 0,5 s danach höchstens 2 pt Abweichung.
6. Schneeschicht: nach 5 Minuten Standardmenge sichtbar volle Schicht. 3 Richtungswechsel in 1 s plus ein weiterer entfernen etwa ein Drittel. Anhaltendes Schütteln macht das Fenster frei. Zehnmal normales Verschieben entfernt nichts. In einer vergrößerten Aufnahme einer Fensterecke liegt kein Schnee außerhalb der Fensterform.
7. Aufstöbern: Schnelles Durchfahren des Schnees (Zeigertempo über etwa 1000 pt/s) bewegt in zwei Aufnahmen im Abstand von 0,3 s sichtbar Flocken in Bewegungsrichtung. Nach 2 s fallen alle wieder normal. Beim Ausweichen und beim waagerechten Durchfahren bewegt sich keine Flocke nach oben. Schnelles Wischen über eine Schneeschicht erzeugt eine aufstiebende Wolke und eine Delle, die sich wieder füllt.
8. Berechtigung erteilen und entziehen ohne Neustart, Verhalten wie in Abschnitt 5.
9. "Bewegung reduzieren" wie in Abschnitt 10.
10. Einstellungen überleben einen Neustart.
11. CPU, Speicher, WindowServer-Mehrlast, Energiebedarf und Flüssigkeit anderer Apps wie in Abschnitt 10, auch mit 30 offenen Fenstern.
12. 8 Stunden Dauerlauf ohne nennenswerten Speicherzuwachs.
