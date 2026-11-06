# Arbeitsplan: Optimierungen in `SmallASM/main.asm`

Die erste Empfehlung — übrig gebliebene Argumente nach entfernten API-Aufrufen zu entfernen — wurde bereits umgesetzt.

## Zielgrößen

| Zielgröße der minimierten EXE | Noch notwendige Einsparung im Bereich aus `main.asm`* |
|---:|---:|
| 3072 Bytes | 62 Bytes |
| 2560 Bytes | 574 Bytes |
| 2048 Bytes | 1086 Bytes |

\* Bei unverändertem PE-Header und unveränderten Importdaten. Die tatsächliche Analyse wird nach jedem Build mit `Tools/BuildAndAnalyze.ps1` aktualisiert.

## Arbeitsregeln

Nach jeder Änderung:

1. `Tools/BuildAndAnalyze.ps1` ausführen.
2. Prüfen, ob die normale und minimierte EXE erzeugt wurden.
3. Die minimierte EXE starten.
4. Fenster, Zeichnen, Zoom und kontrolliertes Beenden testen.
5. Nur Änderungen behalten, die keine Regression verursachen.

---

## Phase 1 — Sichere Instruktionsverkürzungen

### 1. Nullwerte mit `xor` erzeugen

Suche nach:

```asm
mov eax, 0
mov ebx, 0
mov ecx, 0
mov edx, 0
mov esi, 0
mov edi, 0
```

Prüfe jeweils, ob das Zielregister vollständig überschrieben werden darf. Dann ersetzen durch:

```asm
xor eax, eax
```

Typische Einsparung: 3 Bytes pro geeigneter Stelle.

Nicht anwenden, wenn die Flags des vorherigen Befehls erhalten bleiben müssen oder wenn nur ein Teilregister gesetzt werden soll.

### 2. `cmp register, 0` durch `test register, register` ersetzen

Beispiel:

```asm
cmp eax, 0
je label
```

wird zu:

```asm
test eax, eax
je label
```

Typische Einsparung: 1 Byte.

### 3. Inkrementieren und Dekrementieren verkürzen

Geeignete Fälle:

```asm
add edi, 1
sub edi, 1
```

ersetzen durch:

```asm
inc edi
dec edi
```

Typische Einsparung: 2 Bytes je Stelle.

Nicht `sub register, 4` oder andere Werte ersetzen.

### 4. Konstantenregister wiederverwenden

In `Draw` werden feste Werte wie `800`, `596`, `796` und `3` mehrfach geladen. Prüfen, ob ein Register über die jeweilige Schleife hinweg gehalten werden kann.

Ziel:

- doppelte `mov register, immediate` entfernen,
- Registerlebensdauern dokumentieren,
- keine für `GetIterations` oder API-Aufrufe benötigten Werte überschreiben.

---

## Phase 2 — Daten und Initialisierung

### 5. Unbenutzte Variablen entfernen

Mit Referenzsuche prüfen, ob `ua_hdc` weiterhin unbenutzt ist. Falls ja, die Deklaration entfernen.

Auch `ua_rect` prüfen. Ein Entfernen ist nur möglich, wenn `GetClientRect` und die Verwendung für `InvalidateRect` sicher entfallen können.

### 6. Strukturen nur so groß wie nötig anlegen

Zu untersuchen:

- `ua_bmi`
- `ua_paintstruct`
- `ua_msg`
- `ua_wc`

Stack-Mapping kann BSS-/Datenbedarf reduzieren, spart aber nicht automatisch Dateigröße. Die zusätzliche Stackinitialisierung darf nicht größer werden als die eingesparten Daten.

Besonders bei `ua_bmi` prüfen, ob die Struktur bereits vollständig mit `mov` beschrieben wird. Falls ja, kann eine globale Nullinitialisierung überflüssig sein.

### 7. Konstanten zusammenlegen

Identische Anfangswerte prüfen:

- `a_lowerLeft_y` und `a_lowerLeft_y_min`
- `a_pixelSize` und `a_pixelSize_max`

Eine gemeinsame Konstante ist nur möglich, wenn die Werte nicht unabhängig verändert werden. Alternativ kann ein ohnehin vorhandener Registerwert wiederverwendet werden.

---

## Phase 3 — Farbpalette und Datenformat

### 8. Farbpalette verkleinern

Aktuell werden 16 Farben als 16 DWORDs gespeichert. Varianten prüfen:

| Variante | Datenbedarf | Mögliche Einsparung |
|---|---:|---:|
| 16 DWORDs | 64 Bytes | 0 Bytes |
| 16 RGB-Bytes | 48 Bytes | 16 Bytes |
| 16-Bit-Farbwerte | 32 Bytes | 32 Bytes |
| weniger Farben | abhängig von der Anzahl | variabel |

Die Ausgabe muss visuell akzeptabel bleiben. Nach jeder Änderung Pixelvergleich und Zoomtest ausführen.

### 9. Mauskoordinaten verkleinern

`a_mousePos_x` und `a_mousePos_y` benötigen für die aktuellen Fensterdimensionen theoretisch keine vollständigen 32 Bit. Eine Umstellung auf WORD spart Daten, kann aber durch zusätzliche `movzx`-Befehle mehr Code erzeugen.

Nur übernehmen, wenn die Gesamtanalyse eine echte Einsparung zeigt.

---

## Phase 4 — Zeichenroutine `Draw`

### 10. Pixelindex inkrementell berechnen

Aktuell wird der Index mit Multiplikation berechnet:

```asm
mov edx, 800
mul edx
add eax, ebx
add eax, edi
sal eax, 2
```

Prüfen, ob ein laufender Pixelzeiger verwendet werden kann:

- pro Pixel `add pointer, 4`,
- pro Zeile `add pointer, 800 * 4` beziehungsweise ein vorbereiteter Zeilenschritt,
- Entfernen der Multiplikation aus der inneren Schleife.

Dabei müssen die 4x4-Pixelblöcke und die Schleifenrichtung unverändert bleiben.

### 11. Konstanten in `Draw` reduzieren

Prüfen, ob `800`, `596`, `796` und `3` direkt über Schleifenstruktur oder Registerinitialisierung wiederverwendet werden können.

Achtung: `ebp` wird in `Draw` als allgemeines Register verwendet. Änderungen an Prolog/Epilog und an den Parametern der anderen PROC-Routinen müssen getrennt validiert werden.

---

## Phase 5 — Festkommaarithmetik

### 12. `MulFint` spezialisieren

In den Pixelpfaden sind die Koordinaten normalerweise positiv. Prüfen, ob eine kleinere positive Spezialroutine möglich ist.

Die allgemeine Routine darf nur ersetzt werden, wenn auch Zoom- und Randberechnungen abgedeckt sind. Eine sichere Variante ist eine zusätzliche Spezialroutine ausschließlich für `Draw`.

### 13. `AddF` nach Vorzeichenfällen aufteilen

`AddF` behandelt beide Vorzeichen allgemein. Prüfen, ob an häufigen Stellen das Vorzeichen bereits bekannt ist und eine kleinere Spezialroutine verwendet werden kann.

Nicht die allgemeine Routine entfernen, bevor alle Aufrufer und Grenzfälle geprüft sind.

### 14. `MulF` inline oder spezialisiert prüfen

Inlining spart nur dann Dateigröße, wenn die Spezialversion kleiner ist als:

- Argumente auf den Stack legen,
- `call`,
- allgemeine Routine,
- Rücksprung.

Daher vor dem Umbau die erzeugten Bytegrößen mit einer Map-/Disassembly-Analyse vergleichen.

---

## Phase 6 — Fenster- und Nachrichtencode

### 15. `WndProc`-Fallstruktur prüfen

Die Message-Vergleiche können auf Reihenfolge und gemeinsame Rückgabepfade untersucht werden. Ein Sprungtisch ist wegen der weit auseinanderliegenden Message-Werte wahrscheinlich nicht kleiner.

Priorität haben:

- gemeinsame `xor eax,eax`-Rückgaben,
- gemeinsame Endlabels,
- keine doppelten Stackkorrekturen,
- keine bereits entfernten API-Argumente.

### 16. `invoke`-Expansion vergleichen

`invoke LoadCursor` mit einer manuellen Push-/Call-Sequenz vergleichen. Nur die Variante mit der kleineren erzeugten Instruktionsfolge behalten.

---

## Phase 7 — Debug- und Linkeranteile

### 17. MASM-Debugdaten deaktivieren

Im Release-Projekt prüfen:

```xml
<MASM>
  <GenerateDebugInformation>false</GenerateDebugInformation>
</MASM>
```

Die Map-Datei enthielt bisher `.rdata$zzzdbg` mit 220 Bytes. Nach der Änderung erneut analysieren, ob dieser Bereich entfällt.

Das ist keine Änderung des eigentlichen Algorithmus, aber voraussichtlich eine der größten kurzfristigen Einsparungen.

---

## Priorisierung

1. Debugdaten deaktivieren und messen.
2. `xor`, `test`, `inc` und `dec` systematisch prüfen.
3. Konstanten in `Draw` wiederverwenden.
4. Unbenutzte Variablen und überflüssige Strukturen entfernen.
5. Farbpalette komprimieren.
6. Pixelindex inkrementell berechnen.
7. `MulFint` und `AddF` spezialisieren.
8. Erst danach größere Umbauten an `WndProc`, Stacklayout und Festkommaarithmetik durchführen.

Das erste Zwischenziel ist eine minimierte EXE unter 3072 Bytes. Jede Änderung muss anhand der erzeugten Größenanalyse und des Laufzeittests bewertet werden.
