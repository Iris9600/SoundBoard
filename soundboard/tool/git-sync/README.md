# Solar scheduled pushes

Target: `https://github.com/Iris9600/SoundBoard`, branch `D-Time`, account `Solar-owo`.

`SoundBoard-Solar-TwiceDailyPush` runs at **12:00 noon and 00:00 midnight Malaysia time** (`Asia/Kuala_Lumpur`, UTC+08:00). It pushes committed changes only. The owner still confirms changes before commits and performs the GitHub review and merge unless explicitly delegated. The task never stages files, creates commits, pulls, merges or force-pushes.

The task checks the upstream URL, verifies that the saved credential belongs to Solar-owo (account ID 338115045), checks accepted write access, and skips a push if the remote already has the same commit. A rejected push is reported instead of rewriting remote history. Logs live in the ignored root `.git-sync/push.log`; no tokens are logged or stored in project files.

Git Credential Manager must have a Solar login. The repository's local `credential.https://github.com.username` selects Solar for GitHub authentication. The owner's Git author settings remain unchanged; assistant-created commits use the Solar author and committer identity documented in root `AGENTS.md`. Author attribution and push authentication are separate.

The Windows task runs hidden using the signed-in Windows user's credentials. This PC must be on, that user signed in, and Internet access available. Missed runs start when available, and failures retry up to three times at 15-minute intervals. This is a local Windows schedule, not a GitHub-hosted service.

Run from the repository root:

```powershell
node --test soundboard/tool/git-sync/push_commits.test.mjs
node soundboard/tool/git-sync/push_commits.mjs
Get-ScheduledTask -TaskName 'SoundBoard-Solar-TwiceDailyPush'
Get-ScheduledTaskInfo -TaskName 'SoundBoard-Solar-TwiceDailyPush'
Get-Content .git-sync/push.log -Tail 10
```

The seven tests cover upstream validation, account/write-access checks, unchanged commits, branch-limited pushes and refusal to force-push. No test makes real GitHub writes.
