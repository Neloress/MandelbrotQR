# Copilot instructions

## Project guidelines

- Everything is written in **English**: code comments, scripts, documentation.
- `src/64bit/Mandelbrot64.asm` should follow the structure, comments and indentation of `src/32bit/Mandelbrot32.asm` as closely as possible,
  line by line. Differences of the 64 bit version are marked with `;64bit-specific`.
- Generated files only go to `build/` (never committed); the published QR codes go to `qr/`. Do not commit binaries; the C# tools are
  compiled on demand into `build/tools/`.
- After changing code run `python tools/build.py both` (or `build.cmd both`). It must end with `ALL OK` for both versions.
  For size work compare screenshots with `ExeSmokeTester` (see `docs/tools.md`) and log relevant results in `docs/size-optimization.md`.
- Documentation lives in `README.md` (entry point) and `docs/`: `architecture.md`, `size-optimization.md`, `qr-code.md`, `tools.md`.
  Keep it short and update it together with the code.
- Do not create commits unless asked: the repository owner commits changes themselves.

## Where to look first

- Size optimization of the 64 bit version (QR code budget, measurements, open ideas): `docs/size-optimization.md`.
- How the programs work (fixed point math, zoom, controls, register conventions): `docs/architecture.md`.
