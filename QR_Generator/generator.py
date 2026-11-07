import base64
import os
import qrcode

zip_filename = "MandelbrotSet.zip"
png_output_filename = "QR.png"
exe_inside_zip = "MandelbrotSet.exe"  # Name deiner EXE in der ZIP

# 1. Anleitung mit plattformübergreifenden Kommentar-Präfixen (#::)
reader_anleitung = (
    "#:: --- ANLEITUNG ---\n"
    "#:: 1. Kopiere diesen gesamten Text.\n"
    "#:: 2. Oeffne die Windows Eingabeaufforderung (cmd) oder die PowerShell.\n"
    "#:: 3. Fuege den Text ein.\n"
    "#:: Die Anwendung entpackt sich und schliesst dieses Fenster automatisch.\n"
    "#:: -----------------\n"
)

if not os.path.exists(zip_filename):
    print(f"❌ Fehler: '{zip_filename}' nicht gefunden.")
else:
    zip_size_bytes = os.path.getsize(zip_filename)
    print(f"📦 Groesse der originalen ZIP-Datei: {zip_size_bytes} Bytes")

    with open(zip_filename, "rb") as f:
        zip_data = f.read()

    b64_string = base64.b64encode(zip_data).decode('utf-8')

    # 2. Die finale String-Zusammensetzung mit automatischem Enter + Exit
    # Durch das '\n' am Ende der powershell-Zeile wird diese sofort getriggert.
    # Danach wird 'exit\n' eingelesen, was das Terminal sofort schließt.
    final_command = (
        f"{reader_anleitung}"
        f"powershell -Command \""
        f"[IO.File]::WriteAllBytes('MandelbrotSet.zip',[Convert]::FromBase64String('{b64_string}')); "
        f"Expand-Archive MandelbrotSet.zip . -Force; del MandelbrotSet.zip\"\n"
        f"exit\n"
    )

    final_length = len(final_command)
    print(f"📏 Gesamtlaenge für den QR-Code: {final_length} Zeichen / Bytes")

    # 3. QR-Code-Generierung als PNG (Version 40, Error Correction L für maximalen Speicher)
    if final_length <= 2953:
        print(f"✅ Passt! Restlicher Puffer: {2953 - final_length} Zeichen.")
        
        print("🎨 Generiere QR-Code-Bild...")
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
        print(f"❌ Zu groess für einen QR-Code! Limit ueberschritten um {final_length - 2953} Zeichen.")
