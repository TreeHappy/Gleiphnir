# vm/scripts/start-vm.ps1 — launch QEMU (bridge/TAP on Linux, user-NAT anywhere)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

if (Test-VmRunning) {
    Write-Error "VM already appears to be running (pid file $PID_FILE or matching process).`nUse: mise run vm:info / mise run vm:stop"
}

Require-BaseImage

if ((-not (Test-Path -LiteralPath $SYSTEM_DISK)) -or (-not (Test-Path -LiteralPath $DATA_DISK)) -or (-not (Test-Path -LiteralPath $SEED_ISO))) {
    Write-Host "Disks or seed ISO missing. Running prepare step first ..."
    & (Join-Path $PSScriptRoot 'prepare-vm.ps1')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$vmMac = Get-VmMac

# ── ensure networking ──────────────────────────────────────────────────────
$networkMode = $env:NETWORK_MODE
if ($IsWin -and $networkMode -eq 'bridge') {
    Write-Warning "NETWORK_MODE=bridge is not supported on native Windows hosts (no TAP/iptables without touching the host)."
    Write-Warning "Forcing user-mode NAT for this run."
    $networkMode = 'user'
}

if ($networkMode -eq 'bridge' -and -not $IsWin) {
    $null = & ip link show $BRIDGE_NAME 2>$null
    $bridgeExists = ($LASTEXITCODE -eq 0)
    if (-not $bridgeExists) {
        Write-Host "Bridge $BRIDGE_NAME not found — creating (requires sudo) ..."
        $isRoot = ((& id -u) -eq '0')
        if ($isRoot) {
            & (Join-Path $PSScriptRoot 'network-up.ps1')
        } else {
            & sudo -E pwsh -NoProfile -File (Join-Path $PSScriptRoot 'network-up.ps1')
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
            & sudo -E pwsh -NoProfile -File (Join-Path $PSScriptRoot 'network-up.ps1') 2>&1 | Select-Object -Last 5
        }
    }
}

# ── accelerator ────────────────────────────────────────────────────────────
$accelArgs = @()
$accelLabel = ''
switch ($env:QEMU_ACCEL) {
    'kvm'   { if ($IsWin) { Write-Warning "QEMU_ACCEL=kvm invalid on Windows — using whpx" ; $accelArgs = @('-accel','whpx','-cpu','host'); $accelLabel='whpx' }
              else    { $accelArgs = @('-enable-kvm','-cpu','host'); $accelLabel='kvm' } }
    'whpx'  { $accelArgs = @('-accel','whpx','-cpu','host'); $accelLabel='whpx' }
    'tcg'   { $accelArgs = @('-cpu','qemu64'); $accelLabel='tcg' }
    default {
        if ($IsWin) { $accelArgs = @('-accel','whpx','-cpu','host'); $accelLabel='whpx'
                      Write-Host "Windows: using WHPX acceleration (enable 'Virtual Machine Platform' for this to work; set QEMU_ACCEL=tcg to force emulation)" }
        elseif (Test-Path '/dev/kvm') { $accelArgs = @('-enable-kvm','-cpu','host'); $accelLabel='kvm' }
        else { Write-Warning "/dev/kvm not available — VM will run in slow TCG mode."; $accelArgs = @('-cpu','qemu64'); $accelLabel='tcg' }
    }
}

# ── network args per mode ──────────────────────────────────────────────────
if ($networkMode -eq 'user') {
    $netArgs = @('-netdev', "user,id=net0,hostfwd=tcp::${HOST_SSH_FORWARD_PORT}-:22,hostname=$($env:VM_HOSTNAME)",
                 '-device', "virtio-net-pci,netdev=net0,mac=$vmMac")
} else {
    $netArgs = @('-netdev', "tap,id=net0,ifname=$TAP_NAME,script=no,downscript=no",
                 '-device', "virtio-net-pci,netdev=net0,mac=$vmMac")
}

if (-not (Test-Path -LiteralPath $IMAGES_DIR)) { New-Item -ItemType Directory -Path $IMAGES_DIR -Force | Out-Null }

# Monitor target: unix socket on Linux, TCP loopback on Windows
$monitorArg = if (Test-MonitorTcp) { "tcp:127.0.0.1:$QEMU_MONITOR_PORT,server,nowait" } else {
    if (Test-Path -LiteralPath $MONITOR_SOCK) { Remove-Item -LiteralPath $MONITOR_SOCK -Force }
    "unix:$MONITOR_SOCK,server,nowait"
}

$extraArgs = @()
if (-not [string]::IsNullOrWhiteSpace($env:QEMU_EXTRA_ARGS)) {
    $extraArgs = @($env:QEMU_EXTRA_ARGS -split '\s+' | Where-Object { $_ })
}

Write-Host "==> Starting VM $VM_NAME"
Write-Host "  Mode:     $networkMode"
Write-Host "  CPUs:     $VM_CPUS  RAM: ${VM_RAM_MB}MB"
Write-Host "  Accel:    $accelLabel"
Write-Host "  System:   $SYSTEM_DISK"
Write-Host "  Data:     $DATA_DISK"
Write-Host "  Seed:     $SEED_ISO"
Write-Host "  MAC:      $vmMac"
if ($networkMode -eq 'bridge') {
    Write-Host "  Net:      TAP $TAP_NAME → bridge $BRIDGE_NAME → VM $VM_IP (host :$HOST_SSH_FORWARD_PORT → VM :22)"
} else {
    Write-Host "  Net:      user-mode NAT (host 127.0.0.1:$HOST_SSH_FORWARD_PORT → VM :22)"
}
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

if (-not $IsWin) {
    # POSIX QEMU daemonizes itself and writes the pidfile
    & $QEMU_BIN @qemuArgs -daemonize
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    # Windows QEMU has no -daemonize: detach via Start-Process and write pid ourselves
    $quoted = $qemuArgs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }
    $proc = Start-Process -FilePath $QEMU_BIN -ArgumentList ($quoted -join ' ') `
        -WindowStyle Hidden -PassThru -RedirectStandardError (Join-Path $IMAGES_DIR 'qemu-stderr.log')
    Start-Sleep -Milliseconds 800
    if ($proc.HasExited) {
        Write-Error "QEMU exited immediately — see $(Join-Path $IMAGES_DIR 'qemu-stderr.log')"
    }
    Set-Content -LiteralPath $PID_FILE -Value $proc.Id
}

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
if ($networkMode -eq 'bridge') {
    Write-Host "VM should be at $VM_IP (via bridge $BRIDGE_NAME)."
    Write-Host "Host forward: ssh -p $HOST_SSH_FORWARD_PORT $($env:ADMIN_USER)@127.0.0.1  (or ssh $($env:ADMIN_USER)@$VM_IP)"
} else {
    Write-Host "VM SSH via host forward only: ssh -p $HOST_SSH_FORWARD_PORT $($env:ADMIN_USER)@127.0.0.1"
}
Write-Host "Wait for boot: mise run vm:ssh:wait  (or mise run vm:console to watch boot)"
