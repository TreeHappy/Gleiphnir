# dotfiles/profile.ps1 — pwsh profile inside the Gleiphnir sandbox container
# Loaded by every interactive pwsh session (CurrentUserAllHosts).
# Activation order matters: mise first (PATH/tools), then history, then completion.

# ── mise: activate ALL manifest tools ──────────────────────────────────────
if (Get-Command mise -ErrorAction SilentlyContinue) {
    try {
        mise activate pwsh | Out-String | Invoke-Expression
    } catch { Write-Verbose "mise activate failed: $_" }
    # Fallback: ensure shims dir is on PATH even if activation was partial
    $shims = Join-Path ($env:MISE_DATA_DIR ?? '/opt/mise-shared/data') 'shims'
    if ((Test-Path $shims) -and -not (($env:PATH -split ':') -contains $shims)) {
        $env:PATH = "${shims}:$env:PATH"
    }
}

# ── env defaults (fallbacks; mise [env] normally provides these) ───────────
$env:EDITOR   ??= 'nvim'
$env:VISUAL   ??= 'nvim'
$env:PAGER    ??= 'less'

# ── atuin: shell history (persisted via the per-user home volume) ──────────
if (Get-Command atuin -ErrorAction SilentlyContinue) {
    try { Invoke-Expression (@(atuin init powershell --disable-up-arrow | Out-String)) } catch { }
}

# ── carapace: completions ──────────────────────────────────────────────────
if (Get-Command carapace -ErrorAction SilentlyContinue) {
    try { carapace _carapace | Out-String | Invoke-Expression } catch { }
}

# ── prompt: dev@sandbox:/work> ─────────────────────────────────────────────
function prompt {
    $p = (Get-Location).Path
    if ($env:HOME -and $p.StartsWith($env:HOME)) { $p = '~' + $p.Substring($env:HOME.Length) }
    Write-Host -NoNewline -ForegroundColor Green  "dev@sandbox"
    Write-Host -NoNewline ":"
    Write-Host -NoNewline -ForegroundColor Blue   $p
    return '> '
}

# ── aliases ────────────────────────────────────────────────────────────────
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem @args }
function gs { git status @args }
function gd { git diff @args }
function gl { git log --oneline --graph --decorate -n 20 @args }
function md { leaf @args }          # markdown reader

# ── workspace reminder on first login ──────────────────────────────────────
if ([Environment]::UserInteractive -and -not (Test-Path /work/.sandbox-welcomed)) {
@'
┌─ Gleiphnir sandbox ──────────────────────────────────────────────┐
│ Container rootfs: read-only & ephemeral.                          │
│ Persistent workspace:  /work   (→ /srv/sandbox/<you> on VM)       │
│ Persistent home:       ~  (caches, history, configs)               │
│ Shared tools volume:   /opt/mise-shared  (downloads once for all) │
│ Default shell: pwsh · Editor: nvim · Diff pager: delta            │
│ Tools via mise:        mise use node@lts / python@3.12 ...        │
└───────────────────────────────────────────────────────────────────┘
'@ | Write-Host
    New-Item -ItemType File -Path /work/.sandbox-welcomed -Force -ErrorAction SilentlyContinue | Out-Null
}
