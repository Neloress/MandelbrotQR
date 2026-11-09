using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;

if (args.Length < 2 || args.Length > 3)
{
    Console.Error.WriteLine("Usage: MiniPeLinker <input.exe> <output.exe> [imports.csv]");
    Environment.Exit(2);
}

var inputPath = Path.GetFullPath(args[0]);
var outputPath = Path.GetFullPath(args[1]);
var selectionPath = args.Length == 3
    ? Path.GetFullPath(args[2])
    : Path.Combine(AppContext.BaseDirectory, "imports.csv");
var image = File.ReadAllBytes(inputPath);
var selectedImports = ImportSelection.Read(selectionPath);
ImportSelection.ValidateAbsent(image, selectedImports);
var minimized = PeMinimizer.TryMinimize(image, out var minimizedImage, out var minimizeError)
    ? minimizedImage
    : image;
if (!String.IsNullOrEmpty(minimizeError))
    Console.Error.WriteLine($"MiniPeLinker fallback: {minimizeError}");

var directory = Path.GetDirectoryName(outputPath);
if (!String.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
File.WriteAllBytes(outputPath, minimized);

Console.WriteLine($"Input  : {image.Length:N0} bytes");
Console.WriteLine($"Output : {minimized.Length:N0} bytes");
Console.WriteLine($"CSV     : {selectionPath}");
Console.WriteLine($"Marked for removal: {selectedImports.Count:N0}");

static class ImportSelection
{
    public static List<string> Read(string path)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("Import CSV not found.", path);
        var selected = new List<string>();
        foreach (var line in File.ReadLines(path).Skip(1))
        {
            if (String.IsNullOrWhiteSpace(line)) continue;
            var fields = line.Split(',');
            if (fields.Length >= 3 && fields[2].Trim().Equals("x", StringComparison.OrdinalIgnoreCase))
                selected.Add(fields[1].Trim());
        }
        return selected;
    }

    public static void ValidateAbsent(byte[] image, List<string> selected)
    {
        var text = Encoding.ASCII.GetString(image);
        var stillPresent = selected.Where(text.Contains).ToList();
        if (stillPresent.Count != 0)
            throw new InvalidDataException("These imports are marked for removal but are still in the EXE: " + String.Join(", ", stillPresent));
    }
}

static class PeMinimizer
{
    private const int SectionSize = 40;
    private const int ImportDirectory = 1;
    private const int IatDirectory = 12;

    public static bool TryMinimize(byte[] source, out byte[] minimized, out string error)
    {
        try
        {
            minimized = Minimize(source);
            if (!IsStructurallyValid(minimized, out error))
                return false;
            error = String.Empty;
            return true;
        }
        catch (Exception ex)
        {
            minimized = source;
            error = ex.Message;
            return false;
        }
    }

    public static byte[] Minimize(byte[] source)
    {
        ValidateDosAndPe(source, out var peOffset, out var optionalOffset, out var sectionTable, out var sectionCount);
        var sections = ReadSections(source, sectionTable, sectionCount);
        var text = sections.SingleOrDefault(x => x.Name == ".text");
        var idata = sections.SingleOrDefault(x => x.Name == ".idata");
        if (text == null || idata == null || sections.Count != 2)
            throw new InvalidDataException("Expected exactly one .text and one .idata section.");

        var fileAlignment = ReadUInt32(source, optionalOffset + 36);
        var sectionAlignment = ReadUInt32(source, optionalOffset + 32);
        if (fileAlignment != 0x200 || sectionAlignment != 0x200)
            throw new InvalidDataException("This minimal format expects 512 byte alignment.");

        var imageBase = ReadUInt32(source, optionalOffset + 28);
        var textRawOffset = checked((int)text.PointerToRawData);
        var textVirtualEnd = checked(text.VirtualAddress + text.VirtualSize);
        var bssLength = ReadUInt32(source, optionalOffset + 12);
        if (bssLength > text.VirtualSize)
            throw new InvalidDataException("The BSS size in the PE header is invalid.");

        var oldBssStart = textVirtualEnd;
        var oldBssEnd = checked(oldBssStart + bssLength);
        var textDataLength = checked((int)(textVirtualEnd - text.VirtualAddress));

        var oldIdataStart = idata.VirtualAddress;
        var oldIdataEnd = checked(oldIdataStart + idata.VirtualSize);
        var newIdataStart = checked(text.VirtualAddress + (uint)textDataLength);
        var newBssStart = checked(newIdataStart + idata.VirtualSize);
        var importDelta = checked((int)newIdataStart - (int)oldIdataStart);
        var bssDelta = checked((int)newBssStart - (int)oldBssStart);
        var idataDataLength = checked((int)idata.VirtualSize);
        var newRawLength = Align(textDataLength + idataDataLength, (int)fileAlignment);
        var newRawEnd = checked(textRawOffset + newRawLength);
        var result = new byte[newRawEnd];
        Array.Copy(source, 0, result, 0, Math.Min(textRawOffset, source.Length));
        Array.Copy(source, textRawOffset, result, textRawOffset, textDataLength);
        Array.Copy(source, (int)idata.PointerToRawData, result, textRawOffset + textDataLength, idataDataLength);

        PatchRvas(result, optionalOffset, textRawOffset + textDataLength, idataDataLength,
            oldIdataStart, oldIdataEnd, importDelta);
        PatchAbsoluteReferences(result, textRawOffset, textDataLength,
            imageBase + oldIdataStart, imageBase + oldIdataEnd, importDelta,
            imageBase + oldBssStart, imageBase + oldBssEnd, bssDelta);

        WriteUInt16(result, peOffset + 6, 1);
        WriteUInt32(result, optionalOffset + 56, (uint)Align(checked((int)(newBssStart + bssLength)), (int)sectionAlignment));
        WriteUInt32(result, optionalOffset + 96 + ImportDirectory * 8,
            TranslateDirectoryRva(ReadUInt32(source, optionalOffset + 96 + ImportDirectory * 8), oldIdataStart, oldIdataEnd, importDelta));
        WriteUInt32(result, optionalOffset + 96 + IatDirectory * 8,
            TranslateDirectoryRva(ReadUInt32(source, optionalOffset + 96 + IatDirectory * 8), oldIdataStart, oldIdataEnd, importDelta));

        var textHeader = sectionTable;
        WriteUInt32(result, textHeader + 8, checked((uint)textDataLength + idata.VirtualSize + bssLength));
        WriteUInt32(result, textHeader + 16, (uint)newRawLength);
        WriteUInt32(result, textHeader + 20, text.PointerToRawData);
        Array.Clear(result, textHeader + SectionSize, SectionSize);

        if (result.Length < source.Length)
            return result;
        throw new InvalidDataException("The new PE layout is not smaller.");
    }

    private static bool IsStructurallyValid(byte[] image, out string error)
    {
        error = null;
        try
        {
            ValidateDosAndPe(image, out var peOffset, out var optionalOffset, out var sectionTable, out var sectionCount);
            if (sectionCount != 1)
            {
                error = "Expected a single section in the minimized PE.";
                return false;
            }

            var sectionRva = ReadUInt32(image, sectionTable + 12);
            var sectionVirtualSize = ReadUInt32(image, sectionTable + 8);
            var sectionRawSize = ReadUInt32(image, sectionTable + 16);
            var sectionRawOffset = ReadUInt32(image, sectionTable + 20);
            var entryPoint = ReadUInt32(image, optionalOffset + 16);
            if (entryPoint < sectionRva || entryPoint >= sectionRva + sectionVirtualSize)
            {
                error = "The entry point is outside the minimized section.";
                return false;
            }

            var importRva = ReadUInt32(image, optionalOffset + 96 + ImportDirectory * 8);
            var importSize = ReadUInt32(image, optionalOffset + 96 + ImportDirectory * 8 + 4);
            var iatRva = ReadUInt32(image, optionalOffset + 96 + IatDirectory * 8);
            var iatSize = ReadUInt32(image, optionalOffset + 96 + IatDirectory * 8 + 4);

            if (!DirectoryInSection(importRva, importSize, sectionRva, sectionVirtualSize) ||
                !DirectoryInSection(iatRva, iatSize, sectionRva, sectionVirtualSize))
            {
                error = "The import or IAT directory is outside the section.";
                return false;
            }

            if (!TryMapRvaToOffset(importRva, sectionRva, sectionRawOffset, sectionRawSize, out var importOffset) ||
                importOffset + importSize > image.Length)
            {
                error = "The import directory can not be mapped to a file offset.";
                return false;
            }

            return true;
        }
        catch (Exception ex)
        {
            error = ex.Message;
            return false;
        }
    }

    private static bool DirectoryInSection(uint rva, uint size, uint sectionRva, uint sectionSize)
    {
        if (rva == 0 && size == 0) return true;
        if (rva < sectionRva) return false;
        var end = checked(rva + Math.Max(size, 1u));
        return end <= sectionRva + sectionSize;
    }

    private static bool TryMapRvaToOffset(uint rva, uint sectionRva, uint sectionRawOffset, uint sectionRawSize, out int offset)
    {
        offset = 0;
        if (rva < sectionRva) return false;
        var delta = checked(rva - sectionRva);
        if (delta >= sectionRawSize) return false;
        offset = checked((int)(sectionRawOffset + delta));
        return true;
    }

    private static void PatchRvas(byte[] image, int optionalOffset, int importOffset, int importLength,
        uint oldStart, uint oldEnd, int delta)
    {
        var directoryCount = ReadUInt32(image, optionalOffset + 92);
        for (var i = 0; i < directoryCount && i < 16; i++)
        {
            var offset = optionalOffset + 96 + i * 8;
            var rva = ReadUInt32(image, offset);
            WriteUInt32(image, offset, TranslateDirectoryRva(rva, oldStart, oldEnd, delta));
        }

        for (var offset = importOffset; offset + 4 <= importOffset + importLength; offset += 4)
        {
            var value = ReadUInt32(image, offset);
            if (value >= oldStart && value < oldEnd)
                WriteUInt32(image, offset, TranslateDirectoryRva(value, oldStart, oldEnd, delta));
        }
    }

    private static void PatchAbsoluteReferences(byte[] image, int offset, int length,
        uint oldImportStart, uint oldImportEnd, int importDelta,
        uint oldBssStart, uint oldBssEnd, int bssDelta)
    {
        for (var i = offset; i + 4 <= offset + length; i++)
        {
            var value = ReadUInt32(image, i);
            if (value >= oldImportStart && value < oldImportEnd)
                WriteUInt32(image, i, unchecked((uint)((int)value + importDelta)));
            else if (value >= oldBssStart && value < oldBssEnd)
                WriteUInt32(image, i, unchecked((uint)((int)value + bssDelta)));
        }
    }

    private static uint TranslateDirectoryRva(uint rva, uint oldStart, uint oldEnd, int delta) =>
        rva >= oldStart && rva < oldEnd ? unchecked((uint)((int)rva + delta)) : rva;

    private static List<Section> ReadSections(byte[] image, int sectionTable, ushort count)
    {
        var result = new List<Section>();
        for (var i = 0; i < count; i++)
        {
            var offset = sectionTable + i * SectionSize;
            var name = System.Text.Encoding.ASCII.GetString(image, offset, 8).TrimEnd('\0');
            result.Add(new Section(name, ReadUInt32(image, offset + 8), ReadUInt32(image, offset + 12),
                ReadUInt32(image, offset + 16), ReadUInt32(image, offset + 20)));
        }
        return result;
    }

    private static void ValidateDosAndPe(byte[] image, out int peOffset, out int optionalOffset,
        out int sectionTable, out ushort sectionCount)
    {
        if (image.Length < 64 || ReadUInt16(image, 0) != 0x5A4D)
            throw new InvalidDataException("Not a valid MZ file.");
        peOffset = checked((int)ReadUInt32(image, 0x3C));
        if (ReadUInt32(image, peOffset) != 0x00004550) throw new InvalidDataException("Not a PE header.");
        if (ReadUInt16(image, peOffset + 4) != 0x14C) throw new InvalidDataException("Only PE32/x86 is supported.");
        sectionCount = ReadUInt16(image, peOffset + 6);
        optionalOffset = peOffset + 24;
        if (ReadUInt16(image, optionalOffset) != 0x10B) throw new InvalidDataException("Only PE32 is supported.");
        sectionTable = optionalOffset + ReadUInt16(image, peOffset + 20);
    }

    private static int Align(int value, int alignment) => (value + alignment - 1) / alignment * alignment;
    private static ushort ReadUInt16(byte[] data, int offset) => BitConverter.ToUInt16(data, offset);
    private static uint ReadUInt32(byte[] data, int offset) => BitConverter.ToUInt32(data, offset);
    private static void WriteUInt16(byte[] data, int offset, ushort value) => Array.Copy(BitConverter.GetBytes(value), 0, data, offset, 2);
    private static void WriteUInt32(byte[] data, int offset, uint value) => Array.Copy(BitConverter.GetBytes(value), 0, data, offset, 4);

    private sealed class Section
    {
        public Section(string name, uint virtualSize, uint virtualAddress, uint rawSize, uint pointerToRawData)
        {
            Name = name;
            VirtualSize = virtualSize;
            VirtualAddress = virtualAddress;
            RawSize = rawSize;
            PointerToRawData = pointerToRawData;
        }

        public string Name { get; }
        public uint VirtualSize { get; }
        public uint VirtualAddress { get; }
        public uint RawSize { get; }
        public uint PointerToRawData { get; }
    }
}
