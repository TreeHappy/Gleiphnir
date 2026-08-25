# vm/scripts/vm-info.ps1 — show VM status, PID, network mode, disks
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Write-Host "=== VM info: $VM_NAME ==="
Write-Host "Mode:          $($env:NETWORK_MODE)"
Write-Host "Hostname:      $($env:VM_HOSTNAME)"
Write-Host "Resources:     $VM_CPUS vCPU / ${VM_RAM_MB}MB"
if ($env:NETWORK_MODE -eq 'bridge') {
    Write-Host "Bridge:        $BRIDGE_NAME ($BRIDGE_ADDR/$BRIDGE_NETMASK)  TAP: $TAP_NAME"
}
Write-Host "VM IP:         $VM_IP/$VM_NETMASK  GW: $VM_GATEWAY  MAC: $(Get-VmMac)"
Write-Host "Host forward:  127.0.0.1:$HOST_SSH_FORWARD_PORT → ${VM_IP}:22"
Write-Host "Monitor:       $(Get-MonitorDescription)"
Write-Host "Admin:         $($env:ADMIN_USER)  key: $ADMIN_SSH_KEY_PATH"
Write-Host ""

Write-Host "--- Running ---"
$pids = @(Get-QemuPids | Where-Object { $_ })
if ($pids.Count -gt 0) {
    Write-Host "VM appears RUNNING"
    if (Test-Path -LiteralPath $PID_FILE) { Write-Host "  PID file: $PID_FILE → $(Get-Content -LiteralPath $PID_FILE)" }
    foreach ($procId in $pids) {
        $cmdline = ''
        if (-not $IsWin -and (Test-Path "/proc/$procId/cmdline")) {
            $bytes = [System.IO.File]::ReadAllBytes("/proc/$procId/cmdline")
            $cmdline = [Text.Encoding]::UTF8.GetString(($bytes | ForEach-Object { if ($_ -eq 0) { 32 } else { $_ } }))
        } elseif ($IsWin) {
            $ci = Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue
            $cmdline = "$($ci.CommandLine)"
        }
        Write-Host "  [$procId] $cmdline"
    }
} else {
    Write-Host "VM appears STOPPED"
    if (Test-Path -LiteralPath $PID_FILE) {
        Write-Host "  stale PID file: $PID_FILE ($(Get-Content -LiteralPath $PID_FILE -ErrorAction SilentlyContinue))"
    }
}
Write-Host ""

Write-Host "--- Disks ---"
foreach ($f in @($BASE_IMAGE, $SYSTEM_DISK, $DATA_DISK, $SEED_ISO)) {
    if (Test-Path -LiteralPath $f) {
        Get-Item -LiteralPath $f | ForEach-Object { "{0,10:N1} MB  {1}" -f ($_.Length / 1MB), $_.FullName }
        & qemu-img info $f 2>$null | Where-Object { $_ -match 'virtual size|disk size|backing' } | ForEach-Object { "  $_" }
        Write-Host ""
    } else {
        Write-Host "MISSING: $f"
        Write-Host ""
    }
}

Write-Host "--- Networking ---"
try { & (Join-Path $PSScriptRoot 'network-status.ps1') 2>&1 } catch { }

Write-Host "--- Console log (last 20) ---"
if (Test-Path -LiteralPath $CONSOLE_LOG) {
    Get-Content -LiteralPath $CONSOLE_LOG -Tail 20
} else {
    Write-Host "(no console log yet)"
}
