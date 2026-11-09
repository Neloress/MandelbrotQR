"""Shows how many bytes of machine code each kind of instruction produces in an .asm file (x64, ml64).

Usage:  python tools/asm_size_report.py <file.asm> [top-N]
Runs ml64 with a listing (/Fl /Sg) and sums the instruction lengths per mnemonic pattern.
Used to find where the code size goes (see docs/size-optimization.md).
"""
import collections
import glob
import os
import re
import subprocess
import sys
import tempfile


def find_ml64():
    hits = sorted(glob.glob(r"C:\Program Files\Microsoft Visual Studio\*\*\VC\Tools\MSVC\*\bin\HostX64\x64\ml64.exe"))
    if not hits:
        sys.exit("ml64.exe not found (is the Visual Studio C++ toolset installed?)")
    return hits[-1]


def listing(asm):
    tmp = tempfile.mkdtemp()
    env = dict(os.environ, MSYS2_ARG_CONV_EXCL="*")  # keep Git Bash from rewriting the /F options
    subprocess.run([find_ml64(), "/nologo", "/c", "/Sg", "/Fo" + os.path.join(tmp, "m.obj"), "/Fl" + os.path.join(tmp, "m.lst"), asm],
                   check=True, capture_output=True, env=env)
    return open(os.path.join(tmp, "m.lst"), encoding="latin-1").read().splitlines()


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    asm = os.path.abspath(sys.argv[1])
    top = int(sys.argv[2]) if len(sys.argv) > 2 else 25
    pat = re.compile(r"^ ([0-9A-F]{8})\s+((?:[0-9A-F]{2}/?\s?)+)\s*(.*)$")
    items = []
    for line in listing(asm):
        m = pat.match(line)
        if m and m.group(3).strip() and not m.group(3).lstrip().startswith(";"):
            items.append((int(m.group(1), 16), m.group(3).strip()))
    per_pattern = collections.Counter()
    count = collections.Counter()
    singles = []
    for (o, t), (o2, _) in zip(items, items[1:]):
        size = o2 - o
        if size <= 0 or size > 16:
            continue
        code = re.sub(r"\s*;.*$", "", t)
        key = re.sub(r"\b(?:[0-9A-F]+h|\d+)\b", "N", code)
        key = re.sub(r"\[[^\]]*\]", "[M]", key)
        per_pattern[key] += size
        count[key] += 1
        singles.append((size, code))
    print(f"Total instruction bytes: {sum(per_pattern.values())}")
    print("\n== Top instruction patterns (total bytes / count) ==")
    for k, v in per_pattern.most_common(top):
        print(f"{v:5d}  x{count[k]:3d}  {k}")
    print("\n== Largest single instructions ==")
    for s, c in sorted(singles, reverse=True)[:top]:
        print(f"{s:3d}  {c}")


main()
