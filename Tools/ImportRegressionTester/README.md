# ImportRegressionTester

Testet Import-Entfernungen iterativ:

1. erstellt eine temporäre `main.asm`-Variante,
2. baut sie als Release/Win32,
3. minimiert die erzeugte EXE mit `MiniPeLinker`,
4. startet die minimierte EXE,
5. sucht ein sichtbares Fenster,
6. erstellt einen Pixel-Schnappschuss,
7. sendet `WM_MOUSEWHEEL`,
8. prüft, ob sich die sichtbaren Pixel ändern,
9. schließt die EXE kontrolliert.

Eine erfolgreiche Entfernung wird in die nächste Variante übernommen. Nach jedem vollständigen Durchlauf beginnt der Tester erneut bei der ersten noch nicht entfernten API, wenn sich die Basis geändert hat. Erfolgreich entfernte Imports werden am Ende in `Tools\MiniPeLinker\imports.csv` mit `x` markiert. Alle Ergebnisse stehen in:

```plaintext
Tools\ImportRegressionTester\iteration-results.csv
```

Das Tool arbeitet während der Tests in temporären Projektkopien. Nach Abschluss wird die erfolgreich getestete Quelle in `SmallASM\main.asm` gespeichert; vorher wird eine Sicherung als `main.asm.import-test-backup` angelegt.

## Kompilieren

```powershell
$csc = 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\Roslyn\csc.exe'
& $csc /nologo /target:exe /r:System.Drawing.dll /out:ImportRegressionTester.exe Program.cs
