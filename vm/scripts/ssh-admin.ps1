# vm/scripts/ssh-admin.ps1 — SSH into the VM as admin
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Start-OtelSpan 'gleiphnir.ssh_admin' @{ 'script.name' = 'ssh-admin.ps1'; 'service.name' = $env:OTEL_SERVICE_NAME }
try {
$extraArgs = @($args)

Write-Host "Connecting to $($env:ADMIN_USER)@$env:VM_IP (bridge) ..."
$direct = @() + (Get-KeyArgs) + (Get-SshCommonArgs) + @('-o', 'ConnectTimeout=3') + "$($env:ADMIN_USER)@$env:VM_IP" + $extraArgs
& ssh @direct 2>$null
if ($LASTEXITCODE -eq 0) { exit 0 }

Write-Host "Direct connect failed — trying host forward 127.0.0.1:$HOST_SSH_FORWARD_PORT ..."
$fwd = @() + (Get-KeyArgs) + (Get-SshCommonArgs) + @('-p', $HOST_SSH_FORWARD_PORT) + "$($env:ADMIN_USER)@127.0.0.1" + $extraArgs
& ssh @fwd
exit $LASTEXITCODE
End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
