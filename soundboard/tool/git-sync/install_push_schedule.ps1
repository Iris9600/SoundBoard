$ErrorActionPreference = 'Stop'
if ((Get-TimeZone).Id -ne 'Singapore Standard Time') { throw 'Windows must use Kuala Lumpur/Singapore (UTC+08:00).'; }
$taskName = 'SoundBoard-Solar-TwiceDailyPush'
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) { throw 'Solar push task already exists; inspect before replacing.' }
$nodeExecutable = (Get-Command node.exe).Source
$powershell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$runner = Join-Path $PSScriptRoot 'run_push.ps1'
$arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $runner + '" -NodeExecutable "' + $nodeExecutable + '"'
$action = New-ScheduledTaskAction -Execute $powershell -Argument $arguments -WorkingDirectory $PSScriptRoot
$triggers = @(
    New-ScheduledTaskTrigger -Daily -At ([datetime]::Today.AddHours(12))
    New-ScheduledTaskTrigger -Daily -At ([datetime]::Today)
)
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 15) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Principal $principal -Settings $settings |
    Select-Object TaskName,State
Write-Output 'Solar pushes committed D-Time changes at 12:00 and 00:00 Asia/Kuala_Lumpur. Review and merge remain manual.'
