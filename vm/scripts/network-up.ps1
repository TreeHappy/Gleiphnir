# vm/scripts/network-up.ps1 — create bridge + TAP + iptables rules
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Start-OtelSpan 'gleiphnir.network_up' @{ 'script.name' = 'network-up.ps1'; 'service.name' = $env:OTEL_SERVICE_NAME }
try {
$isRoot = ((& id -u) -eq '0')
if (-not $isRoot) {
    Write-Error "network-up.ps1 must be run as root (use: mise run network:up  or  sudo pwsh vm/scripts/network-up.ps1)"
}

Write-Host "==> Creating bridge $BRIDGE_NAME and TAP $TAP_NAME (mode: bridge)"

# Ensure bridge exists
$null = & ip link show $BRIDGE_NAME 2>$null
$bridgeExists = ($LASTEXITCODE -eq 0)
if ($bridgeExists) {
    Write-Host "Bridge $BRIDGE_NAME already exists."
} else {
    Write-Host "Creating bridge $BRIDGE_NAME ..."
    & ip link add name $BRIDGE_NAME type bridge
}

& ip link set $BRIDGE_NAME up

# Assign bridge IP if not already
$addrOut = & ip addr show $BRIDGE_NAME 2>$null
if (-not ($addrOut -match [regex]::Escape($BRIDGE_ADDR))) {
    Write-Host "Assigning $BRIDGE_ADDR/$BRIDGE_NETMASK to $BRIDGE_NAME ..."
    & ip addr add "$BRIDGE_ADDR/$BRIDGE_NETMASK" dev $BRIDGE_NAME 2>$null
}

# TAP device
$null = & ip link show $TAP_NAME 2>$null
$tapExists = ($LASTEXITCODE -eq 0)
if ($tapExists) {
    Write-Host "TAP $TAP_NAME already exists."
} else {
    Write-Host "Creating TAP $TAP_NAME ..."
    $tapUser = $env:SUDO_USER
    if ([string]::IsNullOrEmpty($tapUser)) { $tapUser = (& logname 2>$null); if ($LASTEXITCODE -ne 0) { $tapUser = 'root' } }
    & ip tuntap add dev $TAP_NAME mode tap user $tapUser 2>$null
    if ($LASTEXITCODE -ne 0) { & ip tuntap add dev $TAP_NAME mode tap }
}

# Attach TAP to bridge if not already enslaved
$linkOut = (& ip link show $TAP_NAME) -join "`n"
if ($linkOut -notmatch [regex]::Escape("master $BRIDGE_NAME")) {
    Write-Host "Attaching $TAP_NAME to $BRIDGE_NAME ..."
    & ip link set $TAP_NAME master $BRIDGE_NAME 2>$null
}

& ip link set $TAP_NAME up

# Optionally enslave physical interface (true LAN bridge)
if (-not [string]::IsNullOrEmpty($env:PHYS_IF)) {
    $phys = $env:PHYS_IF
    $null = & ip link show $phys 2>$null
    $physExists = ($LASTEXITCODE -eq 0)
    if ($physExists) {
        $null = & iw dev $phys info 2>$null
        $isWireless = ($LASTEXITCODE -eq 0)
        if ($isWireless) {
            Write-Warning "PHYS_IF=$phys looks like a wireless interface; bridging wifi is not supported."
            Write-Warning "VM will not get LAN DHCP. Use private bridge (PHYS_IF=) instead."
        } else {
            $physLink = (& ip link show $phys) -join "`n"
            if ($physLink -notmatch [regex]::Escape("master $BRIDGE_NAME")) {
                Write-Host "Enslaving physical interface $phys to $BRIDGE_NAME (VM will appear on LAN) ..."
                Write-Host "NOTE: For true LAN bridge you may need to move your host IP to $BRIDGE_NAME and run DHCP there."
                & ip link set $phys master $BRIDGE_NAME 2>$null
                & ip link set $phys up
            } else {
                Write-Host "Physical interface $phys already enslaved to $BRIDGE_NAME."
            }
        }
    } else {
        Write-Warning "PHYS_IF=$phys not found, skipping."
    }
}

# Enable IP forwarding
Set-Content -LiteralPath '/proc/sys/net/ipv4/ip_forward' -Value '1'
if (Test-Path '/proc/sys/net/ipv6/conf/all/forwarding') {
    Set-Content -LiteralPath '/proc/sys/net/ipv6/conf/all/forwarding' -Value '1' -ErrorAction SilentlyContinue
}

# iptables forwarding + NAT for VM outbound, and DNAT for inbound SSH
$iptables = Get-Command iptables -ErrorAction SilentlyContinue
if ($iptables) {
    Write-Host "Configuring iptables forwarding (private bridge NAT + DNAT for :$HOST_SSH_FORWARD_PORT → ${VM_IP}:22)"

    & iptables -C FORWARD -i $BRIDGE_NAME -j ACCEPT 2>$null; if ($LASTEXITCODE -ne 0) { & iptables -I FORWARD 1 -i $BRIDGE_NAME -j ACCEPT }
    & iptables -C FORWARD -o $BRIDGE_NAME -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT 2>$null; if ($LASTEXITCODE -ne 0) { & iptables -I FORWARD 1 -o $BRIDGE_NAME -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT }
    & iptables -C FORWARD -o $BRIDGE_NAME -j ACCEPT 2>$null; if ($LASTEXITCODE -ne 0) { & iptables -I FORWARD -o $BRIDGE_NAME -j ACCEPT }

    & iptables -t nat -C POSTROUTING -s $BRIDGE_NETWORK ! -o $BRIDGE_NAME -j MASQUERADE 2>$null
    if ($LASTEXITCODE -ne 0) { & iptables -t nat -A POSTROUTING -s $BRIDGE_NETWORK ! -o $BRIDGE_NAME -j MASQUERADE }

    & iptables -t nat -C PREROUTING -p tcp --dport $HOST_SSH_FORWARD_PORT -j DNAT --to-destination "${VM_IP}:22" 2>$null
    if ($LASTEXITCODE -ne 0) { & iptables -t nat -A PREROUTING -p tcp --dport $HOST_SSH_FORWARD_PORT -j DNAT --to-destination "${VM_IP}:22" }

    & iptables -C INPUT -p tcp --dport $HOST_SSH_FORWARD_PORT -j ACCEPT 2>$null
    if ($LASTEXITCODE -ne 0) { & iptables -I INPUT 1 -p tcp --dport $HOST_SSH_FORWARD_PORT -j ACCEPT }

    Write-Host "iptables rules added. Current NAT table:"
    & iptables -t nat -L -n -v 2>$null | Select-Object -First 30
}

Write-Host ""
Write-Host "Network ready:"
& ip addr show $BRIDGE_NAME
Write-Host ""
& ip link show master $BRIDGE_NAME 2>$null
Write-Host ""
Write-Host "Bridge $BRIDGE_NAME ($BRIDGE_ADDR/$BRIDGE_NETMASK) → VM $VM_IP/24 via TAP $TAP_NAME"
Write-Host "Host forward: 0.0.0.0:$HOST_SSH_FORWARD_PORT → ${VM_IP}:22 (real source IPs preserved via DNAT)"
if (-not [string]::IsNullOrEmpty($env:PHYS_IF)) {
    Write-Host "Physical IF $($env:PHYS_IF) enslaved — VM appears on LAN (DHCP from LAN)."
}
    End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
