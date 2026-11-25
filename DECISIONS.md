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
- Ausweichen: Der Abstand zum Zeiger wird stetig und monoton aufgeweitet (freie Zone mit halbem Radius), Radien 30 bis 140 pt, Flocken folgen dem Ziel mit 70 ms Trägheit.
- Wind: 38 pt/s mit Böen. Sturm bei "Wind aus" weht nach rechts.
- Etwa 70 % der vordersten Flocken (Tiefe über 0,9) sind Kristalle.
- Sturm: Hülle in `StormEnvelope`, nicht gespeichert, Menüeintrag als Schalter.
- Mit "Bewegung reduzieren" ist der Sturm nicht startbar (Menüeintrag deaktiviert).

## Schneeschicht (F6)
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
