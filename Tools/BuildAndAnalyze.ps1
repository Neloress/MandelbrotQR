[CmdletBinding()]
param(
	[string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
	[string]$Configuration = 'Release',
	[string]$Platform = 'Win32',
	[switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$project = Join-Path $RepositoryRoot 'SmallASM\SmallASM.vcxproj'
$releaseDir = Join-Path $RepositoryRoot 'SmallASM\Release'
$normalExe = Join-Path $releaseDir 'SmallASM.exe'
$minExe = Join-Path $releaseDir 'SmallASM.min.exe'
$mapFile = Join-Path $releaseDir 'SmallASM.map'
$analysisFile = Join-Path $RepositoryRoot 'EXE-GROESSENANALYSE.md'
$miniLinker = Join-Path $RepositoryRoot 'Tools\MiniPeLinker\MiniPeLinker.exe'
$importsFile = Join-Path $RepositoryRoot 'Tools\MiniPeLinker\imports.csv'

if (-not (Test-Path $project)) { throw "Projekt nicht gefunden: $project" }
if (-not (Test-Path $miniLinker)) { throw "MiniPeLinker nicht gefunden: $miniLinker" }
if (-not (Test-Path $importsFile)) { throw "Import-CSV nicht gefunden: $importsFile" }

function Find-MSBuild {
	$commands = @('msbuild.exe', 'MSBuild.exe')
	foreach ($command in $commands) {
		$item = Get-Command $command -ErrorAction SilentlyContinue
		if ($null -ne $item) { return $item.Source }
	}

	$candidates = @(
		'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\MSBuild.exe',
		'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe',
		'C:\Program Files\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe'
	)
	foreach ($candidate in $candidates) {
		if (Test-Path $candidate) { return $candidate }
	}
	throw 'MSBuild.exe wurde nicht gefunden.'
}

function Find-DumpBin {
	$item = Get-Command dumpbin.exe -ErrorAction SilentlyContinue
	if ($null -ne $item) { return $item.Source }

	$roots = @(
		'C:\Program Files\Microsoft Visual Studio\18',
		'C:\Program Files\Microsoft Visual Studio\2022'
	)
	foreach ($root in $roots) {
		if (Test-Path $root) {
			$candidate = Get-ChildItem $root -Filter dumpbin.exe -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
			if ($null -ne $candidate) { return $candidate.FullName }
		}
	}
	throw 'dumpbin.exe wurde nicht gefunden.'
}

if (-not $SkipBuild) {
	$msbuild = Find-MSBuild
	& $msbuild $project /t:Rebuild "/p:Configuration=$Configuration" "/p:Platform=$Platform" /v:minimal
	if ($LASTEXITCODE -ne 0) { throw "MSBuild fehlgeschlagen: ExitCode $LASTEXITCODE" }
}

if (-not (Test-Path $normalExe)) { throw "Normale EXE nicht gefunden: $normalExe" }
if (-not (Test-Path $minExe)) {
	& $miniLinker $normalExe $minExe $importsFile
	if ($LASTEXITCODE -ne 0) { throw "MiniPeLinker fehlgeschlagen: ExitCode $LASTEXITCODE" }
}
if (-not (Test-Path $minExe)) { throw "Minimierte EXE nicht gefunden: $minExe" }

$dumpbin = Find-DumpBin
$headers = @(& $dumpbin /headers $minExe)
if ($LASTEXITCODE -ne 0) { throw 'dumpbin konnte die minimierte EXE nicht analysieren.' }

function Get-HeaderValue([string]$Pattern) {
	$line = $headers | Where-Object { $_ -match $Pattern } | Select-Object -First 1
	if ($null -eq $line) { return $null }
	$match = [regex]::Match($line, '(?<hex>[0-9A-Fa-f]+)')
	if (-not $match.Success) { return $null }
	return [Convert]::ToInt32($match.Groups['hex'].Value, 16)
}

function Format-Bytes([int]$Value) {
	return ('{0:N0} B' -f $Value)
}

function Next-PowerOfTwo([int]$Value) {
	$power = 1
	while ($power -lt $Value) { $power *= 2 }
	return $power
}

$normalSize = (Get-Item $normalExe).Length
$minSize = (Get-Item $minExe).Length
$headerSize = Get-HeaderValue 'size of headers'
$sizeOfCode = Get-HeaderValue 'size of code'
$sizeOfInitialized = Get-HeaderValue 'size of initialized data'
$sizeOfUninitialized = Get-HeaderValue 'size of uninitialized data'
$sizeOfImage = Get-HeaderValue 'size of image'

$mapSections = @()
if (Test-Path $mapFile) {
	$inSectionTable = $false
	foreach ($line in Get-Content $mapFile) {
		if ($line -match '^\s*Start\s+Length\s+Name\s+Class') {
			$inSectionTable = $true
			continue
		}
		if ($inSectionTable -and $line -match '^\s*([0-9A-Fa-f]{4}):([0-9A-Fa-f]{8})\s+([0-9A-Fa-f]+)H\s+(\S+)\s+(\S+)') {
			$mapSections += [pscustomobject]@{
				Segment = $Matches[1]
				Start = [Convert]::ToInt32($Matches[2], 16)
				Length = [Convert]::ToInt32($Matches[3], 16)
				Name = $Matches[4]
				Class = $Matches[5]
			}
		} elseif ($inSectionTable -and [string]::IsNullOrWhiteSpace($line)) {
			break
		}
	}
}

$mapTotal = ($mapSections | Measure-Object Length -Sum).Sum
if ($null -eq $mapTotal) { $mapTotal = 0 }
$sectionPadding = if ($sizeOfImage -gt 0 -and $mapTotal -gt 0) { $sizeOfImage - $headerSize - $mapTotal } else { 0 }
$nextFilePower = Next-PowerOfTwo ([int]$minSize)
$nextImagePower = Next-PowerOfTwo ([int]$sizeOfImage)

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# EXE-Größenanalyse')
$lines.Add('')
$lines.Add("Erzeugt: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$lines.Add('')
$lines.Add('## Artefakte')
$lines.Add('')
$lines.Add('| Datei | Größe |')
$lines.Add('|---|---:|')
$lines.Add("| Normale Release-EXE | $(Format-Bytes $normalSize) |")
$lines.Add("| Minimierte EXE | $(Format-Bytes $minSize) |")
$lines.Add("| Ersparnis | $(Format-Bytes ([int]($normalSize - $minSize))) |")
$lines.Add('')
$lines.Add('## PE-Headerwerte')
$lines.Add('')
$lines.Add('| Wert | Größe |')
$lines.Add('|---|---:|')
$lines.Add("| Header | $(Format-Bytes $headerSize) |")
$lines.Add("| Code laut PE-Header | $(Format-Bytes $sizeOfCode) |")
$lines.Add("| Initialisierte Daten laut PE-Header | $(Format-Bytes $sizeOfInitialized) |")
$lines.Add("| Nicht initialisierte Daten laut PE-Header | $(Format-Bytes $sizeOfUninitialized) |")
$lines.Add("| SizeOfImage | $(Format-Bytes $sizeOfImage) |")
$lines.Add('')
$lines.Add('## Map-Bereiche')
$lines.Add('')
$lines.Add('| Bereich | Größe |')
$lines.Add('|---|---:|')
foreach ($section in $mapSections) {
	$lines.Add("| ``$($section.Name)`` | $(Format-Bytes $section.Length) |")
}
$lines.Add("| Map-Summe | $(Format-Bytes ([int]$mapTotal)) |")
$lines.Add("| Bereichs-/Sektions-Padding | $(Format-Bytes ([int]$sectionPadding)) |")
$lines.Add('')
$lines.Add('## Zweierpotenzen')
$lines.Add('')
$lines.Add('| Wert | Aktuell | Nächste Zweierpotenz | Abstand |')
$lines.Add('|---|---:|---:|---:|')
$lines.Add("| Dateigröße | $(Format-Bytes $minSize) | $(Format-Bytes $nextFilePower) | $(Format-Bytes ($nextFilePower - $minSize)) |")
$lines.Add("| SizeOfImage | $(Format-Bytes $sizeOfImage) | $(Format-Bytes $nextImagePower) | $(Format-Bytes ($nextImagePower - $sizeOfImage)) |")
$lines.Add('')
$lines.Add('## Quellen')
$lines.Add('')
$lines.Add("- Projekt: ``$project``")
$lines.Add("- Map-Datei: ``$mapFile``")
$lines.Add("- Minimierer: ``$miniLinker``")
$lines.Add("- Importauswahl: ``$importsFile``")

[IO.File]::WriteAllLines($analysisFile, $lines, [Text.UTF8Encoding]::new($true))
Write-Host "Analyse geschrieben: $analysisFile"
Write-Host "Minimierte EXE: $minExe ($minSize Bytes)"
