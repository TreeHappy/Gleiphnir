# vm/scripts/network-status.ps1 — show bridge/TAP/iptables status
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Start-OtelSpan 'gleiphnir.network_status' @{ 'script.name' = 'network-status.ps1'; 'service.name' = $env:OTEL_SERVICE_NAME }
try {
Write-Host "=== Network mode: bridge ==="
Write-Host ""
Write-Host "Bridge: $BRIDGE_NAME  TAP: $TAP_NAME  VM: $VM_IP/24  Host forward: :$HOST_SSH_FORWARD_PORT → ${VM_IP}:22"
Write-Host ""

Write-Host "--- ip addr ---"
& ip addr show $BRIDGE_NAME 2>&1
Write-Host ""
& ip addr show $TAP_NAME 2>&1
Write-Host ""

Write-Host "--- bridge members ---"
& bridge link show 2>$null
Write-Host ""

$iptables = Get-Command iptables -ErrorAction SilentlyContinue
if ($iptables) {
    Write-Host "--- iptables nat ---"
    & sudo iptables -t nat -L -n -v 2>&1 | Select-Object -First 40
    Write-Host ""
    Write-Host "--- iptables filter FORWARD ---"
    & sudo iptables -L FORWARD -n -v 2>&1 | Select-Object -First 20
}
    End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
