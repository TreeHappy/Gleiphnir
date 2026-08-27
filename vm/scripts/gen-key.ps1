# vm/scripts/gen-key.ps1 — generate admin SSH keypair if missing
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Start-OtelSpan 'gleiphnir.gen_key' @{ 'script.name' = 'gen-key.ps1'; 'service.name' = $env:OTEL_SERVICE_NAME }
try {
$keyDir = Split-Path -Parent $ADMIN_SSH_KEY_PATH
if (-not (Test-Path -LiteralPath $keyDir)) { New-Item -ItemType Directory -Path $keyDir -Force | Out-Null }

if ((Test-Path -LiteralPath $ADMIN_SSH_PRIV_PATH) -and (Test-Path -LiteralPath $ADMIN_SSH_KEY_PATH)) {
    Write-Host "Admin key already exists:"
    Write-Host "  priv: $ADMIN_SSH_PRIV_PATH"
    Write-Host "  pub:  $ADMIN_SSH_KEY_PATH"
    exit 0
}

Write-Host "Generating admin SSH keypair at $ADMIN_SSH_PRIV_PATH ..."
& ssh-keygen -t ed25519 -f $ADMIN_SSH_PRIV_PATH -N '' -C "$($env:ADMIN_USER)@$($env:VM_HOSTNAME)"
chmod 600 $ADMIN_SSH_PRIV_PATH
chmod 644 $ADMIN_SSH_KEY_PATH
Write-Host "Done."
Get-Item -LiteralPath $ADMIN_SSH_PRIV_PATH, $ADMIN_SSH_KEY_PATH | Format-Table Name, Length, LastWriteTime -AutoSize
End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
