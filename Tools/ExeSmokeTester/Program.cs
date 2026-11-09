using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Threading;

// ExeSmokeTester <exe> <outDir> [refDir]
// Startet die EXE, fuehrt ein festes Szenario aus (Tasten, Mausposition, Zoom) und speichert je Schritt einen Screenshot.
// Mit refDir werden die Screenshots pixelgenau gegen eine Referenz (z.B. unveraenderte EXE) verglichen. Exitcode 0 = OK.
if (args.Length < 2) { Console.Error.WriteLine("Verwendung: ExeSmokeTester <exe> <outDir> [refDir]"); return 2; }
var exe = Path.GetFullPath(args[0]);
var outDir = Path.GetFullPath(args[1]);
var refDir = args.Length > 2 ? Path.GetFullPath(args[2]) : null;
Directory.CreateDirectory(outDir);

var steps = new List<(string name, Action<IntPtr> act)>
{
    ("00_start", h => { }),
    ("01_iter1000", h => Key(h, '3')),
    ("02_block1", h => Key(h, '6')),
    ("03_block4", h => Key(h, '8')),
    ("04_iter100", h => Key(h, '2')),
    ("05_zoomin1", h => { Move(h, 300, 200); Wheel(h, 120); }),
    ("06_zoomin2", h => { Move(h, 500, 400); Wheel(h, 120); }),
    ("07_zoomin3", h => Wheel(h, 120)),
    ("08_zoomin4", h => Wheel(h, 120)),
    ("09_zoomout", h => Wheel(h, -120)),
    ("10_zoomin_many", h => { for (var i = 0; i < 6; i++) { Wheel(h, 120); Thread.Sleep(700); } }),
    ("11_iter1000", h => Key(h, '3')),
};

var failures = 0;
var proc = Process.Start(new ProcessStartInfo(exe) { UseShellExecute = false, WorkingDirectory = Path.GetDirectoryName(exe) });
try
{
    var hwnd = FindWindow(proc.Id, 8000);
    if (hwnd == IntPtr.Zero) { Console.WriteLine("FAIL: kein Fenster"); return 1; }
    SetWindowPos(hwnd, (IntPtr)(-1), 100, 50, 0, 0, 0x0001 | 0x0040); // HWND_TOPMOST, damit der Screenshot nicht von anderen Fenstern verdeckt wird
    SetForegroundWindow(hwnd);
    Thread.Sleep(2500);
    foreach (var (name, act) in steps)
    {
        act(hwnd);
        Thread.Sleep(2500);
        var bmp = Capture(hwnd);
        var file = Path.Combine(outDir, name + ".png");
        bmp.Save(file, ImageFormat.Png);
        string verdict = "saved";
        if (refDir != null)
        {
            var refFile = Path.Combine(refDir, name + ".png");
            if (!File.Exists(refFile)) verdict = "NO-REF";
            else
            {
                using (var r = new Bitmap(refFile))
                {
                    var diff = Diff(bmp, r);
                    verdict = diff == 0 ? "identical" : "DIFF " + diff + " px";
                    if (diff != 0) failures++;
                }
            }
        }
        Console.WriteLine($"{name}: {verdict}");
        bmp.Dispose();
    }
    PostMessage(hwnd, 0x10, IntPtr.Zero, IntPtr.Zero);
    if (!proc.WaitForExit(3000)) Console.WriteLine("Hinweis: Prozess beendet sich nicht auf WM_CLOSE (DefWindowProc -> DestroyWindow -> WM_DESTROY erwartet)");
}
finally { if (!proc.HasExited) proc.Kill(); }
Console.WriteLine(failures == 0 ? "OK" : "FAILURES: " + failures);
return failures == 0 ? 0 : 1;

static void Key(IntPtr h, char c) => PostMessage(h, 0x100, (IntPtr)c, IntPtr.Zero);
static void Move(IntPtr h, int x, int y) => PostMessage(h, 0x200, IntPtr.Zero, (IntPtr)((y << 16) | x));
static void Wheel(IntPtr h, int delta) => PostMessage(h, 0x20A, (IntPtr)(delta << 16), IntPtr.Zero);

static long Diff(Bitmap a, Bitmap b)
{
    if (a.Width != b.Width || a.Height != b.Height) return long.MaxValue;
    long n = 0;
    for (var y = 0; y < a.Height; y++) for (var x = 0; x < a.Width; x++) if ((a.GetPixel(x, y).ToArgb() & 0xFFFFFF) != (b.GetPixel(x, y).ToArgb() & 0xFFFFFF)) n++;
    return n;
}

static IntPtr FindWindow(int pid, int timeoutMs)
{
    var end = DateTime.UtcNow.AddMilliseconds(timeoutMs); IntPtr result = IntPtr.Zero;
    while (DateTime.UtcNow < end && result == IntPtr.Zero)
    {
        EnumWindows((h, _) => { uint id; GetWindowThreadProcessId(h, out id); if (id == pid && IsWindowVisible(h)) { result = h; return false; } return true; }, IntPtr.Zero);
        Thread.Sleep(50);
    }
    return result;
}

static Bitmap Capture(IntPtr hwnd)
{
    RECT c; GetClientRect(hwnd, out c);
    POINT p = new POINT(); ClientToScreen(hwnd, ref p);
    var w = c.Right - c.Left; var h = c.Bottom - c.Top;
    var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
    using (var g = Graphics.FromImage(bmp)) g.CopyFromScreen(p.X, p.Y, 0, 0, new Size(w, h));
    return bmp;
}

[DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc cb, IntPtr extra);
[DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
[DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
[DllImport("user32.dll")] static extern bool GetClientRect(IntPtr hwnd, out RECT rect);
[DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr hwnd, ref POINT p);
[DllImport("user32.dll")] static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr w, IntPtr l);
[DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr hwnd);
[DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr hwnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr extra);
struct POINT { public int X, Y; }
struct RECT { public int Left, Top, Right, Bottom; }
