param([Parameter(Mandatory = $true)][string]$NodeExecutable)
$ErrorActionPreference = 'Stop'
& $NodeExecutable (Join-Path $PSScriptRoot 'push_commits.mjs')
exit $LASTEXITCODE
