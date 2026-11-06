# MiniPeLinker

Projektbezogener PE-Minimierer für die 32-Bit-Release-EXE.

Das Tool unterstützt das aktuelle Mandelbrot-Layout mit genau zwei Sektionen:

- `.text`
- `.idata`

Die Importsektion wird hinter die Nutzdaten von `.text` verschoben. Dabei werden Import-RVAs, IAT-RVAs und absolute IAT-Verweise im x86-Code angepasst. Die nicht benötigte Rohdaten-Ausrichtung am Ende von `.idata` wird entfernt.

Die BSS-Daten werden aus den Rohdaten entfernt und virtuell hinter `.idata` verschoben. Absolute Verweise aus dem x86-Code werden dabei angepasst. Wenn die neue Rohdatengröße noch dieselbe 512-Byte-Grenze erreicht, bleibt die Dateigröße trotz eingesparter Nullbytes zunächst unverändert.

## Kompilieren ohne .NET SDK

```powershell
$csc = 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\Roslyn\csc.exe'
& $csc /nologo /target:exe /out:MiniPeLinker.exe Program.cs
```

## Ausführen

```powershell
.\MiniPeLinker.exe ..\..\SmallASM\Release\SmallASM.exe ..\..\SmallASM\Release\SmallASM.min.exe
```

Die aktuelle EXE wird von 4.096 auf 3.584 Bytes reduziert. Das Tool bricht bei anderen Sektionslayouts ab, statt eine möglicherweise nicht startbare PE-Datei zu erzeugen.

Die Testdatei wird von 4.096 auf 3.584 Bytes reduziert. Die BSS-Verlagerung verändert das Laufzeitlayout, unterschreitet aber wegen der 512-Byte-Ausrichtung nicht automatisch die nächste Dateigrenze.

Die BSS-Verlagerung ist derzeit nicht aktiv, weil die Grenzen bei diesem Linker-Layout nicht zuverlässig aus dem PE-Header ermittelt werden können. Der Minimierer verwendet deshalb das startfähige Layout und verschiebt `.idata` weiterhin in `.text`.

Die Importauswahl wird aus `imports.csv` gelesen. Ein `x` in der Spalte `Remove` markiert einen Import zur Entfernung. Der Minimierer bricht ab, wenn ein markierter Import trotzdem noch in der Eingabe-EXE vorkommt.
