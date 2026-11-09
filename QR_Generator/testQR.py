import os
import sys
from PIL import Image
from pyzbar.pyzbar import decode

# Usage: python testQR.py [png ...]
# Reads each QR code and, if the matching .ps1 (written by generator.py) exists, checks that the QR content is identical to it.
here = os.path.dirname(os.path.abspath(__file__))
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
explicit = bool(sys.argv[1:])
files = sys.argv[1:] or [os.path.join(here, "QR.png"), os.path.join(here, "QR_min.png")]
ok = True

for png in files:
    if not os.path.exists(png):
        print(f"{'❌' if explicit else 'ℹ️'} '{png}' nicht gefunden (Variante zu gross oder generator.py noch nicht gelaufen).")
        ok &= not explicit
        continue
    objects = decode(Image.open(png))
    if not objects:
        print(f"❌ {png}: kein QR-Code gefunden oder beschaedigt.")
        ok = False
        continue
    text = objects[0].data.decode("utf-8")
    ps1 = os.path.splitext(png)[0] + ".ps1"
    if os.path.exists(ps1):
        same = text == open(ps1, encoding="utf-8", newline="").read()
        ok &= same
        print(f"{'✅' if same else '❌'} {png}: {len(text)} Zeichen, {'identisch mit' if same else 'ABWEICHEND von'} {os.path.basename(ps1)}")
    else:
        print(f"ℹ️ {png}: {len(text)} Zeichen gelesen (keine .ps1 zum Vergleich)")

sys.exit(0 if ok else 1)
