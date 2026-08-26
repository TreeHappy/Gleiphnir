# gleiphnir.ps1 — Gleiphnir host orchestration CLI (pwsh shim, wraps mise tasks)
# Alias: gle
$ErrorActionPreference = 'Stop'

function Show-Usage {
  @"
gleiphnir (gle) — Gleiphnir host orchestration CLI (wraps mise tasks) — pwsh

Usage:
  gleiphnir deps
  gleiphnir image download|info
  gleiphnir network up|down|status
  gleiphnir vm prepare|start|stop|kill|console|ssh|ssh:wait|info|clean|clean:all
  gleiphnir user add|remove|list
  gleiphnir fw allow|deny|remove|list|enforce
  gleiphnir container build|info
  gleiphnir sbom container|tools|vm|all
  gleiphnir tools list|info|clean|clean:all|volumes
  gleiphnir obs start|stop|status|open|deploy|clean
  gleiphnir secrets init|encrypt|decrypt|sync|list|status
  gleiphnir up|down|smoke
"@
}

# Find mise
$mise = Get-Command mise -ErrorAction SilentlyContinue
if (-not $mise) { $mise = "mise" }

function Invoke-MiseTask {
  param([string]$Task, [string[]]$Extra)
  $miseBin = if ($mise -is [string]) { $mise } else { $mise.Source }
  if ($Extra.Count -eq 0) {
    & $miseBin run $Task
  } else {
    & $miseBin run $Task -- @Extra
  }
  exit $LASTEXITCODE
}

if ($args.Count -eq 0 -or $args[0] -in @('-h','--help','help')) { Show-Usage; exit 0 }

$cmd = $args[0]
$rest = @()
if ($args.Count -gt 1) { $rest = $args[1..($args.Count-1)] }

switch ($cmd) {
  'deps' { Invoke-MiseTask 'deps' $rest }
  'install:deps' { Invoke-MiseTask 'install:deps' $rest }
  'gen:key' { Invoke-MiseTask 'gen:key' $rest }
  'image' {
    if ($rest.Count -eq 0) { Show-Usage; exit 1 }
    switch ($rest[0]) {
      'download' { Invoke-MiseTask 'image:download' $rest[1..($rest.Count-1)] }
      'info'     { Invoke-MiseTask 'image:info' $rest[1..($rest.Count-1)] }
      default { Write-Error "unknown gleiphnir image subcommand: $($rest[0])"; exit 1 }
    }
  }
  'network' {
    if ($rest.Count -eq 0) { Show-Usage; exit 1 }
    switch ($rest[0]) {
      'up'     { Invoke-MiseTask 'network:up' $rest[1..($rest.Count-1)] }
      'down'   { Invoke-MiseTask 'network:down' $rest[1..($rest.Count-1)] }
      'status' { Invoke-MiseTask 'network:status' $rest[1..($rest.Count-1)] }
      default { Write-Error "unknown gleiphnir network subcommand: $($rest[0])"; exit 1 }
    }
  }
  'vm' {
    if ($rest.Count -eq 0) { Write-Host "Usage: gleiphnir vm prepare|start|stop|kill|console|ssh|ssh:wait|info|clean|clean:all"; exit 1 }
    $sub = $rest[0]; $extra = @(); if ($rest.Count -gt 1) { $extra = $rest[1..($rest.Count-1)] }
    $map = @{ 'prepare'='vm:prepare'; 'start'='vm:start'; 'stop'='vm:stop'; 'kill'='vm:kill'; 'console'='vm:console'; 'ssh'='vm:ssh'; 'ssh:wait'='vm:ssh:wait'; 'info'='vm:info'; 'clean'='vm:clean'; 'clean:all'='vm:clean:all' }
    if ($map.ContainsKey($sub)) { Invoke-MiseTask $map[$sub] $extra } else { Write-Error "unknown gleiphnir vm subcommand: $sub"; exit 1 }
  }
  'user' {
    if ($rest.Count -eq 0) { Write-Host "Usage: gleiphnir user add|remove|list"; exit 1 }
    $sub = $rest[0]; $extra = @(); if ($rest.Count -gt 1) { $extra = $rest[1..($rest.Count-1)] }
    switch ($sub) {
      'add'    { Invoke-MiseTask 'user:add' $extra }
      'remove' { Invoke-MiseTask 'user:remove' $extra }
      'list'   { Invoke-MiseTask 'user:list' $extra }
      default { Write-Error "unknown gleiphnir user subcommand: $sub"; exit 1 }
    }
  }
  { $_ -in @('fw','firewall') } {
    if ($rest.Count -eq 0) { Write-Host "Usage: gleiphnir fw allow|deny|remove|list|enforce"; exit 1 }
    $sub = $rest[0]; $extra = @(); if ($rest.Count -gt 1) { $extra = $rest[1..($rest.Count-1)] }
    # normalize IP= for fw
    $norm = @(); foreach ($a in $extra) { if ($a -match '^[0-9]+\.[0-9]+\.') { $norm += "IP=$a" } else { $norm += $a } }
    switch ($sub) {
      'allow' { Invoke-MiseTask 'fw:allow' $norm }
      'deny'  { Invoke-MiseTask 'fw:deny' $norm }
      { $_ -in @('remove','delete','unallow','undeny') } { Invoke-MiseTask 'fw:remove' $norm }
      { $_ -in @('list','show','status') } { Invoke-MiseTask 'fw:list' $norm }
      { $_ -in @('enforce','lockdown') } { Invoke-MiseTask 'fw:enforce' $norm }
      default { Write-Error "unknown gleiphnir fw subcommand: $sub"; exit 1 }
    }
  }
  'container' {
    if ($rest.Count -eq 0) { Write-Host "Usage: gleiphnir container build|info"; exit 1 }
    switch ($rest[0]) {
      'build' { Invoke-MiseTask 'container:build' $rest[1..($rest.Count-1)] }
      'info'  { Invoke-MiseTask 'container:info' $rest[1..($rest.Count-1)] }
      default { Write-Error "unknown gleiphnir container subcommand: $($rest[0])"; exit 1 }
    }
  }
  'sbom' {
    if ($rest.Count -eq 0) { Write-Host "Usage: gleiphnir sbom container|tools|vm|all"; exit 1 }
    switch ($rest[0]) {
      'container' { Invoke-MiseTask 'sbom:container' $rest[1..($rest.Count-1)] }
      'tools'     { Invoke-MiseTask 'sbom:tools' $rest[1..($rest.Count-1)] }
      'vm'        { Invoke-MiseTask 'sbom:vm' $rest[1..($rest.Count-1)] }
      'all'       { Invoke-MiseTask 'sbom:all' $rest[1..($rest.Count-1)] }
      default { Write-Error "unknown gleiphnir sbom subcommand: $($rest[0])"; exit 1 }
    }
  }
  'tools' {
    if ($rest.Count -eq 0) { Write-Host "Usage: gleiphnir tools list|info|clean|clean:all|volumes"; exit 1 }
    switch ($rest[0]) {
      'list'      { Invoke-MiseTask 'tools:list' $rest[1..($rest.Count-1)] }
      'info'      { Invoke-MiseTask 'tools:info' $rest[1..($rest.Count-1)] }
      'clean'     { Invoke-MiseTask 'tools:clean' $rest[1..($rest.Count-1)] }
      'clean:all' { Invoke-MiseTask 'tools:clean:all' $rest[1..($rest.Count-1)] }
      'volumes'   { Invoke-MiseTask 'tools:volumes' $rest[1..($rest.Count-1)] }
      default { Write-Error "unknown gleiphnir tools subcommand: $($rest[0])"; exit 1 }
    }
  }
  'obs' {
    if ($rest.Count -eq 0) { Write-Host "Usage: gleiphnir obs start|stop|status|open|deploy|clean"; exit 1 }
    switch ($rest[0]) {
      'start'  { Invoke-MiseTask 'obs:start' $rest[1..($rest.Count-1)] }
      'stop'   { Invoke-MiseTask 'obs:stop' $rest[1..($rest.Count-1)] }
      'status' { Invoke-MiseTask 'obs:status' $rest[1..($rest.Count-1)] }
      'open'   { Invoke-MiseTask 'obs:open' $rest[1..($rest.Count-1)] }
      'deploy' { Invoke-MiseTask 'obs:deploy' $rest[1..($rest.Count-1)] }
      'clean'  { Invoke-MiseTask 'obs:clean' $rest[1..($rest.Count-1)] }
      default { Write-Error "unknown gleiphnir obs subcommand: $($rest[0])"; exit 1 }
    }
  }
  'secrets' {
    if ($rest.Count -eq 0) { Write-Host "Usage: gleiphnir secrets init|encrypt|decrypt|sync|list|status"; exit 1 }
    switch ($rest[0]) {
      'init'    { Invoke-MiseTask 'secrets:init' $rest[1..($rest.Count-1)] }
      'encrypt' { Invoke-MiseTask 'secrets:encrypt' $rest[1..($rest.Count-1)] }
      'decrypt' { Invoke-MiseTask 'secrets:decrypt' $rest[1..($rest.Count-1)] }
      'sync'    { Invoke-MiseTask 'secrets:sync' $rest[1..($rest.Count-1)] }
      'list'    { Invoke-MiseTask 'secrets:list' $rest[1..($rest.Count-1)] }
      'status'  { Invoke-MiseTask 'secrets:status' $rest[1..($rest.Count-1)] }
      default { Write-Error "unknown gleiphnir secrets subcommand: $($rest[0])"; exit 1 }
    }
  }
  'up'    { Invoke-MiseTask 'up' $rest }
  'down'  { Invoke-MiseTask 'down' $rest }
  'smoke' { Invoke-MiseTask 'smoke' $rest }
  default {
    Write-Error "unknown gleiphnir command: $cmd (see gleiphnir --help)"
    Show-Usage
    exit 1
  }
}
