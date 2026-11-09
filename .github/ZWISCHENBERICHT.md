# Zwischenbericht 128-Bit-QR-Projekt

Stand: 2026-11-09 (aktualisiert nach Schritten 1-4 der Liste unten). Ergänzt `.github/QR-128BIT-AGENT-NOTES.md` (dort stehen Ziel, Budget, Tools, Umgebungs-Fallen, vollständiges Änderungslog). Dieser Bericht fasst nur Stand, Offenes und die nächsten Schritte zusammen.

## Ergebnis bis jetzt

Gezippte 64-Bit-EXE (Datei im Zip `M.exe`, zlib Level 9):

| Schritt | Zip (Bytes) |
|---|---:|
| Ausgangslage (Commit `86ccc1f`) | 3229 |
| Linkeroptionen (eine Sektion, kein Debug/Manifest/Rich-Header, 64-Byte-DOS-Stub) | 2719 |
| Imports/Init in `main64.asm` verkleinert | 2245 |
| `call`/`ret` statt `lea r15` + `jmp r15` | 2197 |
| `Function_ZoomAxis` (Zoom-/Begrenzung für x und y als eine Subroutine), `IMAGE_WIDTH`/`IMAGE_HEIGHT` als EQU | 2095 |
| Sign-Maske-Peepholes (`btr`/`btc`/`test`+`js`/`shl`) | 2069 |
| `xor r32`, `Draw` ohne Push/Pop + Pixelzeiger (`r12` in `start` gesichert) | 2053 |
| Direkte IAT-Calls (`call qword ptr [__imp_X]`) statt Thunks | **2022** |

- Aktuelle EXE: 4096 Bytes (Ausgangslage 7680).
- Platzbudget: Zip ≤ ~1765 B bei dem Skript von jetzt (~600 Zeichen), ≤ ~1990 B bei ~300 Zeichen. Die **minimale QR-Variante passt bereits** (2693 / 2953 B, siehe Log 17 der Agent-Notizen). Die volle Variante mit Anleitung ist noch 172 B zu groß.
- Jeder Schritt wurde mit `Tools/ExeSmokeTester` gegen die unveränderte Original-EXE geprüft: alle 12 Screenshot-Schritte pixelgleich. Auch der aktuelle Stand ist verifiziert (`OK`, 12/12 identisch).

## Arbeitsstand der Dateien (uncommitted)

- `SmallASM/main64.asm`: Stand nach `Function_ZoomAxis`, gebaut und getestet.
- `SmallASM/SmallASM64.vcxproj`: neue Linkeroptionen (Release).
- `SmallASM/stub64.bin`: 64-Byte-DOS-Stub, neu.
- `Tools/ExeSmokeTester/`: neu (C#, EXE-unabhängiger Screenshot-Regressionstest).
- `Tools/AsmSizeReport/asm_size_report.py`: neu (Bytes je Befehlsmuster aus ml64-Listing).
- `.github/QR-128BIT-AGENT-NOTES.md`, `.github/copilot-instructions.md` (Verweis).

Es wurde nichts committet. Die Hilfsdateien liegen in `%TEMP%\mb_work\` (Baseline-EXE, Referenzscreenshots `ref\`, `build64.sh`/`test64.sh`/`zsize.py` in `/tmp`) und gehen beim Aufräumen verloren. Wie man sie neu erzeugt, steht in den Agent-Notizen (Abschnitt 6).

## Entscheidungen, die du getroffen hast (umgesetzt)

- 32-Bit-Tools dürfen für 64 Bit angepasst werden, ohne die 32-Bit-Version zu brechen. **Noch nicht begonnen.**
- Zoom-/Begrenzungslogik als Subroutine für x und y: **erledigt** (`Function_ZoomAxis`, Adresse des Achsenblocks in `rdi`, Bildgröße in `rsi`, neue Pixelgröße in `r13`/`r14`; Kommentare vom Original übernommen).
- Konstante Werte wie `MODOLU_MASK_COLOUR`: `IMAGE_WIDTH EQU 800` und `IMAGE_HEIGHT EQU 608` **erledigt**. Kleinere Datentypen für `ua_width`/`ua_height` sind damit hinfällig.
- Nach jedem größeren Schritt loggen: erledigt für die Schritte bis hierher.

## Als Nächstes (nicht ausgeführt)

1-4. ~~Sign-Maske-Peepholes, `xor r32`, API-Thunks, `Draw`~~ **erledigt** (Log 13-16 in den Agent-Notizen).
5. **x64-Tools**: `PostLinkStripper`/`MiniPeLinker` für PE32+ verallgemeinern (Image-Base 8 Byte, Optional-Header-Offsets 112 statt 96, 8-Byte-Importthunks, `Machine 0x8664`), 32-Bit-Verhalten unverändert lassen und mit dem 32-Bit-Build gegenprüfen. `BuildAndAnalyze.ps1 -Bits 64` danach an die neue Pipeline anbinden und Zip-Größe ausgeben.
6. **QR-Skript** (`generator.py`) kürzen: Dateiname `M.exe`, kürzere Anleitung, Länge gegen 2953 prüfen, `testQR.py` zum Zurücklesen laufen lassen.
7. ~~Besser komprimieren~~ Zopfli ist im Generator. Offen: kurze Doku zu Bauen/Verkleinern.

## Offene Risiken

- `BuildAndAnalyze.ps1` wurde nicht ausgeführt: PowerShell kann in der Agent-Umgebung keine Programme starten. Gebaut wurde per MSBuild aus Bash.
- Ohne `ExitProcess` und mit NULL-`hInstance` getestet nur auf diesem Rechner (Windows 11). Fixed Base (kein ASLR) ist Voraussetzung für `QWORD OFFSET` in `.data`.
- `EndPaint`, `LoadCursorA` bleiben vorerst, obwohl entfernbar (würde Verhalten ändern).
- `/VOLATILEMETADATA:NO` wurde aus dem `.vcxproj` entfernt (Linker ignorierte es). Der Linker meldet weiterhin erwartete Warnungen LNK4108/4254/4060.
