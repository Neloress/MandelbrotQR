[CmdletBinding()]
param(
	[string]$RepositoryRoot = (Split-Path -Parent $PSScriptRoot),
	[string]$Platform = 'Win32',
	[switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
	@'
RunImportRegressionTester.ps1

  Startet den ImportRegressionTester.
  -RepositoryRoot <Pfad>  Setzt das Repository-Verzeichnis.
	-Platform <Win32|x64>   Zielplattform (aktuell nutzt der Tester intern Win32).
  -Help                   Zeigt diese Hilfe.
'@
	exit 0
}

if ($Platform -ine 'Win32') {
	Write-Warning "ImportRegressionTester unterstützt derzeit nur Win32. Verwende Win32-Testlauf."
}

$toolDir = Join-Path $RepositoryRoot 'Tools\ImportRegressionTester'
$source = Join-Path $toolDir 'Program.cs'
$tester = Join-Path $toolDir 'ImportRegressionTester.exe'
$csc = 'C:\Program Files\Microsoft Visual Studio\18\Community\MSBuild\Current\Bin\Roslyn\csc.exe'

if (-not (Test-Path $source)) { throw "Tester-Quelltext nicht gefunden: $source" }
if (-not (Test-Path $csc)) { throw "Roslyn-csc.exe nicht gefunden: $csc" }

if (-not (Test-Path $tester) -or (Get-Item $source).LastWriteTimeUtc -gt (Get-Item $tester).LastWriteTimeUtc) {
	& $csc /nologo /target:exe /r:System.Drawing.dll /out:$tester $source
	if ($LASTEXITCODE -ne 0) { throw "Kompilierung des ImportRegressionTesters fehlgeschlagen: ExitCode $LASTEXITCODE" }
}

& $tester
if ($LASTEXITCODE -ne 0) { throw "ImportRegressionTester fehlgeschlagen: ExitCode $LASTEXITCODE" }
