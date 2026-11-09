# QR codes

The QR codes in [`qr/`](../qr) (shown in the [README](../README.md)) contain a complete PowerShell script that unpacks and
starts the EXE. They are made by `tools/qr/qr_generator.py`, which `tools/build.py` calls for you.

## Size budget

- QR version 40, error correction level L, byte mode: **2953 bytes**.
- Payload = script text + Base64(compressed EXE). Base64 costs 4/3, so the compressed EXE may be about
  `(2953 - script length) / 4 * 3` bytes: for a 450 character script about 1870 bytes.
- Everything is measured on the *compressed* size; zeros and padding in the EXE are nearly free.
- Zopfli (`pip install zopfli`) gives about 40 bytes less than zlib level 9 and is used automatically when installed.

## The two variants

| | Full | Minimal |
|---|---|---|
| Files | `qr_full.png` / `qr_full.ps1` | `qr_min.png` / `qr_min.ps1` |
| Container | zip (`Expand-Archive`) | raw deflate (`DeflateStream`), no container |
| Script | readable, several lines, with instructions | one line, only comments before/after |
| Files created at run time | `%TEMP%\M_105HDGDL69\M.exe` (the temporary `z.zip` is deleted again) | `%TEMP%\M.exe` only |
| Starts the EXE | yes (`Start-Process`) | yes (`&$f`) |

Both are plug and play: copy the text, paste it into PowerShell, press Enter. The EXE stays in `%TEMP%` because it is running
(a running EXE can not delete itself). The `.ps1` files contain exactly the text that is in the QR code.

The minimal script (`$f` is the target file):

```powershell
$f="$env:temp\M.exe";$o=[IO.File]::Create($f);(New-Object IO.Compression.DeflateStream([IO.MemoryStream][Convert]::FromBase64String('...'),[IO.Compression.CompressionMode]0)).CopyTo($o);$o.Close();&$f
```

`CompressionMode` 0 is *Decompress*; the explicit enum cast is required, because a bare `0` is an ambiguous overload in
Windows PowerShell 5.1.

Which variant goes into `qr/` and the README: the full variant if it fits, else the minimal one. Currently the 32 bit version uses the
full variant, the 64 bit version the minimal one (its full variant is too large).

## Changing the texts

All texts are at the top of `tools/qr/qr_generator.py` under **SETTINGS**:

| Setting | Meaning |
|---|---|
| `VARIANT` | which variant(s) to generate by default (`both`, `full`, `min`) |
| `MIN_TEXT_BEFORE`, `MIN_TEXT_AFTER` | text before/after the script of the minimal variant (becomes `#` comment lines) |
| `FULL_TEXT_BEFORE`, `FULL_TEXT_AFTER` | instructions / closing line of the full variant |
| `FULL_SANDBOX_DIR` | sub folder in `%TEMP%` of the full variant |

The same can be overridden for one run with `--before` / `--after` (minimal variant). Use ASCII only, every byte counts; the generator
prints how many bytes are still free. The 64 bit version has almost no reserve left, so longer texts only fit after the EXE
becomes smaller. Texts are the same for the 32 and 64 bit QR code; the 64 bit window title explains its own keys.

## Verification

`tools/build.py` does not trust the generator: it reads every PNG back with `pyzbar` and compares the text with the `.ps1`, then
really executes the script from the QR code in PowerShell and checks that the unpacked EXE is identical to the built one, that
a window appears, that something is drawn, that the window title reacts to the keys (64 bit) and that the window closes.
Only then the images are copied to `qr/`.
