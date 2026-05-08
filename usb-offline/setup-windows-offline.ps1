<#
.SYNOPSIS
    Offline bootstrap for the olympiad Windows machine: Python + netmiko + Graphviz.

.DESCRIPTION
    Modes:
      A. Existing Python detected -> install offline wheels matching its version.
         (3.10 -> wheels-py310, 3.11 -> wheels-py311, 3.12 -> wheels, 3.13 -> wheels-py313)
      B. No Python  -> run full installer (no-admin via InstallAllUsers=0).
      C. B fails    -> unzip embed Python + bootstrap pip via get-pip.py.
      Diagnose      -> -Diagnose flag prints state only, installs nothing.

    Pre-flight:
      Bundle integrity, curl/tar built-in, PowerShell version, AV/Defender,
      execution policy, disk space.

.PARAMETER InstallRoot
    Default: %USERPROFILE%\PyOlymp

.PARAMETER PythonVersion
    Bundle includes 3.10 / 3.11 / 3.12 (default) / 3.13.

.PARAMETER ForceEmbed
    Skip full installer, use embed Python only.

.PARAMETER SkipPython
    Assume Python is already in PATH.

.PARAMETER Diagnose
    Print system state, do not install.

.EXAMPLE
    PS> .\setup-windows-offline.ps1
    PS> .\setup-windows-offline.ps1 -PythonVersion 3.11
    PS> .\setup-windows-offline.ps1 -Diagnose
    PS> .\setup-windows-offline.ps1 -ForceEmbed
#>

[CmdletBinding()]
param(
    [string]$InstallRoot = "$env:USERPROFILE\PyOlymp",
    [ValidateSet('3.10','3.11','3.12','3.13','auto')]
    [string]$PythonVersion = '3.12',
    [switch]$ForceEmbed,
    [switch]$SkipPython,
    [switch]$Diagnose
)

$VERSION_MAP = @{
    '3.10' = @{ Full = 'python-3.10.11-amd64.exe'; Embed = 'python-3.10.11-embed-amd64.zip'; Tag = '310' }
    '3.11' = @{ Full = 'python-3.11.9-amd64.exe';  Embed = 'python-3.11.9-embed-amd64.zip';  Tag = '311' }
    '3.12' = @{ Full = 'python-3.12.7-amd64.exe';  Embed = 'python-3.12.7-embed-amd64.zip';  Tag = '312' }
    '3.13' = @{ Full = 'python-3.13.1-amd64.exe';  Embed = 'python-3.13.1-embed-amd64.zip';  Tag = '313' }
}

$ErrorActionPreference = 'Continue'
$BundleDir = $PSScriptRoot

function Write-OK    ($m) { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Write-Skip  ($m) { Write-Host "[SKIP] $m" -ForegroundColor Yellow }
function Write-Fail  ($m) { Write-Host "[FAIL] $m" -ForegroundColor Red }
function Write-Warn  ($m) { Write-Host "[WARN] $m" -ForegroundColor DarkYellow }
function Write-Step  ($m) { Write-Host ">>> $m" -ForegroundColor Cyan }
function Write-Info  ($m) { Write-Host "      $m" -ForegroundColor Gray }

Write-Host ""
Write-Host "============================================================"
Write-Host " net/ olympiad - Windows offline bootstrap"
Write-Host " bundle: $BundleDir"
Write-Host " target: $InstallRoot"
if ($Diagnose) { Write-Host " mode:   DIAGNOSE (no install)" -ForegroundColor Yellow }
Write-Host "============================================================"
Write-Host ""

# ----------------------------------------------------------------------------
# 0. PRE-FLIGHT
# ----------------------------------------------------------------------------
Write-Step "Pre-flight checks"

# 0.1 PowerShell version
$psv = $PSVersionTable.PSVersion
if ($psv.Major -lt 5) {
    Write-Fail "PowerShell version $psv too old. Need 5.1 or newer."
    exit 1
}
Write-OK "PowerShell $psv"

# 0.2 curl + tar (Windows 10 1803+)
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
$tar  = Get-Command tar.exe  -ErrorAction SilentlyContinue
if (-not $curl) { Write-Warn "curl.exe not found (default in Windows 10 1803+)" } else { Write-OK "curl.exe -> $($curl.Source)" }
if (-not $tar)  { Write-Warn "tar.exe not found"  } else { Write-OK "tar.exe -> $($tar.Source)" }

# 0.3 Bundle integrity
$missing = @()
foreach ($req in @('wheels','python-full','python-embed','graphviz')) {
    if (-not (Test-Path "$BundleDir\$req")) { $missing += $req }
}
if ($missing.Count -gt 0) {
    Write-Fail "Bundle missing folders: $($missing -join ', ')"
    Write-Info "Expected location: $BundleDir"
    exit 1
}
Write-OK "Bundle complete ($BundleDir)"

# 0.4 Disk space (need ~300MB)
$drive = (Get-Item $env:USERPROFILE).PSDrive
$free  = [math]::Round((Get-PSDrive $drive.Name).Free / 1MB, 0)
if ($free -lt 300) {
    Write-Warn "Drive $($drive.Name): has $free MB free - 300MB+ recommended"
} else {
    Write-OK "Disk: $free MB free on $($drive.Name):"
}

# 0.5 Antivirus
$av = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($av) {
    if ($av.RealTimeProtectionEnabled) {
        Write-Warn "Windows Defender Real-Time Protection ON - may slow Python installer scan (a few sec)"
    } else {
        Write-OK "Windows Defender RTP off"
    }
}

# 0.6 Execution policy
$ep = Get-ExecutionPolicy -Scope Process
if ($ep -eq 'Restricted') {
    Write-Fail "Execution policy = Restricted. Bypass with:"
    Write-Info "  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force"
    if (-not $Diagnose) { exit 1 }
}
Write-OK "ExecutionPolicy (Process scope) = $ep"

if ($Diagnose) {
    Write-Step "DIAGNOSE mode - Python state"
    $pys = Get-Command python.exe, python3.exe, py.exe -All -ErrorAction SilentlyContinue
    if ($pys) {
        foreach ($py in $pys) {
            $v = & $py.Source --version 2>&1
            Write-Info "$($py.Source): $v"
        }
    } else {
        Write-Info "No Python in PATH"
    }
    foreach ($v in @('310','311','312','313')) {
        if (Test-Path "$InstallRoot\Python$v\python.exe") {
            Write-OK "Bundled Python $v installed -> $InstallRoot\Python$v\python.exe"
        }
    }
    if (Test-Path "$InstallRoot\python-portable\python.exe") {
        Write-OK "Bundled embed Python -> $InstallRoot\python-portable\python.exe"
    }
    if (Test-Path "$InstallRoot\graphviz\bin\dot.exe") {
        Write-OK "Bundled Graphviz -> $InstallRoot\graphviz\bin\dot.exe"
    }
    Write-Host ""
    Write-Host "Diagnose done. Re-run without -Diagnose to install." -ForegroundColor Cyan
    exit 0
}

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null

# ----------------------------------------------------------------------------
# 1. PYTHON DETECT / INSTALL
# ----------------------------------------------------------------------------
$PYTHON_EXE = $null
$PYTHON_VER = $null

function Get-PythonVersion($exe) {
    try {
        $v = & $exe --version 2>&1
        if ($v -match "Python (\d+)\.(\d+)") {
            return @{ Major=[int]$matches[1]; Minor=[int]$matches[2]; Tag="$($matches[1])$($matches[2])"; Full=$v }
        }
    } catch {}
    return $null
}

function Get-WheelsDir($tag) {
    $candidate = "$BundleDir\wheels-py$tag"
    if (Test-Path $candidate) { return $candidate }
    return "$BundleDir\wheels"
}

if (-not $SkipPython) {
    Write-Step "Step 1/6 - Python detect / install"

    $existing = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($existing -and -not $ForceEmbed) {
        $info = Get-PythonVersion $existing.Source
        if ($info -and $info.Major -eq 3 -and $info.Minor -ge 10 -and $info.Minor -le 13) {
            Write-OK "Python found: $($info.Full)  ($($existing.Source))"
            $PYTHON_EXE = $existing.Source
            $PYTHON_VER = $info.Tag
        } elseif ($info) {
            Write-Warn "Python $($info.Full) found but bundle wheels cover only 3.10-3.13"
        }
    }

    if (-not $PYTHON_EXE) {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

        $vmap = $VERSION_MAP[$PythonVersion]
        if (-not $vmap) {
            Write-Fail "Unknown PythonVersion: $PythonVersion"; exit 1
        }
        $fullInst = Get-Item "$BundleDir\python-full\$($vmap.Full)" -ErrorAction SilentlyContinue
        $targetVer = $vmap.Tag

        if (-not $fullInst) {
            $fullInst = Get-ChildItem "$BundleDir\python-full\python-*-amd64.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($fullInst) {
                Write-Warn "Requested $PythonVersion installer missing; auto-fallback: $($fullInst.Name)"
            }
        }

        if ($fullInst -and -not $ForceEmbed) {
            Write-Step "Running full installer: $($fullInst.Name)"
            Write-Info "(Per-user install - no admin needed; ~30-60s)"
            $logFile = "$env:TEMP\python-install.log"
            $targetDir = "$InstallRoot\Python$targetVer"
            $instArgs = @(
                '/quiet',
                'InstallAllUsers=0',
                'PrependPath=1',
                'Include_test=0',
                'Include_doc=0',
                'Include_launcher=0',
                "TargetDir=$targetDir",
                '/log',
                "$logFile"
            )
            $proc = Start-Process -FilePath $fullInst.FullName -ArgumentList $instArgs -Wait -PassThru -ErrorAction SilentlyContinue
            if ($proc -and $proc.ExitCode -eq 0 -and (Test-Path "$targetDir\python.exe")) {
                $PYTHON_EXE = "$targetDir\python.exe"
                $PYTHON_VER = $targetVer
                Write-OK "Python full installer OK -> $PYTHON_EXE"
            } else {
                $code = if ($proc) { $proc.ExitCode } else { '?' }
                Write-Warn "Full installer failed (exit=$code) - log: $logFile"
                Write-Info "Possible causes: AV block, UAC denied, disk full"
                Write-Info "Falling back to embed Python..."
            }
        }

        if (-not $PYTHON_EXE) {
            $embedZip = Get-Item "$BundleDir\python-embed\$($vmap.Embed)" -ErrorAction SilentlyContinue
            if (-not $embedZip) {
                $embedZip = Get-ChildItem "$BundleDir\python-embed\python-*-embed-amd64.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($embedZip) { Write-Warn "Requested $PythonVersion embed missing; auto-fallback: $($embedZip.Name)" }
            }
            if (-not $embedZip) { Write-Fail "python-embed .zip missing"; exit 1 }

            $portDir = "$InstallRoot\python-portable"
            if (Test-Path $portDir) { Remove-Item -Recurse -Force $portDir -ErrorAction SilentlyContinue }
            Write-Step "Unzipping embed Python: $($embedZip.Name) -> $portDir"
            try {
                Expand-Archive -Path $embedZip.FullName -DestinationPath $portDir -Force
            } catch {
                Write-Fail "Embed unzip failed: $_"
                Write-Info "Manual: unzip the .zip to $portDir using File Explorer"
                exit 1
            }

            # Edit _pth file to enable site-packages import
            $pth = Get-ChildItem "$portDir\python*._pth" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($pth) {
                $content = Get-Content $pth.FullName
                $content = $content -replace '^#\s*import site', 'import site'
                if ($content -notcontains 'Lib\site-packages') { $content += 'Lib\site-packages' }
                $content | Set-Content -Path $pth.FullName -Encoding ASCII
                Write-OK "_pth file edited to enable site-packages ($($pth.FullName))"
            } else {
                Write-Warn "_pth file not found - pip may not work"
            }

            # Bootstrap pip with get-pip.py
            $py = "$portDir\python.exe"
            $getPip = "$BundleDir\wheels\get-pip.py"
            if (-not (Test-Path $getPip)) {
                Write-Fail "wheels\get-pip.py missing - cannot bootstrap pip"
                exit 1
            }
            $bootstrapWheels = "$BundleDir\wheels-py$targetVer"
            if (-not (Test-Path $bootstrapWheels)) { $bootstrapWheels = "$BundleDir\wheels" }
            Write-Step "pip bootstrap: $getPip (wheels: $bootstrapWheels)"
            & $py $getPip --no-index --find-links="$bootstrapWheels" 2>&1 | Out-Host
            if ($LASTEXITCODE -ne 0) {
                Write-Fail "pip bootstrap failed (exit $LASTEXITCODE)"
                Write-Info "Manual: $py -m ensurepip"
                exit 1
            }
            $PYTHON_EXE = $py
            $PYTHON_VER = $targetVer
            Write-OK "Embed Python ready -> $PYTHON_EXE"
        }
    }
} else {
    $existing = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($existing) {
        $PYTHON_EXE = $existing.Source
        $info = Get-PythonVersion $PYTHON_EXE
        if ($info) { $PYTHON_VER = $info.Tag }
    }
    Write-Skip "Python step skipped"
}

if (-not $PYTHON_EXE) { Write-Fail "Python not found; install failed"; exit 1 }

# ----------------------------------------------------------------------------
# 2. PIP install netmiko + pyyaml (offline)
# ----------------------------------------------------------------------------
Write-Step "Step 2/6 - install netmiko + pyyaml (offline wheels)"

$wheelsDir = Get-WheelsDir $PYTHON_VER
Write-Info "Python version tag: $PYTHON_VER, wheels dir: $wheelsDir"

# Build the import-check command as a simple string (avoid PS string interpolation conflicts)
$importCheckCmd = 'import netmiko, yaml; print("netmiko", netmiko.__version__, "yaml", yaml.__version__)'

$check = & $PYTHON_EXE -c $importCheckCmd 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-OK "Already installed: $check"
} else {
    & $PYTHON_EXE -m pip install --no-index --find-links="$wheelsDir" netmiko pyyaml 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Primary wheels dir failed - falling back to default wheels (3.12)"
        & $PYTHON_EXE -m pip install --no-index --find-links="$BundleDir\wheels" netmiko pyyaml 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "pip install failed from all wheel dirs"
            Write-Info "Manual: $PYTHON_EXE -m pip install --no-index --find-links=$wheelsDir netmiko pyyaml"
            Write-Info "If wheel Python version mismatch - upgrade Python to 3.12"
            exit 1
        }
    }
    $check = & $PYTHON_EXE -c $importCheckCmd 2>&1
    Write-OK $check
}

# ----------------------------------------------------------------------------
# 3. GRAPHVIZ portable
# ----------------------------------------------------------------------------
Write-Step "Step 3/6 - Graphviz portable unzip"

$gvDir = "$InstallRoot\graphviz"
if (Test-Path "$gvDir\bin\dot.exe") {
    Write-Skip "Graphviz already installed: $gvDir\bin\dot.exe"
} else {
    $gvZip = Get-ChildItem "$BundleDir\graphviz\*Graphviz*win64.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $gvZip) { Write-Fail "graphviz zip not found"; exit 1 }
    if (Test-Path $gvDir) { Remove-Item -Recurse -Force $gvDir -ErrorAction SilentlyContinue }
    try {
        Expand-Archive -Path $gvZip.FullName -DestinationPath "$InstallRoot\graphviz-tmp" -Force
        $inner = Get-ChildItem "$InstallRoot\graphviz-tmp" -Directory | Select-Object -First 1
        Move-Item $inner.FullName $gvDir
        Remove-Item -Recurse -Force "$InstallRoot\graphviz-tmp" -ErrorAction SilentlyContinue
        Write-OK "Graphviz unzipped -> $gvDir"
    } catch {
        Write-Fail "Graphviz unzip error: $_"
        Write-Info "Manual: extract $($gvZip.FullName) to $gvDir using File Explorer"
    }
}

# ----------------------------------------------------------------------------
# 4. PATH (current session + user persistent)
# ----------------------------------------------------------------------------
Write-Step "Step 4/6 - PATH update"

$prepend = @()
$pyDir = Split-Path -Parent $PYTHON_EXE
if ($env:PATH -notlike "*$pyDir*") { $prepend += $pyDir }
if ($env:PATH -notlike "*$pyDir\Scripts*") { $prepend += "$pyDir\Scripts" }
if ($env:PATH -notlike "*$gvDir\bin*") { $prepend += "$gvDir\bin" }

if ($prepend.Count -gt 0) {
    $env:PATH = ($prepend -join ';') + ';' + $env:PATH
    Write-OK ("Session PATH prepended: " + ($prepend -join '; '))
}

try {
    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    $missing = @()
    foreach ($p in $prepend) { if ($userPath -notlike "*$p*") { $missing += $p } }
    if ($missing.Count -gt 0) {
        [Environment]::SetEnvironmentVariable('Path', (($missing -join ';') + ';' + $userPath), 'User')
        Write-OK "User PATH persisted (active in new shells)"
    } else {
        Write-Skip "User PATH already correct"
    }
} catch {
    Write-Warn "Could not persist User PATH: $_"
    Write-Info "Manual: Settings -> Environment Variables -> User -> Path -> add $pyDir, $pyDir\Scripts, $gvDir\bin"
}

# ----------------------------------------------------------------------------
# 5. SMOKE TEST
# ----------------------------------------------------------------------------
Write-Step "Step 5/6 - smoke test"

$ok = $true
$fails = @()

try {
    $r = & $PYTHON_EXE -c 'import netmiko, yaml; print("netmiko", netmiko.__version__)'
    Write-OK "Python netmiko: $r"
} catch { Write-Fail "netmiko import: $_"; $ok = $false; $fails += "netmiko import" }

try {
    $r = & "$gvDir\bin\dot.exe" -V 2>&1
    Write-OK "Graphviz: $r"
} catch { Write-Fail "dot: $_"; $ok = $false; $fails += "graphviz dot" }

try {
    $r = & curl.exe --version 2>&1 | Select-Object -First 1
    Write-OK "curl: $r"
} catch { Write-Fail "curl: $_"; $ok = $false; $fails += "curl" }

try {
    $r = & tar.exe --version 2>&1 | Select-Object -First 1
    Write-OK "tar: $r"
} catch { Write-Fail "tar: $_"; $ok = $false; $fails += "tar" }

# ----------------------------------------------------------------------------
# 6. SUMMARY
# ----------------------------------------------------------------------------
Write-Host ""
Write-Step "Step 6/6 - summary"

if ($ok) {
    Write-OK "All checks passed. Olympiad toolkit ready."
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. EVE-NG pre-flight:"
    Write-Host "     python ${env:USERPROFILE}\net\scripts\diagnose-eve.py --host 10.X.Y.Z --check-nodes"
    Write-Host "  2. Auto-emit inventory:"
    Write-Host "     python scripts\diagnose-eve.py --host 10.X.Y.Z --emit-inventory > olymp-day\lab-XX\inventory.yml"
    Write-Host "  3. Backup configs:"
    Write-Host "     python scripts\netmiko_backup.py olymp-day\lab-XX\inventory.yml"
    Write-Host ""
    Write-Host "Persistent paths:"
    Write-Host "  Python:   $PYTHON_EXE  (version $PYTHON_VER)"
    Write-Host "  Graphviz: $gvDir\bin\dot.exe"
    Write-Host "  Wheels:   $wheelsDir"
} else {
    Write-Fail "Failed checks: $($fails -join ', ')"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - usb-offline\TROUBLESHOOTING.md has fixes for each symptom"
    Write-Host "  - .\setup-windows-offline.ps1 -Diagnose                # re-check state"
    Write-Host "  - .\setup-windows-offline.ps1 -ForceEmbed               # if admin path conflict"
    exit 1
}
