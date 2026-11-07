import base64
import os
import random
import qrcode

zip_filename = "MandelbrotSet.zip"
png_output_filename = "QR.png"
exe_inside_zip = "MandelbrotSet.exe"

# 1. Plattformübergreifende Anleitung
reader_anleitung = (
    "#:: --- Open on Windows PC ---\n"
    "#:: 1. Copy whole text.\n"
    "#:: 2. Paste into PowerShell.\n"
    "#:: 3. Enjoy Fractals!\n"
    "#:: ---------------\n"
)

if not os.path.exists(zip_filename):
    print(f"❌ Fehler: '{zip_filename}' nicht gefunden.")
else:
    zip_size_bytes = os.path.getsize(zip_filename)
    print(f"📦 Groesse der originalen ZIP-Datei: {zip_size_bytes} Bytes")

    with open(zip_filename, "rb") as f:
        zip_data = f.read()

    b64_zip = base64.b64encode(zip_data).decode('utf-8')

    # Zufälliges Suffix für maximale Sicherheit vor Überschreiben
    suffix = "105HDGDL69"
    sandbox_name = f"M_{suffix}"

    # 2. PURE POWERSHELL SYNTAX WITHOUT WRAPPERS
    # Absolut stabil, keine verschachtelten Anführungszeichen, kein 'powershell -Command'
    final_command = (
        f"{reader_anleitung}"
        f"$d = Join-Path $env:temp '{sandbox_name}';\n"
        f"New-Item -ItemType Directory -Path $d -Force | Out-Null;\n"
        f"$z = Join-Path $d 'z.zip';\n"
        f"[io.file]::WriteAllBytes($z, [Convert]::FromBase64String('{b64_zip}'));\n"
        f"Expand-Archive $z $d -Force;\n"
        f"Remove-Item $z -Force;\n"
        f"cd $d;\n"
        f"Start-Process '.\\{exe_inside_zip}';\n"
        f"exit;\n"
        f"#These are the last possible bytes that fit on the QR-Code. Have a good day!!!\n"
    )

    final_length = len(final_command)
    print(f"📏 Gesamtlaenge für den QR-Code: {final_length} Zeichen / Bytes")

    if final_length <= 2953:
        print(f"✅ Passt perfekt! Restlicher Puffer: {2953 - final_length} Zeichen.")
        
        qr = qrcode.QRCode(
            version=40,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(final_command)
        qr.make(fit=False)

        img = qr.make_image(fill_color="black", back_color="white")
        img.save(png_output_filename)
        
        print(f"💾 Erfolgreich! Der QR-Code wurde als '{png_output_filename}' gespeichert.")
    else:
        print(f"❌ Zu gross um {final_length - 2953} Zeichen.")
