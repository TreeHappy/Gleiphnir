# vm/scripts/download-image.ps1 — download the Ubuntu cloud image (qcow2)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Start-OtelSpan 'gleiphnir.download_image' @{ 'script.name' = 'download-image.ps1'; 'service.name' = $env:OTEL_SERVICE_NAME }
try {
if (-not (Test-Path -LiteralPath $IMAGES_DIR)) { New-Item -ItemType Directory -Path $IMAGES_DIR -Force | Out-Null }

if (Test-Path -LiteralPath $BASE_IMAGE) {
    Write-Host "Base image already exists: $BASE_IMAGE"
    Write-Host "Remove it first to re-download, or run: mise run image:info"
    & qemu-img info $BASE_IMAGE 2>$null
    exit 0
}

Write-Host "Downloading Ubuntu cloud image:"
Write-Host "  URL:  $UBUNTU_IMAGE_URL"
Write-Host "  Dest: $BASE_IMAGE"
Write-Host ""

$ProgressPreference = 'SilentlyContinue'
$curl = Get-Command curl -ErrorAction SilentlyContinue
$wget = Get-Command wget -ErrorAction SilentlyContinue

if ($curl) {
    & curl -L --progress-bar -o $BASE_IMAGE $UBUNTU_IMAGE_URL
    if ($LASTEXITCODE -ne 0) { Write-Error "curl download failed ($LASTEXITCODE)" }
} elseif ($wget) {
    & wget -O $BASE_IMAGE $UBUNTU_IMAGE_URL
    if ($LASTEXITCODE -ne 0) { Write-Error "wget download failed ($LASTEXITCODE)" }
} else {
    Invoke-WebRequest -Uri $UBUNTU_IMAGE_URL -OutFile $BASE_IMAGE
}

Write-Host ""
Write-Host "Verifying image:"
& qemu-img info $BASE_IMAGE
Get-Item -LiteralPath $BASE_IMAGE | ForEach-Object { "{0,10:N1} MB  {1}" -f ($_.Length / 1MB), $_.FullName }
Write-Host ""
Write-Host "Done. Next: mise run vm:prepare"
End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
