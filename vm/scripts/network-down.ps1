# vm/scripts/network-down.ps1 — remove bridge + TAP + iptables rules (Linux hosts only)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Start-OtelSpan 'gleiphnir.network_down' @{ 'script.name' = 'network-down.ps1'; 'service.name' = $env:OTEL_SERVICE_NAME }
try {
if ($IsWin) {
    Write-Host "network-down is not applicable on native Windows — nothing was created on the host."
    exit 0
}

if ($env:NETWORK_MODE -eq 'user') {
    Write-Host "NETWORK_MODE=user — nothing to tear down."
    exit 0
}

$isRoot = ((& id -u) -eq '0')
if (-not $isRoot) {
    Write-Error "network-down.ps1 must be run as root (use: mise run network:down  or  sudo pwsh vm/scripts/network-down.ps1)"
}

Write-Host "==> Tearing down bridge $BRIDGE_NAME / TAP $TAP_NAME"

$iptables = Get-Command iptables -ErrorAction SilentlyContinue
if ($iptables) {
    Write-Host "Removing iptables rules ..."
    & iptables -t nat -D PREROUTING -p tcp --dport $HOST_SSH_FORWARD_PORT -j DNAT --to-destination "${VM_IP}:22" 2>$null
    & iptables -t nat -D POSTROUTING -s $BRIDGE_NETWORK ! -o $BRIDGE_NAME -j MASQUERADE 2>$null
    & iptables -D FORWARD -i $BRIDGE_NAME -j ACCEPT 2>$null
    & iptables -D FORWARD -o $BRIDGE_NAME -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>$null
    & iptables -D FORWARD -o $BRIDGE_NAME -j ACCEPT 2>$null
    & iptables -D INPUT -p tcp --dport $HOST_SSH_FORWARD_PORT -j ACCEPT 2>$null
}

# Remove TAP from bridge and delete TAP
$null = & ip link show $TAP_NAME 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Deleting TAP $TAP_NAME ..."
    & ip link set $TAP_NAME nomaster 2>$null
    & ip link set $TAP_NAME down 2>$null
    & ip tuntap del dev $TAP_NAME mode tap 2>$null
    if ($LASTEXITCODE -ne 0) { & ip link del $TAP_NAME 2>$null }
}

# Optionally release PHYS_IF from bridge
if (-not [string]::IsNullOrEmpty($env:PHYS_IF)) {
    $phys = $env:PHYS_IF
    $null = & ip link show $phys 2>$null
    if ($LASTEXITCODE -eq 0) {
        if (((& ip link show $phys) -join "`n") -match [regex]::Escape("master $BRIDGE_NAME")) {
            Write-Host "Releasing $phys from $BRIDGE_NAME ..."
            & ip link set $phys nomaster 2>$null
        }
    }
}

$null = & ip link show $BRIDGE_NAME 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Deleting bridge $BRIDGE_NAME ..."
    & ip link set $BRIDGE_NAME down 2>$null
    & ip link del $BRIDGE_NAME 2>$null
}

Write-Host "Done."
    End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
