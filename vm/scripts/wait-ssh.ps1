# vm/scripts/wait-ssh.ps1 — poll until VM SSH is reachable, then show cloud-init status
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$timeoutSecs = 600
$interval    = 5
$elapsed     = 0

# Always use the forward port (works in both user and bridge mode)
$forwardPort = [int]$HOST_SSH_FORWARD_PORT

# Step 1: TCP check via bash (more reliable than PowerShell TcpClient in containers)
Write-Host "Waiting for VM SSH (timeout ${timeoutSecs}s, forward: 127.0.0.1:${forwardPort}) ..."
while ($elapsed -lt $timeoutSecs) {
    $tcpOk = & bash -c "echo >/dev/tcp/127.0.0.1/$forwardPort" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "TCP port ${forwardPort} open (${elapsed}s elapsed) — waiting for sshd ..."
        break
    }
    Write-Host ("{0,4}s — port not yet open" -f $elapsed)
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

if ($elapsed -ge $timeoutSecs) {
    Write-Error "Timed out after ${timeoutSecs}s waiting for TCP 127.0.0.1:${forwardPort}`nCheck: mise run vm:console or mise run vm:info"
}

# Step 2: wait for SSH to accept commands (sshd may still be starting under slow TCG)
$sshTimeout = 300
$sshElapsed = 0
while ($sshElapsed -lt $sshTimeout) {
    $sshArgs = @() + (Get-KeyArgs) + (Get-SshCommonArgs) +
        @('-o', 'ConnectTimeout=10', '-o', 'BatchMode=yes',
          '-p', "$forwardPort",
          "$($env:ADMIN_USER)@127.0.0.1", 'true')
    & ssh @sshArgs 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "VM SSH is up at 127.0.0.1:${forwardPort} (${elapsed}s total elapsed)"
        Write-Host "Checking cloud-init status ..."
        $remote = 'cloud-init status --wait 2>&1 | tail -5; echo ---; systemctl is-active podman 2>&1 | head -5; echo ---; podman images 2>&1 | head -10'
        $sshArgs2 = @() + (Get-KeyArgs) + (Get-SshCommonArgs) +
            @('-p', "$forwardPort", "$($env:ADMIN_USER)@127.0.0.1", $remote)
        & ssh @sshArgs2 2>$null
        exit 0
    }
    Write-Host ("{0,4}s — sshd not ready yet" -f $elapsed)
    Start-Sleep -Seconds $interval
    $elapsed += $interval
    $sshElapsed += $interval
}

Write-Error "Timed out after ${sshTimeout}s SSH attempts (TCP was open).`nCheck: mise run vm:console or mise run vm:info"
