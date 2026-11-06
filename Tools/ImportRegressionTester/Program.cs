using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;

var root = FindRoot();
var asmPath = Path.Combine(root, "SmallASM", "main.asm");
var projectPath = Path.Combine(root, "SmallASM", "SmallASM.vcxproj");
var csvPath = Path.Combine(root, "Tools", "MiniPeLinker", "imports.csv");
var logPath = Path.Combine(root, "Tools", "ImportRegressionTester", "iteration-results.csv");
var msbuildPath = @"C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe";
var source = File.ReadAllText(asmPath);
var candidates = CreateCandidates();
var accepted = ReadAccepted(csvPath);
var original = source;
var iteration = 0;

using (var log = new StreamWriter(logPath, false, Encoding.UTF8))
{
    log.WriteLine("Iteration,Import,Build,Window,ZoomChanged,Closed,Size,Result");
    var changedInPass = true;
    while (changedInPass)
    {
        changedInPass = false;
        iteration++;
        foreach (var candidate in candidates)
        {
            if (accepted.Contains(candidate.Name))
            {
                log.WriteLine($"{iteration},{candidate.Name},SKIP,SKIP,SKIP,SKIP,0,already-removed");
                continue;
            }

            var variant = candidate.Transform(source);
            if (variant == source)
            {
                accepted.Add(candidate.Name);
                log.WriteLine($"{iteration},{candidate.Name},SKIP,SKIP,SKIP,SKIP,0,already-absent");
                continue;
            }

            var result = TestVariant(root, projectPath, variant, msbuildPath);
            var status = result.Build && result.Window && result.ZoomChanged && result.Closed ? "accepted" : "rejected";
            log.WriteLine($"{iteration},{candidate.Name},{result.Build},{result.Window},{result.ZoomChanged},{result.Closed},{result.Size},{status}");
            log.Flush();
            Console.WriteLine($"Iteration {iteration}: {candidate.Name} -> {status}");
            if (status == "accepted")
            {
                source = variant;
                accepted.Add(candidate.Name);
                changedInPass = true;
            }
        }
    }
}

if (source != original) File.WriteAllText(asmPath + ".import-test-backup", original, Encoding.Default);
File.WriteAllText(asmPath, source, Encoding.Default);
UpdateAcceptedCsv(csvPath, accepted);
Console.WriteLine($"Fertig. Iterationen: {iteration}; entfernte Imports: {accepted.Count}; Log: {logPath}");

static List<Candidate> CreateCandidates()
{
    var names = new[] { "BeginPaint", "CreateWindowEx", "DefWindowProc", "DestroyWindow", "DispatchMessage", "EndPaint", "GetClientRect", "GetDC", "GetMessage", "InvalidateRect", "LoadCursor", "LoadIcon", "PostQuitMessage", "RegisterClassEx", "ReleaseDC", "SelectObject", "ShowWindow", "TranslateMessage", "UpdateWindow", "BitBlt", "CreateCompatibleDC", "CreateDIBSection", "DeleteDC" };
    var result = new List<Candidate>();
    foreach (var name in names) result.Add(new Candidate(name, s => TransformImport(s, name)));
    return result;
}

static string TransformImport(string source, string name)
{
    source = source.Replace("\r\n", "\n");
    if (name == "GetDC" || name == "ReleaseDC") return source;
    if (name == "LoadIcon") return ReplaceAny(source, "        push 7F00h", "        push 0", "        call LoadIcon", "        mov dword ptr[ebx+24]", "        mov dword ptr[ebx+44]", "        mov dword ptr[ebx+24] , 0\n        mov dword ptr[ebx+44] , 0");
    if (name == "ShowWindow") source = source.Replace("push 0A0000h             ;WS_OVERLAPPEDWINDOW", "push 100A0000h            ;WS_VISIBLE | WS_OVERLAPPEDWINDOW");
    source = RemoveLines(source, "call " + name).Replace("        invoke  " + name + ", 0, IDC_ARROW\n", "");
    return source;
}

static string ReplaceAny(string source, params string[] parts)
{
    var old = String.Join("\n", parts.Take(parts.Length - 1));
    return source.Replace(old, parts.Last());
}

static string RemoveLines(string source, string token) => String.Join("\n", source.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None).Where(line => !line.Contains(token))) ;

static TestResult TestVariant(string root, string projectPath, string source, string msbuildPath)
{
    var temp = Path.Combine(Path.GetTempPath(), "MandelbrotImportTest_" + Guid.NewGuid().ToString("N"));
    Directory.CreateDirectory(temp);
    try
    {
        var tempProject = Path.Combine(temp, "SmallASM.vcxproj");
        File.Copy(projectPath, tempProject);
        File.WriteAllText(Path.Combine(temp, "main.asm"), source, Encoding.Default);
        var build = Run(msbuildPath, $"\"{tempProject}\" /t:Rebuild /p:Configuration=Release /p:Platform=Win32", temp, 120000);
        if (build.ExitCode != 0) return new TestResult(false, false, false, false, 0);
        var exe = Path.Combine(temp, "Release", "SmallASM.exe");
        var minimizedExe = Path.Combine(temp, "Release", "SmallASM.min.exe");
        var minimizer = Path.Combine(root, "Tools", "MiniPeLinker", "MiniPeLinker.exe");
        var minimized = Run(minimizer, $"\"{exe}\" \"{minimizedExe}\" \"{Path.Combine(root, "Tools", "MiniPeLinker", "imports.csv")}\"", root, 120000);
        if (minimized.ExitCode != 0 || !File.Exists(minimizedExe)) return new TestResult(true, false, false, false, 0);
        using (var process = Process.Start(minimizedExe))
        {
            if (process == null) return new TestResult(true, false, false, false, 0);
            var hwnd = FindWindow(process.Id, 5000);
            if (hwnd == IntPtr.Zero) return new TestResult(true, false, false, false, new FileInfo(minimizedExe).Length);
            Thread.Sleep(1200);
            var before = Capture(hwnd);
            PostMessage(hwnd, 0x020A, new IntPtr(120 << 16), IntPtr.Zero);
            Thread.Sleep(1200);
            var after = Capture(hwnd);
            var changed = before.PixelHash != after.PixelHash && after.DifferentPixels(before) > 10;
            PostMessage(hwnd, 0x0010, IntPtr.Zero, IntPtr.Zero);
            process.WaitForExit(3000);
            var closed = process.HasExited;
            if (!closed) process.Kill();
            return new TestResult(true, true, changed, closed, new FileInfo(minimizedExe).Length);
        }
    }
    finally { try { Directory.Delete(temp, true); } catch { } }
}

static HashSet<string> ReadAccepted(string path)
{
    var result = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    foreach (var line in File.ReadLines(path).Skip(1))
    {
        var fields = line.Split(',');
        if (fields.Length >= 3 && fields[2].Trim().Equals("x", StringComparison.OrdinalIgnoreCase)) result.Add(fields[1].Trim().Replace("A", ""));
    }
    return result;
}

static void UpdateAcceptedCsv(string path, HashSet<string> accepted)
{
    var lines = File.ReadAllLines(path);
    for (var i = 1; i < lines.Length; i++)
    {
        var fields = lines[i].Split(',');
        if (fields.Length >= 3 && accepted.Contains(fields[1].Trim().Replace("A", ""))) fields[2] = "x";
        lines[i] = String.Join(",", fields);
    }
    File.WriteAllLines(path, lines, Encoding.UTF8);
}

static string FindRoot()
{
    var path = AppDomain.CurrentDomain.BaseDirectory;
    while (!String.IsNullOrEmpty(path)) { if (File.Exists(Path.Combine(path, "SmallASM", "SmallASM.vcxproj"))) return path; path = Directory.GetParent(path)?.FullName; }
    throw new DirectoryNotFoundException("Workspace mit SmallASM.vcxproj nicht gefunden.");
}

static ProcessResult Run(string file, string arguments, string workingDirectory, int timeout)
{
    using (var process = Process.Start(new ProcessStartInfo(file, arguments) { WorkingDirectory = workingDirectory, UseShellExecute = false, CreateNoWindow = true }))
    { if (process == null) return new ProcessResult(-1); if (!process.WaitForExit(timeout)) { process.Kill(); return new ProcessResult(-1); } return new ProcessResult(process.ExitCode); }
}

static IntPtr FindWindow(int processId, int timeout)
{
    var end = DateTime.UtcNow.AddMilliseconds(timeout); IntPtr result = IntPtr.Zero;
    while (DateTime.UtcNow < end && result == IntPtr.Zero) { EnumWindows((hwnd, _) => { uint id; GetWindowThreadProcessId(hwnd, out id); if (id == processId && IsWindowVisible(hwnd)) { result = hwnd; return false; } return true; }, IntPtr.Zero); Thread.Sleep(50); }
    return result;
}

static Snapshot Capture(IntPtr hwnd)
{
    RECT rect; GetWindowRect(hwnd, out rect); var width = Math.Max(1, rect.Right - rect.Left); var height = Math.Max(1, rect.Bottom - rect.Top);
    using (var bitmap = new Bitmap(width, height, PixelFormat.Format32bppArgb)) using (var graphics = Graphics.FromImage(bitmap)) { graphics.CopyFromScreen(rect.Left, rect.Top, 0, 0, new Size(width, height)); var data = bitmap.LockBits(new Rectangle(0, 0, width, height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb); var bytes = new byte[Math.Abs(data.Stride) * height]; Marshal.Copy(data.Scan0, bytes, 0, bytes.Length); bitmap.UnlockBits(data); using (var sha = SHA256.Create()) return new Snapshot(sha.ComputeHash(bytes), bytes); }
}

[DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc callback, IntPtr extra);
[DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
[DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr hwnd);
[DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
[DllImport("user32.dll")] static extern bool PostMessage(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam);
delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr extra);
struct RECT { public int Left, Top, Right, Bottom; }
sealed class Candidate { public Candidate(string name, Func<string, string> transform) { Name = name; Transform = transform; } public string Name; public Func<string, string> Transform; }
sealed class ProcessResult { public ProcessResult(int exitCode) { ExitCode = exitCode; } public int ExitCode; }
sealed class TestResult { public TestResult(bool build, bool window, bool zoomChanged, bool closed, long size) { Build = build; Window = window; ZoomChanged = zoomChanged; Closed = closed; Size = size; } public bool Build, Window, ZoomChanged, Closed; public long Size; }
sealed class Snapshot { public Snapshot(byte[] hash, byte[] pixels) { PixelHash = Convert.ToBase64String(hash); Pixels = pixels; } public string PixelHash; public byte[] Pixels; public int DifferentPixels(Snapshot other) { var count = 0; for (var i = 0; i < Math.Min(Pixels.Length, other.Pixels.Length); i += 4) if (Pixels[i] != other.Pixels[i] || Pixels[i + 1] != other.Pixels[i + 1] || Pixels[i + 2] != other.Pixels[i + 2]) count++; return count; } }
