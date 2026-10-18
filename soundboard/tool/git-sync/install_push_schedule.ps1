$ErrorActionPreference = 'Stop'
if ((Get-TimeZone).Id -ne 'Singapore Standard Time') { throw 'Windows must use Kuala Lumpur/Singapore (UTC+08:00).'; }
$taskName = 'SoundBoard-Solar-HourlySync'
$nodeExecutable = (Get-Command node.exe).Source
$powershell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$runner = Join-Path $PSScriptRoot 'run_push.ps1'
$arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $runner + '" -NodeExecutable "' + $nodeExecutable + '"'
$action = New-ScheduledTaskAction -Execute $powershell -Argument $arguments -WorkingDirectory $PSScriptRoot
$triggers = New-ScheduledTaskTrigger -Once -At ([datetime]::Today.AddHours((Get-Date).Hour + 1)) -RepetitionInterval (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 15) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Force |
    Select-Object TaskName,State
if (Get-ScheduledTask -TaskName 'SoundBoard-Solar-TwiceDailyPush' -ErrorAction SilentlyContinue) {
    Disable-ScheduledTask -TaskName 'SoundBoard-Solar-TwiceDailyPush' | Out-Null
}
Write-Output 'Solar commits and pushes eligible D-Time changes hourly and maintains a PR to main. No changes means no action. Owner reviews and merges. PC must be on and user signed in.'
