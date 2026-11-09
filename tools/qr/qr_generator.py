"""QR code generator: packs an EXE into a QR code (QR version 40, level L, max. 2953 bytes).

Usage:
    python qr_generator.py [EXE] [--variant both|full|min] [--before TEXT] [--after TEXT] [--out-dir DIR]

Variants (select with --variant, default see VARIANT below):
    full  qr_full.png / qr_full.ps1  readable PowerShell script with instructions, EXE shipped as .zip (Expand-Archive)
    min   qr_min.png  / qr_min.ps1   shortest possible one-liner, EXE shipped as raw deflate, only comments before/after

Both variants are plug and play: copy the text, paste it into PowerShell, the EXE is unpacked to %TEMP% and started.
The .ps1 files contain exactly the text that is inside the QR code.
Zopfli (pip install zopfli) compresses slightly better than zlib and is used automatically if it is installed.
See docs/qr-code.md for the size budget and how the variants work.
"""
import argparse
import base64
import os
import struct
import sys
import zlib

import qrcode

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DEFAULT_EXE = os.path.join(REPO_ROOT, "build", "64bit", "Mandelbrot64.exe")
DEFAULT_OUT_DIR = os.path.join(REPO_ROOT, "build", "qr")
QR_MAX_BYTES = 2953  # QR version 40, error correction L, byte mode
EXE_NAME = "M.exe"   # name of the EXE inside the archive / in %TEMP%

# ================================ SETTINGS ================================

# Which variant(s) to generate: "both", "full" or "min" (command line: --variant)
VARIANT = "both"

# --- Minimal variant: text before and after the script ----------------------------------------------------
# Inserted as PowerShell comments (every line gets a '#'). Use ASCII only, every byte counts: the free space
# in the QR code is printed after generating. Empty string ("") = no text. Command line: --before / --after
MIN_TEXT_BEFORE = "Copy ALL, paste into PowerShell, press Enter. Mouse wheel = zoom."
MIN_TEXT_AFTER = "This is the very last byte of the QR-Code!"

# --- Full variant: instructions before and closing line after the script ----------------------------------
FULL_TEXT_BEFORE = (
    "#:: --- Open on Windows PC ---\n"
    "#:: 1. Copy whole text.\n"
    "#:: 2. Paste into PowerShell.\n"
    "#:: 3. Enjoy Fractals!\n"
    "#:: ---------------"
)
FULL_TEXT_AFTER = "These are the last possible bytes that fit on the QR-Code. Have a good day!!!"

# Sub folder in %TEMP% the full variant unpacks to (fixed suffix: protects against overwriting existing folders)
FULL_SANDBOX_DIR = "M_105HDGDL69"

# ==========================================================================


# ------------------------------- compression --------------------------------

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


# --------------------------------- scripts ----------------------------------

def as_comment(text):
    """Text -> PowerShell comment lines (every line gets a '#', lines that already start with '#' stay as they are)."""
    if not text:
        return ""
    return "".join((line if line.startswith("#") else "#" + line) + "\n" for line in text.splitlines())


def script_full(exe, packed):
    """Readable script: unpacks the zip with Expand-Archive, deletes the zip again, starts the EXE."""
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
    """Shortest possible one-liner: inflates the raw deflate stream straight to %TEMP%\\M.exe and starts it.
    No file other than the EXE is created (the EXE stays in %TEMP% because it is still running).
    CompressionMode 0 = Decompress; without the enum cast a bare 0 is an ambiguous overload."""
    return (
        f"{as_comment(before)}"
        f'$f="$env:temp\\{EXE_NAME}";$o=[IO.File]::Create($f);'
        f"(New-Object IO.Compression.DeflateStream([IO.MemoryStream][Convert]::FromBase64String('{b64(packed)}'),"
        f"[IO.Compression.CompressionMode]0)).CopyTo($o);"
        f"$o.Close();&$f\n"
        f"{as_comment(after)}"
    )


# --------------------------------- QR code ----------------------------------

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


def generate(exe_path, variant=VARIANT, before=None, after=None, out_dir=DEFAULT_OUT_DIR, log=print):
    """Generates the requested variant(s). Returns a list of results (one dict per variant):
    variant, png, ps1, bytes, limit, fits, extract_path (where the script unpacks the EXE), exe_size, packed_size."""
    if variant not in ("both", "full", "min"):
        raise ValueError(f"Unknown variant '{variant}' (both, full or min)")
    before = MIN_TEXT_BEFORE if before is None else before
    after = MIN_TEXT_AFTER if after is None else after
    os.makedirs(out_dir, exist_ok=True)

    exe = open(exe_path, "rb").read()
    packed, compressor = deflate(exe)
    log(f"📦 EXE: {len(exe)} bytes, deflate: {len(packed)} bytes ({compressor})")

    temp = os.environ.get("TEMP", "")
    jobs = []
    if variant in ("both", "full"):
        jobs.append(("full", "qr_full", script_full(exe, packed), os.path.join(temp, FULL_SANDBOX_DIR, EXE_NAME)))
    if variant in ("both", "min"):
        jobs.append(("min", "qr_min", script_min(packed, before, after), os.path.join(temp, EXE_NAME)))

    results = []
    for name, base, text, extract_path in jobs:
        png = os.path.join(out_dir, base + ".png")
        ps1 = os.path.join(out_dir, base + ".ps1")
        with open(ps1, "w", encoding="utf-8", newline="") as f:
            f.write(text)
        size = len(text.encode("utf-8"))
        fits = save_qr(text, png)
        label = "Full variant (with instructions, zip)" if name == "full" else "Minimal variant (raw deflate)"
        if fits:
            log(f"✅ {label}: {size} / {QR_MAX_BYTES} bytes, {QR_MAX_BYTES - size} free -> {os.path.basename(png)}")
        else:
            log(f"❌ {label}: {size} / {QR_MAX_BYTES} bytes, {size - QR_MAX_BYTES} too large -> no QR code")
        results.append(dict(variant=name, png=png if fits else None, ps1=ps1, bytes=size, limit=QR_MAX_BYTES,
                            fits=fits, extract_path=extract_path, exe_size=len(exe), packed_size=len(packed)))
    return results


def main(argv=None):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # emoji output also works on cp1252 consoles
    ap = argparse.ArgumentParser(description="Packs an EXE into a QR code (see the top of this file).")
    ap.add_argument("exe", nargs="?", default=DEFAULT_EXE, help="EXE to pack (default: build/64bit/Mandelbrot64.exe)")
    ap.add_argument("--variant", choices=("both", "full", "min"), default=VARIANT,
                    help=f"which variant(s) to generate (default: {VARIANT})")
    ap.add_argument("--before", default=None, help="text BEFORE the script of the minimal variant (as comment)")
    ap.add_argument("--after", default=None, help="text AFTER the script of the minimal variant (as comment)")
    ap.add_argument("--out-dir", default=DEFAULT_OUT_DIR, help="output folder (default: build/qr)")
    args = ap.parse_args(argv)

    if not os.path.exists(args.exe):
        sys.exit(f"❌ Error: '{args.exe}' not found (build it first: build.cmd).")
    results = generate(args.exe, args.variant, args.before, args.after, args.out_dir)
    return 0 if all(r["fits"] for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
