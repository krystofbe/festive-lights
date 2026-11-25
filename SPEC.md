# FestiveLights: Spezifikation

Stand: Entwurf zur Abstimmung. Diese Spezifikation beschreibt ausschließlich Verhalten und Erlebnis aus Nutzersicht. Sie enthält bewusst keine Implementierungsdetails. Wie etwas technisch gelöst wird, entscheidet das Implementierungs-Team.

## 1. Produktidee

FestiveLights macht den Mac in der Weihnachtszeit festlich: eine Lichterkette hängt unter der Menüleiste, Schnee fällt über den Bildschirm. Beides reagiert auf den Mauszeiger und stört nie bei der Arbeit.

Ziel ist ein Lächeln innerhalb von 10 Sekunden nach dem ersten Start und dass Nutzer die App die ganze Saison über anlassen.

## 2. Gestaltungsprinzipien

1. **Liebe zum Detail vor Feature-Menge.** Lieber wenige Dinge, die sich hochwertig und lebendig anfühlen.
2. **Nie im Weg.** Klicks gehen immer durch Lichter und Schnee hindurch. Was dem Zeiger nahekommt, weicht sanft aus.
3. **Sofortige Magie.** Nach dem Start leuchtet es sofort, ohne Einrichtung und ohne Dialoge.
4. **Respekt vor dem Rechner.** Sparsam mit Energie, besonders im Akkubetrieb.
5. **Ruhig konfigurierbar.** Wenige, verständliche Einstellungen statt einer Optionswüste.

## 3. Umfang

### Stufe 1, ohne jede Berechtigung (sofort beim ersten Start)

**F1 Lichterkette an der Menüleiste**
- Ein Kabel hängt in mehreren gleichmäßigen Bögen unter der Menüleiste über die volle Bildschirmbreite, an jedem Bildschirm mit Menüleiste.
- Glühbirnen hängen in gleichmäßigen Abständen am Kabel. Jede Birne ist leicht und zufällig geneigt, damit es natürlich wirkt.
- Farben wechseln reihum durch eine festliche Palette (rot, gelb, grün, blau, lila). Alternativ ein warmweißer Modus.
- Muster: Dauerleuchten, sanftes Funkeln (einzelne Birnen dimmen zufällig kurz ab), Lauflicht. Standard ist Funkeln.
- Nähert sich der Mauszeiger dem Kabel, hebt sich der betroffene Kabelabschnitt sanft vom Zeiger weg und senkt sich wieder, wenn der Zeiger geht. Bewegung weich, ohne Ruckeln.
- Klicks in den Bereich hinter Kabel und Birnen erreichen immer die darunterliegende App.

**F2 Schnee**
- Schneeflocken fallen über alle Bildschirme. Mehrere Tiefenebenen: nahe Flocken größer, schneller, heller; ferne kleiner, langsamer, blasser.
- Flocken pendeln leicht seitlich, Wind kann sie gleichmäßig in eine Richtung treiben, gelegentliche Böen variieren die Bewegung.
- Flocken weichen dem Mauszeiger aus. Um den Zeiger entsteht eine kleine schneefreie Zone, die Flocken teilen sich um ihn herum.
- Einstellbar: Schneemenge, Flockengröße, Fallgeschwindigkeit, Wind (aus, links, rechts), Stärke des Ausweichens.
- **Schneesturm:** ein Schalter im Menü, der für den Moment Menge und Tempo deutlich erhöht.
- Schnee sieht besonders vor dunklem Hintergrund gut aus, muss aber auch auf hellem Hintergrund sichtbar bleiben (zum Beispiel durch einen leichten Kontrast oder Schatten).

**F3 Ebene wählen**
- Lichter und Schnee lassen sich jeweils "über allen Fenstern" oder "nur auf dem Schreibtisch" (hinter allen Fenstern) anzeigen.

**F4 Mehrere Bildschirme**
- Lichter und Schnee erscheinen auf allen angeschlossenen Bildschirmen. An- und Abstecken sowie Auflösungswechsel werden ohne Neustart übernommen.
- Bei Vollbild-Apps und auf allen Spaces verhalten sich die Overlays konsistent.

### Stufe 2, nach einer optionalen Berechtigung

Diese Funktionen brauchen die macOS-Bedienungshilfen-Berechtigung. Die App fragt erst danach, wenn der Nutzer die Stufe 1 erlebt hat (siehe Abschnitt 5). Ohne Berechtigung fehlen nur diese Funktionen, alles andere läuft.

**F5 Lichterkette am Dock**
- Eine zweite Lichterkette folgt der Oberkante des Docks (bzw. der Innenkante bei Dock links oder rechts) über die volle Dock-Breite.
- Wenn Apps geöffnet oder beendet werden und das Dock dadurch breiter oder schmaler wird, passt sich die Kette nach Ende der Dock-Animation zuverlässig an.
- Ausgeblendetes Dock: Kette erscheint und verschwindet mit dem Dock.
- Gleiche Optionen wie F1 (Farben, Muster), eigene Ein/Aus-Einstellung.

**F6 Schnee bleibt auf Fenstern liegen**
- Fallender Schnee sammelt sich langsam auf den Oberkanten der Fenster und baut sich über Minuten zu einer weichen Schneeschicht auf.
- Wird ein Fenster bewegt, rieselt etwas Schnee herunter. Wird ein Fenster geschlossen oder minimiert, fällt sein Schnee herab.
- **Abschütteln:** Schüttelt man ein Fenster kurz, fällt ein Teil des Schnees ab. Schüttelt man weiter, ist es irgendwann ganz frei. Hört man auf, baut sich der Schnee wieder auf. Normales Verschieben eines Fensters zählt nicht als Schütteln.
- Herabfallender Schnee zerfällt in feine Flocken, die natürlich und leicht unterschiedlich schnell fallen und ausblenden.

### Nicht im Umfang

Eigener Birnen-Editor, Import und Export von Designs, Kurzbefehle, Zeiger-Effekte, mehrseitiges Onboarding, iPhone-Anbindung, Countdown, Updates über einen Update-Mechanismus.

## 4. Bedienung

**Menüleisten-Symbol** (bunt, drei Birnen am Kabel, dezent animiert, siehe Art/README.md) mit Menü:
- Lichter an der Menüleiste (an/aus)
- Lichter am Dock (an/aus; ohne Berechtigung mit Hinweis "Berechtigung nötig")
- Schnee (an/aus)
- Schneesturm (an/aus)
- Einstellungen…
- Beenden

**Einstellungsfenster**, kompakt, drei Bereiche:
- **Lichter:** Farbmodus (bunt, warmweiß), Muster, Tempo, Birnengröße, Abstand der Birnen, Ebene (F3), Dock-Lichter an/aus.
- **Schnee:** Menge, Flockengröße, Tempo, Wind, Ausweichen, Ebene (F3), "Schnee bleibt auf Fenstern liegen" an/aus.
- **Allgemein:** Beim Anmelden starten, Energiesparen (siehe Abschnitt 6), Berechtigungsstatus mit Erklärung und Button zu den Systemeinstellungen, live aktualisiert.

Alle Einstellungen werden sofort sichtbar übernommen und bleiben über Neustarts erhalten.

## 5. Erster Start

1. App startet, Lichter an der Menüleiste gehen sofort an. Kein Dialog, kein Fenster.
2. Ein kleines, freundliches Hinweisfenster oder Popover am Menüleisten-Symbol: "Lass es schneien ❄️" mit einem Button, der den Schnee einschaltet.
3. Frühestens danach, einmalig und überspringbar: "Lichter auch ans Dock und Schnee, der auf Fenstern liegen bleibt?" mit Erklärung, wofür die Berechtigung gebraucht wird, und Button zu den Systemeinstellungen. Wird die Berechtigung erteilt, schalten sich F5 und F6 ohne Neustart ein.

## 6. Qualität und Energie

- Im Ruhezustand (Zeiger nicht in der Nähe, Muster Dauerleuchten) praktisch keine CPU-Last. Mit Schnee und Funkeln deutlich unter 5 % CPU auf einem aktuellen Apple-Silicon-Mac.
- Energiesparen: im Akkubetrieb bei niedrigem Ladestand oder aktivem Stromsparmodus reduzierte Bildrate. Option "Immer Energie sparen".
- Keine sichtbaren Ruckler bei 60 Hz und ProMotion.
- "Bewegung reduzieren" in den Bedienungshilfen wird respektiert (keine Ausweich- und Funkelanimation, ruhiger Schnee).
- Overlays tauchen nicht in der Fensterauswahl von Bildschirmfotos auf und stehlen nie den Fokus.
- Keine Abstürze ohne Berechtigung oder beim Wechsel von Bildschirmen.

## 7. Grafik

Alle Grafiken (Birnen, Schneeflocken, App-Icon, Menüleisten-Symbol) sind abgestimmte Vorgaben und liegen im Ordner `Art/`. Verbindlich ist `Art/README.md` samt Farbpalette; `Art/preview.png` zeigt das Zielbild. Birnen werden aus den Vektor-Ebenen zusammengesetzt, in jeder Palettenfarbe eingefärbt und bleiben in jeder Größe scharf. Keine anderen Grafiken verwenden.

## 8. Technische Rahmenbedingungen

- Name FestiveLights, Bundle-ID `ms.blckbox.FestiveLights`, macOS 14 oder neuer, Apple Silicon und Intel.
- Swift, SwiftUI und AppKit. Keine Fremdabhängigkeiten ohne Rücksprache.
- Menüleisten-App ohne Dock-Symbol.
- Vertrieb direkt (signiert, notarisiert), nicht über den App Store.

## 9. Abnahme

- Erster Start: Lichter sichtbar in unter 2 Sekunden, ohne Interaktion.
- Klick durch Lichter und Schnee auf darunterliegende Bedienelemente funktioniert überall.
- Zeiger an Kabel und in den Schnee: sichtbares, weiches Ausweichen.
- Zwei Bildschirme: Lichter und Schnee auf beiden, Abstecken ohne Fehler.
- Dock: App öffnen und beenden, Kette passt sich danach korrekt an.
- Schnee auf Fenstern: nach einigen Minuten sichtbare Schicht. Kurzes Schütteln entfernt einen Teil, langes alles, normales Verschieben nichts.
- CPU-Messung gemäß Abschnitt 6.
