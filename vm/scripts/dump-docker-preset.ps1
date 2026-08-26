# vm/scripts/dump-docker-preset.ps1 — try to extract Docker Sandbox Balanced allowlist via `sbx policy ls`
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

Start-OtelSpan "gleiphnir.dump_preset" @{ 'script.name'='dump-docker-preset.ps1'; 'service.name'=$env:OTEL_SERVICE_NAME }
try {
Write-Host "Checking for sbx (Docker Sandbox) CLI..."
$sbx = Get-Command sbx -ErrorAction SilentlyContinue
if (-not $sbx) {
    Write-Warning "sbx not found on PATH — using built-in balanced.txt fallback."
    Write-Host "Install Docker Sandbox or manually copy `sbx policy ls --wide` output to vm/guest/policy-presets/balanced.txt"
    exit 0
}
Write-Host "Found sbx at $($sbx.Source)"
Write-Host "Dumping current policy (sbx policy ls --wide)..."
try {
    $out = & sbx policy ls --wide 2>&1 | Out-String
    Write-Host $out
    $outFile = Join-Path $PSScriptRoot '../guest/policy-presets/balanced-sbx-dump.txt'
    $outFile = [System.IO.Path]::GetFullPath($outFile)
    Set-Content -LiteralPath $outFile -Value $out -Encoding utf8
    Write-Host "Full dump saved to $outFile"
} catch { Write-Warning "sbx policy ls --wide failed: $_" }

Write-Host ""
Write-Host "Extracting allow hosts from sbx policy check (if sbx supports sbx policy ls --wide parsing)..."
try {
    # Try structured dump if `sbx policy ls --json` exists
    $jsonOut = & sbx policy ls --json 2>$null | Out-String
    if ($LASTEXITCODE -eq 0 -and $jsonOut) {
        $jsonFile = Join-Path $PSScriptRoot '../guest/policy-presets/balanced-sbx.json'
        Set-Content -LiteralPath ([System.IO.Path]::GetFullPath($jsonFile)) -Value $jsonOut -Encoding utf8
        Write-Host "JSON dump saved to $jsonFile"
    }
} catch {}

Write-Host ""
Write-Host "To update balanced preset:"
Write-Host "  1. Review vm/guest/policy-presets/balanced.txt (curated fallback)"
Write-Host "  2. If sbx is balanced, compare: diff sbx dump vs balanced.txt and merge missing domains"
Write-Host "  3. Re-run: pwsh vm/scripts/dump-docker-preset.ps1"
End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
