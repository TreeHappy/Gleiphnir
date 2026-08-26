# vm/scripts/manage-policy.ps1 — proxy `sbx policy`–like controls into the VM (sandbox-policy + ufw)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$spanAction = if ($args.Count -gt 0) { $args[0] } else { 'policy' }
Start-OtelSpan "gleiphnir.policy.$spanAction" @{ 'script.name' = 'manage-policy.ps1'; 'script.action' = $spanAction; 'service.name' = $env:OTEL_SERVICE_NAME }
try {

function Show-Usage {
    @"
manage-policy.ps1 — Gleiphnir policy (egress/ingress) via sandbox-policy in VM

Usage:
  manage-policy.ps1 init [balanced|open|locked]
  manage-policy.ps1 ls [--wide] [--sandbox NAME] [--json]
  manage-policy.ps1 allow network <host|cidr|**|*.host> [--port PORT] [--sandbox NAME]
  manage-policy.ps1 deny  network <host|cidr> [--port PORT] [--sandbox NAME]
  manage-policy.ps1 rm network --resource <host> [--sandbox NAME]
  manage-policy.ps1 check network <host|url> [--sandbox NAME]
  manage-policy.ps1 reset [--force]
  manage-policy.ps1 preset list|apply <preset>

Aliases: policy = gleiphnir policy, sbx policy parity.
See: docs/policy.md + docs/policy/*.md
"@
}

if ($args.Count -eq 0 -or $args[0] -in @('-h','--help','help')) { Show-Usage; exit 0 }

$cmd = $args[0]
$rest = @()
if ($args.Count -gt 1) { $rest = $args[1..($args.Count-1)] }

# helper to safely quote for remote bash
function Escape-ShellArg([string]$s) {
    return "'" + ($s -replace "'", "'\''") + "'"
}

switch ($cmd) {
    'init' {
        $preset = if ($rest.Count -ge 1) { $rest[0] } else { '' }
        if ($preset) {
            $q = Escape-ShellArg $preset
            exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-policy init $q")
        } else {
            exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-policy init")
        }
    }
    { $_ -in @('ls','list','show','status') } {
        # forward flags as-is
        $pass = ($rest | ForEach-Object { Escape-ShellArg $_ }) -join ' '
        exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-policy ls $pass")
    }
    'allow' {
        # expect: allow network <resource> [--port N] [--sandbox NAME]
        if ($rest.Count -lt 2 -or $rest[0] -ne 'network') { Write-Error "Usage: manage-policy.ps1 allow network <host|cidr> [--port PORT] [--sandbox NAME]"; exit 1 }
        $resource = $rest[1]
        $extraArgs = @()
        for ($i=2; $i -lt $rest.Count; $i++) {
            $a = $rest[$i]
            if ($a -eq '--port' -or $a -eq '--sandbox') { $extraArgs += $a; $extraArgs += $rest[$i+1]; $i++ }
            else { $extraArgs += $a }
        }
        $qRes = Escape-ShellArg $resource
        $qExtra = ($extraArgs | ForEach-Object { Escape-ShellArg $_ }) -join ' '
        exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-policy allow network $qRes $qExtra")
    }
    'deny' {
        if ($rest.Count -lt 2 -or $rest[0] -ne 'network') { Write-Error "Usage: manage-policy.ps1 deny network <host|cidr> [--port PORT] [--sandbox NAME]"; exit 1 }
        $resource = $rest[1]
        $extraArgs = @()
        for ($i=2; $i -lt $rest.Count; $i++) {
            $a = $rest[$i]
            if ($a -eq '--port' -or $a -eq '--sandbox') { $extraArgs += $a; $extraArgs += $rest[$i+1]; $i++ }
            else { $extraArgs += $a }
        }
        $qRes = Escape-ShellArg $resource
        $qExtra = ($extraArgs | ForEach-Object { Escape-ShellArg $_ }) -join ' '
        exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-policy deny network $qRes $qExtra")
    }
    { $_ -in @('rm','remove','delete') } {
        # rm network --resource <host> [--sandbox]
        if ($rest.Count -lt 1 -or $rest[0] -ne 'network') { Write-Error "Usage: manage-policy.ps1 rm network --resource <host> [--sandbox NAME]"; exit 1 }
        $qRest = ($rest[1..($rest.Count-1)] | ForEach-Object { Escape-ShellArg $_ }) -join ' '
        exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-policy rm network $qRest")
    }
    'check' {
        if ($rest.Count -lt 2 -or $rest[0] -ne 'network') { Write-Error "Usage: manage-policy.ps1 check network <host|url> [--sandbox NAME]"; exit 1 }
        $target = $rest[1]
        $qTarget = Escape-ShellArg $target
        $extra = @()
        for ($i=2; $i -lt $rest.Count; $i++) {
            $a = $rest[$i]
            if ($a -eq '--sandbox') { $extra += $a; $extra += $rest[$i+1]; $i++ }
            else { $extra += $a }
        }
        $qExtra = ($extra | ForEach-Object { Escape-ShellArg $_ }) -join ' '
        $code = Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-policy check network $qTarget $qExtra"
        exit $code
    }
    'reset' {
        $qRest = ($rest | ForEach-Object { Escape-ShellArg $_ }) -join ' '
        exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-policy reset $qRest")
    }
    'preset' {
        $qRest = ($rest | ForEach-Object { Escape-ShellArg $_ }) -join ' '
        exit (Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-policy preset $qRest")
    }
    default {
        Write-Error "Unknown policy subcommand: $cmd"
        Show-Usage
        exit 1
    }
}
    End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
