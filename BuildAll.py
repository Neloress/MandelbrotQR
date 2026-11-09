"""BuildAll.py - baut, verkleinert und verpackt die Mandelbrot-EXE vollautomatisch und prueft das Ergebnis.

Aufruf:
    python BuildAll.py            fragt nach 32 oder 64 Bit
    python BuildAll.py 32|64      direkt waehlen
Optionen:
    --variant both|full|min       welche QR-Variante(n) (Standard: both)
    --before TEXT / --after TEXT  Text vor/nach dem Skript der minimalen Variante (Standard: siehe unten bzw. generator.py)
    --skip-build                  vorhandene EXE verwenden (kein MSBuild)
    --no-run                      EXE nicht starten (nur bauen, QR erzeugen, QR zurücklesen)

Ablauf (jeder Schritt wird im Ergebnis am Ende aufgelistet):
    1. Bauen        MSBuild (Release). 64 Bit: Linker erzeugt direkt die kleine EXE.
                    32 Bit: PostLinkStripper + MiniPeLinker laufen als Post-Build-Schritt des Projekts.
    2. QR erzeugen  QR_Generator/generator.py -> QR_Generator/QR_<bits>bit/
    3. QR einlesen  PNG wird mit pyzbar gelesen und mit der .ps1 verglichen
    4. EXE testen   das Skript aus dem QR-Code wird wirklich ausgefuehrt: Fenster "Mandelbrot set" muss erscheinen,
                    die gestartete Datei muss die gebaute EXE sein (SHA-256), im Fenster muss etwas gezeichnet werden.
                    Danach wird das Fenster geschlossen (WM_CLOSE) und aufgeraeumt (entpackte Dateien in %TEMP%).
Voraussetzungen: Windows, Visual Studio (MSBuild + MASM), Python mit  pip install qrcode pillow pyzbar zopfli
(zopfli ist optional, spart ca. 40 Bytes). Der Test braucht einen sichtbaren Desktop.
"""
import argparse
import ctypes
import glob
import hashlib
import os
import shutil
import subprocess
import sys
import time
from ctypes import wintypes as wt

ROOT = os.path.dirname(os.path.abspath(__file__))
QR_DIR = os.path.join(ROOT, "QR_Generator")
sys.path.insert(0, QR_DIR)

# ---------------------------- Einstellungen je Version ----------------------------
TARGETS = {
    "32": dict(
        project=r"SmallASM\SmallASM32.vcxproj", platform="Win32",
        raw_exe=r"SmallASM\Release\SmallASM32.exe",       # Linker-Ausgabe, wird vom Post-Build verkleinert
        exe=r"SmallASM\Release\SmallASM32.min.exe",       # Ergebnis, kommt in den QR-Code
        after="Mouse wheel = zoom. Close the window to quit. Have fun!"),
    "64": dict(
        project=r"SmallASM\SmallASM64.vcxproj", platform="x64",
        raw_exe=None,
        exe=r"SmallASM\x64\Release\SmallASM64.exe",
        after="Mouse wheel = zoom, keys 1-5 = iterations, 6-9 = pixel size. Close the window to quit."),
}
WINDOW_TITLE = "Mandelbrot set"
WINDOW_TIMEOUT = 15      # Sekunden, bis das Fenster erscheinen muss
DRAW_TIMEOUT = 15        # Sekunden, bis im Fenster gezeichnet sein muss
CLOSE_TIMEOUT = 10       # Sekunden, bis die EXE nach WM_CLOSE beendet sein muss


# ---------------------------------- Ausgabe --------------------------------------
class Report:
    def __init__(self):
        self.rows = []  # (ok, name, detail); ok: True / False / None (nur Hinweis)

    def add(self, ok, name, detail=""):
        self.rows.append((ok, name, detail))
        mark = {True: "✅", False: "❌", None: "ℹ️"}[ok]
        print(f"   {mark} {name}" + (f": {detail}" if detail else ""), flush=True)
        return ok

    @property
    def failed(self):
        return any(ok is False for ok, _, _ in self.rows)


def step(title):
    print(f"\n=== {title} ===", flush=True)


# ---------------------------------- 1. Bauen -------------------------------------
def find_msbuild():
    found = shutil.which("msbuild")
    if found:
        return found
    vswhere = os.path.join(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"),
                           r"Microsoft Visual Studio\Installer\vswhere.exe")
    if os.path.exists(vswhere):
        out = subprocess.run([vswhere, "-latest", "-requires", "Microsoft.Component.MSBuild",
                              "-find", r"MSBuild\**\Bin\MSBuild.exe"], capture_output=True, text=True).stdout.split("\n")
        if out and out[0].strip():
            return out[0].strip()
    for pattern in (r"C:\Program Files\Microsoft Visual Studio\*\*\MSBuild\Current\Bin\MSBuild.exe",
                    r"C:\Program Files (x86)\Microsoft Visual Studio\*\*\MSBuild\Current\Bin\MSBuild.exe"):
        hits = sorted(glob.glob(pattern))
        if hits:
            return hits[-1]
    return None


def build(cfg, report):
    step("1. Bauen und verkleinern")
    final_exe = os.path.join(ROOT, cfg["exe"])
    # alte Ergebnisse loeschen, damit keine veraltete EXE fuer das Ergebnis gehalten wird
    for rel in (cfg["raw_exe"], cfg["exe"]):
        if rel and os.path.exists(os.path.join(ROOT, rel)):
            os.remove(os.path.join(ROOT, rel))
    msbuild = find_msbuild()
    if not msbuild:
        return report.add(False, "MSBuild", "nicht gefunden (Visual Studio installiert?)")
    print(f"   MSBuild: {msbuild}", flush=True)
    t = time.time()
    res = subprocess.run([msbuild, os.path.join(ROOT, cfg["project"]), "/t:Rebuild", "/p:Configuration=Release",
                          f"/p:Platform={cfg['platform']}", "/v:minimal", "/nologo"],
                         capture_output=True, text=True, encoding="mbcs", errors="replace")
    if res.returncode != 0 or not os.path.exists(final_exe):
        errors = [l.strip() for l in (res.stdout + res.stderr).splitlines() if "error" in l.lower()][:8]
        return report.add(False, "Build", f"fehlgeschlagen (Exit {res.returncode})" +
                          ("".join("\n      " + e for e in errors) or "\n      (keine Fehlerzeile, MSBuild-Ausgabe pruefen)"))
    report.add(True, "Build", f"MSBuild Release/{cfg['platform']} in {time.time() - t:.0f} s")
    size = os.path.getsize(final_exe)
    if cfg["raw_exe"] and os.path.exists(os.path.join(ROOT, cfg["raw_exe"])):
        raw = os.path.getsize(os.path.join(ROOT, cfg["raw_exe"]))
        report.add(True, "Verkleinern", f"{raw} -> {size} Bytes (PostLinkStripper + MiniPeLinker)")
    else:
        report.add(True, "Verkleinern", f"{size} Bytes (Linker-Optionen im Projekt)")
    return True


# ------------------------------ 3. QR zuruecklesen ------------------------------
def read_back(results, report):
    from PIL import Image
    from pyzbar.pyzbar import decode
    step("3. QR-Codes einlesen")
    for r in results:
        if not r["fits"]:
            continue
        name = os.path.basename(r["png"])
        objects = decode(Image.open(r["png"]))
        if not objects:
            report.add(False, f"{name} lesen", "kein QR-Code erkannt")
            r["fits"] = False
            continue
        text = objects[0].data.decode("utf-8")
        same = text == open(r["ps1"], encoding="utf-8", newline="").read()
        report.add(same, f"{name} lesen", f"{len(text)} Zeichen, " + ("identisch mit dem Skript" if same else "WEICHT vom Skript ab"))
        r["read_ok"] = same
        r["text"] = text


# ----------------------------- 4. EXE starten und pruefen -----------------------------
user32 = kernel32 = None
if os.name == "nt":
    user32 = ctypes.WinDLL("user32", use_last_error=True)
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    ctypes.windll.user32.SetProcessDPIAware()
    WNDENUMPROC = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    user32.EnumWindows.argtypes = [WNDENUMPROC, wt.LPARAM]
    user32.GetWindowTextW.argtypes = [wt.HWND, wt.LPWSTR, ctypes.c_int]
    user32.IsWindowVisible.argtypes = [wt.HWND]
    user32.GetWindowThreadProcessId.argtypes = [wt.HWND, ctypes.POINTER(wt.DWORD)]
    user32.PostMessageW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]
    user32.GetClientRect.argtypes = [wt.HWND, ctypes.POINTER(wt.RECT)]
    user32.ClientToScreen.argtypes = [wt.HWND, ctypes.POINTER(wt.POINT)]
    user32.SetWindowPos.argtypes = [wt.HWND, wt.HWND, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int, wt.UINT]
    kernel32.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
    kernel32.OpenProcess.restype = wt.HANDLE
    kernel32.QueryFullProcessImageNameW.argtypes = [wt.HANDLE, wt.DWORD, wt.LPWSTR, ctypes.POINTER(wt.DWORD)]
    kernel32.WaitForSingleObject.argtypes = [wt.HANDLE, wt.DWORD]
    kernel32.TerminateProcess.argtypes = [wt.HANDLE, wt.UINT]
    kernel32.CloseHandle.argtypes = [wt.HANDLE]

PROCESS_QUERY_LIMITED_INFORMATION, SYNCHRONIZE, PROCESS_TERMINATE = 0x1000, 0x100000, 0x1
WM_CLOSE = 0x0010


def process_image(pid):
    h = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not h:
        return None
    try:
        buf, size = ctypes.create_unicode_buffer(1024), wt.DWORD(1024)
        return buf.value if kernel32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(size)) else None
    finally:
        kernel32.CloseHandle(h)


def find_window(exe_path):
    """(hwnd, pid) of the visible window WINDOW_TITLE that belongs to exe_path, else None."""
    found = []

    @WNDENUMPROC
    def callback(hwnd, _):
        buf = ctypes.create_unicode_buffer(256)
        user32.GetWindowTextW(hwnd, buf, 256)
        if buf.value == WINDOW_TITLE and user32.IsWindowVisible(hwnd):
            pid = wt.DWORD()
            user32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
            image = process_image(pid.value)
            if image and os.path.exists(exe_path) and os.path.samefile(image, exe_path):
                found.append((hwnd, pid.value))
        return True

    user32.EnumWindows(callback, 0)
    return found[0] if found else None


def window_has_content(hwnd):
    """True if the client area shows more than a few different colours (the fractal is drawn)."""
    from PIL import ImageGrab
    user32.SetWindowPos(hwnd, wt.HWND(-1), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0040)  # TOPMOST, NOMOVE|NOSIZE|SHOWWINDOW
    rect, origin = wt.RECT(), wt.POINT(0, 0)
    user32.GetClientRect(hwnd, ctypes.byref(rect))
    user32.ClientToScreen(hwnd, ctypes.byref(origin))
    img = ImageGrab.grab((origin.x, origin.y, origin.x + rect.right, origin.y + rect.bottom), all_screens=True)
    return len(img.convert("RGB").getcolors(1 << 24) or []) >= 4


def sha256(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def remove_extracted(extract_path):
    """Entfernt die vom Skript entpackte EXE (bei der vollen Variante samt Ordner). True wenn danach nichts mehr da ist."""
    target = extract_path if os.path.dirname(extract_path).lower() == os.environ.get("TEMP", "").lower() \
        else os.path.dirname(extract_path)
    for _ in range(20):
        try:
            if os.path.isdir(target):
                shutil.rmtree(target)
            elif os.path.exists(target):
                os.remove(target)
            return True
        except OSError:
            time.sleep(0.25)
    return not os.path.exists(extract_path)


def run_script(r, built_exe, report):
    """Fuehrt das Skript aus dem QR-Code aus und prueft, ob die EXE korrekt entpackt, startet, zeichnet und sich schliessen laesst."""
    label = f"[{r['variant']}]"
    extract = r["extract_path"]
    if os.path.exists(extract) and not remove_extracted(extract):
        return report.add(False, f"{label} Vorbereitung", f"{extract} laesst sich nicht loeschen (laeuft die EXE noch?)")
    script = os.path.join(os.environ.get("TEMP", "."), f"mb_check_{r['variant']}.ps1")
    with open(script, "w", encoding="utf-8", newline="") as f:
        f.write(r["text"])  # exakt der Text aus dem QR-Code
    ps = subprocess.Popen(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="mbcs", errors="replace")
    hwnd_pid = None
    try:
        deadline = time.time() + WINDOW_TIMEOUT
        while time.time() < deadline and not hwnd_pid:
            hwnd_pid = find_window(extract) if os.path.exists(extract) else None
            if not hwnd_pid:
                time.sleep(0.3)
        if not hwnd_pid:
            err = ""
            if ps.poll() is not None:
                err = " PowerShell: " + (ps.stderr.read() or ps.stdout.read()).strip()[:300]
            return report.add(False, f"{label} Start", f"kein Fenster '{WINDOW_TITLE}' innerhalb {WINDOW_TIMEOUT} s.{err}")
        hwnd, pid = hwnd_pid
        report.add(True, f"{label} Start", f"Skript entpackt und startet die EXE, Fenster '{WINDOW_TITLE}' (PID {pid})")

        same = sha256(extract) == sha256(built_exe)
        report.add(same, f"{label} Entpackte EXE", "identisch mit der gebauten EXE (SHA-256)" if same
                   else "ABWEICHEND von der gebauten EXE")

        drawn, deadline = False, time.time() + DRAW_TIMEOUT
        while time.time() < deadline and not drawn:
            drawn = window_has_content(hwnd)
            if not drawn:
                time.sleep(0.5)
        report.add(drawn, f"{label} Zeichnen", "Fraktal wird im Fenster angezeigt" if drawn
                   else f"Fenster blieb {DRAW_TIMEOUT} s lang einfarbig (verdeckt? nicht gezeichnet?)")

        handle = kernel32.OpenProcess(SYNCHRONIZE | PROCESS_TERMINATE, False, pid)
        user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)
        closed = bool(handle) and kernel32.WaitForSingleObject(handle, CLOSE_TIMEOUT * 1000) == 0
        if handle and not closed:
            kernel32.TerminateProcess(handle, 1)
        if handle:
            kernel32.CloseHandle(handle)
        report.add(closed, f"{label} Schliessen", "EXE beendet sich nach WM_CLOSE" if closed
                   else f"EXE reagierte nicht auf WM_CLOSE ({CLOSE_TIMEOUT} s), wurde beendet")
    finally:
        try:
            out, err = ps.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            ps.kill()
            out, err = ps.communicate()
        if err.strip():
            report.add(False, f"{label} PowerShell-Fehler", err.strip().splitlines()[0][:200])
        os.remove(script)
        report.add(remove_extracted(extract), f"{label} Aufraeumen", "entpackte Dateien in %TEMP% geloescht")


# ------------------------------------- main --------------------------------------
def ask_bits():
    while True:
        answer = input("Welche Version soll gebaut werden?  [1] 32 Bit   [2] 64 Bit  > ").strip().lower()
        if answer in ("1", "32", "32bit", "32-bit"):
            return "32"
        if answer in ("2", "64", "64bit", "64-bit"):
            return "64"
        print("Bitte 1 oder 2 eingeben.")


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="Baut, verkleinert und verpackt die Mandelbrot-EXE und prueft das Ergebnis.")
    ap.add_argument("bits", nargs="?", choices=("32", "64"), help="Zielarchitektur (sonst Abfrage)")
    ap.add_argument("--variant", choices=("both", "full", "min"), default="both", help="QR-Variante(n)")
    ap.add_argument("--before", default=None, help="Text vor dem Skript der minimalen Variante")
    ap.add_argument("--after", default=None, help="Text nach dem Skript der minimalen Variante")
    ap.add_argument("--skip-build", action="store_true", help="vorhandene EXE verwenden")
    ap.add_argument("--no-run", action="store_true", help="EXE nicht starten")
    args = ap.parse_args()
    bits = args.bits or ask_bits()
    cfg = TARGETS[bits]

    try:
        import generator
        import PIL  # noqa: F401
        import pyzbar.pyzbar  # noqa: F401
    except ImportError as e:
        sys.exit(f"❌ Fehlendes Python-Paket ({e.name}). Installieren mit:  pip install qrcode pillow pyzbar zopfli")

    started = time.time()
    report = Report()
    built_exe = os.path.join(ROOT, cfg["exe"])
    print(f"Mandelbrot {bits}-Bit: Build -> QR-Code -> Test")

    if args.skip_build:
        step("1. Bauen und verkleinern")
        if os.path.exists(built_exe):
            report.add(None, "Build uebersprungen", f"{built_exe} ({os.path.getsize(built_exe)} Bytes)")
        else:
            report.add(False, "Build uebersprungen", f"{built_exe} existiert nicht")
    else:
        build(cfg, report)

    results = []
    if not report.failed:
        step("2. QR-Codes erzeugen")
        results = generator.generate(built_exe, args.variant, args.before,
                                     cfg["after"] if args.after is None else args.after,
                                     out_dir=os.path.join(QR_DIR, f"QR_{bits}bit"), log=lambda m: print("   " + m, flush=True))
        for r in results:
            if r["fits"]:
                report.add(True, f"QR [{r['variant']}]", f"{r['bytes']} / {r['limit']} Bytes, Puffer {r['limit'] - r['bytes']}")
            elif args.variant == "both":
                report.add(None, f"QR [{r['variant']}]", f"zu gross um {r['bytes'] - r['limit']} Bytes, uebersprungen")
            else:
                report.add(False, f"QR [{r['variant']}]", f"zu gross um {r['bytes'] - r['limit']} Bytes")
        if not any(r["fits"] for r in results):
            report.add(False, "QR", "keine Variante passt in einen QR-Code")

    if not report.failed:
        read_back(results, report)
        if not args.no_run:
            step("4. EXE aus dem QR-Skript starten und pruefen")
            for r in results:
                if r["fits"] and r.get("read_ok"):
                    run_script(r, built_exe, report)

    # ------------------------------- Ergebnis -------------------------------
    print("\n" + "=" * 70)
    print(f"ERGEBNIS Mandelbrot {bits}-Bit ({time.time() - started:.0f} s)")
    print("=" * 70)
    if os.path.exists(built_exe):
        print(f"EXE: {built_exe} ({os.path.getsize(built_exe)} Bytes)")
    for r in results:
        if r["fits"]:
            print(f"QR [{r['variant']}]: {r['png']}")
    bad = [(n, d) for ok, n, d in report.rows if ok is False]
    for ok, name, detail in report.rows:
        print(f"  {'✅' if ok else '❌' if ok is False else 'ℹ️'} {name}" + (f": {detail.splitlines()[0]}" if detail else ""))
    print("-" * 70)
    if bad:
        print(f"❌ FEHLGESCHLAGEN ({len(bad)} Fehler)")
        return 1
    print("✅ ALLES OK" + ("" if not args.no_run else " (EXE-Test uebersprungen)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
