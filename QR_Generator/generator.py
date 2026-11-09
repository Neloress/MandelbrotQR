"""QR-Code-Generator: packt eine EXE in einen QR-Code (QR Version 40, Level L, max. 2953 Bytes).

Aufruf:
    python generator.py EXE [--variant both|full|min] [--before TEXT] [--after TEXT] [--out-dir DIR]

Varianten (Auswahl per --variant, Standard siehe VARIANT unten):
    full  QR.png / QR.ps1          lesbares PowerShell-Skript mit Anleitung, EXE als .zip (Expand-Archive)
    min   QR_min.png / QR_min.ps1  kuerzester moeglicher Einzeiler, EXE als raw deflate, nur Kommentare davor/danach

Beide Varianten sind "plug and play": Text kopieren, in PowerShell einfuegen, die EXE wird nach %TEMP% entpackt
und gestartet. Die .ps1-Dateien enthalten exakt den Text, der im QR-Code steht.
Zopfli (pip install zopfli) komprimiert etwas besser als zlib und wird automatisch benutzt, wenn installiert.
"""
import argparse
import base64
import os
import struct
import sys
import zlib

import qrcode

HERE = os.path.dirname(os.path.abspath(__file__))
QR_MAX_BYTES = 2953  # QR version 40, error correction L, byte mode
EXE_NAME = "M.exe"   # name of the EXE inside the archive / in %TEMP%

# ============================== EINSTELLUNGEN ==============================

# Welche Variante(n) erzeugt werden: "both", "full" oder "min" (Kommandozeile: --variant)
VARIANT = "both"

# --- Minimale Variante: Text vor und nach dem Skript --------------------------------------------------
# Wird als PowerShell-Kommentar eingefuegt (jede Zeile bekommt ein '#'). Nur ASCII verwenden, jedes Byte zaehlt:
# der freie Platz im QR-Code wird nach dem Erzeugen ausgegeben. Leer lassen ("") = kein Text.
# Kommandozeile: --before / --after
MIN_TEXT_BEFORE = "Copy ALL, paste into PowerShell, press Enter. Mouse wheel = zoom."
MIN_TEXT_AFTER = "This is the very last byte of the QR-Code!"

# --- Volle Variante: Anleitung vor und Abschlusszeile nach dem Skript ---------------------------------
FULL_TEXT_BEFORE = (
    "#:: --- Open on Windows PC ---\n"
    "#:: 1. Copy whole text.\n"
    "#:: 2. Paste into PowerShell.\n"
    "#:: 3. Enjoy Fractals!\n"
    "#:: ---------------"
)
FULL_TEXT_AFTER = "These are the last possible bytes that fit on the QR-Code. Have a good day!!!"

# Unterordner in %TEMP%, in den die volle Variante entpackt (fester Suffix: schuetzt vor Ueberschreiben)
FULL_SANDBOX_DIR = "M_105HDGDL69"

# ===========================================================================


# ------------------------------- Komprimierung ------------------------------

def deflate(data):
    """Raw deflate stream. Zopfli if installed, else zlib level 9. Returns (stream, name of the compressor)."""
    try:
        from zopfli.zlib import compress as zopfli_compress
        return zopfli_compress(data, numiterations=100)[2:-4], "zopfli"  # strip zlib header and adler32
    except ImportError:
        c = zlib.compressobj(9, zlib.DEFLATED, -15)
        return c.compress(data) + c.flush(), "zlib"


def make_zip(name, data, packed):
    """Minimal one-file zip around an already deflated stream (zipfile can not take precompressed data)."""
    crc = zlib.crc32(data) & 0xFFFFFFFF
    n = name.encode()
    local = struct.pack("<IHHHHHIIIHH", 0x04034B50, 20, 0, 8, 0, 0x21, crc, len(packed), len(data), len(n), 0) + n
    central = struct.pack("<IHHHHHHIIIHHHHHII", 0x02014B50, 20, 20, 0, 8, 0, 0x21, crc, len(packed), len(data),
                          len(n), 0, 0, 0, 0, 0, 0) + n
    end = struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, 1, 1, len(central), len(local) + len(packed), 0)
    return local + packed + central + end


def b64(data):
    return base64.b64encode(data).decode()


# ------------------------------- Skript-Texte -------------------------------

def as_comment(text):
    """Text -> PowerShell comment lines (every line gets a '#', lines that already start with '#' stay as they are)."""
    if not text:
        return ""
    return "".join((line if line.startswith("#") else "#" + line) + "\n" for line in text.splitlines())


def script_full(exe, packed):
    """Lesbares Skript: entpackt das zip per Expand-Archive, loescht das zip wieder, startet die EXE."""
    zip_b64 = b64(make_zip(EXE_NAME, exe, packed))
    return (
        f"{as_comment(FULL_TEXT_BEFORE)}"
        f"$d = Join-Path $env:temp '{FULL_SANDBOX_DIR}';\n"
        f"New-Item -ItemType Directory -Path $d -Force | Out-Null;\n"
        f"$z = Join-Path $d 'z.zip';\n"
        f"[io.file]::WriteAllBytes($z, [Convert]::FromBase64String('{zip_b64}'));\n"
        f"Expand-Archive $z $d -Force;\n"
        f"Remove-Item $z -Force;\n"
        f"cd $d;\n"
        f"Start-Process '.\\{EXE_NAME}';\n"
        f"exit;\n"
        f"{as_comment(FULL_TEXT_AFTER)}"
    )


def script_min(packed, before, after):
    """Kuerzester Einzeiler: raw deflate direkt nach %TEMP%\\M.exe entpacken und starten.
    Es entsteht keine andere Datei als die EXE. (Die EXE bleibt in %TEMP% liegen, sie laeuft ja noch.)
    CompressionMode 0 = Decompress; ohne den Enum-Cast ist eine nackte 0 ein mehrdeutiger Overload."""
    return (
        f"{as_comment(before)}"
        f'$f="$env:temp\\{EXE_NAME}";$o=[IO.File]::Create($f);'
        f"(New-Object IO.Compression.DeflateStream([IO.MemoryStream][Convert]::FromBase64String('{b64(packed)}'),"
        f"[IO.Compression.CompressionMode]0)).CopyTo($o);"
        f"$o.Close();&$f\n"
        f"{as_comment(after)}"
    )


# ---------------------------------- QR-Code ---------------------------------

def save_qr(text, png_path):
    """Writes the QR code. Returns True if the text fits (otherwise an outdated png is removed)."""
    if len(text.encode("utf-8")) > QR_MAX_BYTES:
        if os.path.exists(png_path):
            os.remove(png_path)  # do not leave an outdated QR code behind
        return False
    qr = qrcode.QRCode(version=40, error_correction=qrcode.constants.ERROR_CORRECT_L, box_size=10, border=4)
    qr.add_data(text)
    qr.make(fit=False)
    qr.make_image(fill_color="black", back_color="white").save(png_path)
    return True


def generate(exe_path, variant=VARIANT, before=None, after=None, out_dir=HERE, log=print):
    """Erzeugt die gewuenschte(n) Variante(n). Liefert eine Liste von Ergebnissen (ein dict je Variante):
    variant, png, ps1, bytes, limit, fits, extract_path (wohin das Skript die EXE entpackt), exe_size, packed_size."""
    if variant not in ("both", "full", "min"):
        raise ValueError(f"Unbekannte Variante '{variant}' (both, full oder min)")
    before = MIN_TEXT_BEFORE if before is None else before
    after = MIN_TEXT_AFTER if after is None else after
    os.makedirs(out_dir, exist_ok=True)

    exe = open(exe_path, "rb").read()
    packed, compressor = deflate(exe)
    log(f"📦 EXE: {len(exe)} Bytes, deflate: {len(packed)} Bytes ({compressor})")

    temp = os.environ.get("TEMP", "")
    jobs = []
    if variant in ("both", "full"):
        jobs.append(("full", "QR", script_full(exe, packed), os.path.join(temp, FULL_SANDBOX_DIR, EXE_NAME)))
    if variant in ("both", "min"):
        jobs.append(("min", "QR_min", script_min(packed, before, after), os.path.join(temp, EXE_NAME)))

    results = []
    for name, base, text, extract_path in jobs:
        png = os.path.join(out_dir, base + ".png")
        ps1 = os.path.join(out_dir, base + ".ps1")
        with open(ps1, "w", encoding="utf-8", newline="") as f:
            f.write(text)
        size = len(text.encode("utf-8"))
        fits = save_qr(text, png)
        label = "Volle Variante (mit Anleitung, zip)" if name == "full" else "Minimale Variante (raw deflate)"
        if fits:
            log(f"✅ {label}: {size} / {QR_MAX_BYTES} Bytes, Puffer {QR_MAX_BYTES - size} -> {os.path.basename(png)}")
        else:
            log(f"❌ {label}: {size} / {QR_MAX_BYTES} Bytes, zu gross um {size - QR_MAX_BYTES} -> kein QR-Code")
        results.append(dict(variant=name, png=png if fits else None, ps1=ps1, bytes=size, limit=QR_MAX_BYTES,
                            fits=fits, extract_path=extract_path, exe_size=len(exe), packed_size=len(packed)))
    return results


def main(argv=None):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # emoji output also works on cp1252 consoles
    ap = argparse.ArgumentParser(description="Packt eine EXE in einen QR-Code (siehe Kopf der Datei).")
    ap.add_argument("exe", nargs="?", default=os.path.join(HERE, "..", "SmallASM", "x64", "Release", "SmallASM64.exe"),
                    help="EXE, die in den QR-Code soll (Standard: 64-Bit-Release-Build)")
    ap.add_argument("--variant", choices=("both", "full", "min"), default=VARIANT,
                    help=f"welche Variante(n) erzeugt werden (Standard: {VARIANT})")
    ap.add_argument("--before", default=None, help="Text VOR dem Skript der minimalen Variante (als Kommentar)")
    ap.add_argument("--after", default=None, help="Text NACH dem Skript der minimalen Variante (als Kommentar)")
    ap.add_argument("--out-dir", default=HERE, help="Ausgabeordner (Standard: Ordner dieses Skripts)")
    args = ap.parse_args(argv)

    if not os.path.exists(args.exe):
        sys.exit(f"❌ Fehler: '{args.exe}' nicht gefunden.")
    results = generate(args.exe, args.variant, args.before, args.after, args.out_dir)
    return 0 if all(r["fits"] for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
