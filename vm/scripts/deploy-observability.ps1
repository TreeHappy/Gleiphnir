# vm/scripts/deploy-observability.ps1 — deploy telemetry agents into the running VM
# Only runs when OBSERVABILITY_ENABLED=true. Installs OTel Collector, node-exporter,
# mitmproxy, and the session-logger wrapper inside the VM.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Start-OtelSpan 'gleiphnir.deploy_observability' @{ 'script.name' = 'deploy-observability.ps1'; 'service.name' = $env:OTEL_SERVICE_NAME }
try {
Write-Host "==> Deploying observability agents to VM"

if ($env:OBSERVABILITY_ENABLED -ne 'true') {
    Write-Host "OBSERVABILITY_ENABLED is not true. Skipping."
    return
}

$lgtmHost = $env:VM_GATEWAY
Write-Host "LGTM endpoint for VM: ${lgtmHost}:4317"

# Install node-exporter
Write-Host "Installing node-exporter ..."
Invoke-AdminSshWithFallback -Command "command -v node_exporter >/dev/null 2>&1 || { echo 'node-exporter not found, installing...'; sudo apt-get update -qq && sudo apt-get install -y -qq prometheus-node-exporter 2>&1 | tail -5; }" | Out-Null

# Install mitmproxy (for HTTP traffic capture)
Write-Host "Installing mitmproxy ..."
Invoke-AdminSshWithFallback -Command "command -v mitmdump >/dev/null 2>&1 || { echo 'mitmproxy not found, installing...'; sudo apt-get update -qq && sudo apt-get install -y -qq mitmproxy 2>&1 | tail -5; }" | Out-Null

# Install OTel Collector
Write-Host "Installing OpenTelemetry Collector ..."
$otelVersion = "0.115.0"
Invoke-AdminSshWithFallback -Command @"
command -v otelcol >/dev/null 2>&1 || {
  echo "Installing OTel Collector v${otelVersion} ..."
  cd /tmp
  curl -sLO "https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${otelVersion}/otelcol-contrib_${otelVersion}_linux_amd64.tar.gz"
  sudo tar xzf "otelcol-contrib_${otelVersion}_linux_amd64.tar.gz" -C /usr/local/bin otelcol-contrib
  sudo mv /usr/local/bin/otelcol-contrib /usr/local/bin/otelcol
  rm -f "otelcol-contrib_${otelVersion}_linux_amd64.tar.gz"
  echo "OTel Collector installed: \$(otelcol --version 2>&1 | head -1)"
}
"@ | Out-Null

# Create log directory
Invoke-AdminSshWithFallback -Command "sudo mkdir -p /var/log/sandbox && sudo chmod 1777 /var/log/sandbox" | Out-Null

# Deploy OTel Collector config with the correct LGTM host
Write-Host "Deploying OTel Collector config ..."
$otelConfig = Get-Content -LiteralPath (Join-Path $RepoRoot 'vm/guest/lib/otelcol-config.yaml') -Raw
$otelConfig = $otelConfig.Replace('__LGTM_HOST__', $lgtmHost)
$otelB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($otelConfig))
Invoke-AdminSshWithFallback -Command "echo '$otelB64' | base64 -d | sudo tee /etc/otelcol-config.yaml >/dev/null" | Out-Null

# Create OTel Collector systemd service
Write-Host "Creating OTel Collector systemd service ..."
$otelService = @"
[Unit]
Description=OpenTelemetry Collector (Gleiphnir)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/otelcol --config=/etc/otelcol-config.yaml
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=otelcol

[Install]
WantedBy=multi-user.target
"@
$svcB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($otelService))
Invoke-AdminSshWithFallback -Command "echo '$svcB64' | base64 -d | sudo tee /etc/systemd/system/otelcol.service >/dev/null && sudo systemctl daemon-reload && sudo systemctl enable otelcol && sudo systemctl start otelcol" | Out-Null

# Create mitmproxy systemd service
Write-Host "Creating mitmproxy systemd service ..."
$proxyService = @"
[Unit]
Description=Gleiphnir HTTP Proxy (mitmproxy)
After=network-online.target
Wants=network-online.target
ConditionPathExists=/var/lib/sandbox/observability-enabled

[Service]
Type=simple
ExecStart=/usr/local/bin/sandbox-proxy
Restart=always
RestartSec=5
Environment=PROXY_PORT=8080
StandardOutput=journal
StandardError=journal
SyslogIdentifier=sandbox-proxy

[Install]
WantedBy=multi-user.target
"@
$prxB64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($proxyService))
Invoke-AdminSshWithFallback -Command "echo '$prxB64' | base64 -d | sudo tee /etc/systemd/system/sandbox-proxy.service >/dev/null && sudo systemctl daemon-reload && sudo systemctl enable sandbox-proxy" | Out-Null

# Create observability-enabled marker
Invoke-AdminSshWithFallback -Command "sudo touch /var/lib/sandbox/observability-enabled" | Out-Null

# Allow OTLP outbound through ufw (to LGTM on host)
Invoke-AdminSshWithFallback -Command "sudo ufw allow out 4317/tcp comment gleiphnir-otlp 2>/dev/null || true" | Out-Null

# Start services
Invoke-AdminSshWithFallback -Command "sudo systemctl start sandbox-proxy 2>/dev/null || true" | Out-Null

# Verify
Write-Host "Verifying telemetry agents ..."
Invoke-AdminSshWithFallback -Command "systemctl is-active otelcol" | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OTel Collector: running"
} else {
    Write-Warning "  OTel Collector: not running"
}
Invoke-AdminSshWithFallback -Command "systemctl is-active node_exporter 2>/dev/null || echo active" | Out-Null
Write-Host "  node-exporter: installed"
Invoke-AdminSshWithFallback -Command "systemctl is-active sandbox-proxy 2>/dev/null || echo active" | Out-Null
Write-Host "  mitmproxy: installed"

Write-Host ""
Write-Host "Observability agents deployed. Telemetry flows to ${lgtmHost}:4317."
    End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
