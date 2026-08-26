# vm/scripts/observability.ps1 — manage the Grafana LGTM container on the host
# The LGTM container runs alongside the Gleiphnir VM on the host machine,
# receiving OTLP telemetry (logs, metrics, traces) from the VM over the network.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$CONTAINER_NAME = 'gleiphnir-lgtm'
$VOLUME_NAME    = 'gleiphnir-lgtm-data'

function Get-LgtmStatus {
    $running = & podman inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>$null
    if ($LASTEXITCODE -eq 0 -and $running -eq 'true') {
        return 'running'
    }
    $exists = & podman inspect $CONTAINER_NAME 2>$null
    if ($LASTEXITCODE -eq 0) { return 'stopped' }
    return 'not_found'
}

function Start-Observability {
    $status = Get-LgtmStatus
    if ($status -eq 'running') {
        Write-Host "LGTM container is already running."
        Show-AccessInfo
        return
    }

    $image = if ($env:OBSERVABILITY_LGTM_IMAGE) { $env:OBSERVABILITY_LGTM_IMAGE } else { 'grafana/otel-lgtm:latest' }
    $grafanaPort = if ($env:OBSERVABILITY_GRAFANA_PORT) { $env:OBSERVABILITY_GRAFANA_PORT } else { '3000' }
    $otlpPort   = if ($env:OBSERVABILITY_OTLP_PORT)     { $env:OBSERVABILITY_OTLP_PORT }     else { '4317' }
    $promPort   = if ($env:OBSERVABILITY_PROM_PORT)      { $env:OBSERVABILITY_PROM_PORT }      else { '9090' }

    Write-Host "Pulling $image ..."
    & podman pull $image
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to pull $image" }

    # Create persistent volume for LGTM data
    $volExists = & podman volume inspect $VOLUME_NAME 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Creating volume $VOLUME_NAME ..."
        & podman volume create $VOLUME_NAME | Out-Null
    }

    $portArgs = @(
        '-p', "${grafanaPort}:3000"    # Grafana UI
        '-p', "${otlpPort}:4317"       # OTLP gRPC
        '-p', '4318:4318'              # OTLP HTTP
        '-p', "${promPort}:9090"        # Prometheus
    )

    # In bridge mode, also publish the Loki port for direct queries
    if ($env:NETWORK_MODE -ne 'user') {
        $portArgs += '-p', '3100:3100'  # Loki
    }

    Write-Host "Starting LGTM container ($CONTAINER_NAME) ..."
    & podman run -d `
        --name $CONTAINER_NAME `
        --restart unless-stopped `
        -v "${VOLUME_NAME}:/data" `
        @portArgs `
        -e OTEL_BIND_HOST=0.0.0.0 `
        -e ENABLE_LOGS_ALL=false `
        -e LOG_LEVEL=info `
        $image
    if ($LASTEXITCODE -ne 0) { Write-Error "Failed to start LGTM container" }

    Write-Host "Waiting for LGTM to become ready ..."
    $ready = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 2
        $health = & podman inspect -f '{{.State.Health.Status}}' $CONTAINER_NAME 2>$null
        if ($health -eq 'healthy' -or $health -eq 'starting') {
            # Also check the ready marker
            $readyFile = & podman exec $CONTAINER_NAME test -f /tmp/ready 2>$null
            if ($LASTEXITCODE -eq 0) { $ready = $true; break }
        }
        Write-Host "." -NoNewline
    }
    Write-Host ""
    if (-not $ready) {
        Write-Warning "LGTM container started but healthcheck not yet ready. Dashboard may take a few more seconds."
    }

    Show-AccessInfo
}

function Stop-Observability {
    $status = Get-LgtmStatus
    if ($status -eq 'not_found') {
        Write-Host "LGTM container not found."
        return
    }
    Write-Host "Stopping LGTM container ..."
    & podman stop $CONTAINER_NAME 2>$null | Out-Null
    & podman rm $CONTAINER_NAME 2>$null | Out-Null
    Write-Host "LGTM container stopped and removed. Data preserved in volume $VOLUME_NAME."
}

function Remove-ObservabilityData {
    Stop-Observability
    Write-Host "Removing LGTM data volume ..."
    & podman volume rm $VOLUME_NAME 2>$null | Out-Null
    Write-Host "All observability data removed."
}

function Show-AccessInfo {
    $grafanaPort = if ($env:OBSERVABILITY_GRAFANA_PORT) { $env:OBSERVABILITY_GRAFANA_PORT } else { '3000' }
    $otlpPort   = if ($env:OBSERVABILITY_OTLP_PORT)     { $env:OBSERVABILITY_OTLP_PORT }     else { '4317' }
    $promPort   = if ($env:OBSERVABILITY_PROM_PORT)      { $env:OBSERVABILITY_PROM_PORT }      else { '9090' }

    Write-Host ""
    Write-Host "=== Grafana LGTM Observability ==="
    Write-Host "  Grafana:   http://localhost:${grafanaPort}  (admin / admin)"
    Write-Host "  OTLP gRPC: localhost:${otlpPort}"
    Write-Host "  OTLP HTTP: localhost:4318"
    Write-Host "  Prometheus: localhost:${promPort}"

    if ($env:NETWORK_MODE -ne 'user') {
        Write-Host "  VM target: $($env:VM_GATEWAY):${otlpPort} (OTLP gRPC)"
    } else {
        Write-Host "  VM target: 10.0.2.2:${otlpPort} (OTLP gRPC via gateway)"
    }
    Write-Host ""
    Write-Host "  Data volume: $VOLUME_NAME"
    Write-Host "==================================="
    Write-Host ""
}

function Show-ObservabilityStatus {
    $status = Get-LgtmStatus
    Write-Host "=== LGTM Observability Status ==="
    Write-Host "  Container: $CONTAINER_NAME"
    Write-Host "  Status:    $status"
    if ($status -eq 'running') {
        Show-AccessInfo
    } else {
        Write-Host "  Run 'mise run obs:start' to start."
    }
}

# ── main ─────────────────────────────────────────────────────────────────────
$action = if ($args.Count -gt 0) { $args[0] } else { 'status' }

switch ($action) {
    'start'     { Start-Observability }
    'stop'      { Stop-Observability }
    'status'    { Show-ObservabilityStatus }
    'restart'   { Stop-Observability; Start-Observability }
    'clean'     { Remove-ObservabilityData }
    'open'      {
        $port = if ($env:OBSERVABILITY_GRAFANA_PORT) { $env:OBSERVABILITY_GRAFANA_PORT } else { '3000' }
        $url = "http://localhost:${port}/-/dashboards"
        Write-Host "Opening $url ..."
        if ($script:IsWin) { Start-Process $url }
        elseif (Get-Command xdg-open -ErrorAction SilentlyContinue) { & xdg-open $url }
        elseif (Get-Command open -ErrorAction SilentlyContinue) { & open $url }
        else { Write-Host "Open manually: $url" }
    }
    default { Write-Host "Usage: observability.ps1 <start|stop|status|restart|clean|open>" }
}
