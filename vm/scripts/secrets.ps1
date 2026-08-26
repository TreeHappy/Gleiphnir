# vm/scripts/secrets.ps1 — manage sandbox secrets (encrypt/decrypt/sync/list)
# Secrets live in config/secrets.env (plaintext, gitignored).
# Encrypted at rest on the host with age → config/secrets.env.enc.
# Synced to the VM over SSH and stored at /var/lib/sandbox/secrets.env (chmod 600).
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$spanAction = if ($args.Count -gt 0) { $args[0] } else { 'default' }
Start-OtelSpan "gleiphnir.$spanAction" @{ 'script.name' = 'secrets.ps1'; 'script.action' = $spanAction; 'service.name' = $env:OTEL_SERVICE_NAME }
try {

$SECRETS_PLAIN = Join-Path $RepoRoot 'config/secrets.env'
$SECRETS_ENC   = Join-Path $RepoRoot 'config/secrets.env.enc'
$VM_SECRETS    = '/var/lib/sandbox/secrets.env'

function Show-Usage {
    Write-Host "Usage: secrets.ps1 <command>"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  encrypt   Encrypt config/secrets.env → config/secrets.env.enc (age)"
    Write-Host "  decrypt   Decrypt config/secrets.env.enc → config/secrets.env"
    Write-Host "  sync      Copy secrets to VM over SSH (decrypt on host first)"
    Write-Host "  list      Show configured secret key names (on VM)"
    Write-Host "  status    Show local encryption/sync status"
}

function Test-AgeInstalled {
    $age = Get-Command age -ErrorAction SilentlyContinue
    if (-not $age) {
        Write-Error "age not found. Install: https://github.com/FiloSottile/age`n  winget install FiloSottile.age  (Windows)`n  apt install age / brew install age  (Linux/macOS)"
    }
}

function Encrypt-Secrets {
    Test-AgeInstalled

    if (-not (Test-Path -LiteralPath $SECRETS_PLAIN)) {
        Write-Error "No secrets file at $SECRETS_PLAIN`nCreate it with KEY=VALUE pairs first."
    }

    $pubKey = $env:SECRETS_AGE_PUBKEY
    if ([string]::IsNullOrEmpty($pubKey)) {
        Write-Error "SECRETS_AGE_PUBKEY not set in config/sandbox.env`nSet it to your age public key (age1...)."
    }

    Write-Host "Encrypting $SECRETS_PLAIN → $SECRETS_ENC ..."
    & age -r "$pubKey" -o "$SECRETS_ENC" "$SECRETS_PLAIN"
    if ($LASTEXITCODE -ne 0) { Write-Error "age encryption failed" }
    Write-Host "Encrypted. Plaintext is still at $SECRETS_PLAIN (gitignored)."
}

function Decrypt-Secrets {
    Test-AgeInstalled

    if (-not (Test-Path -LiteralPath $SECRETS_ENC)) {
        Write-Error "No encrypted secrets at $SECRETS_ENC"
    }

    $privKey = Join-Path ([System.Environment]::GetFolderPath('UserProfile')) '.ssh/gleiphnir_secrets_key'
    if (-not (Test-Path -LiteralPath $privKey)) {
        Write-Error "Age private key not found at $privKey`nGenerate one: age-keygen -o $privKey"
    }

    Write-Host "Decrypting $SECRETS_ENC → $SECRETS_PLAIN ..."
    & age -d -i "$privKey" -o "$SECRETS_PLAIN" "$SECRETS_ENC"
    if ($LASTEXITCODE -ne 0) { Write-Error "age decryption failed (wrong key?)" }
    Write-Host "Decrypted."
}

function Sync-Secrets {
    if (-not (Test-Path -LiteralPath $SECRETS_PLAIN)) {
        if (Test-Path -LiteralPath $SECRETS_ENC) {
            Write-Host "Plaintext secrets not found — decrypting first ..."
            Decrypt-Secrets
        } else {
            Write-Error "No secrets found. Create config/secrets.env first."
        }
    }

    Write-Host "Syncing secrets to VM ..."
    $scpArgs = @()
    $scpArgs += Get-SshCommonArgs
    $scpArgs += Get-KeyArgs
    $scpArgs += @($SECRETS_PLAIN, "$($env:ADMIN_USER)@127.0.0.1:${VM_SECRETS}")

    if ($env:NETWORK_MODE -eq 'user') {
        $scpArgs = @('-P', $HOST_SSH_FORWARD_PORT) + $scpArgs
    }
    & scp @scpArgs
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to copy secrets to VM" }

    # Set permissions on VM (chmod 600, owned by root) and create marker
    Invoke-AdminSsh -Command "sudo chmod 600 $VM_SECRETS && sudo chown root:root $VM_SECRETS && sudo touch /var/lib/sandbox/secrets-enabled && echo 'Secrets synced and secured on VM.'" -Quiet
}

function List-Secrets {
    Invoke-AdminSsh -Command "if [ -f $VM_SECRETS ]; then sudo /usr/local/bin/sandbox-secrets list; else echo '(no secrets deployed yet)'; fi" -Quiet
}

function Show-Status {
    Write-Host "=== Secrets Status ==="
    Write-Host ""
    Write-Host "Plaintext:  $(if (Test-Path -LiteralPath $SECRETS_PLAIN) { 'exists' } else { 'not found' })  $SECRETS_PLAIN"
    Write-Host "Encrypted:  $(if (Test-Path -LiteralPath $SECRETS_ENC) { 'exists' } else { 'not found' })  $SECRETS_ENC"
    Write-Host "Age pubkey: $($env:SECRETS_AGE_PUBKEY ?? '(not set in sandbox.env)')"
    Write-Host ""

    if (Test-Path -LiteralPath $SECRETS_PLAIN) {
        $count = (Get-Content -LiteralPath $SECRETS_PLAIN | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '=' }).Count
        Write-Host "Secrets configured: $count"
    }

    Write-Host ""
    Write-Host "On VM:"
    Invoke-AdminSsh -Command "if [ -f $VM_SECRETS ]; then ls -la $VM_SECRETS; echo ''; sudo /usr/local/bin/sandbox-secrets list 2>/dev/null || echo '  (sandbox-secrets not deployed)'; else echo '  (not deployed yet)'; fi" -Quiet
}

# ── main ─────────────────────────────────────────────────────────────────────
$action = if ($args.Count -gt 0) { $args[0] } else { 'status' }

switch ($action) {
    'encrypt' { Encrypt-Secrets }
    'decrypt' { Decrypt-Secrets }
    'sync'    { Sync-Secrets }
    'list'    { List-Secrets }
    'status'  { Show-Status }
    default   { Show-Usage }
}
    End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
