param([Parameter(Mandatory = $true)][string]$NodeExecutable)
$ErrorActionPreference = 'Stop'
& $NodeExecutable (Join-Path $PSScriptRoot 'hourly_sync.mjs')
exit $LASTEXITCODE
