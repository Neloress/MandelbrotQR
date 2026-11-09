# Size optimization

The goal of the project: the whole program must fit into **one QR code** (QR version 40, error correction L: 2953 bytes in
byte mode). The QR payload is a PowerShell script plus the Base64 encoded, compressed EXE, so what counts is the **compressed**
size of the EXE (zeros and padding cost almost nothing when compressed), not the file size.

Budget: payload = script text + Base64(deflate(EXE)), Base64 costs 4/3. With the minimal script (about 450 characters including the
texts) the deflated EXE may be at most about 1900-1990 bytes. See [qr-code.md](qr-code.md).

## Results

### 64 bit (128 bit fixed point)

Size of the zipped EXE (deflate level 9, file name `M.exe`), measured after every step. Every step was verified to give
pixel-identical screenshots against the original EXE (`ExeSmokeTester`).

| Step | EXE | Zip (bytes) |
|---|---:|---:|
| Starting point (v1, default linker options) | 7680 | 3229 |
| Linker options: one section, no debug info / manifest / rich header, 64 byte DOS stub | 6144 | 2719 |
| Imports and start-up reduced (see below) | 5120 | 2245 |
| `call` / `ret` instead of `lea r15` + `jmp r15` | 4608 | 2197 |
| `Function_ZoomAxis` (zoom of x and y as one subroutine), `IMAGE_WIDTH/HEIGHT` as `EQU` | 4608 | 2095 |
| Sign-mask peepholes (`btr`/`btc`, `test`+`js`, `shl 1`) | 4608 | 2069 |
| `xor r32`, `Draw` without push/pop and with a pixel pointer | 4608 | 2053 |
| Direct import calls (`call qword ptr [__imp_X]`) instead of thunks | 4096 | 2022 |

After that the window title with the current settings was added (about +125 bytes compressed, since reduced by using lookup
tables instead of a `div` loop); the keys 0-9 now have a built-in explanation, so the text in the QR code can stay short.
Current state: EXE 4608 bytes, raw deflate (Zopfli) about 1980 bytes; the minimal QR variant fits exactly into 2953 bytes
with the default texts. The full variant (with instructions, zip container) is about 320 bytes too large.

Techniques used (all in `Mandelbrot64.asm`):

- **Linker** (`Mandelbrot64.vcxproj`): `/ALIGN:512 /FILEALIGN:512`, `/MERGE:.rdata=.text /MERGE:.data=.text /SECTION:.text,RWE`,
  no debug info, no manifest, no rich header (`/EMITTOOLVERSIONINFO:NO`), 64 byte DOS stub (`dos_stub.bin`), fixed base
  (no ASLR, no relocations), no DEP.
- **Imports removed**: `GetModuleHandleA` (hInstance = NULL), `ExitProcess` (returning from the entry point ends the process),
  `ShowWindow` (`WS_VISIBLE` in the style), `SetFocus`, `TranslateMessage`, `LoadIconA`, `GetClientRect`, `DeleteObject`, `DeleteDC`.
- **Window class and BITMAPINFOHEADER initialised statically** in `.data` (`QWORD OFFSET WndProc`, works because of the fixed base),
  only `hCursor` is stored at run time. The bitmap and its DC are created once in `start`; there is no `WM_SIZE` handler.
- **One permanent call frame** in `start` instead of aligning the stack around every API call.
- **`call`/`ret`** for the math routines instead of a hand-made return register.
- **Shared subroutine** for the zoom of both axes; the axis data of x and y have an identical layout (`AXIS_*` offsets) so
  `[rdi+disp8]` addressing (4 bytes) replaces RIP-relative addressing (7 bytes).
- **Constants as `EQU`**: image size, palette mask.
- **Sign handling without a 64 bit mask**: `mov rax, 8000000000000000h` is 10 bytes; `btr/btc reg, 63`, `test reg, reg` + `js/jns`, `shl reg, 1` are shorter.
- **`xor r32, r32`** instead of `xor r64, r64` (one byte less each).
- **`Draw`**: no push/pop (it is only called from `start`, which saves the registers once), pointer instead of an `imul` per pixel.
- **No import thunks**: `EXTERN __imp_X:QWORD` and `call qword ptr [__imp_X]` skip the 6 byte `jmp [IAT]` thunk per API.

### 32 bit

| | Size |
|---|---:|
| Linker output (`build/32bit/obj/Mandelbrot32.exe`) | 4096 |
| Final EXE after `PostLinkStripper` + `MiniPeLinker` (`build/32bit/Mandelbrot32.exe`) | 3072 |
| Full QR variant (zip + instructions) | 2769 of 2953 bytes |

The shrinking is done by two small tools in the post-build step (see [tools.md](tools.md)):

1. `PostLinkStripper` cuts the MASM/linker debug block `.rdata$zzzdbg` (220 bytes) out of `.text` using the map file.
2. `MiniPeLinker` moves the import section behind the code into a single section, removes imports marked in
   `tools/MiniPeLinker/imports.csv` (the code no longer calls them), and drops the unneeded alignment padding.

Imports that turned out to be unnecessary (checked with an automatic remove-and-test loop): `EndPaint`, `ReleaseDC`,
`TranslateMessage`, `UpdateWindow`, `GetDC`, `DeleteDC`.

Further size targets for the 32 bit EXE (header 512 bytes + imports about 514 bytes stay fixed): 3072 bytes needs about 62 bytes less in
code and data, 2560 bytes about 574 bytes, 2048 bytes about 1086 bytes.

## Ideas that were collected for the code (mostly 32 bit; many are done in the 64 bit version)

Safe instruction shortening (check flags and partial registers each time):

- `mov r, 0` -> `xor r, r` (about 3 bytes each); `cmp r, 0` -> `test r, r`; `add r, 1` -> `inc r`; `sub r, 1` -> `dec r`.
- Keep constants that are loaded many times (`800`, `596`, ...) in a register for the length of a loop.
- Remove unused variables and structures; collapse identical initial values if they are never changed independently.
- Smaller palette (16 DWORDs = 64 bytes; 16 RGB byte triples = 48 bytes; fewer colours); smaller mouse coordinates (WORD) only if
  the extra `movzx` do not cost more than they save.
- `Draw`: compute the pixel address incrementally (pointer + 4 per pixel) instead of multiplying per pixel.
- Special-purpose versions of `MulFint` / `AddF` for call sites where the sign is known (only if the specialised routine is
  smaller than the call overhead).
- `WndProc`: shared `xor eax, eax` / return paths; no jump table (the message numbers are too far apart).
- Debug data: `GenerateDebugInformation=false` for MASM and the linker.

## Open ideas (64 bit)

Roughly in order of expected benefit:

1. **Constant / base registers**: values such as `[a_pixelSize_low]` are RIP-relative (7 bytes per access); a base register with
   `disp8` (4 bytes) may pay off.
2. **x64 PE writer** (a new tool like `MiniPeLinker`): hand-built header with only the import directory, no leftover debug
   directory, imports without `OriginalFirstThunk`/hints, import names ordered so that they compress well. Expected gain 60-150 bytes.
3. **Optional feature cuts** (behaviour changes, only with approval): `EndPaint`, `LoadCursorA`, fewer iteration stages, a smaller palette,
   keeping the `GetIterations` temporaries in registers.
4. **Better compression**: Zopfli is already used; `7-Zip -mx9` could be compared.

## How to measure

- `python tools/build.py 64` prints the EXE size and the QR payload size; the minimal QR variant shows the free bytes.
- `python tools/asm_size_report.py src/64bit/Mandelbrot64.asm 30` shows how many bytes each kind of instruction uses.
- Regression: keep an EXE of the version before your change, create reference screenshots from it
  (`ExeSmokeTester.exe old.exe ref`), then compare the new EXE (`ExeSmokeTester.exe new.exe run ref`, add `--keys0` for the 64 bit key layout).
  Expected: `OK`, all steps `identical`. See [tools.md](tools.md).
- The compressed size is printed by the QR step (`EXE: ... bytes, deflate: ... bytes`), either by `tools/build.py` or by `tools/qr/qr_generator.py`.

## Environment notes

- From Git Bash, MSBuild options need a double slash (`//t:Rebuild`) and `ml64` options must not contain spaces; set `MSYS2_ARG_CONV_EXCL="*"`.
  `tools/build.py` avoids all of this by running everything from Python.
- Fixed base (no ASLR) is required for the static `QWORD OFFSET` entries in `.data`; only tested on Windows 10/11.
- `EndPaint` and `LoadCursorA` stay in for now although they could be removed (it would change the behaviour).
