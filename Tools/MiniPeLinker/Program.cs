using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

if (args.Length != 2)
{
    Console.Error.WriteLine("Verwendung: MiniPeLinker <Eingabe.exe> <Ausgabe.exe>");
    Environment.Exit(2);
}

var inputPath = Path.GetFullPath(args[0]);
var outputPath = Path.GetFullPath(args[1]);
var image = File.ReadAllBytes(inputPath);
var minimized = PeMinimizer.Minimize(image);

var directory = Path.GetDirectoryName(outputPath);
if (!String.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
File.WriteAllBytes(outputPath, minimized);

Console.WriteLine($"Eingabe : {image.Length:N0} Bytes");
Console.WriteLine($"Ausgabe : {minimized.Length:N0} Bytes");

static class PeMinimizer
{
    private const int SectionSize = 40;
    private const int ImportDirectory = 1;
    private const int IatDirectory = 12;

    public static byte[] Minimize(byte[] source)
    {
        ValidateDosAndPe(source, out var peOffset, out var optionalOffset, out var sectionTable, out var sectionCount);
        var sections = ReadSections(source, sectionTable, sectionCount);
        var text = sections.SingleOrDefault(x => x.Name == ".text");
        var idata = sections.SingleOrDefault(x => x.Name == ".idata");
        if (text == null || idata == null || sections.Count != 2)
            throw new InvalidDataException("Erwartet wird genau eine .text- und eine .idata-Sektion.");

        var fileAlignment = ReadUInt32(source, optionalOffset + 36);
        var sectionAlignment = ReadUInt32(source, optionalOffset + 32);
        if (fileAlignment != 0x200 || sectionAlignment != 0x200)
            throw new InvalidDataException("Dieses Minimalformat erwartet 512-Byte-Ausrichtung.");

        var imageBase = ReadUInt32(source, optionalOffset + 28);
        var textRawOffset = checked((int)text.PointerToRawData);
        var textVirtualEnd = checked(text.VirtualAddress + text.VirtualSize);
        var textRawEnd = checked(textRawOffset + (int)text.VirtualSize);
        var lastNonZero = textRawOffset - 1;
        for (var offset = textRawOffset; offset < textRawEnd; offset++)
        {
            if (source[offset] != 0) lastNonZero = offset;
        }

        var textDataLength = checked(lastNonZero - textRawOffset + 1);
        var oldBssStart = checked(text.VirtualAddress + (uint)textDataLength);
        if (oldBssStart >= textVirtualEnd)
            throw new InvalidDataException("Kein abschließender BSS-Bereich gefunden.");

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
            imageBase + oldBssStart, imageBase + textVirtualEnd, bssDelta);

        WriteUInt16(result, peOffset + 6, 1);
        WriteUInt32(result, optionalOffset + 56, (uint)Align(checked((int)(newIdataStart + idata.VirtualSize)), (int)sectionAlignment));
        WriteUInt32(result, optionalOffset + 92 + ImportDirectory * 8, newIdataStart);
        WriteUInt32(result, optionalOffset + 92 + IatDirectory * 8,
            TranslateDirectoryRva(ReadUInt32(source, optionalOffset + 92 + IatDirectory * 8), oldIdataStart, oldIdataEnd, importDelta));

        var textHeader = sectionTable;
        WriteUInt32(result, textHeader + 8, checked(text.VirtualSize + idata.VirtualSize));
        WriteUInt32(result, textHeader + 16, (uint)newRawLength);
        WriteUInt32(result, textHeader + 20, text.PointerToRawData);
        Array.Clear(result, textHeader + SectionSize, SectionSize);

        if (result.Length < source.Length)
            return result;
        throw new InvalidDataException("Das neue PE-Layout ist nicht kleiner; Originaldatei bleibt unverändert.");
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
            throw new InvalidDataException("Keine gültige MZ-Datei.");
        peOffset = checked((int)ReadUInt32(image, 0x3C));
        if (ReadUInt32(image, peOffset) != 0x00004550) throw new InvalidDataException("Kein PE-Header.");
        if (ReadUInt16(image, peOffset + 4) != 0x14C) throw new InvalidDataException("Nur PE32/x86 wird unterstützt.");
        sectionCount = ReadUInt16(image, peOffset + 6);
        optionalOffset = peOffset + 24;
        if (ReadUInt16(image, optionalOffset) != 0x10B) throw new InvalidDataException("Nur PE32 wird unterstützt.");
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
