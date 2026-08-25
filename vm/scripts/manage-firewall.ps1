# vm/scripts/manage-firewall.ps1 — proxy fw allow/deny/remove/list into the VM (ufw)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$action = ''; $ip = ''
$positional = @()
foreach ($a in $args) {
    if ($a -match '^(IP)=(.*)$') { $ip = $Matches[2] } else { $positional += $a }
}
if ($positional.Count -ge 1) { $action = $positional[0] }
if ($positional.Count -ge 2 -and -not $ip) { $ip = $positional[1] }

switch ($action) {
    'allow' {
        if (-not $ip) { Write-Error "Usage: manage-firewall.ps1 allow <IP>[/prefix]" }
        exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-firewall allow '$ip'")
    }
    'deny' {
        if (-not $ip) { Write-Error "Usage: manage-firewall.ps1 deny <IP>[/prefix]" }
        exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-firewall deny '$ip'")
    }
    { $_ -in 'remove','delete','unallow','undeny' } {
        if (-not $ip) { Write-Error "Usage: manage-firewall.ps1 remove <IP>[/prefix]" }
        exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-firewall remove '$ip'")
    }
    { $_ -in 'list','show','status' } {
        exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-firewall list")
    }
    'enforce' {
        exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-firewall enforce")
    }
    default {
        Write-Error "Usage: manage-firewall.ps1 allow|deny|remove|enforce|list [IP]"
    }
}
