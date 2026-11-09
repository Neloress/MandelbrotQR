# BuildAll – alles in einem Schritt

`BuildAll` baut die EXE, verkleinert sie, erzeugt die QR-Codes, liest sie wieder ein und startet die EXE aus dem QR-Skript, um zu prüfen, ob alles funktioniert. Am Ende steht eine Ergebnisliste.

## Starten

- **Doppelklick auf `BuildAll.cmd`** und `1` (32 Bit) oder `2` (64 Bit) wählen, oder
- `python BuildAll.py 32` bzw. `python BuildAll.py 64` (ohne Zahl wird gefragt).

Optionen (alle optional):

| Option | Bedeutung |
|---|---|
| `--variant both\|full\|min` | welche QR-Variante(n); Standard `both` |
| `--before "Text"` / `--after "Text"` | Text vor/nach dem Skript der minimalen Variante (wird Kommentar) |
| `--skip-build` | vorhandene EXE verwenden, nicht neu bauen |
| `--no-run` | EXE nicht starten (nur bauen, QR erzeugen, QR einlesen) |

## Was passiert

1. **Bauen:** MSBuild (Release). 64 Bit: der Linker erzeugt direkt die kleine EXE. 32 Bit: das Projekt verkleinert sie danach mit PostLinkStripper und MiniPeLinker (Ergebnis `SmallASM32.min.exe`).
2. **QR erzeugen:** `QR_Generator/generator.py`. Ergebnis in `QR_Generator/QR_32bit/` bzw. `QR_64bit/`: `QR.png`/`QR.ps1` (volle Variante, mit Anleitung, Zip) und `QR_min.png`/`QR_min.ps1` (nur Einzeiler, raw deflate). Passt eine Variante nicht in 2953 Bytes, wird sie übersprungen (ℹ️), solange die andere passt.
3. **QR einlesen:** jedes PNG wird mit pyzbar gelesen und muss exakt dem `.ps1`-Text entsprechen.
4. **EXE testen:** das Skript aus dem QR-Code wird wirklich in PowerShell ausgeführt. Geprüft wird: Fenster „Mandelbrot set“ erscheint, die entpackte EXE ist byte-identisch mit der gebauten (SHA-256), im Fenster wird gezeichnet, die EXE beendet sich nach dem Schließen (WM_CLOSE). Danach werden die entpackten Dateien in `%TEMP%` gelöscht.

Exit-Code `0` = alles OK, `1` = mindestens ein Fehler (steht mit ❌ in der Liste).

## Voraussetzungen

- Windows mit Visual Studio (MSBuild + MASM)
- Python mit `pip install qrcode pillow pyzbar zopfli` (`zopfli` optional, spart ca. 40 Bytes)
- Beim Test (Schritt 4) muss ein Desktop sichtbar sein und darf das Fenster nicht verdeckt werden (es wird kurz in den Vordergrund gesetzt). Ein ggf. noch laufendes `M.exe` aus `%TEMP%` vorher schließen.

## Texte und Varianten anpassen

Alle Texte stehen **nur** in `QR_Generator/generator.py` oben unter **EINSTELLUNGEN**: `MIN_TEXT_BEFORE`/`MIN_TEXT_AFTER` (Minimalvariante), `FULL_TEXT_BEFORE`/`FULL_TEXT_AFTER` (volle Variante) und die Standard-Variante `VARIANT`. `BuildAll` verwendet sie unverändert (für 32 und 64 Bit gleich), außer du gibst `--before`/`--after` an. Nach dem Erzeugen steht der freie Platz im QR-Code in der Ausgabe; die 64-Bit-Minimalvariante hat nur noch ca. 20 Bytes Reserve, längere Texte passen dort nicht mehr.

## Fenstertitel der 64-Bit-Version

Der Titel zeigt die Bedienung und die aktuellen Werte: `Mandelbrotmenge | Key (6-9) Pixelsize: 4 | Key (1-5) Iterationen: 10`. Er ändert sich bei jedem Tastendruck. `BuildAll` prüft das für 64 Bit mit (Tasten werden an das Fenster gesendet, Liste `title_checks` in `BuildAll.py`). Hinweis: Taste 9 = Pixelsize 8, die Stufe 16 ist über Tasten nicht erreichbar.

Was der Einzeiler (`QR_min`) macht: entpackt per `DeflateStream` direkt nach `%TEMP%\M.exe` und startet sie. Es entsteht keine andere Datei; die EXE bleibt in `%TEMP%` liegen, weil sie noch läuft. Die volle Variante legt `z.zip` in `%TEMP%\M_105HDGDL69\` an, entpackt, löscht die Zip wieder und startet die EXE.
