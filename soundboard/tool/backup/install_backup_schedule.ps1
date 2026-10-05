param(
    [Parameter(Mandatory = $true)][string]$OneDriveRoot,
    [string]$DailyTime = '23:59'
)
$ErrorActionPreference = 'Stop'
if ((Get-TimeZone).Id -ne 'Singapore Standard Time') {
    throw 'Windows time zone must be Kuala Lumpur/Singapore (UTC+08:00) before installing this schedule.'
}
if ($DailyTime -notmatch '^([01][0-9]|2[0-3]):[0-5][0-9]$') { throw 'DailyTime must be HH:mm.' }
$resolvedOneDrive = (Resolve-Path -LiteralPath $OneDriveRoot).Path
$knownRoots = @(Get-ChildItem -LiteralPath 'HKCU:/Software/Microsoft/OneDrive/Accounts' |
    ForEach-Object { (Get-ItemProperty -LiteralPath $_.PSPath).UserFolder } |
    Where-Object { $_ })
if ($resolvedOneDrive -notin $knownRoots) { throw 'Destination is not a configured OneDrive account folder.' }
$node = (Get-Command node.exe).Source
$firebaseCli = Join-Path $env:APPDATA 'npm/node_modules/firebase-tools/lib/bin/firebase.js'
if (-not (Test-Path -LiteralPath $firebaseCli)) { throw 'Firebase CLI entry point not found.' }
$stateDirectory = Join-Path $PSScriptRoot '../../.firebase-data-backups/onedrive-state'
New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
$stateDirectory = (Resolve-Path -LiteralPath $stateDirectory).Path
$configPath = Join-Path $stateDirectory 'config.json'
if (Test-Path -LiteralPath $configPath) { throw 'Backup configuration already exists; inspect it before replacing.' }
@{
    projectId = 'soundboard-95778'; oneDriveRoot = $resolvedOneDrive
    firebaseCliPath = $firebaseCli; stateDirectory = $stateDirectory
    nodeExecutable = $node
    timeZone = 'Asia/Kuala_Lumpur'; dailyTime = $DailyTime
} | ConvertTo-Json | Set-Content -LiteralPath $configPath -Encoding UTF8
$script = Join-Path $PSScriptRoot 'run_backup.ps1'
$powershell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $script + '" -ConfigPath "' + $configPath + '"'
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 15)
$taskNames = @('SoundBoard-OneDrive-DailyBackup', 'SoundBoard-OneDrive-BackupSync')
foreach ($taskName in $taskNames) {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) { throw "Scheduled task already exists: $taskName" }
}
$dailyTrigger = New-ScheduledTaskTrigger -Daily -At ([datetime]::Today.Add([TimeSpan]::Parse($DailyTime)))
$dailyAction = New-ScheduledTaskAction -Execute $powershell -Argument $arguments -WorkingDirectory $PSScriptRoot
Register-ScheduledTask -TaskName $taskNames[0] -Action $dailyAction -Trigger $dailyTrigger -Principal $principal -Settings $settings |
    Select-Object TaskName,State

# Maintenance only confirms OneDrive upload and rotates backups; no Firebase reads.
$syncTrigger = New-ScheduledTaskTrigger -Once -At ([datetime]::Now.AddMinutes(1)) -RepetitionInterval (New-TimeSpan -Minutes 15)
$syncAction = New-ScheduledTaskAction -Execute $powershell -Argument ($arguments + ' -Maintenance') -WorkingDirectory $PSScriptRoot
Register-ScheduledTask -TaskName $taskNames[1] -Action $syncAction -Trigger $syncTrigger -Principal $principal -Settings $settings |
    Select-Object TaskName,State
Write-Output "Daily backup: $DailyTime Asia/Kuala_Lumpur; sync verification every 15 minutes."
Write-Output "Configuration: $configPath"
