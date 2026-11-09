"""Zeigt, welche Befehle von main64.asm wie viele Bytes Maschinencode erzeugen.

Verwendung:  python asm_size_report.py <datei.asm> [Top-N]
Ruft ml64 mit Listing (/Fl /Sg) auf und summiert die Befehlslaengen je Mnemonic-Muster.
"""
import os, re, subprocess, sys, tempfile, collections

ML64 = r"C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.44.35207\bin\HostX64\x64\ml64.exe"


def listing(asm):
    tmp = tempfile.mkdtemp()
    env = dict(os.environ, MSYS2_ARG_CONV_EXCL="*")
    subprocess.run([ML64, "/nologo", "/c", "/Sg", "/Fo" + os.path.join(tmp, "m.obj"), "/Fl" + os.path.join(tmp, "m.lst"), asm],
                   check=True, capture_output=True, env=env)
    name = "m.lst"
    return open(os.path.join(tmp, name), encoding="latin-1").read().splitlines()


def main():
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
    print(f"Summe Befehle: {sum(per_pattern.values())} Bytes")
    print("\n== Top Befehlsmuster (Bytes gesamt / Anzahl) ==")
    for k, v in per_pattern.most_common(top):
        print(f"{v:5d}  x{count[k]:3d}  {k}")
    print("\n== Groesste Einzelbefehle ==")
    for s, c in sorted(singles, reverse=True)[:top]:
        print(f"{s:3d}  {c}")


main()
