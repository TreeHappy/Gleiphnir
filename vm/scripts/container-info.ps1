# vm/scripts/container-info.ps1 — show container image info from inside the VM
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Start-OtelSpan 'gleiphnir.container_info' @{ 'script.name' = 'container-info.ps1'; 'service.name' = $env:OTEL_SERVICE_NAME }
try {
$cmd = @"
echo '=== images ==='; podman images; echo; echo '=== inspect __IMG__ ==='; podman image inspect __IMG__ --format '{{.Os}}/{{.Architecture}} {{.Size}} bytes  created {{.Created}}' 2>&1
"@.Replace('__IMG__', $CONTAINER_IMAGE)

    End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
exit (Invoke-AdminSshWithFallback -Command $cmd)
