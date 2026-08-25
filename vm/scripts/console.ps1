# vm/scripts/console.ps1 — tail the VM serial console log
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

if (-not (Test-Path -LiteralPath $CONSOLE_LOG)) {
    Write-Error "Console log not found: $CONSOLE_LOG`nIs the VM running? mise run vm:info"
}

Write-Host "==> VM console log (tailing). VM serial is also available via QEMU monitor."
Write-Host "    Log: $CONSOLE_LOG"
Write-Host "    Press Ctrl-C to stop tailing (VM keeps running)."
Write-Host ""

Get-Content -LiteralPath $CONSOLE_LOG -Wait -Tail 20
