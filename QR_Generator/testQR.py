import os
from PIL import Image
from pyzbar.pyzbar import decode

# Dateiname des zu lesenden QR-Codes
png_input_filename = "./QR.png"

if not os.path.exists(png_input_filename):
    print(f"❌ Fehler: Die Datei '{png_input_filename}' wurde nicht gefunden.")
    print("Bitte stelle sicher, dass das erste Skript das PNG bereits generiert hat.")
else:
    print(f"🔍 Öffne Bilddatei '{png_input_filename}'...")
    
    try:
        # 1. Bild mit Pillow laden
        img = Image.open(png_input_filename)
        
        # 2. QR-Code decodieren
        print("Scanning QR-Code (Version 40)...")
        decoded_objects = decode(img)
        
        if not decoded_objects:
            print("❌ Kein QR-Code im Bild gefunden oder der Code ist beschädigt.")
        else:
            # 3. Inhalt auslesen (Es könnte theoretisch mehr als ein Code im Bild sein)
            for obj in decoded_objects:
                # Die Rohdaten liegen als Bytes vor und müssen decodiert werden
                qr_text = obj.data.decode('utf-8')
                
                print("\n" + "="*50)
                print("🎉 QR-CODE ERFOLGREICH GELESEN!")
                print("="*50)
                print("\n--- Angezeigter Inhalt / Befehl ---")
                print(qr_text)
                print("="*50)
                
                # Optionale Statistik
                print(f"\n📊 Extrahierte Datenlänge: {len(qr_text)} Zeichen.")
                
    except Exception as e:
        print(f"❌ Ein Fehler ist aufgetreten: {e}")
