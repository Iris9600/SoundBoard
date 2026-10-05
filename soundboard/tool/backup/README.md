# Daily Firebase to OneDrive backup

The Windows scheduler exports the SoundBoard Firestore database into personal OneDrive `Sound` at **23:59 Asia/Kuala_Lumpur (UTC+08:00)**. The local Windows zone is Kuala Lumpur/Singapore. A new snapshot is created only when document data or Firestore document timestamps differ from the last completed snapshot. This is a daily snapshot of the latest committed state, not a history of every edit during the day.

```text
Sound/
  f1/
    firestore.json
    manifest.json
    SHao--cd5ed331684f45eb8ce58cdafcb01667/
      sounds.sqlite
  f2/
  f3/
```

Each device gets a separate folder identified by its name and stable installation ID. The full JSON export preserves Firestore's typed fields, document paths, creation times, update times and embedded Base64 audio. Each device's SQLite file contains:

- `metadata`: project, read time and device ID.
- `documents`: exact Firestore document JSON, including nested subcollections.
- `sounds`: sound names, device identifiers, encoded audio, decoded embedded audio bytes and creation times.

Documents outside valid device paths are preserved in `unassigned.sqlite`. Renamed devices retain their ID; names cannot merge two devices. New devices are discovered automatically. This implementation backs up the `(default)` Firestore database only. It does not export Firebase Authentication, security rules, or Cloud Storage buckets. Current sounds contain embedded audio; any future URL-based audio is preserved as a reference, not downloaded. The manifest reports the number of these references.

## Consistency and retention

All document and collection reads use one server-provided Firestore read time. Pagination and missing parent documents are handled, so nested data is not omitted. SQLite files are closed before they are placed in the sync folder. Database integrity, document read-back, document counts and SHA-256 checksums are verified.

A new snapshot is staged as `.pending-fN`. The Windows Cloud Files API must report all snapshot files in sync before it is published as `fN`. Maintenance runs every 15 minutes. After publishing `f4`, it removes `f1`, leaving `f2`, `f3`, `f4`. Later snapshots continue with `f5`, `f6`, etc. Only folders created and verified by this backup tool can be deleted. Incomplete, corrupted, offline or pending backups never replace older completed backups.

## Installed tasks

- `SoundBoard-OneDrive-DailyBackup`: 23:59 each day, Malaysia time.
- `SoundBoard-OneDrive-BackupSync`: every 15 minutes; confirms upload, publishes and applies retention without reading Firebase.

The tasks use the current Windows user's interactive login and Firebase CLI credentials. No account passwords or tokens are written into configuration or backup files. This PC must be on and the user signed in for the tasks to run; OneDrive and Internet access are required to complete cloud upload. Missed daily runs are configured to start when available and failures retry up to three times at 15-minute intervals. A delayed run captures data at its actual execution time, not the missed end-of-day instant. Backups do not depend on the SoundBoard app being open and do not require opening its expired client rules.

The task host runs hidden. Configuration, logs and the process lock are kept outside OneDrive in `.firebase-data-backups/onedrive-state/`, ignored by Git. A crashed process can leave `backup.lock`; inspect the logged process ID and confirm it is no longer running before removing that exact lock file. If a partial staging folder has no valid manifest, inspect it before moving it aside; do not delete an existing completed backup to recover space.

## Run and check

From the repository root:

```powershell
node --disable-warning=ExperimentalWarning --test soundboard/tool/backup/backup.test.mjs
node --disable-warning=ExperimentalWarning soundboard/tool/backup/sound_backup.mjs --config soundboard/.firebase-data-backups/onedrive-state/config.json
node --disable-warning=ExperimentalWarning soundboard/tool/backup/sound_backup.mjs --config soundboard/.firebase-data-backups/onedrive-state/config.json --maintenance
Get-ScheduledTask -TaskName 'SoundBoard-OneDrive-*'
Get-Content soundboard/.firebase-data-backups/onedrive-state/backup.log -Tail 10
```

Ten tests cover SQLite read-back and audio, exact Firestore types, fourth-backup retention, pending uploads, corruption, unchanged data, unsafe names, unmanaged roots, unassigned documents, consistent snapshot pagination and credential-safe errors. Tests use isolated temporary directories, never real OneDrive backups.

## Recovery

Download one complete `fN` folder, verify the manifest checksums, and use `firestore.json` or the SQLite `documents.firestore_json` rows to recover the original document paths and fields. SQLite `sounds.audio_bytes` holds embedded audio ready for file export. Restore is an explicit administrator operation; this tool never overwrites Firebase data automatically. Do not treat these device folders as an app identity-linking mechanism.
