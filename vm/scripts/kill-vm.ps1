# vm/scripts/kill-vm.ps1 — force-kill QEMU
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Start-OtelSpan 'gleiphnir.kill_vm' @{ 'script.name' = 'kill-vm.ps1'; 'service.name' = $env:OTEL_SERVICE_NAME }
try {
Write-Host "Force-killing VM $VM_NAME ..."
$pids = @(Get-QemuPids | Where-Object { $_ })

if ($pids.Count -eq 0) {
    Write-Host "No VM process found."
    foreach ($f in @($PID_FILE, $MONITOR_SOCK)) {
        if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force }
    }
    exit 0
}

Write-Host "Killing PIDs: $($pids -join ' ')"
foreach ($procId in $pids) {
    try     { Stop-Process -Id $procId -Force -ErrorAction Stop }
    catch   { if (-not $IsWin) { & sudo kill -9 $procId 2>$null } }
}
foreach ($f in @($PID_FILE, $MONITOR_SOCK)) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force }
}
Write-Host "Done."
End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
