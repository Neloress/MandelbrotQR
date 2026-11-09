# Architecture

How the two programs work. The 64 bit version is a line-by-line relative of the 32 bit version (same structure, same comments);
everything that differs is marked `;64bit-specific` in `src/64bit/Mandelbrot64.asm`.

## Program flow

1. `start` / `WinMain` registers a window class and creates the window (800x600). A 32 bit DIB section (800x608 pixels,
   bottom-up) is created once; the program draws into it and the window only blits it (`WM_PAINT` -> `BitBlt`).
2. The message loop (`GetMessage` / `DispatchMessage`) runs; the window procedure `WndProc` only records what happened
   (`a_mousePos_*` on mouse move, `a_mouseWheel_state` on wheel, key presses) and sets the flag `a_enable_draw`.
3. After each dispatched message, if `a_enable_draw` is set, the main loop applies the zoom (mouse wheel), calls `Draw`
   and `InvalidateRect`, so the window repaints from the finished bitmap.
4. Closing the window (`WM_CLOSE` -> `DefWindowProc` -> `WM_DESTROY`) calls `PostQuitMessage`.

## Fixed point numbers

There is no floating point and no `div`. All coordinates are sign-magnitude fixed point numbers:

| Version | Layout | Registers |
|---|---|---|
| 32 bit | 1 sign bit, 5 integer bits, 26 fraction bits (`S?????.??????...`) in one DWORD | 1 register |
| 64 bit | 1 sign bit, 5 integer bits, **122** fraction bits in a *high* QWORD (sign, integer, upper fraction) and a *low* QWORD (rest of the fraction) | 2 registers |

Routines (all internal, not the Windows ABI; the register convention is at the top of `Mandelbrot64.asm`):

| Routine | Purpose |
|---|---|
| `MulF` | fixed point x fixed point. 64 bit: four 64x64 multiplications (`mul`), the 256 bit product is shifted back to the 1/5/122 format |
| `MulFint` | fixed point x integer (used for `pixel * pixelSize`) |
| `AddF` | signed addition/subtraction (handles all sign combinations by comparing magnitudes) |
| `GetIterations` | escape-time iteration `z = z^2 + c` until `|z|^2 > 4` or the maximum iteration count; returns -1 for "inside" |
| `Draw` | for every pixel block: coordinate = `lowerLeft + position * pixelSize`, iterations, palette colour, fill the block |
| `ZoomAxis` (64 bit) | zoom and bounds for one axis; x and y have identical layouts so the same routine is called twice. In the 32 bit version this code exists twice |

In `GetIterations` all intermediate values stay in registers or on the stack; no division is needed anywhere, including the
window title of the 64 bit version (see below).

## Zoom

The mouse wheel zooms around the mouse position: the real position under the mouse must stay the same.

```
lowerLeft_old + pixelSize_old * mousePos = lowerLeft_new + pixelSize_new * mousePos
lowerLeft_new = lowerLeft_old + (pixelSize_old - pixelSize_new) * mousePos
```

Bounds: `pixelSize` is limited to a maximum (whole set visible) and to a minimum (the precision of the number format).
If the new view would leave the initial region, it is shifted back: `shiftVal = (lowerLeft_new + imageSize * pixelSize_new) - upperRight_max`,
and the lower left corner is moved by `-shiftVal` when that is positive; the lower left corner itself is limited to its minimum.
Wheel up zooms in, wheel down zooms out.

## Controls and window title (64 bit)

| Keys | Effect | Values |
|---|---|---|
| `0` - `4` | maximum iterations | 10, 100, 1000, 10000, 100000 |
| `5` - `9` | pixel block size (pixels drawn together) | 1, 2, 4, 8, 16 |
| mouse wheel | zoom | |

The window title always shows the current values: `Mandelbrot set | Keys 5-9: Pixel size  4 | Keys 0-4: Iterations 10`.
It is built without any arithmetic:

- The title text is a buffer in `.data` that is also used as `lpWindowName` for `CreateWindowEx` (so its initial content must match
  the initial values).
- Lookup tables with the *text* of every value (`a_iteration_title_lookup`, 8 bytes per entry incl. terminator;
  `a_pixelBlockSize_title_lookup`, exactly 2 characters per entry) have the same indices as the value tables. A key press copies
  one table entry into the buffer with a single `mov`.
- The pixel size has a fixed width of 2 characters (right aligned) and the iterations are the last part of the title, so no text ever has to move.
- `WM_SETTEXT` is sent through the already imported `DefWindowProcA`, so no extra import is needed.

The 32 bit version only has the mouse wheel and a fixed title.

## Colours

`COLOUR_MODE` (assembler constant, default 16) selects a palette with 16, 32, 64 or 128 entries. The colour index is
`iterations AND mask`. Inside pixels are black. See the top of the `.asm` files.

## Startup shortcuts of the 64 bit version

These are only possible because the program is tiny and always runs as an ordinary process; they are listed here because they are
the first suspects if it ever misbehaves on another machine:

- Returning from the entry point ends the process (no `ExitProcess` call).
- `hInstance` is `NULL` for `RegisterClassEx` / `CreateWindowEx` (accepted for the own process).
- The image is linked at a fixed base without ASLR (`/FIXED`, no relocations), because `WNDCLASSEXA` is initialised statically in `.data`
  with absolute addresses (`QWORD OFFSET WndProc`).
- The stack is aligned once in `start` (7 saved registers + 2 zeroed stack parameters + 32 byte shadow space = a permanent call frame);
  `Draw` and the math routines make no API calls and need no alignment.
- The message loop has no `TranslateMessage`; `WM_KEYDOWN` is handled directly (virtual key codes of `0`-`9`).
