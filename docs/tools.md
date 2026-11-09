# Tools

Everything the build and the experiments need lives in `tools/`. The C# tools are **not** stored as binaries: `tools/build.py`
and the 32 bit project compile them on demand with the Roslyn compiler that ships with MSBuild into `build/tools/`.

## `tools/build.py` (and `build.cmd`)

The automatic pipeline: build -> shrink -> generate QR code -> read it back -> run the script from the QR code and verify the EXE -> publish.

```
build.cmd                         asks 32 / 64 / both
build.cmd 64                      one version (python tools/build.py 64 does the same)
python tools/build.py both        both versions
```

| Option | Meaning |
|---|---|
| `--variant both\|full\|min` | which QR variant(s) (default both) |
| `--before TEXT` / `--after TEXT` | text before/after the script of the minimal variant (default: see `qr_generator.py`) |
| `--skip-build` | use the existing EXE instead of building |
| `--no-run` | do not start the EXE (nothing is published either) |
| `--no-publish` | do not update `qr/` |

Output (same layout for both versions): `build/<bits>bit/Mandelbrot<bits>.exe`, intermediate files in `build/<bits>bit/obj/`,
generated QR codes in `build/<bits>bit/qr/`. On success the best variant is copied to `qr/mandelbrot<bits>.png|.ps1`.
Exit code `0` = everything OK, `1` = at least one error (marked with a cross in the final list). The check of the running EXE
needs a visible desktop and the window must not be covered (it is briefly brought to the front).

## `tools/qr/qr_generator.py`

EXE -> QR code, two variants. Details and settings: [qr-code.md](qr-code.md).

```
python tools/qr/qr_generator.py build/64bit/Mandelbrot64.exe --variant min --out-dir build/qr
```

## `tools/ExeSmokeTester` (C#)

Screenshot regression test for any EXE. It starts the EXE (window moved to a fixed position, topmost), runs a fixed scenario
(keys, mouse position, wheel zoom) and saves one PNG of the client area per step. With a reference folder the PNGs are compared
pixel by pixel.

```
build\tools\ExeSmokeTester.exe <exe> <outDir> [refDir] [--keys0]
```

Typical use when changing code that must not change the picture:

1. Build the *unchanged* version and make the reference: `ExeSmokeTester.exe old.exe ref`
2. Build your change and compare: `ExeSmokeTester.exe new.exe run ref` -> expected `OK`, every step `identical` (takes about 40 s).

`--keys0` maps the scenario's keys to the 64 bit layout (every key minus 1; the scenario is written for the older layout 1-5 / 6-9).
The tool is compiled by `tools/build.py` (or manually: `csc /target:exe /r:System.Drawing.dll /out:build\tools\ExeSmokeTester.exe tools\ExeSmokeTester\Program.cs`).

## `tools/PostLinkStripper` (C#, 32 bit)

`PostLinkStripper <in.exe> <out.exe> <map>`: removes the `.rdata$zzzdbg` block (linker/MASM debug data) from `.text`, using the
addresses from the linker map file. Run automatically in the post-build step of `Mandelbrot32.vcxproj`.

## `tools/MiniPeLinker` (C#, 32 bit)

`MiniPeLinker <in.exe> <out.exe> [imports.csv]`: minimizer for the PE32 file with exactly two sections (`.text`, `.idata`).

- moves the import section behind the code and merges everything into one section (import RVAs, IAT RVAs and the absolute IAT
  references in the x86 code are fixed up),
- removes the alignment padding at the end,
- reads `imports.csv` (`Dll,Import,Remove,Reason`): an `x` in `Remove` marks an import that the code no longer uses; the tool aborts if
  a marked import is still present in the input (instead of producing an EXE that might not start),
- aborts on any other section layout.

The BSS relocation is currently not active, because the bounds can not be determined reliably from the PE header with this linker layout.
Run automatically in the post-build step of `Mandelbrot32.vcxproj`; the 64 bit version is shrunk by linker options only.

## `tools/asm_size_report.py`

`python tools/asm_size_report.py src/64bit/Mandelbrot64.asm [top-N]`: runs `ml64` with a listing and shows how many bytes each kind of
instruction produces. Used to decide which size optimization is worth doing ([size-optimization.md](size-optimization.md)).
