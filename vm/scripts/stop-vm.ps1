# vm/scripts/stop-vm.ps1 — gracefully stop the VM (monitor "quit", then SIGTERM/Stop-Process)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Start-OtelSpan 'gleiphnir.stop_vm' @{ 'script.name' = 'stop-vm.ps1'; 'service.name' = $env:OTEL_SERVICE_NAME }
try {
function script:Send-MonitorQuit {
    try {
        if (Test-MonitorTcp) {
            $client = [System.Net.Sockets.TcpClient]::new()
            $client.Connect('127.0.0.1', [int]$QEMU_MONITOR_PORT)
            $stream = $client.GetStream()
            $writer = [System.IO.StreamWriter]::new($stream, [Text.Encoding]::ASCII)
            $writer.WriteLine('quit'); $writer.Flush()
            $writer.Close(); $client.Close()
            return $true
        } elseif (Test-Path -LiteralPath $MONITOR_SOCK) {
            $sock = [System.Net.Sockets.Socket]::new(
                [System.Net.Sockets.AddressFamily]::Unix,
                [System.Net.Sockets.SocketType]::Stream,
                [System.Net.Sockets.ProtocolType]::Unspecified)
            $sock.Connect([System.Net.Sockets.UnixDomainSocketEndPoint]::new($MONITOR_SOCK))
            $payload = [Text.Encoding]::ASCII.GetBytes("quit`n")
            [void]$sock.Send($payload)
            $sock.Close()
            return $true
        }
    } catch { return $false }
    return $false
}

$usedMonitor = Send-MonitorQuit
if ($usedMonitor) {
    Write-Host "Asked QEMU to quit via monitor $(Get-MonitorDescription) ..."
    Start-Sleep -Seconds 2
}

$pids = @(Get-QemuPids | Where-Object { $_ })
if ($pids.Count -gt 0) {
    foreach ($procId in $pids) {
        Write-Host "Stopping QEMU PID $procId ..."
        try {
            Stop-Process -Id $procId -ErrorAction Stop
        } catch {
            if (-not $IsWin) { & sudo kill $procId 2>$null } else { Write-Warning "could not stop pid ${procId}: $_" }
        }
        # wait up to 10s
        for ($i = 0; $i -lt 10; $i++) {
            if (-not (Get-Process -Id $procId -ErrorAction SilentlyContinue)) { break }
            Start-Sleep -Seconds 1
        }
        if (Get-Process -Id $procId -ErrorAction SilentlyContinue) {
            Write-Warning "PID $procId still alive, use mise run vm:kill to force."
            exit 1
        }
    }
    Write-Host "VM stopped."
} else {
    Write-Host "No running VM found."
}

# cleanup
foreach ($f in @($PID_FILE, $MONITOR_SOCK)) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force }
}
End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
