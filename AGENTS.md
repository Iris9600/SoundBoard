# SoundBoard collaboration workflow

These instructions record the repository owner's preferences for work in this repository.

## Changes, commits and pushes

- Use `D-Time` as the working branch for changes prepared by the assistant.
- Prepare changes and run the relevant checks so the owner can inspect them in VS Code.
- Wait for the owner's explicit confirmation of the changes before creating commits or pushing them to GitHub. Silence, completed tests, or an approval to run a sandbox command is not approval of the code changes.
- Push confirmed changes to `origin/D-Time`, never directly to the default branch.
- Scope each commit to the approved work. Exclude Firebase data exports, login credentials, local backup configuration/logs and unrelated repositories such as the separate `Developing-skill` checkout.
- After pushing, report the branch, commit and checks so the owner can review and merge.

## Review and merge

- The owner performs the GitHub code review and merge by default.
- Perform review and merge only when the owner explicitly delegates both for the particular work. This authorization does not automatically apply to later work.
- When review and merge are delegated, complete the relevant checks and review before merging. Do not force-push or bypass required repository protections.
- Keep `D-Time` available after a merge unless the owner requests deletion.

## Assistant contribution identity

- The assistant's requested contribution display name is `Solar`.
- GitHub account: `Solar-owo`.
- Commit email: `338115045+Solar-owo@users.noreply.github.com` (provided by the owner).
- After the owner approves the work, create assistant commits using `git -c user.name=Solar -c user.email=338115045+Solar-owo@users.noreply.github.com commit ...`. These per-command settings attribute both author and committer to Solar without changing the owner's Git configuration.
- For assistant-created commits, use a per-commit author identity rather than changing the owner's global Git identity or the identity of their manual VS Code commits.
- Use only the Solar identity above for assistant contributions. Do not invent an account/email or use another person's account.
- Do not claim that the author display name alone creates a GitHub account, contributor avatar or collaborator permission.
- The requested avatar is Yuuki Asuna. A prepared image must be uploaded to the actual Solar GitHub account; an asset in this repository does not change a GitHub profile picture.
