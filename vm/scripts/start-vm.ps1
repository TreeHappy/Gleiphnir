# vm/scripts/start-vm.ps1 — launch QEMU (bridge/TAP on Linux, KVM)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

if (Test-VmRunning) {
    Write-Error "VM already appears to be running (pid file $PID_FILE or matching process).`nUse: mise run vm:info / mise run vm:stop"
}

Require-BaseImage
Start-OtelSpan 'gleiphnir.start_vm' @{ 'script.name' = 'start-vm.ps1'; 'service.name' = $env:OTEL_SERVICE_NAME }
try {

if ((-not (Test-Path -LiteralPath $SYSTEM_DISK)) -or (-not (Test-Path -LiteralPath $DATA_DISK)) -or (-not (Test-Path -LiteralPath $SEED_ISO))) {
    Write-Host "Disks or seed ISO missing. Running prepare step first ..."
    & (Join-Path $PSScriptRoot 'prepare-vm.ps1')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$vmMac = Get-VmMac

# ── ensure networking (bridge mode only) ───────────────────────────────────
if (-not (Test-Path '/dev/net/tun')) {
    Write-Error "/dev/net/tun not available — bridge mode requires TAP support."
}

$null = & ip link show $BRIDGE_NAME 2>$null
$bridgeExists = ($LASTEXITCODE -eq 0)
if (-not $bridgeExists) {
    Write-Host "Bridge $BRIDGE_NAME not found — creating (requires sudo) ..."
    $isRoot = ((& id -u) -eq '0')
    # Resolve full pwsh path for sudo (mise shims not on sudo PATH)
    $pwshFull = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwshFull) { $pwshFull = 'pwsh' }
    if ($isRoot) {
        & (Join-Path $PSScriptRoot 'network-up.ps1')
    } else {
        & sudo -E $pwshFull -NoProfile -File (Join-Path $PSScriptRoot 'network-up.ps1')
    }
} else {
    Write-Host "Bridge $BRIDGE_NAME exists."
}
# ensure iptables DNAT is present after reboot
$ipt = Get-Command iptables -ErrorAction SilentlyContinue
if ($ipt) {
    & sudo iptables -t nat -C PREROUTING -p tcp --dport $HOST_SSH_FORWARD_PORT -j DNAT --to-destination "${VM_IP}:22" *>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Re-adding iptables DNAT rule ..."
        $pwshFull = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
        if (-not $pwshFull) { $pwshFull = 'pwsh' }
        & sudo -E $pwshFull -NoProfile -File (Join-Path $PSScriptRoot 'network-up.ps1') 2>&1 | Select-Object -Last 5
    }
}

# ── accelerator (Linux: kvm or tcg) ────────────────────────────────────────
$accelArgs = @()
$accelLabel = ''
switch ($env:QEMU_ACCEL) {
    'kvm'   { $accelArgs = @('-enable-kvm','-cpu','host'); $accelLabel='kvm' }
    'tcg'   { $accelArgs = @('-cpu','qemu64'); $accelLabel='tcg' }
    default {
        if (Test-Path '/dev/kvm') { $accelArgs = @('-enable-kvm','-cpu','host'); $accelLabel='kvm' }
        else { Write-Warning "/dev/kvm not available — VM will run in slow TCG mode."; $accelArgs = @('-cpu','qemu64'); $accelLabel='tcg' }
    }
}

# ── network args (bridge/TAP) ──────────────────────────────────────────────
$netArgs = @('-netdev', "tap,id=net0,ifname=$TAP_NAME,script=no,downscript=no",
             '-device', "virtio-net-pci,netdev=net0,mac=$vmMac")

if (-not (Test-Path -LiteralPath $IMAGES_DIR)) { New-Item -ItemType Directory -Path $IMAGES_DIR -Force | Out-Null }

# Monitor target: unix socket
if (Test-Path -LiteralPath $MONITOR_SOCK) { Remove-Item -LiteralPath $MONITOR_SOCK -Force }
$monitorArg = "unix:$MONITOR_SOCK,server,nowait"

$extraArgs = @()
if (-not [string]::IsNullOrWhiteSpace($env:QEMU_EXTRA_ARGS)) {
    $extraArgs = @($env:QEMU_EXTRA_ARGS -split '\s+' | Where-Object { $_ })
}

Write-Host "==> Starting VM $VM_NAME"
Write-Host "  Mode:     bridge"
Write-Host "  CPUs:     $VM_CPUS  RAM: ${VM_RAM_MB}MB"
Write-Host "  Accel:    $accelLabel"
Write-Host "  System:   $SYSTEM_DISK"
Write-Host "  Data:     $DATA_DISK"
Write-Host "  Seed:     $SEED_ISO"
Write-Host "  MAC:      $vmMac"
Write-Host "  Net:      TAP $TAP_NAME → bridge $BRIDGE_NAME → VM $VM_IP (host :$HOST_SSH_FORWARD_PORT → VM :22)"
Write-Host "  QEMU:     $QEMU_BIN $($accelArgs -join ' ')"
Write-Host "  Monitor:  $(Get-MonitorDescription)"
Write-Host "  Console:  $CONSOLE_LOG"
Write-Host ""

$qemuArgs = @(
    '-name', $VM_NAME
) + $accelArgs + @(
    '-smp', $VM_CPUS,
    '-m', $VM_RAM_MB,
    "-drive", "file=${SYSTEM_DISK},if=virtio,format=qcow2",
    "-drive", "file=${DATA_DISK},if=virtio,format=qcow2",
    "-drive", "file=${SEED_ISO},if=virtio,format=raw,readonly=on",
    '-boot', 'order=c'
) + $netArgs + @(
    '-display', 'none',
    '-pidfile', $PID_FILE,
    "-serial", "file:${CONSOLE_LOG}",
    '-monitor', $monitorArg
) + $extraArgs

& $QEMU_BIN @qemuArgs -daemonize
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
# Wait briefly for pid file (POSIX path)
for ($i = 0; $i -lt 5; $i++) {
    if (Test-Path -LiteralPath $PID_FILE) { break }
    Start-Sleep -Milliseconds 500
}

if (Test-Path -LiteralPath $PID_FILE) {
    Write-Host "VM started with PID $(Get-Content -LiteralPath $PID_FILE)"
} elseif (Test-VmRunning) {
    Write-Host "VM started (pid file not found but process exists)"
} else {
    Write-Error "VM start may have failed — check $CONSOLE_LOG"
}

Write-Host ""
Write-Host "Console log tail:"
if (Test-Path -LiteralPath $CONSOLE_LOG) {
    Get-Content -LiteralPath $CONSOLE_LOG -Tail 20 -ErrorAction SilentlyContinue
} else {
    Write-Host "(no console output yet)"
}
Write-Host ""
Write-Host "VM should be at $VM_IP (via bridge $BRIDGE_NAME)."
Write-Host "Host forward: ssh -p $HOST_SSH_FORWARD_PORT $($env:ADMIN_USER)@127.0.0.1  (or ssh $($env:ADMIN_USER)@$VM_IP)"
Write-Host "Wait for boot: mise run vm:ssh:wait  (or mise run vm:console to watch boot)"
End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
