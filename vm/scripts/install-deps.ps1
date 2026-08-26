# vm/scripts/install-deps.ps1 — install missing host dependencies
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'lib.ps1')

Write-Host "==> Installing host dependencies"
$script:installed = 0
$script:failed = 0

function script:Install-Apt([string[]]$packages, [string]$reason) {
    $missing = @()
    foreach ($pkg in $packages) {
        $check = dpkg -l $pkg 2>$null | Select-String "^ii"
        if (-not $check) { $missing += $pkg }
    }
    if ($missing.Count -eq 0) {
        Write-Host "  $($packages[0])  (already installed)"
        return
    }
    Write-Host "  Installing: $($missing -join ', ') ($reason)"
    sudo apt-get install -y --no-install-recommends @missing
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED to install $($missing -join ', ')" -ForegroundColor Red
        $script:failed++
    } else {
        $script:installed += $missing.Count
    }
}

function script:Ensure-MiseTool([string]$tool, [string]$version = "latest") {
    $current = mise ls $tool 2>$null | Select-String $tool
    if ($current -and $current -match '\S+\s+\S+') {
        Write-Host "  $tool  (already installed via mise)"
        return
    }
    Write-Host "  Installing $tool@$version via mise"
    mise use -g "$tool@$version"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  FAILED to install $tool via mise" -ForegroundColor Red
        $script:failed++
    } else {
        $script:installed++
    }
}

# ── Python (via mise) ──────────────────────────────────────────────────────
Write-Host "`n[1/3] Python"
Ensure-MiseTool "python" "3.12"

# ── System packages (via apt) ──────────────────────────────────────────────
Write-Host "`n[2/3] System packages (apt)"
if ($IsWin) {
    Write-Host "  Skipping apt — on Windows. Install QEMU via winget or scoop."
} else {
    Install-Apt @('qemu-system-x86') "QEMU emulator (qemu-system-x86_64 + qemu-img)"
    Install-Apt @('cloud-utils') "cloud-localds (seed ISO generator)"
    Install-Apt @('genisoimage') "genisoimage (fallback seed ISO generator)"
    Install-Apt @('libicu-dev') "libicu (required by PowerShell)"
    Install-Apt @('iproute2') "ip command (optional, for bridged networking)"
    Install-Apt @('iptables') "iptables (optional, for bridged networking)"
}

# ── pycdlib (Python fallback for seed ISO) ────────────────────────────────
Write-Host "`n[3/3] Python packages"
# Find python with pip — prefer mise python (has pip), then system python
$pyBin = $null
$misePy = (mise which python 2>$null | Select-Object -First 1)
if ($misePy -and (Test-Path -LiteralPath $misePy)) { $pyBin = $misePy }
if (-not $pyBin) {
    $pyBin = (Get-Command python3 -ErrorAction SilentlyContinue)?.Source ??
             (Get-Command python -ErrorAction SilentlyContinue)?.Source
}
if ($pyBin) {
    & $pyBin -c "import pycdlib" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Installing pycdlib via $pyBin (cross-platform seed-ISO fallback)"
        & $pyBin -m pip install --quiet pycdlib 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Retrying with ensurepip..."
            & $pyBin -m ensurepip --upgrade 2>$null
            & $pyBin -m pip install --quiet pycdlib 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  FAILED to install pycdlib" -ForegroundColor Red
            $script:failed++
        } else {
            $script:installed++
        }
    } else {
        Write-Host "  pycdlib  (already installed)"
    }
} else {
    Write-Host "  python3 not found — cannot install pycdlib"
}

# ── summary ────────────────────────────────────────────────────────────────
Write-Host ""
if ($script:failed -gt 0) {
    Write-Host "==> Done with errors ($script:failed package(s) failed to install)" -ForegroundColor Yellow
    exit 1
} elseif ($script:installed -gt 0) {
    Write-Host "==> Done — $script:installed package(s) installed" -ForegroundColor Green
} else {
    Write-Host "==> Done — all dependencies already present" -ForegroundColor Green
}
exit 0
