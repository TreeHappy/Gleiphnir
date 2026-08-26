# vm/scripts/manage-user.ps1 — create/remove/list sandbox users on the VM (proxies over SSH)
# Usage: manage-user.ps1 add <user> [<key.pub>|<literal pubkey>] | remove <user> | list
#        or KEY=VALUE style: manage-user.ps1 add USER=alice KEY=path/or/literal
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$spanAction = if ($args.Count -gt 0) { $args[0] } else { 'default' }
Start-OtelSpan "gleiphnir.$spanAction" @{ 'script.name' = 'manage-user.ps1'; 'script.action' = $spanAction; 'service.name' = $env:OTEL_SERVICE_NAME }
try {

# Accept both positional and KEY=VALUE forms
$action = ''; $user = ''; $keyArg = ''
$positional = @()
foreach ($a in $args) {
    if ($a -match '^([^=]+)=(.*)$' -and $a -match '^(USER|KEY)=') {
        $k = $Matches[1]; $v = $Matches[2]
        switch ($k) {
            'USER' { $user = $v }
            'KEY'  { $keyArg = $v }
        }
    } else {
        $positional += $a
    }
}
if ($positional.Count -ge 1) { $action = $positional[0] }
if ($positional.Count -ge 2 -and -not $user) { $user = $positional[1] }
if ($positional.Count -ge 3 -and -not $keyArg) { $keyArg = $positional[2] }

if (-not $action) {
    Write-Error "Usage: manage-user.ps1 add|remove|list [user] [key.pub]"
}

switch ($action) {
    'add' {
        if (-not $user) { Write-Error "Usage: manage-user.ps1 add <username> [key.pub]" }

        $pubkey = ''
        if ($keyArg -and (Test-Path -LiteralPath $keyArg)) {
            $pubkey = (Get-Content -LiteralPath $keyArg -Raw).Trim()
        } elseif ($keyArg) {
            $pubkey = $keyArg   # treat as literal key string
        } else {
            foreach ($cand in @(
                (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.ssh/id_ed25519.pub'),
                (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.ssh/id_rsa.pub'),
                (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.ssh/id_ecdsa.pub'))) {
                if (Test-Path -LiteralPath $cand) {
                    $pubkey = (Get-Content -LiteralPath $cand -Raw).Trim()
                    Write-Host "Using key $cand"
                    break
                }
            }
            if (-not $pubkey) {
                Write-Error "No key file provided and no default key found at ~/.ssh/id_*.pub`nUsage: manage-user.ps1 add $user /path/to/key.pub"
            }
        }

        Write-Host "Creating sandbox user '$user' ..."
        # base64 to avoid remote shell quoting issues
        $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pubkey))
        $code = Invoke-AdminSshWithFallback -Command "echo '$b64' | base64 -d | sudo /usr/local/bin/sandbox-user add '$user' --key-file /dev/stdin"
        if ($code -ne 0) { exit $code }
        Write-Host "Done. Test: ssh ${user}@$VM_IP  (or ssh -p $HOST_SSH_FORWARD_PORT ${user}@127.0.0.1)"
    }
    'remove' {
        if (-not $user) { Write-Error "Usage: manage-user.ps1 remove <username>" }
        Write-Host "Removing sandbox user '$user' ..."
        $code = Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-user remove '$user'"
        exit $code
    }
    'list' {
        $code = Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-user list || ls -1 /home/ 2>&1 | head -30; echo '--- workspaces ---'; ls -1 /srv/sandbox/ 2>&1 | head -30"
        exit $code
    }
    default {
        Write-Error "Unknown action: $action (expected add|remove|list)"
    }
}
    End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
