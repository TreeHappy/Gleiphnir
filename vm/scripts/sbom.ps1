# vm/scripts/sbom.ps1 — generate SBOMs for Gleiphnir components
# SSHes into the VM and runs sandbox-sbom, then copies results to the host.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$usage = @"
sbom.ps1 — generate Software Bill of Materials

Usage:
  sbom.ps1 container [--format spdx-json|cyclonedx] [--output DIR]
  sbom.ps1 tools     [--format spdx-json|cyclonedx] [--output DIR]
  sbom.ps1 vm        [--format spdx-json|cyclonedx] [--output DIR]
  sbom.ps1 all       [--format spdx-json|cyclonedx] [--output DIR]

SBOMs are generated inside the VM via sandbox-sbom and copied to the
host repo under sbom/ (or a custom --output directory).
"@

# Parse arguments
$SubCmd = ""
$Format = "spdx-json"
$OutputDir = Join-Path $RepoRoot 'sbom'

$args_list = @($args)
$i = 0
while ($i -lt $args_list.Count) {
    switch ($args_list[$i]) {
        'container' { $SubCmd = 'container'; $i++ }
        'tools'     { $SubCmd = 'tools'; $i++ }
        'vm'        { $SubCmd = 'vm'; $i++ }
        'all'       { $SubCmd = 'all'; $i++ }
        '--format'  { $Format = $args_list[$i+1]; $i += 2 }
        '--output'  { $OutputDir = $args_list[$i+1]; $i += 2 }
        '-h'        { Write-Host $usage; exit 0 }
        '--help'    { Write-Host $usage; exit 0 }
        default     { Write-Error "Unknown argument: $($args_list[$i])"; Write-Host $usage; exit 1 }
    }
}

if (-not $SubCmd) {
    Write-Host $usage
    exit 1
}

# Ensure output directory exists on host
if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Host "==> Generating SBOM: $SubCmd (format: $Format)"

# Run sandbox-sbom inside the VM (as admin, since syft may need to inspect the image)
$vmOutputDir = "/tmp/sbom-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$cmd = "sudo -u $($env:ADMIN_USER) sandbox-sbom $SubCmd --format $Format --output $vmOutputDir 2>&1"
$code = Invoke-AdminSshWithFallback -Command $cmd
if ($code -ne 0) { exit $code }

# List generated files
$listCmd = "ls -la $vmOutputDir/ 2>/dev/null"
Invoke-AdminSshWithFallback -Command $listCmd | Out-Null

# Copy SBOM files from VM to host
Write-Host "Copying SBOM files to $OutputDir ..."

# Use scp to copy files back
$keyArgs = @()
if (Test-Path -LiteralPath $ADMIN_SSH_PRIV_PATH) {
    $keyArgs = @('-i', $ADMIN_SSH_PRIV_PATH)
}
$sshBase = @('-o', 'StrictHostKeyChecking=no', '-o', "UserKnownHostsFile=$(if ($IsWin) { 'NUL' } else { '/dev/null' })", '-o', 'LogLevel=ERROR')

$target = "$($env:ADMIN_USER)@$($env:VM_IP)"
if ($env:NETWORK_MODE -eq 'user') {
    $target = "$($env:ADMIN_USER)@127.0.0.1"
    $sshBase += @('-p', $HOST_SSH_FORWARD_PORT)
}

# Get the list of files to copy
$filesCmd = "ls $vmOutputDir/*.* 2>/dev/null || true"
$tmpSbomList = Join-Path ([System.IO.Path]::GetTempPath()) "sbom-list-$(Get-Random).txt"
$scpArgs = @()
$scpArgs += $keyArgs
$scpArgs += $sshBase
$scpArgs += "${target}:${vmOutputDir}/*"
$scpArgs += "$OutputDir/"

& scp @scpArgs 2>&1 | ForEach-Object { Write-Host "  $_" }

# Cleanup VM temp dir
$cleanupCmd = "rm -rf $vmOutputDir"
Invoke-AdminSshWithFallback -Command $cleanupCmd | Out-Null

# List host output
Write-Host ""
Write-Host "SBOM files in $OutputDir :"
Get-ChildItem -LiteralPath $OutputDir -File | Sort-Object LastWriteTime -Descending |
    Select-Object -First 10 |
    ForEach-Object { Write-Host "  $($_.Name)  $([math]::Round($_.Length / 1KB, 1)) KB" }

Write-Host ""
Write-Host "Done."
