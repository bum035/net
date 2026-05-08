<#
.SYNOPSIS
    Olympiad VM bootstrap — Windows (PowerShell 5+)

.DESCRIPTION
    Idempotent one-shot setup для олимпиадын Windows станц.
    Linux-ын setup-linux.sh-ийн адил.

    Хийдэг зүйл:
      1) Repo presence шалгана
      2) %APPDATA%\VanDyke\Config-ыг repo-руу junction
      3) %USERPROFILE%\OlympBackup үүсгэнэ + ENV var
      4) VS Code extension суулгана (-NoExtensions-аар алгасна)
      5) Telnet:// handler reg merge санал болгоно
      6) Claude Code CLI шалгана

.EXAMPLE
    PS> .\setup-windows.ps1

.EXAMPLE
    PS> .\setup-windows.ps1 -NoExtensions -SkipReg

.NOTES
    Олимпиадын машинд SecureCRT, VS Code, PuTTY, Wireshark аль хэдийн суусан гэж үздэг.
#>

[CmdletBinding()]
param(
    [switch]$NoExtensions,
    [switch]$SkipReg
)

$ErrorActionPreference = 'Stop'

# ----- paths -----
$RepoRoot   = if ($env:NET_REPO_ROOT) { $env:NET_REPO_ROOT } else { Join-Path $env:USERPROFILE 'net' }
$ScrtRepo   = Join-Path $RepoRoot 'secureCRT\VanDyke\Config'
$ScrtDest   = Join-Path $env:APPDATA 'VanDyke\Config'
$BackupDir  = Join-Path $env:USERPROFILE 'OlympBackup'

function Write-Ok    ($msg) { Write-Host "[ OK ] $msg"   -ForegroundColor Green }
function Write-Skip  ($msg) { Write-Host "[SKIP] $msg"   -ForegroundColor Yellow }
function Write-Fail  ($msg) { Write-Host "[FAIL] $msg"   -ForegroundColor Red }
function Write-Step  ($msg) { Write-Host "`n=== $msg ===" -ForegroundColor Cyan }

# ----- 1) repo presence -----
Write-Step "1/6 Repo presence"
if (-not (Test-Path (Join-Path $RepoRoot '.git'))) {
    Write-Fail "$RepoRoot нь git repo биш. Эхлээд clone:"
    Write-Host "    git clone https://github.com/bum035/net.git $RepoRoot"
    exit 1
}
Write-Ok "Repo: $RepoRoot"
Push-Location $RepoRoot
$branch = (git rev-parse --abbrev-ref HEAD 2>$null)
Pop-Location
Write-Ok "Branch: $branch"

# ----- 2) prerequisites -----
Write-Step "2/6 CLI prerequisites"
foreach ($cmd in @('git','code','SecureCRT')) {
    $found = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($found) {
        Write-Ok ("{0}: {1}" -f $cmd, $found.Source)
    } else {
        Write-Skip "$cmd PATH-д алга — олимпиадын машин дээр аль хэдийн суусан байх ёстой"
    }
}

# Claude Code CLI (npm-based)
$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
$claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
if ($claudeCmd) {
    Write-Ok "Claude Code CLI: $($claudeCmd.Source)"
} elseif ($npmCmd) {
    Write-Skip "Claude Code CLI байхгүй — npm install -g @anthropic-ai/claude-code"
} else {
    Write-Skip "npm + Claude Code CLI байхгүй — Node.js LTS суулгасны дараа: npm i -g @anthropic-ai/claude-code"
}

# ----- 3) SecureCRT junction -----
Write-Step "3/6 SecureCRT config junction"
if (-not (Test-Path $ScrtRepo)) {
    Write-Fail "Repo SecureCRT payload алга: $ScrtRepo"
    exit 1
}

$scrtParent = Split-Path $ScrtDest -Parent
if (-not (Test-Path $scrtParent)) {
    New-Item -ItemType Directory -Path $scrtParent -Force | Out-Null
}

# License-ийг хадгалах
$savedLicense = $null
$savedSsh2    = $null
$origLic = Join-Path $ScrtDest 'SecureCRT_eval.lic'
$origSsh = Join-Path $ScrtDest 'SSH2.ini'
if (Test-Path $origLic) {
    $savedLicense = Get-Content $origLic -Raw -Encoding Byte -ErrorAction SilentlyContinue
}
if (Test-Path $origSsh) {
    $savedSsh2 = Get-Content $origSsh -Raw -Encoding Byte -ErrorAction SilentlyContinue
}

if (Test-Path $ScrtDest) {
    $item = Get-Item $ScrtDest -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        Write-Ok "Junction аль хэдийн оршин байна: $ScrtDest"
    } else {
        $bak = "$ScrtDest.predeploy.bak"
        if (Test-Path $bak) { Remove-Item $bak -Recurse -Force }
        Move-Item $ScrtDest $bak
        Write-Skip "Хуучин Config → Config.predeploy.bak"
        New-Item -ItemType Junction -Path $ScrtDest -Target $ScrtRepo | Out-Null
        Write-Ok "Junction үүсгэв: $ScrtDest → $ScrtRepo"
    }
} else {
    New-Item -ItemType Junction -Path $ScrtDest -Target $ScrtRepo | Out-Null
    Write-Ok "Junction үүсгэв: $ScrtDest → $ScrtRepo"
}

# Junction-ийн доор license-ийг сэргээх (repo-д commit байхгүй)
if ($savedLicense) {
    $licOut = Join-Path $ScrtDest 'SecureCRT_eval.lic'
    if (-not (Test-Path $licOut)) {
        [IO.File]::WriteAllBytes($licOut, $savedLicense)
        Write-Ok "License буцаагдсан: SecureCRT_eval.lic"
    } else {
        Write-Skip "License хэвээр байна"
    }
} else {
    Write-Skip "License алга — олимпиадын машинаас .lic файл хуул"
}

# ----- 4) OlympBackup -----
Write-Step "4/6 OlympBackup directory + ENV"
if (-not (Test-Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    Write-Ok "Үүсгэв: $BackupDir"
} else {
    Write-Ok "Бэлэн: $BackupDir"
}

$envCurrent = [Environment]::GetEnvironmentVariable('OLYMP_BACKUP_DIR','User')
if ($envCurrent -ne $BackupDir) {
    [Environment]::SetEnvironmentVariable('OLYMP_BACKUP_DIR', $BackupDir, 'User')
    Write-Ok "User ENV OLYMP_BACKUP_DIR=$BackupDir тавив"
} else {
    Write-Ok "User ENV OLYMP_BACKUP_DIR аль хэдийн зөв"
}

# ----- 5) VS Code extensions -----
Write-Step "5/6 VS Code extensions"
if ($NoExtensions) {
    Write-Skip "-NoExtensions флаг идэвхтэй"
} elseif (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Skip "code CLI алга — VS Code суулгасны дараа дахин ажиллуул"
} else {
    $wanted = @(
        'fabiospampinato.vscode-highlight',
        'auchenberg.vscode-browser-preview',
        'anthropic.claude-code'
    )
    $installed = code --list-extensions 2>$null
    foreach ($ext in $wanted) {
        if ($installed -contains $ext) {
            Write-Ok "extension: $ext"
        } else {
            try {
                code --install-extension $ext --force | Out-Null
                Write-Ok "extension суулгав: $ext"
            } catch {
                Write-Fail "$ext суулгаж чадсангүй: $($_.Exception.Message)"
            }
        }
    }
}

# ----- 6) Telnet handler .reg -----
Write-Step "6/6 EVE-NG telnet:// handler"
$regFile = Join-Path $RepoRoot 'EVE-NG\win10_64bit_sCRT.reg'
if ($SkipReg) {
    Write-Skip "-SkipReg флаг идэвхтэй"
} elseif (-not (Test-Path $regFile)) {
    Write-Skip "Reg файл алга: $regFile"
} else {
    Write-Host "telnet:// URL-ийг SecureCRT-руу redirect хийх .reg файл бэлэн:"
    Write-Host "    $regFile"
    Write-Host "Manual merge:  Explorer-ээс double-click эсвэл:"
    Write-Host "    reg import `"$regFile`""
    Write-Skip "Auto-merge хийгээгүй (admin-prompt бүтэхгүй) — manual үйлдлээр merge хий"
}

# ----- summary -----
Write-Step "Дараагийн алхам"
@'
  1. SecureCRT-г дахин нээж Sessions tree-н доор pod-template/R1..SW3 гарч байгаа эсэх
  2. Button Bar дээр BACKUP / PUSH / clean_ALL товч харагдаж буй эсэх
  3. .reg файлыг merge хийсний дараа: EVE-NG web UI-аас "Connect" → SecureCRT нээгдэх
  4. PowerShell-ийг шинээр нээж: $env:OLYMP_BACKUP_DIR-ыг echo хийж шалга
  5. SecureCRT GUI: Script → Run → Scripts\backup_configs.vbs (Windows VBS)
  6. Claude Code: VS Code дотор Ctrl+Esc → Sign in
'@
