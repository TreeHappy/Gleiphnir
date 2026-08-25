# vm/scripts/smoke-test.ps1 — end-to-end checks against a running VM
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Write-Host "=== Gleiphnir smoke test ==="
Write-Host "VM: $VM_IP  Forward: :$HOST_SSH_FORWARD_PORT  Mode: $($env:NETWORK_MODE)"
Write-Host ""

$script:pass = 0
$script:fail = 0
function script:Check([string]$Desc, [scriptblock]$Body) {
    Write-Host "  [ ] $Desc ... " -NoNewline
    try {
        $code = & $Body
        $ok = if ($null -eq $code) { $LASTEXITCODE -eq 0 } else { $code -eq 0 }
    } catch { $ok = $false }
    if ($ok) { Write-Host "PASS"; $script:pass++ }
    else     { Write-Host "FAIL"; $script:fail++ }
}

function script:Run-C([string]$Inner) {
    # Run a bash snippet inside a one-shot sandbox container (same flags as sandbox-shell)
    Invoke-AdminSshWithFallback -Command (
        "podman run --rm --read-only --tmpfs /tmp:rw,mode=1777 --tmpfs /run:rw,mode=755 " +
        "--cap-drop ALL --security-opt no-new-privileges " +
        "-v sandbox-mise:/opt/mise-shared:rw " +
        "-v /srv/sandbox/.smoke:/work:rw -w /work $CONTAINER_IMAGE bash -c '" + ($Inner -replace "'", "'\\''") + "'"
    )
}

# ── discover/create a sandbox user ─────────────────────────────────────────
Write-Host "Discovering sandbox users ..."
$usersRaw = ''
Invoke-AdminSshWithFallback -Command "ls -1 /srv/sandbox 2>/dev/null | head -5" | ForEach-Object { $usersRaw += "$_`n" }
$users = @($usersRaw -split "`n" | Where-Object { $_ -match '\S' })
$ephemeral = $false

if ($users.Count -eq 0) {
    Write-Host ""
    Write-Host "No sandbox workspaces found. Creating ephemeral test user 'smoketest' ..."
    $tmpKey = Join-Path ([IO.Path]::GetTempPath()) ("smoke-" + [Guid]::NewGuid().ToString('N').Substring(0,6))
    & ssh-keygen -t ed25519 -f $tmpKey -N '' -C 'smoketest@smoke' *>$null
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Get-Content "$tmpKey.pub" -Raw).Trim()))
    Invoke-AdminSshWithFallback -Command "echo '$b64' | base64 -d | sudo /usr/local/bin/sandbox-user add smoketest --key-file /dev/stdin 2>&1 | tail -5" | Out-Null
    Remove-Item "$tmpKey", "$tmpKey.pub" -Force -ErrorAction SilentlyContinue
    $users = @('smoketest')
    $ephemeral = $true
}
$testUser = $users[0].Trim()
Write-Host "Testing as user: $testUser"
Write-Host ""

Write-Host "--- VM-level checks (as admin) ---"
Check 'VM SSH reachable'            { Invoke-AdminSsh -Command 'true' -QuickTimeout }
Check 'ufw active'                  { Invoke-AdminSsh -Command 'sudo ufw status | grep -qv inactive' }
Check 'podman works'                { Invoke-AdminSsh -Command 'podman info >/dev/null' }
Check 'sandbox image exists'        { Invoke-AdminSsh -Command "podman image exists $CONTAINER_IMAGE" }
Check 'shared mise volume exists'   { Invoke-AdminSsh -Command 'podman volume exists sandbox-mise' }
Check 'data disk mounted at /srv/sandbox' { Invoke-AdminSsh -Command 'mountpoint -q /srv/sandbox' }

Write-Host ""
Write-Host "--- container checks ---"
Invoke-AdminSshWithFallback -Command "sudo mkdir -p /srv/sandbox/.smoke && sudo chown 1000:1000 /srv/sandbox/.smoke" | Out-Null

Check 'container starts and prints hello'      { Run-C 'echo hello | grep -q hello' }
Check 'default chain boots into pwsh'          { Invoke-AdminSshWithFallback -Command "podman run --rm --read-only --tmpfs /tmp:rw,mode=1777 --cap-drop ALL --security-opt no-new-privileges -v /srv/sandbox/.smoke:/work:rw -w /work $CONTAINER_IMAGE -NoProfile -NoLogo -Command '`$PSVersionTable.PSEdition' | grep -q Core" }
Check 'rootfs is read-only (touch / fails)'    { Run-C '! touch /should-fail 2>/dev/null' }
Check '/work is writable'                      { Run-C 'touch /work/smoke-marker && ls /work/smoke-marker' }
Check 'no sudo in container'                   { Run-C '! command -v sudo >/dev/null' }
Check 'git present'                            { Run-C 'git --version | grep -q git' }
Check 'mise present'                           { Run-C 'mise --version | grep -q mise' }
Check 'mise env provides EDITOR=nvim'          { Run-C 'bash -lc "mise env | grep -q EDITOR=nvim"' }
Check 'core tools (rg/fd/fzf/delta/yazi)'      { Run-C 'for t in rg fd fzf delta yazi; do command -v \$t >/dev/null || exit 1; done' }
Check 'extra tools (nvim/hunk/opencode/leaf/atuin/carapace/dotnet)' { Run-C 'for t in nvim hunk opencode leaf atuin carapace dotnet; do command -v \$t >/dev/null || exit 1; done' }

Write-Host ""
Write-Host "--- firewall checks ---"
Check 'sandbox-firewall list works'            { Invoke-AdminSsh -Command 'sudo /usr/local/bin/sandbox-firewall list >/dev/null' }
Check 'sandbox-firewall allow 192.0.2.1'       { Invoke-AdminSsh -Command 'sudo /usr/local/bin/sandbox-firewall allow 192.0.2.1' }
Check 'sandbox-firewall remove 192.0.2.1'      { Invoke-AdminSsh -Command 'sudo /usr/local/bin/sandbox-firewall remove 192.0.2.1' }

# cleanup
Invoke-AdminSshWithFallback -Command 'sudo rm -rf /srv/sandbox/.smoke' | Out-Null
if ($ephemeral) {
    Write-Host ""
    Write-Host "Cleaning up ephemeral smoketest user ..."
    Invoke-AdminSshWithFallback -Command 'sudo /usr/local/bin/sandbox-user remove smoketest 2>&1 | tail -3' | Out-Null
}

Write-Host ""
Write-Host "=== Results: $script:pass passed, $script:fail failed ==="
if ($script:fail -gt 0) { Write-Host "Some checks failed — see above."; exit 1 }
Write-Host "All smoke checks passed."
