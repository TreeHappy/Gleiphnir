# vm/scripts/wait-ssh.ps1 — poll until VM SSH is reachable, then show cloud-init status
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$timeoutSecs = 180
$interval    = 3
$elapsed     = 0

# Targets to poll: direct + forward in bridge mode, forward only in user mode
$targets = @()
if ($env:NETWORK_MODE -eq 'user') {
    $targets += @{ Host = '127.0.0.1'; Port = [int]$HOST_SSH_FORWARD_PORT }
} else {
    $targets += @{ Host = $VM_IP;      Port = 22 }
    $targets += @{ Host = '127.0.0.1'; Port = [int]$HOST_SSH_FORWARD_PORT }
}

Write-Host "Waiting for VM SSH (timeout ${timeoutSecs}s, mode: $($env:NETWORK_MODE)) ..."

function script:Try-Ssh([hashtable]$t) {
    $sshArgs = @() + (Get-KeyArgs) + (Get-SshCommonArgs) +
        @('-o', 'ConnectTimeout=2')
    if ($t.Host -eq '127.0.0.1') { $sshArgs += @('-p', "$($t.Port)") }
    $sshArgs += "$($env:ADMIN_USER)@$($t.Host)"
    $sshArgs += 'true'
    & ssh @sshArgs *>$null
    return ($LASTEXITCODE -eq 0)
}

while ($elapsed -lt $timeoutSecs) {
    foreach ($t in $targets) {
        if (Try-Ssh $t) {
            Write-Host "VM SSH is up at $($t.Host):$($t.Port) (${elapsed}s elapsed)"
            Write-Host "Checking cloud-init status ..."
            $remote = 'cloud-init status --wait 2>&1 | tail -5; echo ---; systemctl is-active podman 2>&1 | head -5; echo ---; podman images 2>&1 | head -10'
            $sshArgs = @() + (Get-KeyArgs) + (Get-SshCommonArgs)
            if ($t.Host -eq '127.0.0.1') { $sshArgs += @('-p', "$($t.Port)") }
            $sshArgs += "$($env:ADMIN_USER)@$($t.Host)"
            $sshArgs += $remote
            & ssh @sshArgs 2>$null
            exit 0
        }
    }
    $label = (($targets | ForEach-Object { "$($_.Host):$($_.Port)" }) -join ', ')
    Write-Host ("{0,4}s — not yet (targets: {1})" -f $elapsed, $label)
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

Write-Error "Timed out after ${timeoutSecs}s waiting for VM SSH`nCheck: mise run vm:console or mise run vm:info"
