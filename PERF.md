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
| 26.11.2026 | dock-probe (dieser Commit) | ohne App | 0,1 | - | |
| 26.11.2026 | dock-probe | Ruhezustand, mit Berechtigung (Bedienungshilfen, jetzt ereignisgetrieben) | 1,3 | 0,4 | vorher 1,4 / 0,7: keine 5-Hz-Abfrage mehr |
| 26.11.2026 | dock-probe | Ruhezustand, ohne Berechtigung (Treffer-Test) | 1,2 | 0,4 | im Ruhezustand keine Abfrage |
| 26.11.2026 | dock-probe | Standard (Funkeln, Schnee) | 46,9 | 4,1 | vorher 47,0 / 3,8, App +0,3 innerhalb der Schwankung |

Dock-Vergrößerung ohne Berechtigung (Treffer-Test, Debug-Build, Zeiger kreist 6 s über dem Dock): Haupt-Thread je Bild im Mittel 1,17 ms, höchstens 2,03 ms (Grenze 2 ms mittel, nie über 8 ms), Hintergrund je Messung im Mittel 4,9 ms, höchstens 23 ms. Die Messung der ruhenden Leiste (etwa 110 Aufrufe, 12 ms im Hintergrund) läuft nur bei Ereignissen.
