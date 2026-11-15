<# : batch part. cmd can't run PowerShell code, so these lines start PowerShell,
@echo off
rem which reads this same file and runs everything below. PowerShell skips this block.
set "SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ([IO.File]::ReadAllText($env:SELF))"
exit /b
#>

# content.zipe checker for Minecraft Bedrock (Windows)
# https://github.com/AxmBro/content-zipe-checker
# Read-only: it only reads files. Nothing is changed, deleted, uploaded or downloaded.

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$maxArchive = 2GB
$maxNested  = 500MB
# OneDrive "online-only" files (Offline, RecallOnDataAccess): opening them would download them
$cloudOnly  = 0x1000 -bor 0x400000

$downloads = $null
try { $downloads = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path } catch {}

# Kind: Game = installed, worlds, Marketplace; Cache = packs sent by servers; File = not installed
$locations = @(
    @{ Label = 'Minecraft';                 Kind = 'Game';  Path = "$env:APPDATA\Minecraft Bedrock" }
    @{ Label = 'Minecraft Preview';         Kind = 'Game';  Path = "$env:APPDATA\Minecraft Bedrock Preview" }
    @{ Label = 'Server packs';              Kind = 'Cache'; Path = "$env:TEMP\Minecraft Bedrock\minecraftpe" }
    @{ Label = 'Server packs (Preview)';    Kind = 'Cache'; Path = "$env:TEMP\Minecraft Bedrock Preview\minecraftpe" }
    # Older Microsoft Store (UWP) installs keep everything under Packages, server packs in LocalCache
    @{ Label = 'Minecraft (old version)';   Kind = 'Game';  Path = "$env:LOCALAPPDATA\Packages\Microsoft.MinecraftUWP_8wekyb3d8bbwe" }
    @{ Label = 'Preview (old version)';     Kind = 'Game';  Path = "$env:LOCALAPPDATA\Packages\Microsoft.MinecraftWindowsBeta_8wekyb3d8bbwe" }
    @{ Label = 'Downloads';                 Kind = 'File';  Path = $downloads }
    @{ Label = 'Downloads';                 Kind = 'File';  Path = "$env:USERPROFILE\Downloads" }
    @{ Label = 'Desktop';                   Kind = 'File';  Path = [Environment]::GetFolderPath('Desktop') }
)

# Minecraft content files are renamed ZIPs (.mcpack, .mcaddon, .mcworld, .mctemplate, .mcproject,
# .mceditoraddon...). Every .mc* and .zip file is tried, so new or rare types are covered too.
$notArchives = '.mcfunction', '.mcstructure', '.mcmeta', '.mc'
function Test-ArchiveName([string]$name) {
    $ext = [IO.Path]::GetExtension($name).ToLower()
    return ($ext -eq '.zip' -or ($ext.StartsWith('.mc') -and $notArchives -notcontains $ext))
}

function Get-NameFromManifest([string]$json, [string]$fallback) {
    # Manifests with comments fail to parse on PowerShell 5.1; then the folder name is used
    try {
        $name = ($json | ConvertFrom-Json -ErrorAction Stop).header.name
        # Strip Minecraft color codes; "pack.name" is a translation key, not a real name
        $name = "$name" -replace "$([char]0xA7).", ''
        if ($name.Trim() -and $name -ne 'pack.name') { return $name.Trim() }
    } catch {}
    return $fallback
}

function Get-FolderPackName([string]$dir) {
    $d = $dir
    for ($i = 0; $i -lt 4 -and $d; $i++) {
        $manifest = Join-Path $d 'manifest.json'
        if (Test-Path -LiteralPath $manifest) {
            $json = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
            return Get-NameFromManifest $json (Split-Path $d -Leaf)
        }
        $d = Split-Path $d -Parent
    }
    return Split-Path $dir -Leaf
}

function Read-ZipText($entry) {
    if ($entry.Length -gt 1MB) { return $null }
    $reader = New-Object IO.StreamReader($entry.Open())
    try { return $reader.ReadToEnd() } finally { $reader.Dispose() }
}

$hits = New-Object System.Collections.Generic.List[object]

function Search-Zip([IO.Compression.ZipArchive]$zip, [string]$file, [string]$kind, [string]$chain, [string]$archiveName, [int]$depth) {
    $byPath = @{}
    foreach ($e in $zip.Entries) { $byPath[$e.FullName.Replace('\', '/')] = $e }

    foreach ($entry in $zip.Entries) {
        $path = $entry.FullName.Replace('\', '/')
        $leaf = $path.Split('/')[-1]

        if ($leaf -ieq 'content.zipe') {
            $dir = $path.Substring(0, $path.Length - $leaf.Length)
            $pack = if ($dir) { $dir.TrimEnd('/').Split('/')[-1] } else { $archiveName }
            $manifest = $byPath[$dir + 'manifest.json']
            if ($manifest) { try { $pack = Get-NameFromManifest (Read-ZipText $manifest) $pack } catch {} }
            $hits.Add([pscustomobject]@{ Kind = $kind; Pack = $pack; File = $file; Inner = $chain + $path })
        }
        # .mcaddon and .mcworld files often contain .mcpack files
        elseif ($depth -lt 3 -and $entry.Length -le $maxNested -and (Test-ArchiveName $leaf)) {
            try {
                $ms = New-Object IO.MemoryStream
                $stream = $entry.Open()
                try { $stream.CopyTo($ms) } finally { $stream.Dispose() }
                $ms.Position = 0
                $inner = New-Object IO.Compression.ZipArchive($ms, [IO.Compression.ZipArchiveMode]::Read)
                try { Search-Zip $inner $file $kind "$chain$path  >  " $leaf ($depth + 1) }
                finally { $inner.Dispose(); $ms.Dispose() }
            } catch {}
        }
    }
}

function Write-Section([string]$title, [string]$color, [string]$todo, $list) {
    if ($list.Count -eq 0) { return }
    Write-Host ''
    Write-Host "  $title" -ForegroundColor $color -NoNewline
    Write-Host "  $todo" -ForegroundColor Yellow
    foreach ($h in $list) {
        $where = if ($h.Inner) { "$($h.File)  >  $($h.Inner)" } else { $h.File }
        Write-Host "    $($h.Pack)" -ForegroundColor White
        Write-Host "    $where" -ForegroundColor DarkGray
    }
}

try { $Host.UI.RawUI.WindowTitle = 'content.zipe checker' } catch {}
Write-Host ''
Write-Host '  content.zipe checker for Minecraft Bedrock' -ForegroundColor Cyan
Write-Host '  Read-only: nothing is changed, deleted or sent.' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  Checking installed packs, worlds, Marketplace, server packs, Downloads and Desktop.' -ForegroundColor Gray
Write-Host '  This can take a minute or two.' -ForegroundColor DarkGray
Write-Host ''

$scanned = New-Object System.Collections.Generic.List[string]
$skipped = 0
foreach ($loc in $locations) {
    $root = $loc.Path
    if (-not $root -or -not (Test-Path -LiteralPath $root) -or $scanned -contains $root) { continue }
    $scanned.Add($root)

    $label  = '    {0,-24}' -f $loc.Label
    $before = $hits.Count
    $count  = 0
    $timer  = [Diagnostics.Stopwatch]::StartNew()
    Write-Host $label -ForegroundColor Gray -NoNewline
    # Piped, not collected first, so the live counter moves while big folders are read
    Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $f = $_
        $count++
        if ($timer.ElapsedMilliseconds -ge 250) {
            Write-Host ("`r" + $label + ('{0,8} files...' -f $count)) -ForegroundColor Gray -NoNewline
            $timer.Restart()
        }
        if ([int]$f.Attributes -band $cloudOnly) { $skipped++; return }
        $kind = if ($f.FullName -like '*\LocalCache\minecraftpe\*') { 'Cache' } else { $loc.Kind }

        if ($f.Name -ieq 'content.zipe') {
            $hits.Add([pscustomobject]@{ Kind = $kind; Pack = Get-FolderPackName $f.DirectoryName; File = $f.FullName; Inner = $null })
        }
        elseif ((Test-ArchiveName $f.Name) -and $f.Length -le $maxArchive) {
            try {
                $zip = [IO.Compression.ZipFile]::OpenRead($f.FullName)
                try { Search-Zip $zip $f.FullName $kind '' $f.Name 0 } finally { $zip.Dispose() }
            } catch {}
        }
    }
    Write-Host ("`r" + $label + ('{0,8} files   ' -f $count)) -ForegroundColor Gray -NoNewline
    $new = $hits.Count - $before
    if ($new) { Write-Host "$new found   " -ForegroundColor Red -NoNewline }
    Write-Host $root -ForegroundColor DarkGray
}
if ($scanned.Count -eq 0) {
    Write-Host '    No Minecraft, Downloads or Desktop folders found.' -ForegroundColor Yellow
}

$found = @($hits | Sort-Object File, Inner -Unique)
$game  = @($found | Where-Object { $_.Kind -eq 'Game' })
$cache = @($found | Where-Object { $_.Kind -eq 'Cache' })
$files = @($found | Where-Object { $_.Kind -eq 'File' })

Write-Host ''
Write-Host ('  ' + ('-' * 76)) -ForegroundColor DarkGray
Write-Host ''
if ($found.Count -eq 0) {
    Write-Host '  All clear: no pack on this PC has content.zipe.' -ForegroundColor Green
    Write-Host '  This only covers what''s here right now. Stay careful until Minecraft is patched.' -ForegroundColor DarkGray
}
else {
    Write-Host "  Found content.zipe in $($found.Count) place(s)." -ForegroundColor Red
    Write-Host '  Don''t panic: it means a pack CAN run hidden scripts, not that it did.' -ForegroundColor Gray
    Write-Host '  If you don''t fully trust where a pack came from, get rid of it:' -ForegroundColor Gray

    Write-Section 'INSTALLED IN MINECRAFT' 'Red' 'remove it from Minecraft or delete its folder' $game
    Write-Section 'FROM SERVERS' 'Red' 'close Minecraft, delete the folder, avoid that server' $cache
    Write-Section 'FILES ON YOUR PC' 'DarkYellow' 'not installed, don''t import it, delete it' $files

    if ($game.Count -or $cache.Count) {
        Write-Host ''
        Write-Host '  Played with one of these and don''t trust it? Run a full scan in Windows Security.' -ForegroundColor Gray
    }
}

if ($skipped) {
    Write-Host ''
    Write-Host "  Skipped $skipped OneDrive file(s) that are only in the cloud, so nothing gets downloaded." -ForegroundColor DarkGray
}
Write-Host ''
Write-Host '  More info: https://github.com/AxmBro/content-zipe-checker' -ForegroundColor DarkGray
Write-Host ''
Read-Host '  Press Enter to close' | Out-Null
