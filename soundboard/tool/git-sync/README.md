# Solar hourly sync

The owner authorizes automatic commits and pushes of eligible code changes every hour to `Iris9600/SoundBoard`, branch `D-Time`, as `Solar-owo`. `SoundBoard-Solar-HourlySync` runs on the hour Malaysia time, opens or reuses a PR to `main`, and leaves review and merge to the owner. This replaces the noon/midnight schedule. No eligible changes or pending retries means no action.

The task checks the current branch, upstream, Solar account and accepted write access. Commits use the Solar identity per command. It never switches branches, pulls, merges or force-pushes. An excluded staged file or interrupted Git operation stops the run. Network failures retry; pending PR state survives a completed push.

Eligible files are code, build definitions, documentation and standard application assets under `soundboard/`, plus root `AGENTS.md` and `.gitignore`. Ignored files, private data exports, credentials, local backup configuration/logs and unrelated checkouts are excluded. Keep private material out of source files; filename exclusions cannot identify every possible secret. Automated runs do not run Flutter checks; inspect changes and run relevant checks before merging.

The task runs hidden as the signed-in Windows user. This PC must be on, the user signed in and Internet access available. Missed runs catch up when available. Failures retry three times at 15-minute intervals. Installation disables the previous twice-daily task. Logs and pending PR state live under ignored `.git-sync/`. Git Credential Manager supplies Solar authentication; the owner's Git identity remains unchanged.

Run from the repository root:

```powershell
node --test soundboard/tool/git-sync/push_commits.test.mjs soundboard/tool/git-sync/hourly_sync.test.mjs
powershell -NoProfile -ExecutionPolicy Bypass -File soundboard/tool/git-sync/install_push_schedule.ps1
node soundboard/tool/git-sync/hourly_sync.mjs
Get-ScheduledTaskInfo -TaskName 'SoundBoard-Solar-HourlySync'
Get-Content .git-sync/push.log -Tail 10
```
