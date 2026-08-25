# vm/scripts/image-info.ps1 — show downloaded image info
$ErrorActionAttribute = $null
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$base = $BASE_IMAGE
if (-not (Test-Path -LiteralPath $base)) {
    $found = Get-ChildItem -LiteralPath $IMAGES_DIR -Filter '*.img' -ErrorAction SilentlyContinue | Select-Object -First 1
    $base = if ($found) { $found.FullName } else { '' }
}

if ($base -and (Test-Path -LiteralPath $base)) {
    & qemu-img info $base
    Get-Item -LiteralPath $base | ForEach-Object { "{0,10:N1} MB  {1}" -f ($_.Length / 1MB), $_.FullName }
} else {
    Write-Host "No image found. Run: mise run image:download"
}
