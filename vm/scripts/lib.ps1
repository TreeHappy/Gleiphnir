# vm/scripts/lib.ps1 — shared helpers for all vm/scripts/*.ps1
# Usage (dot-source from a sibling script):  . (Join-Path $PSScriptRoot 'lib.ps1')

$ErrorActionPreference = 'Stop'

$script:ScriptDir = $PSScriptRoot
$script:RepoRoot  = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$script:ConfigFile = Join-Path $RepoRoot 'config/sandbox.env'

# ── config/sandbox.env ─────────────────────────────────────────────────────
# KEY=VALUE lines; '#' comments ignored. File values win over inherited env,
# matching previous bash behaviour (`set -a; source ...`).
if (Test-Path -LiteralPath $ConfigFile) {
    foreach ($line in Get-Content -LiteralPath $ConfigFile) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $idx = $line.IndexOf('=')
        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim()
        if ($key -eq '') { continue }
        # strip simple surrounding quotes
        if ($val.Length -ge 2 -and (($val.StartsWith('"') -and $val.EndsWith('"')) -or ($val.StartsWith("'") -and $val.EndsWith("'")))) {
            $val = $val.Substring(1, $val.Length - 2)
        }
        Set-Item -Path "env:$key" -Value $val
    }
}

# ── defaults (mirror sandbox.env) ──────────────────────────────────────────
function script:Set-Default([string]$Key, [string]$Value) {
    $existing = [System.Environment]::GetEnvironmentVariable($Key)
    if ([string]::IsNullOrEmpty($existing)) {
        Set-Item -Path "env:$Key" -Value $Value
    }
}

Set-Default 'VM_NAME'               'gleiphnir'
Set-Default 'VM_HOSTNAME'           'gleiphnir'
Set-Default 'UBUNTU_RELEASE'        'resolute'
Set-Default 'UBUNTU_VERSION'        '26.04'
Set-Default 'UBUNTU_ARCH'           'amd64'
Set-Default 'UBUNTU_IMAGE_URL'      ''
Set-Default 'VM_CPUS'               '4'
Set-Default 'VM_RAM_MB'             '4096'
Set-Default 'VM_DISK_SIZE'          '20G'
Set-Default 'DATA_DISK_SIZE'        '20G'
Set-Default 'QEMU_EXTRA_ARGS'       ''
Set-Default 'QEMU_BIN'              'qemu-system-x86_64'
Set-Default 'QEMU_ACCEL'            'auto'      # auto|kvm|whpx|tcg
Set-Default 'QEMU_MONITOR_PORT'     '4444'      # TCP monitor on Windows hosts
Set-Default 'NETWORK_MODE'          'bridge'
Set-Default 'BRIDGE_NAME'           'br-gleiphnir'
Set-Default 'TAP_NAME'              'tap-gleiphnir'
Set-Default 'BRIDGE_ADDR'           '192.168.100.1'
Set-Default 'BRIDGE_NETMASK'        '24'
Set-Default 'BRIDGE_NETWORK'        '192.168.100.0/24'
Set-Default 'VM_IP'                 '192.168.100.10'
Set-Default 'VM_NETMASK'            '24'
Set-Default 'VM_GATEWAY'            '192.168.100.1'
Set-Default 'VM_MAC'                ''
Set-Default 'PHYS_IF'               ''
Set-Default 'HOST_SSH_FORWARD_PORT' '2222'
Set-Default 'ADMIN_USER'            'admin'
Set-Default 'ADMIN_SSH_KEY_PATH'    '~/.ssh/gleiphnir_admin.pub'
Set-Default 'ADMIN_SSH_PRIV_PATH'   '~/.ssh/gleiphnir_admin'
Set-Default 'IMAGES_DIR'            'vm/images'
Set-Default 'SEED_ISO'              'vm/images/seed.iso'
Set-Default 'SYSTEM_DISK'           'vm/images/system.qcow2'
Set-Default 'DATA_DISK'             'vm/images/data.qcow2'
Set-Default 'CONTAINER_IMAGE'       'localhost/sandbox:latest'

$script:IsWin = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)

# ── path helpers ───────────────────────────────────────────────────────────
function script:Expand-RepoPath([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return $p }
    if ($p.StartsWith('~')) {
        $p = Join-Path ([System.Environment]::GetFolderPath('UserProfile')) $p.Substring(1).TrimStart('/','\')
    }
    if (-not [System.IO.Path]::IsPathRooted($p)) {
        $p = Join-Path $RepoRoot $p
    }
    return [System.IO.Path]::GetFullPath($p)
}

# Expand selected path vars in place (env + convenience vars below)
foreach ($_pathVar in @('IMAGES_DIR','SEED_ISO','SYSTEM_DISK','DATA_DISK','ADMIN_SSH_KEY_PATH','ADMIN_SSH_PRIV_PATH')) {
    Set-Item -Path "env:$_pathVar" -Value (Expand-RepoPath ([System.Environment]::GetEnvironmentVariable($_pathVar)))
}
Remove-Variable -Name _pathVar -ErrorAction SilentlyContinue

# Auto-construct image URL if empty
if ([string]::IsNullOrEmpty($env:UBUNTU_IMAGE_URL)) {
    $env:UBUNTU_IMAGE_URL = "https://cloud-images.ubuntu.com/$($env:UBUNTU_RELEASE)/current/$($env:UBUNTU_RELEASE)-server-cloudimg-$($env:UBUNTU_ARCH).img"
}

# Derived paths
$env:BASE_IMAGE   = Join-Path $env:IMAGES_DIR "$($env:UBUNTU_RELEASE)-server-cloudimg-$($env:UBUNTU_ARCH).img"
$env:PID_FILE     = Join-Path $env:IMAGES_DIR 'qemu.pid'
$env:CONSOLE_LOG  = Join-Path $env:IMAGES_DIR 'console.log'
$env:MAC_FILE     = Join-Path $env:IMAGES_DIR 'mac.addr'
$env:MONITOR_SOCK = Join-Path $env:IMAGES_DIR 'qemu-monitor.sock'

# Convenience variables (same names as the old bash lib)
foreach ($_v in @('VM_NAME','VM_HOSTNAME','UBUNTU_RELEASE','UBUNTU_VERSION','UBUNTU_ARCH','UBUNTU_IMAGE_URL',
                  'VM_CPUS','VM_RAM_MB','VM_DISK_SIZE','DATA_DISK_SIZE','QEMU_EXTRA_ARGS','QEMU_BIN','QEMU_ACCEL',
                  'QEMU_MONITOR_PORT','NETWORK_MODE','BRIDGE_NAME','TAP_NAME','BRIDGE_ADDR','BRIDGE_NETMASK',
                  'BRIDGE_NETWORK','VM_IP','VM_NETMASK','VM_GATEWAY','VM_MAC','PHYS_IF','HOST_SSH_FORWARD_PORT',
                  'ADMIN_USER','IMAGES_DIR','SEED_ISO','SYSTEM_DISK','DATA_DISK','CONTAINER_IMAGE',
                  'BASE_IMAGE','PID_FILE','CONSOLE_LOG','MAC_FILE','MONITOR_SOCK','ADMIN_SSH_KEY_PATH','ADMIN_SSH_PRIV_PATH')) {
    Set-Variable -Name $_v -Value ([System.Environment]::GetEnvironmentVariable($_v))
}
Remove-Variable -Name _v -ErrorAction SilentlyContinue

# ── small helpers ──────────────────────────────────────────────────────────
function script:Get-NullDevice { if ($script:IsWin) { 'NUL' } else { '/dev/null' } }

function script:Test-MonitorTcp { $script:IsWin }

function script:Get-MonitorDescription {
    if (Test-MonitorTcp) { "tcp:127.0.0.1:$($env:QEMU_MONITOR_PORT)" } else { "unix:$env:MONITOR_SOCK" }
}

function Get-VmMac {
    if (-not [string]::IsNullOrEmpty($env:VM_MAC)) { return $env:VM_MAC }
    if (Test-Path -LiteralPath $MAC_FILE) { return (Get-Content -LiteralPath $MAC_FILE -Raw).Trim() }
    $mac = '52:54:00:{0:x2}:{1:x2}:{2:x2}' -f (Get-Random -Maximum 256), (Get-Random -Maximum 256), (Get-Random -Maximum 256)
    $dir = Split-Path -Parent $MAC_FILE
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -LiteralPath $MAC_FILE -Value $mac -NoNewline
    return $mac
}

function script:Get-QemuPids {
    $pids = @()
    # pidfile first
    if (Test-Path -LiteralPath $PID_FILE) {
        $raw = (Get-Content -LiteralPath $PID_FILE -Raw -ErrorAction SilentlyContinue)
        $pidVal = 0
        if ([int]::TryParse("$raw".Trim(), [ref]$pidVal)) {
            if (Get-Process -Id $pidVal -ErrorAction SilentlyContinue) { $pids += $pidVal }
        }
    }
    if ($pids.Count -gt 0) { return $pids }
    # fallback: scan processes whose command line mentions qemu + VM name
    try {
        if ($script:IsWin) {
            $procs = Get-CimInstance Win32_Process -Filter "Name LIKE 'qemu%'" -ErrorAction Stop |
                Where-Object { $_.CommandLine -match 'qemu' -and $_.CommandLine -match [regex]::Escape($VM_NAME) }
            $pids += @($procs | ForEach-Object { [int]$_.ProcessId })
        } else {
            foreach ($procDir in (Get-ChildItem '/proc' -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d+$' })) {
                $cmdFile = Join-Path $procDir.FullName 'cmdline'
                if (-not (Test-Path -LiteralPath $cmdFile)) { continue }
                $bytes = [System.IO.File]::ReadAllBytes($cmdFile)
                if ($bytes.Length -eq 0) { continue }
                $cmd = [System.Text.Encoding]::UTF8.GetString(($bytes | ForEach-Object { if ($_ -eq 0) { 32 } else { $_ } }))
                if ($cmd -match 'qemu' -and $cmd -match [regex]::Escape($VM_NAME)) { $pids += [int]$procDir.Name }
            }
        }
    } catch { }
    return @($pids | Select-Object -Unique)
}

function Test-VmRunning {
    return ((Get-QemuPids).Count -gt 0)
}

function Require-BaseImage {
    if (-not (Test-Path -LiteralPath $BASE_IMAGE)) {
        Write-Error "Base image not found: $BASE_IMAGE`nRun: mise run image:download"
    }
}

function script:Get-KeyArgs {
    if (Test-Path -LiteralPath $ADMIN_SSH_PRIV_PATH) { return @('-i', $ADMIN_SSH_PRIV_PATH) }
    return @()
}

function script:Get-SshCommonArgs {
    return @('-o', 'StrictHostKeyChecking=no',
             '-o', "UserKnownHostsFile=$(Get-NullDevice)",
             '-o', 'LogLevel=ERROR')
}

# Invoke a command on the VM as admin. Streams output; returns exit code.
function Invoke-AdminSsh {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [switch]$QuickTimeout,
        [switch]$Quiet
    )
    $sshArgs = @()
    $sshArgs += Get-KeyArgs
    $sshArgs += Get-SshCommonArgs
    if ($QuickTimeout) { $sshArgs += @('-o', 'ConnectTimeout=3') }
    if ($Quiet)        { $sshArgs += @('-o', 'BatchMode=yes') }

    if ($env:NETWORK_MODE -eq 'user') {
        $sshArgs += @('-p', $HOST_SSH_FORWARD_PORT)
        $sshArgs += "$($env:ADMIN_USER)@127.0.0.1"
    } else {
        $sshArgs += "$($env:ADMIN_USER)@$env:VM_IP"
    }
    $sshArgs += $Command
    if ($Quiet) { & ssh @sshArgs 2>$null } else { & ssh @sshArgs }
    return $LASTEXITCODE
}

# Invoke-AdminSshWithFallback: direct IP first, then host-forward (bridge mode).
function Invoke-AdminSshWithFallback {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Command)
    if ($env:NETWORK_MODE -eq 'user') {
        return (Invoke-AdminSsh -Command $Command)
    }
    $code = Invoke-AdminSsh -Command $Command -QuickTimeout
    if ($code -eq 0) { return 0 }
    $sshArgs = @()
    $sshArgs += Get-KeyArgs
    $sshArgs += Get-SshCommonArgs
    $sshArgs += @('-p', $HOST_SSH_FORWARD_PORT, "$($env:ADMIN_USER)@127.0.0.1", $Command)
    & ssh @sshArgs
    return $LASTEXITCODE
}

function script:Write-Info([string]$msg) { Write-Host $msg }
