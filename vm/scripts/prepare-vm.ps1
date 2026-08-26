# vm/scripts/prepare-vm.ps1 — build seed ISO and data disk from cloud-init templates
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Write-Host "==> Preparing VM (mode: $($env:NETWORK_MODE))"

Require-BaseImage
if (-not (Test-Path -LiteralPath $IMAGES_DIR)) { New-Item -ItemType Directory -Path $IMAGES_DIR -Force | Out-Null }

# ── detect TUN availability for bridge mode ────────────────────────────────
if ($env:NETWORK_MODE -eq 'bridge' -and -not $IsWin -and -not (Test-Path '/dev/net/tun')) {
    Write-Warning "/dev/net/tun not available — bridge mode requires TAP support."
    Write-Warning "Switching to user-mode NAT for this run."
    $env:NETWORK_MODE = 'user'
}

# ── admin SSH key ──────────────────────────────────────────────────────────
if (-not (Test-Path -LiteralPath $ADMIN_SSH_KEY_PATH)) {
    Write-Host "Admin key not found at $ADMIN_SSH_KEY_PATH — generating one ..."
    & (Join-Path $PSScriptRoot 'gen-key.ps1')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
$adminPub = (Get-Content -LiteralPath $ADMIN_SSH_KEY_PATH -Raw).Trim()
if (-not $adminPub) { Write-Error "Failed to read admin public key at $ADMIN_SSH_KEY_PATH" }
Write-Host "Admin key: $ADMIN_SSH_KEY_PATH"
Write-Host "Admin user: $($env:ADMIN_USER)"

# ── MAC ────────────────────────────────────────────────────────────────────
$vmMac = Get-VmMac
Write-Host "VM MAC: $vmMac"

# ── disks ──────────────────────────────────────────────────────────────────
if (-not (Test-Path -LiteralPath $SYSTEM_DISK)) {
    Write-Host "Creating system overlay disk $SYSTEM_DISK (backing: $BASE_IMAGE, size: $VM_DISK_SIZE) ..."
    & qemu-img create -f qcow2 -F qcow2 -b $BASE_IMAGE $SYSTEM_DISK $VM_DISK_SIZE
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "System disk already exists: $SYSTEM_DISK"
    & qemu-img info $SYSTEM_DISK | Select-Object -First 5
}

if (-not (Test-Path -LiteralPath $DATA_DISK)) {
    Write-Host "Creating data disk $DATA_DISK ($DATA_DISK_SIZE) ..."
    & qemu-img create -f qcow2 $DATA_DISK $DATA_DISK_SIZE
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
    Write-Host "Data disk already exists: $DATA_DISK"
    & qemu-img info $DATA_DISK | Select-Object -First 5
}

# ── cloud-init staging ─────────────────────────────────────────────────────
$cloudInitDir = Join-Path $RepoRoot 'vm/cloud-init'
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("gleiphnir-seed-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    Write-Host "Generating cloud-init seed ISO ..."

    $template = Join-Path $cloudInitDir 'user-data.yaml.tpl'
    if (-not (Test-Path -LiteralPath $template)) { Write-Error "Template not found: $template" }
    Copy-Item -LiteralPath $template -Destination (Join-Path $tmp 'user-data')

    # Template user-data via the python helper (explicit argv, no shell interpolation)
    $python = (Get-Command python3 -ErrorAction SilentlyContinue) ?? (Get-Command python -ErrorAction SilentlyContinue)
    if (-not $python) { Write-Error "python3/python is required for templating" }
    & $python.Source (Join-Path $PSScriptRoot 'template_userdata.py') `
        $tmp $RepoRoot $ADMIN_SSH_KEY_PATH $env:ADMIN_USER $env:VM_HOSTNAME $CONTAINER_IMAGE
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    # network-config depends on NETWORK_MODE
    if ($env:NETWORK_MODE -eq 'user') {
        $netSrc = Join-Path $cloudInitDir 'network-config.user.yaml'
    } else {
        $netSrc = Join-Path $cloudInitDir 'network-config.bridge.yaml'
    }
    if (Test-Path -LiteralPath $netSrc) {
        $netText = Get-Content -LiteralPath $netSrc -Raw
        $netText = $netText.Replace('__VM_IP__', $VM_IP)
        $netText = $netText.Replace('__VM_NETMASK__', $VM_NETMASK)
        $netText = $netText.Replace('__VM_GATEWAY__', $VM_GATEWAY)
        $netText = $netText.Replace('__VM_MAC__', $vmMac)
        Set-Content -LiteralPath (Join-Path $tmp 'network-config') -Value $netText -NoNewline
        Write-Host "Using network-config: $netSrc"
    } else {
        Write-Warning "network-config source not found: $netSrc — using DHCP fallback"
        @'
version: 2
ethernets:
  vmnet:
    match: {name: "en*"}
    dhcp4: true
'@ | Set-Content -LiteralPath (Join-Path $tmp 'network-config')
    }

    $metaSrc = Join-Path $cloudInitDir 'meta-data'
    if (Test-Path -LiteralPath $metaSrc) {
        Copy-Item -LiteralPath $metaSrc -Destination (Join-Path $tmp 'meta-data')
    } else {
        "instance-id: $VM_NAME" | Set-Content -LiteralPath (Join-Path $tmp 'meta-data')
    }

    Write-Host "--- user-data preview (first 80 lines) ---"
    Get-Content -LiteralPath (Join-Path $tmp 'user-data') | Select-Object -First 80
    Write-Host "--- network-config ---"
    Get-Content -LiteralPath (Join-Path $tmp 'network-config')

    # ── build seed ISO: cloud-localds → genisoimage/mkisofs → oscdimg → pycdlib ──
    $userData = Join-Path $tmp 'user-data'
    $metaData = Join-Path $tmp 'meta-data'
    $netConf  = Join-Path $tmp 'network-config'
    $built    = $false

    foreach ($tool in @('cloud-localds', 'genisoimage', 'mkisofs')) {
        $cmd = Get-Command $tool -ErrorAction SilentlyContinue
        if (-not $cmd) { continue }
        if ($tool -eq 'cloud-localds') {
            Write-Host "Building seed ISO with cloud-localds ..."
            & cloud-localds $SEED_ISO $userData $metaData --network-config=$netConf --verbose
        } else {
            Write-Host "Building seed ISO with $tool fallback ..."
            & $cmd.Source -output $SEED_ISO -volid cidata -joliet -rock $userData $metaData $netConf 2>&1 |
                Select-Object -First 20
        }
        $built = ($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $SEED_ISO)
        if ($built) { break }
    }

    if (-not $built -and $IsWin) {
        $oscdimg = Get-Command oscdimg -ErrorAction SilentlyContinue
        if ($oscdimg) {
            Write-Host "Building seed ISO with oscdimg ..."
            & $oscdimg.Source "-m" "-o" "-j1" $tmp $SEED_ISO 2>&1 | Select-Object -Last 10
            $built = ($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $SEED_ISO)
        }
    }

    if (-not $built) {
        Write-Host "No native ISO tool found — trying pycdlib (pip install pycdlib) ..."
        & $python.Source -c "import pycdlib" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error @"
Cannot build seed ISO. Install one of:
  Ubuntu: sudo apt-get install cloud-image-utils      (cloud-localds)
          or: pip3 install pycdlib                    (cross-platform)
  Windows: pip install pycdlib                        (recommended)
"@
        }
        & $python.Source (Join-Path $PSScriptRoot 'build_seed_iso.py') $SEED_ISO $userData $metaData $netConf
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
}
finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

Get-Item -LiteralPath $SEED_ISO | ForEach-Object { "{0,8:N1} KB  {1}" -f ($_.Length / 1KB), $_.FullName }
Write-Host ""
Write-Host "VM preparation complete. Disks:"
Get-ChildItem -LiteralPath $IMAGES_DIR | Format-Table Name, @{n='Size';e={"{0:N1} MB" -f ($_.Length/1MB)}} -AutoSize
Write-Host ""
Write-Host "Next: mise run vm:start  (or mise run up for full bring-up)"
