<#
.SYNOPSIS
    Олимпиадын Windows машинд бүрэн offline (USB-аас) Python + netmiko + Graphviz суулгах.

.DESCRIPTION
    Боломжит хувилбар:
      Mode A: Existing Python олох → version-тэй тохирсон wheels-folder-аар install
              (3.10 → wheels-py310, 3.11 → wheels-py311, 3.12 → wheels, 3.13 → wheels-py313)
      Mode B: Python алга → full installer (admin OR no-admin)
      Mode C: B fail → embed Python + get-pip bootstrap
      Diagnose: -Diagnose flag — юу install хийхгүй, зөвхөн төлөв report хийнэ

    Шалгалтууд:
      ✓ Bundle бүрэн уу
      ✓ Curl/tar built-in
      ✓ PowerShell version
      ✓ Antivirus / Defender блоклож байгаа эсэх
      ✓ Disk space хүрэлцэх

.PARAMETER InstallRoot
    Default: %USERPROFILE%\PyOlymp

.PARAMETER ForceEmbed
    Force embed Python install (no-admin path).

.PARAMETER SkipPython
    Skip Python install (assume present in PATH).

.PARAMETER Diagnose
    Зөвхөн system шалгана, install хийхгүй.

.EXAMPLE
    PS> .\setup-windows-offline.ps1
    PS> .\setup-windows-offline.ps1 -Diagnose
    PS> .\setup-windows-offline.ps1 -ForceEmbed
#>

[CmdletBinding()]
param(
    [string]$InstallRoot = "$env:USERPROFILE\PyOlymp",
    [switch]$ForceEmbed,
    [switch]$SkipPython,
    [switch]$Diagnose
)

$ErrorActionPreference = 'Continue'   # don't bail on first error
$BundleDir = $PSScriptRoot

function Write-OK    ($m) { Write-Host "[ OK ] $m" -ForegroundColor Green }
function Write-Skip  ($m) { Write-Host "[SKIP] $m" -ForegroundColor Yellow }
function Write-Fail  ($m) { Write-Host "[FAIL] $m" -ForegroundColor Red }
function Write-Warn  ($m) { Write-Host "[WARN] $m" -ForegroundColor DarkYellow }
function Write-Step  ($m) { Write-Host ">>> $m" -ForegroundColor Cyan }
function Write-Info  ($m) { Write-Host "      $m" -ForegroundColor Gray }

Write-Host ""
Write-Host "============================================================"
Write-Host " net/ olympiad — Windows offline bootstrap"
Write-Host " bundle: $BundleDir"
Write-Host " target: $InstallRoot"
if ($Diagnose) { Write-Host " mode:   DIAGNOSE (no install)" -ForegroundColor Yellow }
Write-Host "============================================================"
Write-Host ""

# ────────────────────────────────────────────────────────────────────────────
# 0. PRE-FLIGHT
# ────────────────────────────────────────────────────────────────────────────
Write-Step "Pre-flight шалгалтууд"

# 0.1 PowerShell version
$psv = $PSVersionTable.PSVersion
if ($psv.Major -lt 5) {
    Write-Fail "PowerShell version $psv хэт хуучин. Windows PowerShell 5.1 эсвэл шинэ хэрэгтэй."
    exit 1
}
Write-OK "PowerShell $psv"

# 0.2 Curl + tar (Windows 10 1803+)
$curl = Get-Command curl.exe -ErrorAction SilentlyContinue
$tar = Get-Command tar.exe -ErrorAction SilentlyContinue
if (-not $curl) { Write-Warn "curl.exe олдсонгүй (Windows 10 1803+ default-аар орно)" } else { Write-OK "curl.exe → $($curl.Source)" }
if (-not $tar)  { Write-Warn "tar.exe олдсонгүй"  } else { Write-OK "tar.exe → $($tar.Source)" }

# 0.3 Bundle бүрэн уу
$missing = @()
foreach ($req in @('wheels','python-full','python-embed','graphviz')) {
    if (-not (Test-Path "$BundleDir\$req")) { $missing += $req }
}
if ($missing.Count -gt 0) {
    Write-Fail "Bundle дотор дутуу folder: $($missing -join ', ')"
    Write-Info "Хүлээж байсан зам: $BundleDir"
    exit 1
}
Write-OK "Bundle бүрэн ($BundleDir)"

# 0.4 Disk space шалгах (~200MB хэрэгтэй)
$drive = (Get-Item $env:USERPROFILE).PSDrive
$free  = [math]::Round((Get-PSDrive $drive.Name).Free / 1MB, 0)
if ($free -lt 300) {
    Write-Warn "Бичигдэх drive ($($drive.Name)) дээр $free MB үлдсэн — 300MB+ зөвлөж байна"
} else {
    Write-OK "Disk: $free MB free on $($drive.Name):"
}

# 0.5 Antivirus тэмдэглэгээ
$av = Get-MpComputerStatus -ErrorAction SilentlyContinue
if ($av) {
    if ($av.RealTimeProtectionEnabled) {
        Write-Warn "Windows Defender Real-Time Protection ON — Python installer-ыг scan-аар саатуулж магадгүй (хэдэн секунд)"
    } else {
        Write-OK "Windows Defender RTP off"
    }
}

# 0.6 Execution policy
$ep = Get-ExecutionPolicy -Scope Process
if ($ep -eq 'Restricted') {
    Write-Fail "Execution policy = Restricted. Дараах командаар bypass хийнэ:"
    Write-Info "  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force"
    if (-not $Diagnose) { exit 1 }
}
Write-OK "ExecutionPolicy (Process scope) = $ep"

if ($Diagnose) {
    Write-Step "DIAGNOSE mode — Python state шалгана"
    $pys = Get-Command python.exe, python3.exe, py.exe -All -ErrorAction SilentlyContinue
    if ($pys) {
        foreach ($py in $pys) {
            $v = & $py.Source --version 2>&1
            Write-Info "$($py.Source): $v"
        }
    } else {
        Write-Info "PATH дотор Python байхгүй"
    }
    if (Test-Path "$InstallRoot\Python312\python.exe") {
        Write-OK "Bundled Python 3.12 байна → $InstallRoot\Python312\python.exe"
    }
    if (Test-Path "$InstallRoot\python-portable\python.exe") {
        Write-OK "Bundled Embed Python байна → $InstallRoot\python-portable\python.exe"
    }
    if (Test-Path "$InstallRoot\graphviz\bin\dot.exe") {
        Write-OK "Bundled Graphviz байна → $InstallRoot\graphviz\bin\dot.exe"
    }
    Write-Host ""
    Write-Host "Diagnose дууссан. Установка хэрэгтэй бол -Diagnose flag-гүйгээр дахин ажиллуул." -ForegroundColor Cyan
    exit 0
}

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null

# ────────────────────────────────────────────────────────────────────────────
# 1. PYTHON хувилбар тогтоох / суулгах
# ────────────────────────────────────────────────────────────────────────────
$PYTHON_EXE = $null
$PYTHON_VER = $null     # нэмэх "310" / "311" / "312" / "313"

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
    return "$BundleDir\wheels"   # default 3.12
}

if (-not $SkipPython) {
    Write-Step "Step 1/6 — Python шалгах + суулгах"

    $existing = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($existing -and -not $ForceEmbed) {
        $info = Get-PythonVersion $existing.Source
        if ($info -and $info.Major -eq 3 -and $info.Minor -ge 10 -and $info.Minor -le 13) {
            Write-OK "Python байна: $($info.Full)  ($($existing.Source))"
            $PYTHON_EXE = $existing.Source
            $PYTHON_VER = $info.Tag
        } elseif ($info) {
            Write-Warn "Python $($info.Full) олдсон, гэхдээ wheels 3.10-3.13 хүртэл л зориулагдсан"
        }
    }

    if (-not $PYTHON_EXE) {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        $fullInst = Get-ChildItem "$BundleDir\python-full\python-*-amd64.exe" -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($fullInst -and -not $ForceEmbed) {
            Write-Step "Full installer ажиллуулна: $($fullInst.Name)"
            Write-Info "(Хэрэглэгчийн install — admin шаардлагагүй; 30-60s болно)"
            $logFile = "$env:TEMP\python-install.log"
            $args = @(
                '/quiet',
                'InstallAllUsers=0',
                'PrependPath=1',
                'Include_test=0',
                'Include_doc=0',
                'Include_launcher=0',
                "TargetDir=$InstallRoot\Python312",
                "/log",
                "$logFile"
            )
            $proc = Start-Process -FilePath $fullInst.FullName -ArgumentList $args -Wait -PassThru -ErrorAction SilentlyContinue
            if ($proc -and $proc.ExitCode -eq 0 -and (Test-Path "$InstallRoot\Python312\python.exe")) {
                $PYTHON_EXE = "$InstallRoot\Python312\python.exe"
                $PYTHON_VER = "312"
                Write-OK "Python full installer амжилттай → $PYTHON_EXE"
            } else {
                $code = if ($proc) { $proc.ExitCode } else { "?" }
                Write-Warn "Full installer fail (exit=$code) — лог: $logFile"
                Write-Info "Шалтгаан байж магадгүй: AV блок, UAC, диск дүүрсэн"
                Write-Info "Embed fallback ашиглана..."
            }
        }

        if (-not $PYTHON_EXE) {
            $embedZip = Get-ChildItem "$BundleDir\python-embed\python-*-embed-amd64.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
            if (-not $embedZip) { Write-Fail "python-embed .zip алга"; exit 1 }

            $portDir = "$InstallRoot\python-portable"
            if (Test-Path $portDir) { Remove-Item -Recurse -Force $portDir -ErrorAction SilentlyContinue }
            Write-Step "Embed Python-ийг unzip: $($embedZip.Name) → $portDir"
            try {
                Expand-Archive -Path $embedZip.FullName -DestinationPath $portDir -Force
            } catch {
                Write-Fail "Embed unzip амжилтгүй: $_"
                Write-Info "Manual: PowerShell-аар File Explorer-аас .zip-ыг гар дэлэн задал → $portDir"
                exit 1
            }

            # _pth file засаж site-packages импорт идэвхжүүлнэ
            $pth = Get-ChildItem "$portDir\python*._pth" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($pth) {
                $content = Get-Content $pth.FullName
                $content = $content -replace '^#\s*import site', 'import site'
                if ($content -notcontains 'Lib\site-packages') { $content += 'Lib\site-packages' }
                $content | Set-Content -Path $pth.FullName -Encoding ASCII
                Write-OK "_pth файлыг засаж site-packages идэвхжүүлсэн ($($pth.FullName))"
            } else {
                Write-Warn "_pth файл олдсонгүй — pip ажиллахгүй магадгүй"
            }

            # get-pip.py-аар pip bootstrap
            $py = "$portDir\python.exe"
            $getPip = "$BundleDir\wheels\get-pip.py"
            if (-not (Test-Path $getPip)) {
                Write-Fail "wheels\get-pip.py алга — embed Python-д pip суулгаж чадахгүй"
                exit 1
            }
            Write-Step "pip bootstrap: $getPip"
            & $py $getPip --no-index --find-links="$BundleDir\wheels" 2>&1 | Out-Host
            if ($LASTEXITCODE -ne 0) {
                Write-Fail "pip bootstrap амжилтгүй (exit $LASTEXITCODE)"
                Write-Info "Manual: $py -m ensurepip эсвэл .whl-ийг гар хуулах"
                exit 1
            }
            $PYTHON_EXE = $py
            $PYTHON_VER = "312"
            Write-OK "Embed Python бэлэн → $PYTHON_EXE"
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

if (-not $PYTHON_EXE) { Write-Fail "Python олдсонгүй; install fail"; exit 1 }

# ────────────────────────────────────────────────────────────────────────────
# 2. PIP install netmiko + pyyaml (offline)
# ────────────────────────────────────────────────────────────────────────────
Write-Step "Step 2/6 — netmiko + pyyaml install (offline wheels)"

$wheelsDir = Get-WheelsDir $PYTHON_VER
Write-Info "Python хувилбар: $PYTHON_VER, wheels folder: $wheelsDir"

$check = & $PYTHON_EXE -c "import netmiko, yaml; print('netmiko', netmiko.__version__, 'yaml', yaml.__version__)" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-OK "Аль хэдийн суусан: $check"
} else {
    & $PYTHON_EXE -m pip install --no-index --find-links="$wheelsDir" netmiko pyyaml 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Primary wheels folder fail — fallback default wheels (3.12) ашиглана"
        & $PYTHON_EXE -m pip install --no-index --find-links="$BundleDir\wheels" netmiko pyyaml 2>&1 | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Write-Fail "pip install бүх wheels-ээс fail"
            Write-Info "Manual: $PYTHON_EXE -m pip install --no-index --find-links=$wheelsDir netmiko pyyaml"
            Write-Info "Хэрэв wheels-ийн Python хувилбар тохирохгүй бол Python-ийг 3.12-руу update хий"
            exit 1
        }
    }
    $check = & $PYTHON_EXE -c "import netmiko, yaml; print('netmiko', netmiko.__version__, 'yaml', yaml.__version__)" 2>&1
    Write-OK $check
}

# ────────────────────────────────────────────────────────────────────────────
# 3. GRAPHVIZ portable
# ────────────────────────────────────────────────────────────────────────────
Write-Step "Step 3/6 — Graphviz portable unzip"

$gvDir = "$InstallRoot\graphviz"
if (Test-Path "$gvDir\bin\dot.exe") {
    Write-Skip "Graphviz аль хэдийн байна: $gvDir\bin\dot.exe"
} else {
    $gvZip = Get-ChildItem "$BundleDir\graphviz\*Graphviz*win64.zip" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $gvZip) { Write-Fail "graphviz zip олдсонгүй"; exit 1 }
    if (Test-Path $gvDir) { Remove-Item -Recurse -Force $gvDir -ErrorAction SilentlyContinue }
    try {
        Expand-Archive -Path $gvZip.FullName -DestinationPath "$InstallRoot\graphviz-tmp" -Force
        $inner = Get-ChildItem "$InstallRoot\graphviz-tmp" -Directory | Select-Object -First 1
        Move-Item $inner.FullName $gvDir
        Remove-Item -Recurse -Force "$InstallRoot\graphviz-tmp" -ErrorAction SilentlyContinue
        Write-OK "Graphviz unzipped → $gvDir"
    } catch {
        Write-Fail "Graphviz unzip алдаа: $_"
        Write-Info "Manual: File Explorer-аас $($gvZip.FullName)-ыг $gvDir руу гар дэлэн задал"
    }
}

# ────────────────────────────────────────────────────────────────────────────
# 4. PATH (current session + user persistent)
# ────────────────────────────────────────────────────────────────────────────
Write-Step "Step 4/6 — Session PATH-руу нэмэх"

$prepend = @()
$pyDir = Split-Path -Parent $PYTHON_EXE
if ($env:PATH -notlike "*$pyDir*") { $prepend += $pyDir }
if ($env:PATH -notlike "*$pyDir\Scripts*") { $prepend += "$pyDir\Scripts" }
if ($env:PATH -notlike "*$gvDir\bin*") { $prepend += "$gvDir\bin" }

if ($prepend.Count -gt 0) {
    $env:PATH = ($prepend -join ';') + ';' + $env:PATH
    Write-OK ("Session PATH нэмэгдсэн: " + ($prepend -join '; '))
}

# Persist to user PATH (хэрэглэгчийн next session-д хадгалагдана)
try {
    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    $missing = @()
    foreach ($p in $prepend) { if ($userPath -notlike "*$p*") { $missing += $p } }
    if ($missing.Count -gt 0) {
        [Environment]::SetEnvironmentVariable('Path', (($missing -join ';') + ';' + $userPath), 'User')
        Write-OK "User PATH-д persist хийсэн (шинэ shell-д идэвхжинэ)"
    } else {
        Write-Skip "User PATH аль хэдийн зөв"
    }
} catch {
    Write-Warn "User PATH persist хийж чадсангүй: $_"
    Write-Info "Manual: Settings → Environment Variables → User → Path → $pyDir, $pyDir\Scripts, $gvDir\bin нэм"
}

# ────────────────────────────────────────────────────────────────────────────
# 5. SMOKE TEST
# ────────────────────────────────────────────────────────────────────────────
Write-Step "Step 5/6 — Smoke test"

$ok = $true
$fails = @()

try {
    $r = & $PYTHON_EXE -c "import netmiko, yaml; print('netmiko', netmiko.__version__)"
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

# ────────────────────────────────────────────────────────────────────────────
# 6. SUMMARY
# ────────────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Step 6/6 — Дүгнэлт"

if ($ok) {
    Write-OK "Бүх шалгуур passed. Олимпиадын toolkit бэлэн."
    Write-Host ""
    Write-Host "Дараагийн алхам:" -ForegroundColor Cyan
    Write-Host "  1. EVE-NG IP олох + ажиллаж байгаа эсэхийг шалгах:"
    Write-Host "     python ${env:USERPROFILE}\net\scripts\diagnose-eve.py --host 10.X.Y.Z --check-nodes"
    Write-Host "  2. Inventory yml-ийг авах (auto-emit):"
    Write-Host "     python scripts\diagnose-eve.py --host 10.X.Y.Z --emit-inventory > olymp-day\lab-XX\inventory.yml"
    Write-Host "  3. Backup татах:"
    Write-Host "     python scripts\netmiko_backup.py olymp-day\lab-XX\inventory.yml"
    Write-Host ""
    Write-Host "Persistent installation paths:"
    Write-Host "  Python:   $PYTHON_EXE  (version $PYTHON_VER)"
    Write-Host "  Graphviz: $gvDir\bin\dot.exe"
    Write-Host "  Wheels:   $wheelsDir"
} else {
    Write-Fail "Алдсан тест: $($fails -join ', ')"
    Write-Host ""
    Write-Host "Алдааг шийдэхэд:" -ForegroundColor Yellow
    Write-Host "  - usb-offline\TROUBLESHOOTING.md дотор шинж тэмдэг бүрд тайлбар бий"
    Write-Host "  - .\setup-windows-offline.ps1 -Diagnose                # дахиад шалгах"
    Write-Host "  - .\setup-windows-offline.ps1 -ForceEmbed               # admin зөрчилтэй бол embed"
    exit 1
}
