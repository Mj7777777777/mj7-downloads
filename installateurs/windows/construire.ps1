# Construit un installateur .exe par plugin (Inno Setup), plus un installateur pour toute la suite.
# Entree : zips\*-Windows.zip et versions.txt ("MJ7-Tune 1.0.3"). Sortie : out\*.exe
$ErrorActionPreference = 'Stop'

$iscc = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
if (-not (Test-Path $iscc)) {
    choco install innosetup -y --no-progress | Out-Host
}
if (-not (Test-Path $iscc)) { throw "Inno Setup introuvable" }

# Identifiants fixes : Windows reconnait ainsi une mise a jour du meme plugin.
$guids = @{
    'MJ7-Vocal-Chain'  = '5F329C9F-AC95-4573-B46F-F20671FFFCA0'
    'MJ7-Master-Chain' = 'CCBDC3D4-57CF-462E-909F-CA7653D2CD56'
    'MJ7-Voice-Over'   = 'D7CD40D5-5837-4B96-BDDB-F0A18FBE0B9A'
    'MJ7-Backs-Adlibs' = '7719BD5B-E629-4DE9-8A53-7D0864E6441D'
    'MJ7-Tune'         = '78561D2A-A507-4C94-B52F-B804BBB768CD'
    'MJ7-Live-Monitor' = '9C3996E0-B775-4FE1-B577-22499CB3CF3F'
    'MJ7-Vocal-Booth'  = 'BBCE29B7-A5F3-4905-8DF1-4755FEE7DA8D'
    'MJ7-Suite'        = '1A439DDC-00E9-4B72-B6F0-4EEFC0A5E217'
}

$versions = @{}
Get-Content versions.txt | ForEach-Object { $p = $_ -split ' '; if ($p.Count -ge 2) { $versions[$p[0]] = $p[1] } }

Remove-Item -Recurse -Force stage, out, iss -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force stage, out, iss | Out-Null

function New-Installer([string]$outName, [string]$appName, [string]$guid, [string]$version, $plugins) {
    $lines = @(
        '[Setup]',
        "AppId={{$guid}",
        "AppName=$appName",
        "AppVersion=$version",
        'AppPublisher=MJ7',
        'DefaultDirName={commoncf64}\VST3',
        'DisableDirPage=yes',
        'DisableProgramGroupPage=yes',
        "UninstallFilesDir={commonappdata}\MJ7\Desinstallation\$outName",
        "UninstallDisplayName=$appName",
        'ArchitecturesAllowed=x64',
        'ArchitecturesInstallIn64BitMode=x64',
        'PrivilegesRequired=admin',
        "OutputDir=$((Resolve-Path out).Path)",
        "OutputBaseFilename=$outName",
        'Compression=lzma2',
        'SolidCompression=yes',
        'WizardStyle=modern',
        '',
        '[Languages]',
        'Name: "fr"; MessagesFile: "compiler:Languages\French.isl"',
        '',
        '[Messages]',
        "fr.WelcomeLabel2=Ce programme va installer $appName (VST3) sur votre ordinateur.%n%nFermez FL Studio, Ableton ou votre logiciel de musique avant de continuer.",
        'fr.FinishedLabel=Installation terminée.%n%nDans FL Studio : Options > Manage plugins > Find installed plugins.%nDans Ableton : Préférences > Plug-Ins > Rescan.%n%nEssai complet de 14 jours, puis activation avec votre clé de licence (petite ligne dorée sous le nom du plugin).',
        '',
        '[InstallDelete]'
    )
    foreach ($p in $plugins) { $lines += "Type: filesandordirs; Name: ""{commoncf64}\VST3\$($p.Name)""" }
    $lines += ''
    $lines += '[Files]'
    foreach ($p in $plugins) {
        $lines += "Source: ""$($p.FullName)\*""; DestDir: ""{commoncf64}\VST3\$($p.Name)""; Flags: recursesubdirs createallsubdirs ignoreversion"
    }
    $iss = Join-Path (Resolve-Path iss).Path "$outName.iss"
    Set-Content -Path $iss -Value $lines -Encoding utf8BOM
    & $iscc /Q $iss
    if ($LASTEXITCODE -ne 0) { throw "Echec Inno Setup pour $outName" }
}

$all = @()
foreach ($z in Get-ChildItem zips\*-Windows.zip) {
    $base = $z.Name -replace '-Windows\.zip$', ''
    $dir = Join-Path (Resolve-Path stage).Path $base
    Expand-Archive -Path $z.FullName -DestinationPath $dir -Force
    $vst = Get-ChildItem $dir -Directory -Filter '*.vst3' | Select-Object -First 1
    if ($null -eq $vst) { throw "Pas de .vst3 dans $($z.Name)" }
    $app = $vst.Name -replace '\.vst3$', ''
    $ver = if ($versions.ContainsKey($base)) { $versions[$base] } else { '1.0.0' }
    New-Installer "$base-Windows-Installateur" $app $guids[$base] $ver @($vst)
    $all += $vst
}
New-Installer 'MJ7-Suite-Windows-Installateur' 'MJ7 Suite (tous les plugins)' $guids['MJ7-Suite'] $env:SUITE_VERSION $all
Get-ChildItem out | Format-Table Name, Length
