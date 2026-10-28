<#
.SYNOPSIS
  Crée le zip installable d'un ou plusieurs mods Factorio du dépôt.

.DESCRIPTION
  Détecte les dossiers contenant un info.json, propose un menu de sélection,
  puis crée dist\<name>_<version>.zip avec le dossier racine <name>_<version>\
  (format attendu par Factorio).

.EXAMPLE
  .\build-mod.ps1                              # menu interactif
  .\build-mod.ps1 -Mod ElectrifiedRailways     # sans menu
  .\build-mod.ps1 -All                         # tous les mods
  .\build-mod.ps1 -NoInstall                   # crée le zip sans le copier dans Factorio

  Par défaut, chaque zip est aussi copié dans %APPDATA%\Factorio\mods
  (autre dossier : -FactorioModsDir "D:\...\mods").
#>
[CmdletBinding()]
param(
    [string[]]$Mod,
    [switch]$All,
    [string]$Root = $PSScriptRoot,
    [string]$OutputDir = (Join-Path $PSScriptRoot 'dist'),
    [string]$FactorioModsDir = (Join-Path $env:APPDATA 'Factorio\mods'),
    [switch]$NoInstall
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$excludedNames = @('.git', '.github', '.vscode', '.idea', 'dist', 'node_modules')
$excludedFiles = @('*.zip', '*.bak', '*.tmp', 'Thumbs.db', '.DS_Store', '.gitignore', '.gitattributes')

# Parcourt $Root sur 2 niveaux. Retourne un objet par dossier, IsMod = présence d'un info.json valide.
function Get-Projects {
    $rootFull = (Resolve-Path $Root).Path.TrimEnd('\')
    $candidates = Get-ChildItem -Path $rootFull -Directory |
        Where-Object { $excludedNames -notcontains $_.Name }

    foreach ($dir in $candidates) {
        $infoPath = Join-Path $dir.FullName 'info.json'
        if (-not (Test-Path $infoPath)) {
            # Dossier de regroupement : on cherche un niveau plus bas
            $children = Get-ChildItem -Path $dir.FullName -Directory |
                Where-Object { $excludedNames -notcontains $_.Name -and (Test-Path (Join-Path $_.FullName 'info.json')) }
            if ($children) {
                foreach ($child in $children) { Read-Project $child $rootFull }
                continue
            }
        }
        Read-Project $dir $rootFull
    }
}

function Read-Project($dir, $rootFull) {
    $infoPath = Join-Path $dir.FullName 'info.json'
    $display = $dir.FullName.Substring($rootFull.Length + 1)
    $project = [ordered]@{
        Folder = $display; Path = $dir.FullName; IsMod = $false
        Name = $null; Version = $null; Title = $null; Reason = $null
    }
    if (-not (Test-Path $infoPath)) {
        $project.Reason = 'pas de info.json'
    } else {
        try {
            $info = Get-Content $infoPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $info.name -or -not $info.version) {
                $project.Reason = 'info.json sans name ou version'
            } else {
                $project.IsMod = $true
                $project.Name = $info.name
                $project.Version = $info.version
                $project.Title = $info.title
            }
        } catch {
            $project.Reason = "info.json illisible ($($_.Exception.Message))"
        }
    }
    [pscustomobject]$project
}

function Get-Mods($projects) {
    @($projects | Where-Object IsMod)
}

function Select-Mods($available, $skipped) {
    Write-Host ''
    Write-Host "Projets trouvés dans $Root :" -ForegroundColor Cyan
    for ($i = 0; $i -lt $available.Count; $i++) {
        $m = $available[$i]
        $title = if ($m.Title) { $m.Title } else { $m.Name }
        '  [{0}] {1}  -  {2} {3}  ->  {4}_{3}.zip' -f ($i + 1), $m.Folder, $title, $m.Version, $m.Name | Write-Host
    }
    foreach ($s in $skipped) {
        Write-Host ('  [-] {0}  (ignoré : {1})' -f $s.Folder, $s.Reason) -ForegroundColor DarkGray
    }
    Write-Host '  [A] Tous'
    Write-Host '  [Q] Quitter'
    Write-Host ''
    $answer = Read-Host 'Choix (ex : 1 ou 1,3 ou A)'

    if ($answer -match '^[Qq]$') { return @() }
    if ($answer -match '^[Aa]$') { return $available }

    $picked = foreach ($token in ($answer -split '[,\s]+' | Where-Object { $_ })) {
        $n = 0
        if ([int]::TryParse($token, [ref]$n) -and $n -ge 1 -and $n -le $available.Count) {
            $available[$n - 1]
        } else {
            Write-Warning "Choix ignoré : '$token'"
        }
    }
    return @($picked)
}

function New-ModZip($m) {
    $rootName = '{0}_{1}' -f $m.Name, $m.Version
    $zipPath = Join-Path $OutputDir "$rootName.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

    $basePath = $m.Path.TrimEnd('\')
    $files = Get-ChildItem -Path $basePath -Recurse -File -Force | Where-Object {
        $relative = $_.FullName.Substring($basePath.Length + 1)
        $parts = $relative -split '[\\/]'
        $skip = $false
        if ($parts.Count -gt 1) {
            foreach ($p in $parts[0..($parts.Count - 2)]) {
                if ($excludedNames -contains $p) { $skip = $true }
            }
        }
        if (-not $skip) {
            foreach ($pattern in $excludedFiles) {
                if ($_.Name -like $pattern) { $skip = $true }
            }
        }
        -not $skip
    }

    $zip = [System.IO.Compression.ZipFile]::Open($zipPath, 'Create')
    try {
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($basePath.Length + 1) -replace '\\', '/'
            $entryName = "$rootName/$relative"
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $file.FullName, $entryName, [System.IO.Compression.CompressionLevel]::Optimal)
        }
    } finally {
        $zip.Dispose()
    }

    $sizeKb = [math]::Round((Get-Item $zipPath).Length / 1KB)
    Write-Host ("  OK  {0}  ({1} fichiers, {2} Ko)" -f $zipPath, @($files).Count, $sizeKb) -ForegroundColor Green

    if (-not $NoInstall) {
        Install-ModZip $m $zipPath
    }
}

# Copie le zip dans le dossier mods de Factorio. Factorio charge la version la plus récente,
# les anciens zips du même mod sont laissés en place.
function Install-ModZip($m, $zipPath) {
    if (-not (Test-Path $FactorioModsDir)) {
        Write-Warning "Dossier mods de Factorio introuvable : $FactorioModsDir (copie ignorée, utilise -FactorioModsDir)"
        return
    }

    # Un dossier non zippé du même nom serait chargé à la place du zip
    $looseFolder = Join-Path $FactorioModsDir $m.Name
    if (Test-Path $looseFolder) {
        Write-Warning "Un dossier '$($m.Name)' non zippé existe dans les mods de Factorio : il peut prendre le pas sur le zip."
    }

    $target = Join-Path $FactorioModsDir (Split-Path $zipPath -Leaf)
    Copy-Item -Path $zipPath -Destination $target -Force
    Write-Host ("  ->  copié dans {0}" -f $target) -ForegroundColor Cyan

    $others = @(Get-ChildItem -Path $FactorioModsDir -Filter ($m.Name + '_*.zip') -File |
        Where-Object { $_.FullName -ne $target })
    if ($others.Count -gt 0) {
        Write-Host ("      anciennes versions présentes : {0}" -f (($others | ForEach-Object Name) -join ', ')) -ForegroundColor DarkGray
    }
}

$projects = @(Get-Projects)
$available = @(Get-Mods $projects)
$skipped = @($projects | Where-Object { -not $_.IsMod })
if ($available.Count -eq 0) {
    throw "Aucun mod (dossier avec info.json) trouvé dans $Root"
}

if ($All) {
    $selected = $available
} elseif ($Mod) {
    $selected = foreach ($requested in $Mod) {
        $match = $available | Where-Object { $_.Folder -eq $requested -or $_.Name -eq $requested }
        if (-not $match) { throw "Mod introuvable : '$requested'" }
        $match
    }
} else {
    $selected = Select-Mods $available $skipped
}

if (-not $selected -or @($selected).Count -eq 0) {
    Write-Host 'Rien à compacter.'
    return
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
Write-Host ''
Write-Host "Création des zips dans $OutputDir" -ForegroundColor Cyan
foreach ($m in $selected) { New-ModZip $m }
