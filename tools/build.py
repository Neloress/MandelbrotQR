"""build.py - builds, shrinks and packs the Mandelbrot EXE fully automatically and verifies the result.

Usage:
    python tools/build.py             asks for 32 bit, 64 bit or both   (build.cmd in the repo root does the same)
    python tools/build.py 32|64|both  choose directly
Options:
    --variant both|full|min        which QR variant(s) to generate (default: both)
    --before TEXT / --after TEXT   text before/after the script of the minimal variant (default: see qr/qr_generator.py)
    --skip-build                   use the existing EXE (no MSBuild)
    --no-run                       do not start the EXE (build, generate QR codes, read them back; nothing is published)
    --no-publish                   do not update the QR codes in qr/ (they are shown in README.md)

Steps (every step is listed in the result at the end):
    1. Build      MSBuild (Release) on src/<bits>bit/Mandelbrot<bits>.sln. 64 bit: the linker already produces the small EXE.
                  32 bit: PostLinkStripper + MiniPeLinker run as post-build step of the project.
                  Result: build/<bits>bit/Mandelbrot<bits>.exe (same layout for both versions)
    2. QR codes   tools/qr/qr_generator.py -> build/<bits>bit/qr/
    3. Read back  every PNG is read with pyzbar and must be identical to its .ps1
    4. Run EXE    the script from the QR code is really executed: the window "Mandelbrot..." must appear, the started file
                  must be the built EXE (SHA-256), something must be drawn, the window title must react to the keys (64 bit).
                  Then the window is closed (WM_CLOSE) and the unpacked files in %TEMP% are removed.
    5. Publish    the best variant (full if it fits, else min) is copied to qr/mandelbrot<bits>.png/.ps1
Requirements: Windows, Visual Studio (MSBuild + MASM), Python with  pip install qrcode pillow pyzbar zopfli
(zopfli is optional, saves about 40 bytes). The EXE test needs a visible desktop.
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

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS_DIR = os.path.join(ROOT, "tools")
BUILD_DIR = os.path.join(ROOT, "build")
sys.path.insert(0, os.path.join(TOOLS_DIR, "qr"))

# ------------------------------ settings per version ------------------------------
TARGETS = {
    "32": dict(
        solution=os.path.join("src", "32bit", "Mandelbrot32.sln"), platform="Win32",
        raw_exe=os.path.join("build", "32bit", "obj", "Mandelbrot32.exe"),  # linker output, shrunk by the post-build step
        exe=os.path.join("build", "32bit", "Mandelbrot32.exe"),             # result, goes into the QR code
        title_checks=[]),
    "64": dict(
        solution=os.path.join("src", "64bit", "Mandelbrot64.sln"), platform="x64",
        raw_exe=None,
        exe=os.path.join("build", "64bit", "Mandelbrot64.exe"),
        # (key, expected end of the window title): keys are sent with WM_KEYDOWN, None = title right after start.
        # Key '4' (100000 iterations) is not tested: drawing would take minutes.
        title_checks=[(None, "Pixel size  4 | Keys 0-4: Iterations 10"), ("2", "Pixel size  4 | Keys 0-4: Iterations 1000"),
                      ("9", "Pixel size 16 | Keys 0-4: Iterations 1000"), ("8", "Pixel size  8 | Keys 0-4: Iterations 1000"),
                      ("6", "Pixel size  2 | Keys 0-4: Iterations 1000"), ("5", "Pixel size  1 | Keys 0-4: Iterations 1000"),
                      ("0", "Pixel size  1 | Keys 0-4: Iterations 10"), ("7", "Pixel size  4 | Keys 0-4: Iterations 10")]),
}
CSHARP_TOOLS = {  # tool name -> extra compiler arguments (sources: tools/<name>/Program.cs, output: build/tools/<name>.exe)
    "PostLinkStripper": [],
    "MiniPeLinker": [],
    "ExeSmokeTester": ["/r:System.Drawing.dll"],
}
WINDOW_TITLE_PREFIX = "Mandelbrot"   # 32 bit: "Mandelbrot set", 64 bit: "Mandelbrot set | Keys ..." (title shows the settings)
WINDOW_TIMEOUT = 15      # seconds until the window must appear
DRAW_TIMEOUT = 15        # seconds until something must be drawn in the window
TITLE_TIMEOUT = 10       # seconds until the title must have changed after a key press
CLOSE_TIMEOUT = 10       # seconds until the EXE must have exited after WM_CLOSE


# ------------------------------------- output -------------------------------------
class Report:
    def __init__(self):
        self.rows = []  # (ok, name, detail); ok: True / False / None (note only)

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


# ------------------------------------ 1. build ------------------------------------
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


def compile_tools(msbuild, report):
    """Compiles the C# helper tools to build/tools/ (only if missing or older than their source). No binaries in the repo."""
    csc = os.path.join(os.path.dirname(msbuild), "Roslyn", "csc.exe")
    if not os.path.exists(csc):
        return report.add(False, "C# compiler", f"{csc} not found")
    out_dir = os.path.join(BUILD_DIR, "tools")
    os.makedirs(out_dir, exist_ok=True)
    for name, extra in CSHARP_TOOLS.items():
        source = os.path.join(TOOLS_DIR, name, "Program.cs")
        out = os.path.join(out_dir, name + ".exe")
        if os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(source):
            continue
        res = subprocess.run([csc, "/nologo", "/target:exe", f"/out:{out}", *extra, source],
                             capture_output=True, text=True, encoding="mbcs", errors="replace")
        if res.returncode != 0:
            return report.add(False, f"Compile {name}", (res.stdout + res.stderr).strip().splitlines()[0][:200])
        report.add(True, f"Compile {name}", os.path.relpath(out, ROOT))
    return True


def build(cfg, report):
    step("1. Build and shrink")
    final_exe = os.path.join(ROOT, cfg["exe"])
    # delete old results so an outdated EXE can never be mistaken for the new one
    for rel in (cfg["raw_exe"], cfg["exe"]):
        if rel and os.path.exists(os.path.join(ROOT, rel)):
            os.remove(os.path.join(ROOT, rel))
    msbuild = find_msbuild()
    if not msbuild:
        return report.add(False, "MSBuild", "not found (is Visual Studio installed?)")
    print(f"   MSBuild: {msbuild}", flush=True)
    if not compile_tools(msbuild, report):
        return False
    t = time.time()
    res = subprocess.run([msbuild, os.path.join(ROOT, cfg["solution"]), "/t:Rebuild", "/p:Configuration=Release",
                          f"/p:Platform={cfg['platform']}", "/v:minimal", "/nologo"],
                         capture_output=True, text=True, encoding="mbcs", errors="replace")
    if res.returncode != 0 or not os.path.exists(final_exe):
        errors = [l.strip() for l in (res.stdout + res.stderr).splitlines() if "error" in l.lower()][:8]
        return report.add(False, "Build", f"failed (exit code {res.returncode})" +
                          ("".join("\n      " + e for e in errors) or "\n      (no error line, check the MSBuild output)"))
    report.add(True, "Build", f"MSBuild Release/{cfg['platform']} in {time.time() - t:.0f} s")
    size = os.path.getsize(final_exe)
    if cfg["raw_exe"] and os.path.exists(os.path.join(ROOT, cfg["raw_exe"])):
        raw = os.path.getsize(os.path.join(ROOT, cfg["raw_exe"]))
        report.add(True, "Shrink", f"{raw} -> {size} bytes (PostLinkStripper + MiniPeLinker)")
    else:
        report.add(True, "Shrink", f"{size} bytes (linker options in the project)")
    return True


# ---------------------------------- 3. read back ----------------------------------
def read_back(results, report):
    from PIL import Image
    from pyzbar.pyzbar import decode
    step("3. Read the QR codes back")
    for r in results:
        if not r["fits"]:
            continue
        name = os.path.basename(r["png"])
        objects = decode(Image.open(r["png"]))
        if not objects:
            report.add(False, f"read {name}", "no QR code recognised")
            r["fits"] = False
            continue
        text = objects[0].data.decode("utf-8")
        same = text == open(r["ps1"], encoding="utf-8", newline="").read()
        report.add(same, f"read {name}", f"{len(text)} characters, " + ("identical to the script" if same else "DIFFERS from the script"))
        r["read_ok"] = same
        r["text"] = text


# ------------------------------- 4. run and verify EXE -------------------------------
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
WM_CLOSE, WM_KEYDOWN = 0x0010, 0x0100


def process_image(pid):
    h = kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
    if not h:
        return None
    try:
        buf, size = ctypes.create_unicode_buffer(1024), wt.DWORD(1024)
        return buf.value if kernel32.QueryFullProcessImageNameW(h, 0, buf, ctypes.byref(size)) else None
    finally:
        kernel32.CloseHandle(h)


def window_title(hwnd):
    buf = ctypes.create_unicode_buffer(256)
    user32.GetWindowTextW(hwnd, buf, 256)  # other process: reads the caption directly, does not wait for its message loop
    return buf.value


def find_window(exe_path):
    """(hwnd, pid) of the visible window titled WINDOW_TITLE_PREFIX... that belongs to exe_path, else None."""
    found = []

    @WNDENUMPROC
    def callback(hwnd, _):
        if window_title(hwnd).startswith(WINDOW_TITLE_PREFIX) and user32.IsWindowVisible(hwnd):
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
    """Removes the EXE unpacked by the script (with its folder for the full variant). True if nothing is left."""
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


def run_script(r, built_exe, report, title_checks):
    """Runs the script from the QR code and checks that the EXE unpacks, starts, draws, reacts to keys and can be closed."""
    label = f"[{r['variant']}]"
    extract = r["extract_path"]
    if os.path.exists(extract) and not remove_extracted(extract):
        return report.add(False, f"{label} Preparation", f"{extract} can not be deleted (is the EXE still running?)")
    script = os.path.join(os.environ.get("TEMP", "."), f"mandelbrot_check_{r['variant']}.ps1")
    with open(script, "w", encoding="utf-8", newline="") as f:
        f.write(r["text"])  # exactly the text from the QR code
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
            return report.add(False, f"{label} Start", f"no window '{WINDOW_TITLE_PREFIX}...' within {WINDOW_TIMEOUT} s.{err}")
        hwnd, pid = hwnd_pid
        report.add(True, f"{label} Start", f"script unpacked and started the EXE, window '{window_title(hwnd)}' (PID {pid})")

        same = sha256(extract) == sha256(built_exe)
        report.add(same, f"{label} Unpacked EXE", "identical to the built EXE (SHA-256)" if same
                   else "DIFFERS from the built EXE")

        drawn, deadline = False, time.time() + DRAW_TIMEOUT
        while time.time() < deadline and not drawn:
            drawn = window_has_content(hwnd)
            if not drawn:
                time.sleep(0.5)
        report.add(drawn, f"{label} Drawing", "fractal is shown in the window" if drawn
                   else f"window stayed one colour for {DRAW_TIMEOUT} s (covered? not drawn?)")

        for key, expected in title_checks:
            if key:
                user32.PostMessageW(hwnd, WM_KEYDOWN, ord(key), 0)
            deadline = time.time() + TITLE_TIMEOUT
            while time.time() < deadline and not window_title(hwnd).endswith(expected):
                time.sleep(0.2)
            title = window_title(hwnd)
            report.add(title.endswith(expected), f"{label} Title" + (f" (key '{key}')" if key else " (start)"),
                       f"'{title}'" if title.endswith(expected) else f"'{title}' does not end with '{expected}'")

        handle = kernel32.OpenProcess(SYNCHRONIZE | PROCESS_TERMINATE, False, pid)
        user32.PostMessageW(hwnd, WM_CLOSE, 0, 0)
        closed = bool(handle) and kernel32.WaitForSingleObject(handle, CLOSE_TIMEOUT * 1000) == 0
        if handle and not closed:
            kernel32.TerminateProcess(handle, 1)
        if handle:
            kernel32.CloseHandle(handle)
        report.add(closed, f"{label} Close", "EXE exits after WM_CLOSE" if closed
                   else f"EXE did not react to WM_CLOSE ({CLOSE_TIMEOUT} s), it was terminated")
    finally:
        try:
            out, err = ps.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            ps.kill()
            out, err = ps.communicate()
        if err.strip():
            report.add(False, f"{label} PowerShell error", err.strip().splitlines()[0][:200])
        os.remove(script)
        report.add(remove_extracted(extract), f"{label} Clean up", "unpacked files in %TEMP% deleted")


# --------------------------------- 5. publish ---------------------------------
def publish(bits, results, report):
    """Copies the best verified variant (full if it fits, else min) to qr/mandelbrot<bits>.png/.ps1 (shown in README.md)."""
    step("5. Publish the QR code")
    verified = [r for r in results if r["fits"] and r.get("read_ok")]
    if not verified:
        return report.add(False, "Publish", "no verified QR code")
    best = next((r for r in verified if r["variant"] == "full"), verified[0])
    dest_dir = os.path.join(ROOT, "qr")
    os.makedirs(dest_dir, exist_ok=True)
    for ext, src in (("png", best["png"]), ("ps1", best["ps1"])):
        shutil.copyfile(src, os.path.join(dest_dir, f"mandelbrot{bits}.{ext}"))
    return report.add(True, "Publish", f"qr/mandelbrot{bits}.png ({best['variant']} variant, {best['bytes']} / {best['limit']} bytes)")


# ------------------------------------- main -------------------------------------
def ask_bits():
    while True:
        answer = input("Which version should be built?  [1] 32 bit   [2] 64 bit   [3] both  > ").strip().lower()
        if answer in ("1", "32", "32bit", "32-bit"):
            return "32"
        if answer in ("2", "64", "64bit", "64-bit"):
            return "64"
        if answer in ("3", "both", "all"):
            return "both"
        print("Please enter 1, 2 or 3.")


def run(bits, args):
    """Full pipeline for one version. Returns True if everything is OK."""
    import qr_generator
    cfg = TARGETS[bits]
    started = time.time()
    report = Report()
    built_exe = os.path.join(ROOT, cfg["exe"])
    print(f"\n{'#' * 70}\nMandelbrot {bits}-bit: build -> QR code -> test\n{'#' * 70}")

    if args.skip_build:
        step("1. Build and shrink")
        if os.path.exists(built_exe):
            report.add(None, "Build skipped", f"{built_exe} ({os.path.getsize(built_exe)} bytes)")
        else:
            report.add(False, "Build skipped", f"{built_exe} does not exist")
    else:
        build(cfg, report)

    results = []
    if not report.failed:
        step("2. Generate the QR codes")
        results = qr_generator.generate(built_exe, args.variant, args.before, args.after,
                                        out_dir=os.path.join(BUILD_DIR, f"{bits}bit", "qr"),
                                        log=lambda m: print("   " + m, flush=True))
        for r in results:
            if r["fits"]:
                report.add(True, f"QR [{r['variant']}]", f"{r['bytes']} / {r['limit']} bytes, {r['limit'] - r['bytes']} free")
            elif args.variant == "both":
                report.add(None, f"QR [{r['variant']}]", f"{r['bytes'] - r['limit']} bytes too large, skipped")
            else:
                report.add(False, f"QR [{r['variant']}]", f"{r['bytes'] - r['limit']} bytes too large")
        if not any(r["fits"] for r in results):
            report.add(False, "QR", "no variant fits into a QR code")

    if not report.failed:
        read_back(results, report)
        if not args.no_run:
            step("4. Run the EXE from the QR script and verify it")
            for r in results:
                if r["fits"] and r.get("read_ok"):
                    run_script(r, built_exe, report, cfg["title_checks"])
        if not report.failed and not args.no_run and not args.no_publish:
            publish(bits, results, report)

    # ------------------------------- result -------------------------------
    print("\n" + "=" * 70)
    print(f"RESULT Mandelbrot {bits}-bit ({time.time() - started:.0f} s)")
    print("=" * 70)
    if os.path.exists(built_exe):
        print(f"EXE: {built_exe} ({os.path.getsize(built_exe)} bytes)")
    for r in results:
        if r["fits"]:
            print(f"QR [{r['variant']}]: {r['png']}")
    bad = [(n, d) for ok, n, d in report.rows if ok is False]
    for ok, name, detail in report.rows:
        print(f"  {'✅' if ok else '❌' if ok is False else 'ℹ️'} {name}" + (f": {detail.splitlines()[0]}" if detail else ""))
    print("-" * 70)
    if bad:
        print(f"❌ FAILED ({len(bad)} error{'s' if len(bad) != 1 else ''})")
        return False
    print("✅ ALL OK" + ("" if not args.no_run else " (EXE test skipped)"))
    return True


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="Builds, shrinks and packs the Mandelbrot EXE and verifies the result.")
    ap.add_argument("bits", nargs="?", choices=("32", "64", "both"), help="target (asked interactively if omitted)")
    ap.add_argument("--variant", choices=("both", "full", "min"), default="both", help="QR variant(s)")
    ap.add_argument("--before", default=None, help="text before the script of the minimal variant")
    ap.add_argument("--after", default=None, help="text after the script of the minimal variant")
    ap.add_argument("--skip-build", action="store_true", help="use the existing EXE")
    ap.add_argument("--no-run", action="store_true", help="do not start the EXE (nothing is published)")
    ap.add_argument("--no-publish", action="store_true", help="do not update the QR codes in qr/")
    args = ap.parse_args()
    bits = args.bits or ask_bits()

    try:
        import qr_generator  # noqa: F401
        import PIL  # noqa: F401
        import pyzbar.pyzbar  # noqa: F401
    except ImportError as e:
        sys.exit(f"❌ Missing Python package ({e.name}). Install with:  pip install qrcode pillow pyzbar zopfli")

    versions = ["32", "64"] if bits == "both" else [bits]
    outcomes = {v: run(v, args) for v in versions}
    if len(versions) > 1:
        print("\n" + "=" * 70)
        for v, ok in outcomes.items():
            print(f"  {'✅' if ok else '❌'} Mandelbrot {v}-bit")
    return 0 if all(outcomes.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
