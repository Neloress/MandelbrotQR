using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

if (args.Length != 3)
{
    Console.Error.WriteLine("Verwendung: PostLinkStripper <input.exe> <output.exe> <map> ");
    Environment.Exit(2);
}

var inputPath = Path.GetFullPath(args[0]);
var outputPath = Path.GetFullPath(args[1]);
var mapPath = Path.GetFullPath(args[2]);
var image = File.ReadAllBytes(inputPath);
var map = File.ReadAllLines(mapPath);
var debugBlock = ReadMapBlock(map, ".rdata$zzzdbg");
var pe = Pe.Read(image);
var text = pe.Sections.Single(x => x.Name == ".text");
debugBlock = new MapBlock(text.VirtualAddress + debugBlock.Start, debugBlock.Length);

if (debugBlock.Start < text.VirtualAddress || debugBlock.Start + debugBlock.Length > text.VirtualAddress + text.VirtualSize)
    throw new InvalidDataException("Der Debugblock liegt nicht innerhalb von .text.");

var removeStart = checked((int)(text.PointerToRawData + debugBlock.Start - text.VirtualAddress));
var removeLength = checked((int)debugBlock.Length);
var oldEnd = checked((int)(text.PointerToRawData + text.VirtualSize));
if (removeStart + removeLength > oldEnd)
    throw new InvalidDataException("Der Debugblock liegt außerhalb der physischen .text-Daten.");

var result = new byte[image.Length];
Array.Copy(image, 0, result, 0, removeStart);
Array.Copy(image, removeStart + removeLength, result, removeStart, oldEnd - removeStart - removeLength);
Array.Clear(result, oldEnd - removeLength, removeLength);
Array.Copy(image, oldEnd, result, oldEnd, image.Length - oldEnd);

var delta = -removeLength;
var rvaStart = debugBlock.Start;
var rvaEnd = checked(debugBlock.Start + debugBlock.Length);
PatchHeader(result, pe, rvaStart, rvaEnd, delta);
PatchSection(result, pe, text, removeLength);
PatchAbsoluteReferences(result, pe, text, imageBase: pe.ImageBase, rvaEnd,
    text.VirtualAddress + text.VirtualSize, delta);

var directory = Path.GetDirectoryName(outputPath);
if (!String.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
File.WriteAllBytes(outputPath, result);
Console.WriteLine($"Entfernt: {removeLength:N0} Bytes .rdata$zzzdbg");
Console.WriteLine($"Ausgabe: {result.Length:N0} Bytes");

static MapBlock ReadMapBlock(string[] lines, string name)
{
    foreach (var line in lines)
    {
        var match = System.Text.RegularExpressions.Regex.Match(line, @"^\s*0001:([0-9A-Fa-f]{8})\s+([0-9A-Fa-f]+)H\s+" + System.Text.RegularExpressions.Regex.Escape(name) + @"\s+");
        if (match.Success)
            return new MapBlock(Convert.ToUInt32(match.Groups[1].Value, 16), Convert.ToUInt32(match.Groups[2].Value, 16));
    }
    throw new InvalidDataException($"Map-Bereich nicht gefunden: {name}");
}

static void PatchHeader(byte[] image, Pe pe, uint start, uint end, int delta)
{
    var entryPointOffset = pe.OptionalOffset + 16;
    WriteUInt32(image, entryPointOffset, Translate(ReadUInt32(image, entryPointOffset), end,
        uint.MaxValue, delta));

    for (var i = 0; i < pe.DataDirectoryCount; i++)
    {
        var offset = pe.OptionalOffset + 96 + i * 8;
        var rva = ReadUInt32(image, offset);
        WriteUInt32(image, offset, Translate(rva, start, end, delta));
    }

    var debugDirectoryOffset = pe.OptionalOffset + 96 + 6 * 8;
    WriteUInt32(image, debugDirectoryOffset, 0);
    WriteUInt32(image, debugDirectoryOffset + 4, 0);
}

static void PatchSection(byte[] image, Pe pe, Section text, int removed)
{
    var sectionHeader = pe.SectionTable + text.Index * 40;
    WriteUInt32(image, sectionHeader + 8, text.VirtualSize - (uint)removed);
    WriteUInt32(image, sectionHeader + 16, text.RawSize);
    WriteUInt32(image, pe.OptionalOffset + 56, Align(text.VirtualAddress + text.VirtualSize - (uint)removed, pe.SectionAlignment));

}

static void PatchAbsoluteReferences(byte[] image, Pe pe, Section text, uint imageBase, uint start, uint end, int delta)
{
    var startOffset = checked((int)text.PointerToRawData);
    var endOffset = Math.Min(image.Length, checked(startOffset + (int)text.VirtualSize - (-delta)));
    for (var i = startOffset; i + 4 <= endOffset; i++)
    {
        var value = ReadUInt32(image, i);
        if (value >= imageBase + start && value < imageBase + end)
            WriteUInt32(image, i, unchecked((uint)((int)value + delta)));
    }
}

static uint Translate(uint value, uint start, uint end, int delta) =>
    value >= start && value < end ? unchecked((uint)((int)value + delta)) : value;
static uint Align(uint value, uint alignment) => (value + alignment - 1) / alignment * alignment;
static uint ReadUInt32(byte[] data, int offset) => BitConverter.ToUInt32(data, offset);
static void WriteUInt32(byte[] data, int offset, uint value) => Array.Copy(BitConverter.GetBytes(value), 0, data, offset, 4);

sealed class MapBlock
{
    public MapBlock(uint start, uint length) { Start = start; Length = length; }
    public uint Start { get; }
    public uint Length { get; }
}

sealed class Pe
{
    public int OptionalOffset { get; private set; }
    public int SectionTable { get; private set; }
    public uint ImageBase { get; private set; }
    public uint FileAlignment { get; private set; }
    public uint SectionAlignment { get; private set; }
    public uint DataDirectoryCount { get; private set; }
    public List<Section> Sections { get; private set; } = new List<Section>();

    public static Pe Read(byte[] image)
    {
        if (ReadUInt16(image, 0) != 0x5A4D) throw new InvalidDataException("Keine MZ-Datei.");
        var peOffset = checked((int)ReadUInt32(image, 0x3C));
        if (ReadUInt32(image, peOffset) != 0x4550) throw new InvalidDataException("Kein PE-Header.");
        var sectionCount = ReadUInt16(image, peOffset + 6);
        var optionalOffset = peOffset + 24;
        var sectionTable = optionalOffset + ReadUInt16(image, peOffset + 20);
        var sections = new List<Section>();
        for (var i = 0; i < sectionCount; i++)
        {
            var offset = sectionTable + i * 40;
            var name = Encoding.ASCII.GetString(image, offset, 8).TrimEnd('\0');
            sections.Add(new Section(i, name, ReadUInt32(image, offset + 8), ReadUInt32(image, offset + 12), ReadUInt32(image, offset + 16), ReadUInt32(image, offset + 20)));
        }
        return new Pe
        {
            OptionalOffset = optionalOffset,
            SectionTable = sectionTable,
            ImageBase = ReadUInt32(image, optionalOffset + 28),
            FileAlignment = ReadUInt32(image, optionalOffset + 36),
            SectionAlignment = ReadUInt32(image, optionalOffset + 32),
            DataDirectoryCount = ReadUInt32(image, optionalOffset + 92),
            Sections = sections
        };
    }

    private static ushort ReadUInt16(byte[] data, int offset) => BitConverter.ToUInt16(data, offset);
    private static uint ReadUInt32(byte[] data, int offset) => BitConverter.ToUInt32(data, offset);
}

sealed class Section
{
    public Section(int index, string name, uint virtualSize, uint virtualAddress, uint rawSize, uint pointerToRawData)
    {
        Index = index;
        Name = name;
        VirtualSize = virtualSize;
        VirtualAddress = virtualAddress;
        RawSize = rawSize;
        PointerToRawData = pointerToRawData;
    }

    public int Index { get; }
    public string Name { get; }
    public uint VirtualSize { get; }
    public uint VirtualAddress { get; }
    public uint RawSize { get; }
    public uint PointerToRawData { get; }
}
