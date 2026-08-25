# vm/scripts/container-build.ps1 — build the sandbox image inside the running VM
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Write-Host "Building sandbox container image inside VM ($CONTAINER_IMAGE) ..."
$code = Invoke-AdminSshWithFallback -Command "sudo /usr/local/lib/sandbox/build-container.sh 2>&1 | tail -100"
if ($code -ne 0) { exit $code }
Write-Host ""
Write-Host "Verifying ..."
$code = Invoke-AdminSshWithFallback -Command "podman images | grep -E 'REPOSITORY|sandbox' || podman images | head -20"
exit $code
