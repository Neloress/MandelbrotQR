import base64
import os
import struct
import sys
import zlib
import qrcode

# Usage: python generator.py [path-to-exe]
#
# Builds two QR codes from the same EXE:
#   QR.png      full variant:    readable PowerShell script with instructions, EXE shipped as .zip (Expand-Archive)
#   QR_min.png  minimal variant: only the shortest possible PowerShell one-liner, EXE shipped as raw deflate
# Both are plug and play: copy the text, paste it into PowerShell, the EXE is unpacked to %TEMP% and started.
# The scripts are also written as QR.ps1 / QR_min.ps1 (exactly the text that is inside the QR code).

here = os.path.dirname(os.path.abspath(__file__))
exe_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "..", "SmallASM", "x64", "Release", "SmallASM64.exe")
exe_name = "M.exe"
QR_MAX_BYTES = 2953  # QR version 40, error correction L, byte mode
sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # emoji output also works on cp1252 consoles


def deflate(data):
    """Raw deflate stream. Zopfli (pip install zopfli) if available, else zlib level 9."""
    try:
        from zopfli.zlib import compress as zopfli_compress
        return zopfli_compress(data, numiterations=100)[2:-4]  # strip zlib header and adler32
    except ImportError:
        c = zlib.compressobj(9, zlib.DEFLATED, -15)
        return c.compress(data) + c.flush()


def make_zip(name, data, raw_deflate):
    """Minimal one-file zip around an already deflated stream (zipfile can not take precompressed data)."""
    crc = zlib.crc32(data) & 0xFFFFFFFF
    n = name.encode()
    local = struct.pack("<IHHHHHIIIHH", 0x04034B50, 20, 0, 8, 0, 0x21, crc, len(raw_deflate), len(data), len(n), 0) + n
    central = struct.pack("<IHHHHHHIIIHHHHHII", 0x02014B50, 20, 20, 0, 8, 0, 0x21, crc, len(raw_deflate), len(data),
                          len(n), 0, 0, 0, 0, 0, 0) + n
    end = struct.pack("<IHHHHIIH", 0x06054B50, 0, 0, 1, 1, len(central), len(local) + len(raw_deflate), 0)
    return local + raw_deflate + central + end


def b64(data):
    return base64.b64encode(data).decode()


def save_qr(text, png_name):
    length = len(text.encode("utf-8"))
    if length > QR_MAX_BYTES:
        print(f"   ❌ Zu gross um {length - QR_MAX_BYTES} Bytes ({length} / {QR_MAX_BYTES}), kein QR-Code erzeugt.")
        if os.path.exists(os.path.join(here, png_name)):
            os.remove(os.path.join(here, png_name))  # do not leave an outdated QR code behind
            print(f"      (veraltete '{png_name}' geloescht)")
        return False
    qr = qrcode.QRCode(version=40, error_correction=qrcode.constants.ERROR_CORRECT_L, box_size=10, border=4)
    qr.add_data(text)
    qr.make(fit=False)
    qr.make_image(fill_color="black", back_color="white").save(os.path.join(here, png_name))
    print(f"   ✅ Passt: {length} / {QR_MAX_BYTES} Bytes, Puffer {QR_MAX_BYTES - length}. Gespeichert als '{png_name}'.")
    return True


if not os.path.exists(exe_path):
    sys.exit(f"❌ Fehler: '{exe_path}' nicht gefunden (Pfad als Argument uebergeben).")

exe = open(exe_path, "rb").read()
packed = deflate(exe)
print(f"📦 EXE: {len(exe)} Bytes, deflate: {len(packed)} Bytes ({'zopfli' if 'zopfli' in sys.modules else 'zlib'})")

# ---------------- Variant 1: full, with instructions, zip + Expand-Archive ----------------
reader_anleitung = (
    "#:: --- Open on Windows PC ---\n"
    "#:: 1. Copy whole text.\n"
    "#:: 2. Paste into PowerShell.\n"
    "#:: 3. Enjoy Fractals!\n"
    "#:: ---------------\n"
)
sandbox_name = "M_105HDGDL69"  # fixed suffix: protects against overwriting existing folders
zip_b64 = b64(make_zip(exe_name, exe, packed))
full = (
    f"{reader_anleitung}"
    f"$d = Join-Path $env:temp '{sandbox_name}';\n"
    f"New-Item -ItemType Directory -Path $d -Force | Out-Null;\n"
    f"$z = Join-Path $d 'z.zip';\n"
    f"[io.file]::WriteAllBytes($z, [Convert]::FromBase64String('{zip_b64}'));\n"
    f"Expand-Archive $z $d -Force;\n"
    f"Remove-Item $z -Force;\n"
    f"cd $d;\n"
    f"Start-Process '.\\{exe_name}';\n"
    f"exit;\n"
    f"#These are the last possible bytes that fit on the QR-Code. Have a good day!!!\n"
)
print("1) Volle Variante (mit Anleitung, zip):")
open(os.path.join(here, "QR.ps1"), "w", encoding="utf-8", newline="").write(full)
save_qr(full, "QR.png")

# ---------------- Variant 2: minimal one-liner, raw deflate, no whitespace/comments ----------------
# CompressionMode 0 = Decompress (needs the enum cast: a bare 0 is an ambiguous overload). Paste target is PowerShell 5.1 / 7, the trailing newline executes the line.
minimal = (
    f'$f="$env:tmp\\{exe_name}";$o=[IO.File]::Create($f);'
    f"(New-Object IO.Compression.DeflateStream([IO.MemoryStream][Convert]::FromBase64String('{b64(packed)}'),[IO.Compression.CompressionMode]0)).CopyTo($o);"
    "$o.Close();&$f\n"
)
print("2) Minimale Variante (nur Skript, raw deflate):")
open(os.path.join(here, "QR_min.ps1"), "w", encoding="utf-8", newline="").write(minimal)
save_qr(minimal, "QR_min.png")
