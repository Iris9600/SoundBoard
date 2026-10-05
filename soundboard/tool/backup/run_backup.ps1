param([Parameter(Mandatory = $true)][string]$ConfigPath, [switch]$Maintenance)
$ErrorActionPreference = 'Stop'
$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$backupScript = Join-Path $PSScriptRoot 'sound_backup.mjs'
$backupArguments = @('--disable-warning=ExperimentalWarning', $backupScript, '--config', $ConfigPath)
if ($Maintenance) { $backupArguments += '--maintenance' }
& $config.nodeExecutable @backupArguments
exit $LASTEXITCODE
