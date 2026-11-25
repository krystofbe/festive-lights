# Performance-Messungen

Mac mini (Testrechner), 1920x1080, 60 Hz, Release-Build, Mittel über 60 s mit `top -l 2 -s 60`. Spalten: WindowServer / FestiveLights in Prozent einer CPU.
Referenz für den WindowServer (SPEC §10): transparentes Vollbildfenster mit 80 fallenden Punkten bei 60 Bildern pro Sekunde: **43,8 %** (25.11.2026). Ohne App im Ruhezustand 0,1 %.
Regel: Vor jedem Commit, der Zeichnen, Abfragen, Timer oder Physik betrifft, gegen den vorherigen Stand messen. Verschlechterung über 0,3 Prozentpunkte beheben oder begründen.

| Datum | Commit | Zustand | WindowServer | App | Bemerkung |
|---|---|---|---|---|---|
| 25.11.2026 | 31f963e~ (frühe Fassung) | Standard (Funkeln, Schnee), mit RustDesk-Sitzung | 41,4 | 7,3 | Fensterliste 8 Hz, Funkeln mit jedem Bild |
| 25.11.2026 | dto. | Ruhezustand (Dauerleuchten, kein Schnee), mit RustDesk | 6,5 | 1,7 | Menüleisten-Symbol 4 Bilder pro Sekunde |
| 25.11.2026 | dto. | Schneesturm, mit RustDesk | 41,8 | 6,7 | |
| 25.11.2026 | dto. | 30 Fenster, Standard / ohne App, mit RustDesk | 37,7 / 30,9 | 7,0 | |
| 25.11.2026 | 31f963e | ohne App | 0,1 | - | ohne RustDesk |
| 25.11.2026 | 31f963e | Standard | 47,0 | 3,8 | Fensterliste 2 Hz, Muster mit 22 Bildern pro Sekunde |
| 25.11.2026 | 31f963e | Ruhezustand | 1,7 | 0,8 | |
| 25.11.2026 | 31f963e | Schneesturm | 47,1 | 5,7 | |
| 25.11.2026 | 31f963e | 30 Fenster, Standard / ohne App | 44,9 / 17,2 | 4,3 | |
| 25.11.2026 | b2b1c1b | Tanne warmgold, Ruhezustand | 1,7 | 0,8 | gleich wie klassisch |
| 25.11.2026 | b2b1c1b | Tanne bunt, Standard | 46,3 | 4,1 | |
| 25.11.2026 | 6300502 | Ruhezustand, Menüleisten-Symbol als Vorlage | 1,4 | 0,7 | Symbol in 3 Stufen |
| 25.11.2026 | 9641b00 | ohne App | 0,1 | - | |
| 25.11.2026 | 9641b00 | Ruhezustand, mit Berechtigung (Bedienungshilfen, jetzt ereignisgetrieben) | 1,3 | 0,4 | vorher 1,4 / 0,7: keine 5-Hz-Abfrage mehr |
| 25.11.2026 | 9641b00 | Ruhezustand, ohne Berechtigung (Treffer-Test) | 1,2 | 0,4 | im Ruhezustand keine Abfrage |
| 25.11.2026 | 9641b00 | Standard (Funkeln, Schnee) | 46,9 | 4,1 | vorher 47,0 / 3,8, App +0,3 innerhalb der Schwankung |

Dock-Vergrößerung ohne Berechtigung (Treffer-Test, Debug-Build, Zeiger kreist 6 s über dem Dock): Haupt-Thread je Bild im Mittel 1,17 ms, höchstens 2,03 ms (Grenze 2 ms mittel, nie über 8 ms), Hintergrund je Messung im Mittel 4,9 ms, höchstens 23 ms. Die Messung der ruhenden Leiste (etwa 110 Aufrufe, 12 ms im Hintergrund) läuft nur bei Ereignissen.
| 25.11.2026 | ca4b6c4 | Ruhezustand | 1,3 | 0,4 | Review-Befunde 1 bis 24 |
| 25.11.2026 | ca4b6c4 | Standard | 46,8 | 3,7 | vorher 46,9 / 4,1 |
| 25.11.2026 | c85a896 | Ruhezustand, mit Berechtigung | 1,3 | 0,4 | Dock-Review: Zustandsautomat, zwei Queues, Bedienungshilfen auf Queue |
| 25.11.2026 | c85a896 | Ruhezustand, ohne Berechtigung (Treffer-Test) | 1,3 | 0,4 | ein früherer Lauf zeigte 2,0 / 0,5, der Wiederholungslauf mit Referenz (ohne App 0,1) 1,3 / 0,4, also Ausreißer durch Fremdlast am Testrechner |
| 25.11.2026 | c85a896 | Standard | 47,0 | 3,7 | Referenz Vollbild-Animation 43,8, Differenz +3,2 |

Dock-Vergrößerung ohne Berechtigung nach dem Review (c85a896, Test-Build, 8 s Zeigerkreisen über dem Dock): Haupt-Thread je Bild im Mittel 0,011 ms, höchstens 0,044 ms (Grenze 2 ms mittel, nie über 8 ms), Hintergrund je Messung im Mittel 4,5 ms, höchstens 22,6 ms.
| 25.11.2026 | acde7e3 | Ruhezustand, mit Berechtigung | 1,3 | 0,7 | Nachprüfung N1 bis N10; App +0,3 gegenüber c85a896, Wiederholung 1,3 / 0,6 (+0,2, unter der Grenze 0,3); im Code ändert sich im Ruhezustand nichts (keine Timer, kein Abfragen), vermutlich Schwankung des Testrechners |
| 25.11.2026 | acde7e3 | Ruhezustand, ohne Berechtigung (Treffer-Test) | 1,4 | 0,7 | vorher 1,3 / 0,4 |
| 25.11.2026 | acde7e3 | Standard | 47,2 | 3,9 | vorher 47,0 / 3,7, Differenz zur Referenz 43,8 ist +3,4 |

Dock-Vergrößerung ohne Berechtigung (acde7e3, Test-Build, 8 s Zeigerkreisen): Haupt-Thread je Bild im Mittel 0,012 ms, höchstens 0,047 ms, Hintergrund je Messung im Mittel 4,6 ms, höchstens 25,8 ms (vorher 0,011 / 0,044 und 4,5 / 22,6).
| 25.11.2026 | 6613994 | Ruhezustand, mit Berechtigung | 1,3 | 0,7 | zweite Nachprüfung; gleich wie acde7e3 (1,3 / 0,7), Standard nicht neu gemessen (keine Änderung an Zeichnen oder Physik) |

A/B-Messung Ruhezustand am Testrechner (25.11.2026, direkt hintereinander, gleiche Bedingungen, Test-Build, mit Berechtigung, WindowServer / App): c85a896 1,3 / 0,7 und 1,3 / 0,7, 6613994 1,3 / 0,6 und 1,3 / 0,7 (ein Lauf mit 7,2 / 0,0 und einer mit 4,0 / 0,7 durch Fremdlast beziehungsweise nicht gestartete App, nicht gewertet beziehungsweise nur App gewertet). Der alte Stand liegt heute ebenfalls bei 0,7, der Unterschied zu den 0,4 vom Vormittag ist also Schwankung des Testrechners, keine Regression.

Tanne bunt und getrennte Ketten (25.11.2026, Test-Build, Mini, 40 s je Lauf, WindowServer / App): Ruhezustand klassisch 1,3 / 0,7 (zweimal), Tanne bunt 1,3 / 0,7 (zweimal), Tanne warmgold 1,4 / 0,7, kein Stilunterschied. Ein früherer Lauf mit Tanne bunt zeigte 2,5 / 0,7 und war Fremdlast. Standard mit Tanne bunt (Schnee, Funkeln): 46,4 / 4,1, Referenz 43,8, Differenz +2,6. Die Büschel sind vorgerenderte Bitmaps (je ein Layer), im Stillstand wird nichts gezeichnet. Die Ebenen ändern sich nur durch eine Stufe Abstand zwischen Kette und Schnee, die Fensterzahl bleibt gleich.

Einstellungsfenster offen (25.11.2026, Mini, Test-Build, Schnee an, Tanne bunt, App-CPU): vor der Korrektur (0b7dc89) 71,6 % beim Anlauf und 95,7 % mit offenem Fenster, Ursache: `energySaving` veröffentlichte bei jedem `apply()` (bildweise während des Schneeanlaufs) den Live-Status des Sparmodus, SwiftUI layoutete das Fenster pro Durchlauf neu. Nach der Korrektur (nur bei echter Änderung): 4,8 % beim Anlauf, 5,1 % danach, 5,5 % mit offenem Fenster. Test `SettingsViewStateTests`.

Abnahmewerte nach dem finalen Review (25.11.2026, Mini, Test-Build 658e9d8 plus Dock-Korrekturen, Standardeinstellungen: Tanne bunt an Menüleiste und Dock, Schnee, Funkeln, Mittelstellung; WindowServer / App, Spalten CPU, Speicher, Energie-Einfluss aus `top`):
- Standard: WindowServer 47,3 % (Energie 48,5), App 5,3 % (Energie 10,1), App-Speicher 18 MB Footprint, 91 MB resident. Grenzen: Speicher unter 150 MB erfüllt.
- Standard mit offenem Einstellungsfenster: 48,7 / 5,7, Speicher 35 MB Footprint. Der 0,4-Punkte-Aufschlag ist das Rendern des Fensters, ohne Timer und ohne Neulayout (der 100-%-Fehler ist behoben).
- Die App liegt mit 5,3 % knapp über der Grenze von 5 % für Funkeln plus Schnee, der WindowServer mit +3,5 über der Referenz 43,8 knapp über +3. Ursache: Seit der Umstellung ist Tanne bunt Standard an Menüleiste und Dock, es funkeln zwei Ketten statt einer (vorher eine Kette 46,4 / 4,1). Der `sample` zeigt keine einzelne Spitze: Schnee 1,6 %, Fensterabfrage 1,1 %, Ketten 0,7 %, Rest Bildschleife.
- Dock-Vergrößerung ohne Berechtigung, Tanne bunt, 8 s Zeigerkreisen: Haupt-Thread im Mittel 0,012 ms je Bild, höchstens 0,039 ms, Hintergrund im Mittel 4,3 ms, höchstens 21,3 ms (Grenze 2 ms mittel, nie über 8 ms).
- 8-Stunden-Lauf auf dem Mini gestartet (Standardeinstellungen, alle 5 Minuten Messung in `~/festivelights-test/long.log`), Ergebnis steht aus.

A/B Dock-Kette mit halber Funkelrate (25.11.2026, Mini mit neuem Standbild-Hintergrund, Standardeinstellungen, WindowServer / App, je zwei Läufe direkt hintereinander): vorher 48,8 / 6,0 und 48,6 / 5,8, nachher 48,9 / 5,9 und 48,8 / 5,7. Die halbe Rate spart nur etwa 0,1 Punkte App-CPU, der WindowServer bleibt gleich. Der Funkelrate-Anteil ist klein, die Last kommt vom Bildaufbau der Ketten und des Schnees. Gegenüber den Werten vom Vormittag (47,3 / 5,3) hat sich der Rechner verändert (neues Hintergrundbild), die Absolutwerte sind nicht vergleichbar. Die halbe Rate bleibt trotzdem drin (kein sichtbarer Unterschied bei der Dock-Kette). Der 8-Stunden-Lauf läuft seit 20:04 auf dem Stand mit halber Dock-Rate.

Neue Grenzen (SPEC §10, Entscheidung des Auftraggebers, 25.11.2026): Mit Ketten an Menüleiste und Dock liegt die App unter 7 % und der WindowServer höchstens 6 Prozentpunkte über der Referenz (43,8). Gemessen mit den Standardeinstellungen (Tanne bunt an beiden Ketten, Schnee, Funkeln): App 5,7 bis 6,0 %, WindowServer 48,6 bis 48,9 %, also +4,8 bis +5,1 über der Referenz. Beide Grenzen sind damit erfüllt. Es wird nicht weiter optimiert, die halbe Funkelrate am Dock bleibt.
