# Code-Optimierungsziele

## Ausgangslage

Nach der bisherigen Optimierung wird die Release-Anwendung automatisch minimiert:

| Datei | Größe |
|---|---:|
| Normale Release-EXE | 4096 Bytes |
| Minimierte EXE | 3584 Bytes |

Die minimierte PE-Datei besteht aktuell aus einem 512-Byte-Header und einer einzigen `.text`-Sektion. Der BSS-Bereich wird virtuell bereitgestellt und nicht mehr physisch in der Datei gespeichert.

Die folgenden Werte stammen aus der Linker-Map-Datei und beziehen sich auf die aktuell minimierte EXE.

## Aktuell reduzierbarer Bereich in `main.asm`

Für die weitere Optimierung zählt alles, was durch Änderungen an `main.asm` reduziert werden kann:

| Bereich | Größe |
|---|---:|
| Daten vor dem Code | `0x1AC` = **428 Bytes** |
| Eigener Code | `0x690` = **1680 Bytes** |
| **Daten und Code zusammen** | `0x83C` = **2108 Bytes** |

Der BSS-Bereich ist dabei nicht enthalten, da er bereits physisch aus der minimierten Datei entfernt wurde.

## Vorläufig feste Bereiche

Für diese Zielrechnung bleiben folgende Bereiche unverändert:

| Bereich | Größe |
|---|---:|
| PE-Header | **512 Bytes** |
| Importdaten | **514 Bytes** |
| **Fester Anteil** | **1026 Bytes** |

Die aktuelle physische Nutzlast vor dem Sektions-Padding beträgt damit:

```text
Header       512 Bytes
main.asm    2108 Bytes
Imports      514 Bytes
-------------------
			 3134 Bytes
```

Die Datei wird anschließend auf die nächste 512-Byte-Grenze aufgerundet und ist deshalb aktuell 3584 Bytes groß.

## Zielgrößen

### Ziel: 2048 Bytes

Für Daten und Code aus `main.asm` stehen maximal zur Verfügung:

```text
2048 - 512 - 514 = 1022 Bytes
```

Aktuell werden dafür 2108 Bytes verwendet:

```text
2108 - 1022 = 1086 Bytes
```

| Wert | Größe |
|---|---:|
| Aktueller Bereich aus `main.asm` | **2108 Bytes** |
| Maximal zulässiger Bereich | **1022 Bytes** |
| **Mindestens einzusparen** | **1086 Bytes** |

Bei unveränderten Daten vor dem Code dürfte der verbleibende Code höchstens 594 Bytes groß sein:

```text
1022 - 428 = 594 Bytes Code
```

### Ziel: 2560 Bytes

```text
2560 - 512 - 514 = 1534 Bytes
```

```text
2108 - 1534 = 574 Bytes
```

| Wert | Größe |
|---|---:|
| Aktueller Bereich aus `main.asm` | **2108 Bytes** |
| Maximal zulässiger Bereich | **1534 Bytes** |
| **Mindestens einzusparen** | **574 Bytes** |

Bei unveränderten Daten vor dem Code dürfte der verbleibende Code höchstens 1106 Bytes groß sein:

```text
1534 - 428 = 1106 Bytes Code
```

### Ziel: 3072 Bytes

```text
3072 - 512 - 514 = 2046 Bytes
```

```text
2108 - 2046 = 62 Bytes
```

| Wert | Größe |
|---|---:|
| Aktueller Bereich aus `main.asm` | **2108 Bytes** |
| Maximal zulässiger Bereich | **2046 Bytes** |
| **Mindestens einzusparen** | **62 Bytes** |

Bei unveränderten Daten vor dem Code dürfte der verbleibende Code höchstens 1618 Bytes groß sein:

```text
2046 - 428 = 1618 Bytes Code
```

## Zusammenfassung

| Zielgröße der EXE | Maximaler Bereich für Daten + Code | Aktueller Bereich | Mindestens einzusparen |
|---:|---:|---:|---:|
| **2048 Bytes (2 KiB)** | 1022 Bytes | 2108 Bytes | **1086 Bytes** |
| **2560 Bytes (2,5 KiB)** | 1534 Bytes | 2108 Bytes | **574 Bytes** |
| **3072 Bytes (3 KiB)** | 2046 Bytes | 2108 Bytes | **62 Bytes** |

Die Einsparung kann beliebig auf Daten und Code verteilt werden. Es ist nicht erforderlich, ausschließlich den Maschinencode zu verkleinern.

Beispiel für das Ziel 2048 Bytes:

```text
Daten vor dem Code: 428 Bytes
Verbleibender Code: 594 Bytes
----------------------------
Daten + Code:      1022 Bytes
```

Wenn Daten in `main.asm` verkleinert werden, verringert sich der notwendige Einsparungsbedarf im Code entsprechend.

## Aufteilung der Daten vor dem Code

Die 428 Bytes vor dem Code setzen sich laut Map-Datei zusammen aus:

| Abschnitt | Größe |
|---|---:|
| `.data` | 108 Bytes |
| `.rdata` | 76 Bytes |
| `.rdata$voltmd` | 24 Bytes |
| `.rdata$zzzdbg` | 220 Bytes |
| **Gesamt** | **428 Bytes** |

Diese Bereiche enthalten unter anderem Fensterklassendaten, Fenstertitel, numerische Initialwerte und die Farbpalette.

## Bedeutung der Imports

Die Rechnung verwendet zunächst unveränderte Importdaten von 514 Bytes. Jede Reduzierung der Importdaten verbessert das verfügbare Budget direkt:

```text
1 Byte weniger Importdaten
= 1 Byte mehr Platz für Daten oder Code
```

Die Imports sollten jedoch nur entfernt werden, wenn die Anwendung weiterhin korrekt startet, zeichnet, zoomt und beendet werden kann.

## Nächster Optimierungsschritt

Nachdem Header, PE-Struktur, BSS-Bereich, Sections, Padding und bestätigte Imports bereits optimiert wurden, liegt der nächste Schwerpunkt direkt in `SmallASM/main.asm`.

Zu untersuchen sind insbesondere:

1. redundante oder doppelte Daten in `.data` und `.const`,
2. die Farbpalette und ihre tatsächlich benötigte Größe,
3. übergroße Strukturen und Puffer,
4. wiederholte Instruktionsfolgen,
5. unnötige Initialisierungen,
6. unnötige Register- oder Stackoperationen,
7. alternative kürzere Berechnungen für das Mandelbrot-Rendering,
8. weitere sichere Möglichkeiten zum Entfernen von API-Aufrufen.

Das erste realistische Zwischenziel ist **3072 Bytes**. Dafür müssen im Bereich aus `main.asm` lediglich **62 Bytes** eingespart werden. Das Ziel von **2560 Bytes** erfordert insgesamt **574 Bytes**, während **2048 Bytes** eine Einsparung von **1086 Bytes** voraussetzen.

Jede Änderung sollte anschließend mit dem bestehenden Build, dem MiniPeLinker und dem Import-/Fenster-/Zoom-/Close-Test validiert werden.
