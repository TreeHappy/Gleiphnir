# vm/scripts/deps.ps1 — check host dependencies (Linux only)
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot 'lib.ps1')

Write-Host "==> Checking host dependencies"
$script:missing = 0

function script:Check-Bin([string[]]$bins) {
    foreach ($b in $bins) {
        $cmd = Get-Command $b -ErrorAction SilentlyContinue
        if ($cmd) {
            "{0,-22} {1}" -f $b, $cmd.Source
            return
        }
    }
    "{0,-22} MISSING" -f $bins[0]
    $script:missing = 1
}

Start-OtelSpan 'gleiphnir.deps' @{ 'script.name' = 'deps.ps1'; 'service.name' = $env:OTEL_SERVICE_NAME }
try {
    Write-Host "  Required on Linux: pwsh, git, curl, ssh, qemu-system-x86_64, qemu-img,"
    Write-Host "                     cloud-localds OR genisoimage OR pycdlib, python3"
    Check-Bin @('git')
    Check-Bin @('curl')
    Check-Bin @('ssh')
    Check-Bin @('qemu-system-x86_64')
    Check-Bin @('qemu-img')
    Check-Bin @('cloud-localds', 'genisoimage', 'mkisofs')
    Check-Bin @('python3', 'python')
    Check-Bin @('mise')
    Write-Host ""
    Write-Host "Optional (for bridged mode): ip, iptables"
    Check-Bin @('ip')
    Check-Bin @('iptables')
    Write-Host ""
    if (-not ((Get-Command cloud-localds -ErrorAction SilentlyContinue) -or
              (Get-Command genisoimage -ErrorAction SilentlyContinue) -or
              (Get-Command mkisofs -ErrorAction SilentlyContinue))) {
        Write-Host "No native seed-ISO tool found — the pycdlib fallback will be used."
    }

Write-Host ""
$pipPython = (Get-Command python3 -ErrorAction SilentlyContinue) ?? (Get-Command python -ErrorAction SilentlyContinue)
if ($pipPython) {
    & $pipPython.Source -c "import pycdlib" *>$null
    if ($LASTEXITCODE -eq 0) { "  pycdlib               OK" }
    else { "  pycdlib               missing (cross-platform seed-ISO fallback) — pip install pycdlib" }
}

Write-Host ""
if (Get-Command mise -ErrorAction SilentlyContinue) {
    Write-Host "==> mise"
    & mise --version
}
$qemuCmd = Get-Command $QEMU_BIN -ErrorAction SilentlyContinue
    if ($qemuCmd) {
    Write-Host ""
    Write-Host "==> QEMU"
    & $QEMU_BIN --version | Select-Object -First 1
    if (Test-Path '/dev/kvm') { Write-Host "KVM: available (/dev/kvm)" }
    else { Write-Host "KVM: NOT available (VM will be slow TCG)" }
}
    End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
exit 0
