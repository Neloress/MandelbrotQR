# Agent-Notizen: 128-Bit-Mandelbrot (`main64.asm`) in einen QR-Code packen

Stand: 2026-11-09, Zwischenstand. Alles hier wurde gemessen oder gebaut, nichts geraten. Nicht committet, Änderungen liegen im Arbeitsverzeichnis.

## 1. Ziel

- Die 32-Bit-Variante (`SmallASM/main.asm`) passt bereits in einen QR-Code (`QR_Generator/`, Zip 1842 B).
- Dasselbe soll für die 128-Bit-Variante (`SmallASM/main64.asm`, x64, Festkomma 1+5+122 Bit) gelingen.
- Maßgeblich ist die **gezippte Größe**, nicht die EXE-Größe. Nullen/Padding kosten gezippt fast nichts.
- Änderungen am Code müssen geloggt werden (siehe Abschnitt 8). Skripte müssen funktionsfähig bleiben. Doku soll kurz sein.
- Das QR-Skript (`QR_Generator/generator.py`) darf stark gekürzt werden, aber es soll Platz für eine Anleitung bleiben (die 128-Bit-Version hat mehr Features: Tasten 1-5 = Iterationen 10..100000, 6-9 = Pixelblock 1/2/4/8).
- Konvention aus `copilot-instructions.md`: Abweichungen der 64-Bit-Version vom 32-Bit-Code mit `;64bit-specific` markieren.

## 2. Platzbudget

- QR Version 40, Level L, Byte-Modus: **2953 Bytes**.
- Payload = Skript-Text + Base64(Zip). Base64 kostet 4/3.
- Zip-Größe max. = `floor((2953 - Skriptlänge) / 4) * 3`.
  - Skript 600 Zeichen (jetzt: Anleitung + Entpack-Befehle ≈ 600) → Zip ≤ ~1765 B.
  - Skript 300 Zeichen → Zip ≤ ~1989 B.
- Zip-Container-Overhead ≈ 30 + 46 + 22 + 2×Dateinamenlänge. Dateiname `M.exe` statt `MandelbrotSet.exe` spart ~24 B. Raw-Deflate ohne Zip (`DeflateStream`) spart ~100 B Container, braucht aber längeren PowerShell-Text.
- Zip mit `zlib` Level 9 messen: `python /tmp/zsize.py <exe>` (Hilfsskript, siehe Abschnitt 6). 7-Zip/Zopfli könnte noch ~3 % bringen (ungetestet).

## 3. Vorhandene Tools im Repo

| Tool | Zweck | Gilt für |
|---|---|---|
| `Tools/BuildAndAnalyze.ps1 -Bits 32\|64` | MSBuild + `EXE-GROESSENANALYSE.md` | 64-Bit-Zweig baut nur, ruft **keinen** Stripper/Minimizer auf |
| `Tools/PostLinkStripper` | entfernt `.rdata$zzzdbg` laut Map | nur x86 (liest 4-Byte-ImageBase, PE32-Offsets) |
| `Tools/MiniPeLinker` (+ `imports.csv`) | `.idata` hinter `.text`, eine Sektion, prüft entfernte Imports | nur x86/PE32, erwartet 2 Sektionen |
| `Tools/ImportRegressionTester` | entfernt iterativ Imports in `main.asm`, testet per Screenshot | nur Win32/`main.asm` |
| `Tools/ExeSmokeTester` (**neu**) | startet beliebige EXE, Szenario aus Tasten/Maus/Zoom, Screenshots, pixelgenauer Vergleich gegen Referenz | EXE-unabhängig |
| `Tools/AsmSizeReport/asm_size_report.py` (**neu**) | ml64-Listing → Bytes je Befehlsmuster | `main64.asm` |
| `QR_Generator/generator.py`, `testQR.py` | QR erzeugen / per pyzbar zurücklesen | beide |

Die 32-Bit-Tools funktionieren **nicht** für x64. Beim `.vcxproj` für 64 Bit gibt es keinen `MinimizeRelease`-Target (das 32-Bit-Projekt `SmallASM32.vcxproj` hat einen).

## 4. Umgebungs-Fallen (wichtig)

- Die Bash-Umgebung des Agenten kann mit PowerShell **keine nativen Programme starten** (`& msbuild` liefert keine Ausgabe, `$LASTEXITCODE` leer, `$PSScriptRoot` leer). `BuildAndAnalyze.ps1` ließ sich dadurch hier nicht testen. Stattdessen direkt aus Bash:
  - MSBuild: `"/c/Program Files/Microsoft Visual Studio/18/Community/MSBuild/Current/Bin/MSBuild.exe" SmallASM/SmallASM64.vcxproj //t:Rebuild //p:Configuration=Release //p:Platform=x64 //v:minimal` (doppelte Slashes wegen Git-Bash-Pfadumwandlung).
  - csc: `.../MSBuild/Current/Bin/Roslyn/csc.exe //nologo //target:exe //r:System.Drawing.dll //out:X.exe Program.cs`.
  - dumpbin / ml64: `.../VC/Tools/MSVC/14.44.35207/bin/HostX64/x64/`. ml64-Optionen ohne Leerzeichen (`/Fo<datei>`, `/Fl<datei>`), `MSYS2_ARG_CONV_EXCL="*"` setzen.
- Ausgabe der 64-Bit-Release-EXE: `SmallASM/x64/Release/SmallASM64.exe` (Map: `SmallASM64.map`).
- Python 3.13 mit `qrcode`, `PIL`, `pyzbar` ist installiert.
- `ExeSmokeTester` benötigt einen sichtbaren interaktiven Desktop (CopyFromScreen). Er setzt das Fenster auf (100,50) und TOPMOST und erfasst nur die Client-Area, dann sind Screenshots deterministisch. Ein Lauf dauert ~40 s.

## 5. Programmverhalten (relevant für Tests)

- Fenster 800x600 (Außenmaß, CW_USEDEFAULT-Position), DIB 800x608 bottom-up, Fester Mandelbrot-Ausschnitt, Start: Iterationen 10, Pixelblock 4.
- Mausrad **positiv = Zoom hinein**, negativ = hinaus (empirisch geprüft; die Namen `zoom_factor_in/out` im Code sind vertauscht gegenüber dem Verhalten). In der Startansicht ist hinauszoomen begrenzt (keine Änderung).
- Zoom um die zuletzt per `WM_MOUSEMOVE` gemeldete Mausposition. Tests senden Nachrichten per `PostMessage`, echte Maus nicht nötig.
- Tasten `'1'..'5'` Iterationen, `'6'..'9'` Pixelblock 1,2,4,8 (`WM_KEYDOWN`, `wParam`).
- `WM_CLOSE` → `DefWindowProc` → `WM_DESTROY` → `PostQuitMessage`. Kein DestroyWindow-Import nötig.
- Rechenfunktionen `Function_MulF/MulFint/AddF/GetIterations` sind interne Routinen mit eigener Registerkonvention (Parameter in rbx/rcx/rbp/r8, Ergebnis rbx/rcx). **Kein** Windows-ABI. Sie nutzen keinen Stack und rufen keine APIs auf, daher ist Stack-Ausrichtung dort egal.

## 6. Messmethodik

1. Bauen (siehe Abschnitt 4), Größe und Zip messen. Hilfsskript (lag nur in `/tmp`, bei Bedarf neu anlegen): Python `zipfile` (Level 9) und `zlib.compressobj(9, DEFLATED, -15)` auf die EXE anwenden, Name `M.exe`.
2. Regression: Referenz einmalig aus der **unveränderten Original-EXE** erzeugen: `ExeSmokeTester.exe baseline.exe ref`. Die Original-EXE ist das Build von Commit `86ccc1f` (mit Standard-Linkeroptionen). Danach jede Änderung mit `ExeSmokeTester.exe neu.exe run ref` prüfen. Erwartet: `OK`, alle 12 Schritte `identical`. Kleine Abweichungen sind nur zulässig, wenn sie beabsichtigt sind (dann Referenz neu erzeugen und im Log vermerken).
3. Referenzbilder und Baseline lagen in `%TEMP%\mb_work\` (`baseline.exe`, `ref\`). Sind sie weg: `git stash`/`git worktree` auf `86ccc1f`, bauen, Referenz neu erzeugen.
4. Bytes je Befehlsmuster: `python Tools/AsmSizeReport/asm_size_report.py C:\...\SmallASM\main64.asm 30`.

## 7. Messwerte bisher (Zip mit Name `M.exe`)

| Schritt | EXE | Zip | Raw-Deflate |
|---|---:|---:|---:|
| Ausgangslage (Commit `86ccc1f`, Release) | 7680 | 3229 | 3121 |
| Linker: `/ALIGN:512 /FILEALIGN:512 /DEBUG:NONE /MANIFEST:NO /MERGE:.rdata=.text /MERGE:.data=.text /SECTION:.text,RWE`, EnableUAC aus, Fixed Base, GenerateDebugInformation aus | 6656 | 2832 | 2724 |
| + `/STUB:stub64.bin` (64-Byte-DOS-Header), `/EMITTOOLVERSIONINFO:NO` (kein Rich-Header) | 6144 | 2719 | 2611 |
| + Imports/Init-Umbau in `main64.asm` (Abschnitt 8) | 5120 | 2245 | 2137 |
| + `call`/`ret` statt `lea r15`/`jmp r15`, r15/rsi-Sicherungen entfernt | 4608 | 2197 | 2089 |
| + Zoom-/Begrenzungslogik als `Function_ZoomAxis` (x und y), `IMAGE_WIDTH/HEIGHT` als EQU | 4608 | 2095 | 1987 |
| + Sign-Maske-Peepholes (Log 13) | 4608 | 2069 | 1961 |
| + `xor r32` + `Draw` ohne Push/Pop, Pixelzeiger (Log 14-15) | 4608 | 2053 | 1945 |
| + direkte IAT-Calls statt Thunks (Log 16) | 4096 | **2022** | 1914 |

Zielbereich: Zip ≲ 1765 B (aktuelles Skript) bzw. ≲ 1990 B (Skript auf ~300 Zeichen gekürzt). Es fehlen noch **~30-260 B**.

Grobe Zerlegung (Stand 2245 B, Raw-Deflate): Header ≈ 130, Code ≈ 1500, Daten ≈ 160, Imports ≈ 330. Der Code komprimiert nur auf ~55 %, weil x64-Code viele `mov reg, imm64`, REX-Präfixe und rel32 enthält.

Funktionsgrößen vor dem Umbau (Byte): Math-Funktionen ≈ 670, Draw 330, WndProc 693, start ≈ 1350 (davon der Zoom-/Begrenzungsblock der größte Teil).

## 8. Änderungslog (Code, `main64.asm` / `.vcxproj`)

Alle Änderungen: Screenshots pixelgleich zur Original-EXE.

**SmallASM64.vcxproj (Release)**: Linkeroptionen wie oben, `GenerateDebugInformation=false` (Link und MASM), `LinkIncremental=false`, `EnableUAC=false`, `FixedBaseAddress=true`, `RandomizedBaseAddress=false`, `DataExecutionPrevention=false`. Neue Datei `SmallASM/stub64.bin` (64 Byte: `MZ`, `e_lfanew=0x40`). `LNK4108`/`LNK4254`/`LNK4060` sind erwartete Warnungen.

**main64.asm**
1. **WM_SIZE-Handler entfernt.** Bitmap-Größe ist fest 800x608; `ua_width`/`ua_height` statisch 800/608. Erste Zeichnung passiert in der Hauptschleife, weil `a_enable_draw` initial 1 ist.
2. **`GetClientRect` entfernt** (auch in `WM_PAINT`): BitBlt nimmt konstant 800x608, das Client-DC clippt.
3. **Bitmap und Memory-DC werden einmal in `start` erzeugt** (`CreateCompatibleDC(NULL)`, `CreateDIBSection`, `SelectObject`). `RecreateBitmap` entfällt komplett (Draw überschreibt alle Pixel, Größe ändert sich nie). Pro Paint kein `CreateCompatibleDC`/`SelectObject`/`DeleteDC` mehr (löst nebenbei das DC-Leck pro Paint). Entfernte Imports: `DeleteObject`, `DeleteDC`.
4. **`WNDCLASSEXA` und `BITMAPINFOHEADER` statisch in `.data` initialisiert** (`QWORD OFFSET WndProc` – funktioniert wegen Fixed Base ohne Relocations). Zur Laufzeit wird nur `hCursor` gesetzt. Entfernt: ~20 `mov [ua_wc+...]`-Stores und 15 redundante `mov dword ptr [ua_bmi+..], 0`-Stores.
5. **Imports entfernt**: `GetModuleHandleA` (hInstance = NULL), `ExitProcess` (Rücksprung aus `start` beendet den Prozess; nichtflüchtige Register werden gesichert), `ShowWindow` (Fensterstil `WS_VISIBLE`: `100A0000h`), `SetFocus`, `TranslateMessage` (WM_KEYDOWN wird direkt behandelt), `LoadIconA` (hIcon = NULL, nur kosmetisch anderes Icon möglich). Geblieben: `RegisterClassExA, CreateWindowExA, DefWindowProcA, GetMessageA, DispatchMessageA, PostQuitMessage, LoadCursorA, BeginPaint, EndPaint, BitBlt, CreateCompatibleDC, CreateDIBSection, SelectObject, InvalidateRect`.
6. **Stack-Ausrichtung einmal statt pro API-Aufruf.** Die `mov rsi,rsp / and rsp,-16 / sub rsp,32 / … / mov rsp,rsi`-Hüllen sind weg. `start` sichert rbx, rbp, r13, r14 + Dummy-`push rax` (macht rsp 16-ausgerichtet), legt dauerhaft `push 0 / push 0 / sub rsp,20h` an (2 genullte Stack-Parameter für `CreateDIBSection` + Shadow-Space). `CreateWindowExA`-Parameter per `push` (rechts nach links), danach `sub rsp,20h … add rsp,60h`.
7. **`WM_PAINT`** neu: `BeginPaint`, `BitBlt` (800, 608, `ua_hdcMem`, SRCCOPY), `EndPaint` mit gesichertem `hwnd` (früher `ua_hwnd`, das vor `CreateWindowEx` noch 0 war).
8. **`lea r15, X / jmp Function_Y / X:` → `call Function_Y`** (29 Stellen), `jmp r15` → `ret`. `push/pop r15` in `GetIterations`, `Draw`, `start` entfernt.

9. **`Function_ZoomAxis`** (Schritt 3): Der Zoom-/Begrenzungsblock für X und Y (vorher ~2×140 Zeilen in `start`) ist eine Subroutine (`call`/`ret`, wie `MulF`/`AddF`). Aufruf zweimal: `lea rdi, a_lowerLeft_x_low` + `mov esi, IMAGE_WIDTH`, dann `add rdi, AXIS_SIZE` + `mov esi, IMAGE_HEIGHT`. Eingaben: `rdi` = Adresse des Achsenblocks, `rsi` = Bildgröße der Achse, `r13/r14` = neue pixelSize (low/high). Kommentare und Variablennamen aus dem Original übernommen (`_x`/`_y` → ohne Suffix). Labels: `BoundNewLL_4`, `BoundNewLL_8`.
10. **Achsenblöcke in `.data`**: x und y haben identisches Layout (Offsets `AXIS_lowerLeft_low=0`, `_high=8`, `_min_high=16`, `upperRight_max_high=24`, `AXIS_mousePos=32`, `AXIS_SIZE=40`; 4 Byte Padding). Die Namen `a_lowerLeft_x_low` usw. und `a_mousePos_x` bleiben als Labels erhalten (Draw/WndProc unverändert). Zugriffe über `[rdi+disp8]` sind 4 statt 7 Byte.
11. **`IMAGE_WIDTH EQU 800` / `IMAGE_HEIGHT EQU 608`** (wie `MODOLU_MASK_COLOUR`) statt `ua_width`/`ua_height`-Variablen. Nutzung: `mov r14d, IMAGE_HEIGHT`, `imul rax, rax, IMAGE_WIDTH`, BitBlt, `ua_bmi`, `CreateWindowExA`. Kleinere Datentypen waren damit hinfällig, die Variablen existieren nicht mehr.
12. `start` sichert jetzt rbx, rbp, rdi, rsi, r13, r14; das 16-Byte-Alignment kommt aus einem dritten `push 0` im Dauer-Frame (`push 0`×3 + `sub rsp,20h`, Abbau `add rsp,38h`).

13. **Sign-Maske-Peepholes** (`MulF`, `MulFint`, `AddF`, `GetIterations`, `ZoomAxis`, Zoom-Start): `mov rax, 8000000000000000h` entfällt überall. Vorzeichen per `btr/btc reg, 63`, `test reg,reg` + `js/jns`, `shr/shl 63`; Betragsvergleich in `ZoomAxis` über `shl reg, 1` auf beiden Seiten; Nullprüfung der pixelSize-High per `mov rax, rcx / shl rax, 1`. Gewinn nur −26 B gezippt (Code −60 B roh).
14. **`xor r64, r64` → `xor r32, r32`** (z0-Initialisierung in `GetIterations`, Zoom-Start).
15. **`Draw`**: keine Push/Pops und kein `sub rsp, 28h` mehr (nur von `start` gerufen, ruft keine API). `start` sichert dafür zusätzlich `r12` (ersetzt den Alignment-Dummy-`push 0`, Abbau `add rsp, 30h` + `pop r12`). Pixel-Schreiben: Blockstart-Adresse einmal per `imul`, danach Zeiger (`add rdx, 4` / `add rsi, IMAGE_WIDTH*4`), Zähler 1..B statt B-1..0 mit `jnz`.
16. **API-Thunks entfernt**: `EXTERN __imp_X:QWORD` + `call qword ptr [__imp_X]` für alle 14 APIs. Die 6-Byte-`jmp [IAT]`-Thunks entfallen, EXE 4608 → 4096 B.

17. **`QR_Generator/generator.py` neu**: `python generator.py [exe]` (Default `SmallASM/x64/Release/SmallASM64.exe`) erzeugt zwei Varianten, jeweils plug and play (Text in PowerShell einfügen, EXE wird nach `%TEMP%` entpackt und gestartet). Deflate per Zopfli (`pip install zopfli`, sonst zlib Level 9). `QR.png`/`QR.ps1`: volle Variante mit Anleitung, Zip + `Expand-Archive` (eigener Zip-Writer, damit der Zopfli-Stream ins Zip kommt). `QR_min.png`/`QR_min.ps1`: nur Einzeiler ohne Kommentare, raw deflate via `DeflateStream` (`[IO.Compression.CompressionMode]0`, eine nackte `0` ist ein mehrdeutiger Overload), `$env:tmp\M.exe`. Passt eine Variante nicht, wird kein QR erzeugt und ein altes PNG gelöscht. `testQR.py [png ...]` liest die PNGs zurück und vergleicht sie mit den `.ps1`. Gemessen bei Zopfli-Deflate 1872 B: minimal **2693 / 2953 B (Puffer 260)**, voll 3125 B (172 B zu groß). Beide Skripte in Windows PowerShell 5.1 getestet (Hash der entpackten EXE identisch, minimale Variante startet `M.exe`).

## 9. Nächste Schritte (Backlog, grob nach Nutzen)

Nutzen gezippt geschätzt, alles mit `ExeSmokeTester` gegen die Referenz prüfen.

1. ~~`mov rax, 8000000000000000h` ersetzen~~ erledigt (Log 13). Ursprünglich: Vorzeichenbit-Tests per `test rcx, rcx / js`, `bt`/`btc`/`btr reg, 63` (5 B) statt `xor reg, rax`. Maske nur in `MulF`/`AddF` einmal laden.
2. **`mov qword ptr [mem], 0` (11 B)** per `and`/Register 0; `xor rXX, rXX` → `xor eXX, eXX` (−1 B pro Stelle, auch `xor rbp,rbp`, `xor rsi,rsi`).
3. **Konstantenregister**: mehrfach geladene `[a_pixelSize_low]`, `[a_lowerLeft_*]` (RIP-relativ je 7 B). Basisregister + disp8 (4 B) prüfen. Register sind knapp (rdi/r15 sind frei).
4. ~~Zoom-/Begrenzungsblock als Unterroutine~~ erledigt (Log 9-11).
5. ~~`Draw`~~ erledigt (Log 15). Ursprünglich: Push/Pop-Orgie (jetzt 7 Register) und `sub rsp,28h` entfernen, weil `Draw` nur von `start` gerufen wird und keine APIs aufruft. Inneres Pixel-Schreiben mit laufendem Zeiger statt `imul` je Pixel.
6. ~~Thunks vermeiden~~ erledigt (Log 16). Ursprünglich: Statt `call GetMessageA` (5 B + 6-B-Thunk `jmp [IAT]`) direkt `call qword ptr [__imp_GetMessageA]` (6 B) mit `EXTERN __imp_X:QWORD`. Spart ~100 B Roh-Code.
7. **PE-Writer für x64** (neues Tool, Vorbild `MiniPeLinker`): handgebauter Header (`NumberOfRvaAndSizes` = 2, nur Import-Directory, Rest 0), restliches Debug-Directory (`RVA 0x444, Größe 0x1C` bleibt vom Linker) entfernen, Import ohne `OriginalFirstThunk`/Hint, Imports alphabetisch/nach Namen so sortieren, dass gleiche Präfixe komprimieren. Erwarteter Gewinn ≈ 60-150 B.
8. **Weitere optionale Funktions-Streichungen** (Verhalten ändert sich, nur mit Zustimmung): `EndPaint`, `LoadCursorA`, 3 der 4 Iterations-Stufen, Palette 16 → 8 Farben, `GetIterations`-Zwischenspeicher in Register.
9. ~~QR-Skript kürzen~~ erledigt (Log 17). Ursprünglich: (`generator.py`): Dateiname `M.exe`, kürzere Anleitung, ggf. Raw-Deflate statt Zip. Danach `testQR.py` (pyzbar) zum Zurücklesen laufen lassen und Länge gegen 2953 prüfen.
10. ~~Besser komprimieren~~ Zopfli im Generator eingebaut (Log 17), −42 B gegenüber zlib. Ursprünglich: Zopfli/7-Zip `-mx9 -mfb258 -mpass15` testen.
11. **Skripte/Doku**:
    - `Tools/BuildAndAnalyze.ps1 -Bits 64` an die neue Pipeline anpassen (Zip-Größe ausgeben, Stub/Map prüfen) und in einer echten PowerShell-Sitzung testen.
    - `ImportRegressionTester`/`MiniPeLinker`/`PostLinkStripper` bleiben 32-Bit-only. Falls ein x64-Minimizer entsteht, die READMEs ergänzen.
    - Kurze Doku "bauen und verkleinern" (ohne lange Erklärungen) in `README`-Form ablegen.
    - `EXE-GROESSENANALYSE.md` wird von `BuildAndAnalyze.ps1` überschrieben; beim 64-Bit-Lauf neu erzeugen.

## 10. Risiken / offene Punkte

- Fixed Base (kein ASLR, keine Relocations, Image bei 0x400000) ist Voraussetzung für `QWORD OFFSET` in `.data`. Läuft auf dem Entwicklungsrechner (Win 11), andere Rechner nicht getestet.
- Rücksprung aus dem EXE-Entry statt `ExitProcess` ist offiziell nicht garantiert, funktioniert aber unter Windows 10/11 (hier getestet, Prozess endet nach `WM_CLOSE`).
- NULL-`hInstance` bei `RegisterClassEx`/`CreateWindowEx` funktioniert hier; bei Problemen auf anderen Systemen `GetModuleHandleA` zurückholen.
- `EndPaint` bleibt vorerst drin (die 32-Bit-Version lässt es weg und leakt dafür einen DC pro Paint).
- Die Test-EXE-Pfade/Referenzbilder liegen außerhalb des Repos (`%TEMP%`); sie sind nicht versioniert.
