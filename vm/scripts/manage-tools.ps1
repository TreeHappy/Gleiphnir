# vm/scripts/manage-tools.ps1 — manage mise tool installs inside the VM
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib.ps1')

$spanAction = if ($args.Count -gt 0) { $args[0] } else { 'default' }
Start-OtelSpan "gleiphnir.$spanAction" @{ 'script.name' = 'manage-tools.ps1'; 'script.action' = $spanAction; 'service.name' = $env:OTEL_SERVICE_NAME }
try {

$usage = @"
manage-tools.ps1 — inspect and manage mise tool installs

Usage:
  manage-tools.ps1 list                List all installed tools (shared + personal)
  manage-tools.ps1 info TOOL           Show details for a specific tool
  manage-tools.ps1 clean TOOL          Remove a personal tool install
  manage-tools.ps1 clean:all           Remove all personal tool installs
  manage-tools.ps1 volumes             Show volume mount and disk usage info
  manage-tools.ps1 search QUERY [--source npm|pypi|crates|go|github|exa] [--json]
                                     Proxy-aware search over package managers + GitHub + Exa AI
"@

$SubCmd = ""
$ToolName = ""
$SearchExtra = @()

$args_list = @($args)
$i = 0
while ($i -lt $args_list.Count) {
    switch ($args_list[$i]) {
        'list'     { $SubCmd = 'list'; $i++ }
        'info'     { $SubCmd = 'info'; $ToolName = $args_list[$i+1]; $i += 2 }
        'clean'    { $SubCmd = 'clean'; $ToolName = $args_list[$i+1]; $i += 2 }
        'clean:all'{ $SubCmd = 'clean:all'; $i++ }
        'volumes'  { $SubCmd = 'volumes'; $i++ }
        'search'   {
            $SubCmd = 'search'
            if ($i+1 -ge $args_list.Count) { Write-Error "search requires a query"; exit 1 }
            $ToolName = $args_list[$i+1]
            $i += 2
            while ($i -lt $args_list.Count) { $SearchExtra += $args_list[$i]; $i++ }
        }
        '-h'       { Write-Host $usage; exit 0 }
        '--help'   { Write-Host $usage; exit 0 }
        default    { Write-Error "Unknown argument: $($args_list[$i])"; Write-Host $usage; exit 1 }
    }
}

if (-not $SubCmd) {
    Write-Host $usage
    exit 1
}

switch ($SubCmd) {
    'list' {
        exit (Invoke-AdminSshWithFallback -Command "sandbox-tools list")
    }
    'info' {
        if (-not $ToolName) { Write-Error "info requires a tool name"; exit 1 }
        exit (Invoke-AdminSshWithFallback -Command "sandbox-tools info $ToolName")
    }
    'clean' {
        if (-not $ToolName) { Write-Error "clean requires a tool name"; exit 1 }
        exit (Invoke-AdminSshWithFallback -Command "sandbox-tools clean $ToolName")
    }
    'clean:all' {
        exit (Invoke-AdminSshWithFallback -Command "sandbox-tools clean:all")
    }
    'volumes' {
        exit (Invoke-AdminSshWithFallback -Command "sandbox-tools volumes")
    }
    'search' {
        $query = $ToolName
        if (-not $query) { Write-Error "search requires a query (e.g. 'http client')"; exit 1 }
        $escapedQuery = $query -replace "'", "'\''"
        $qExtra = ($SearchExtra -join ' ') -replace "'", "'\''"
        Write-Host "Checking policy for registries (npm, pypi, exa)..."
        Invoke-AdminSshWithFallback -Command "sudo /usr/local/bin/sandbox-policy check network registry.npmjs.org >/dev/null 2>&1 && echo 'npm: allowed' || echo 'npm: blocked'; sudo /usr/local/bin/sandbox-policy check network pypi.org >/dev/null 2>&1 && echo 'pypi: allowed' || echo 'pypi: blocked'; sudo /usr/local/bin/sandbox-policy check network api.exa.ai >/dev/null 2>&1 && echo 'exa: allowed' || echo 'exa: blocked'"
        exit (Invoke-AdminSshWithFallback -Command "sandbox-tools search '$escapedQuery' $qExtra")
    }
}
    End-OtelSpan 'OK'
} catch {
    End-OtelSpan 'ERROR' $_.Exception.Message
    throw
}
