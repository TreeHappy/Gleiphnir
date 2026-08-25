# vm/scripts/clean-vm.ps1 — remove generated disks/seed (keep base image unless -All)
param([switch]$All)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

if (Test-VmRunning) {
    Write-Error "VM is running — stop it first: mise run vm:stop"
}

Write-Host "Cleaning VM artifacts in ${IMAGES_DIR} (all=$All) ..."
$targets = @($SEED_ISO, $SYSTEM_DISK, $DATA_DISK, $PID_FILE, $MONITOR_SOCK, $CONSOLE_LOG,
             (Join-Path $IMAGES_DIR 'mac.addr'))
foreach ($f in $targets) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Force }
}

if ($All) {
    Write-Host "Removing base image as well (-All)"
    if (Test-Path -LiteralPath $BASE_IMAGE) { Remove-Item -LiteralPath $BASE_IMAGE -Force }
}

Write-Host "Done. Remaining in ${IMAGES_DIR}:"
if (Test-Path -LiteralPath $IMAGES_DIR) {
    Get-ChildItem -LiteralPath $IMAGES_DIR | Format-Table Name, @{n='Size';e={"{0:N1} MB" -f ($_.Length/1MB)}} -AutoSize
} else {
    Write-Host "(empty)"
}
