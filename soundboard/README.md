# Soundboard

A Flutter soundboard with persistent installation identity. Each device reads and uploads sounds under `devices/{deviceId}/sounds` in Firestore. Uploads atomically create/update the parent device record and store both `deviceId` and `deviceName` on the sound. Names are display labels; two devices with the same name still have separate IDs.

## Code organization

- `lib/main.dart`: Firebase initialization and startup.
- `lib/app.dart`: App theme and initial screen.
- `lib/models/`: Stored sounds and selected audio file data.
- `lib/pages/`: Identity loading, sound list, and upload form.
- `lib/widgets/`: Reusable audio player card.
- `lib/services/device_identity.dart`: Persistent installation identity.
- `lib/services/device_name.dart`: Platform device display name.
- `lib/services/sound_repository.dart`: Firestore access and upload validation.
- `lib/services/audio_file_picker.dart`: Platform file selection.
- `lib/services/audio_playback_controller.dart`: Player state and resource lifecycle.
- `lib/firebase_options.dart`: Generated Firebase configuration.

Pages own UI state and delegate persistence and platform operations to services. Models represent data independently of widgets. The playback controller owns one completion subscription and is disposed by its card. The repository validates uploads before writing.

Existing Firestore fields and Base64/URL playback remain supported. Raw audio uploads are limited to 700 KB to leave room for Base64 and document metadata. Firebase must be configured for the target platform.

## Verification

Run from this directory:

```sh
flutter analyze
flutter test
flutter run
```

Tests cover installation identity, identity failure UI, sound mapping, and upload validation. File selection, actual playback, and Firestore writes require manual testing in a configured app.

## Device names

Windows and macOS use the computer name. Android reads the system device name, falling back to its model if unavailable. iOS may return a generic name unless Apple's user-assigned-device-name entitlement is available. Web uses `Web browser`, because websites cannot read the computer name. The device-details button shows the stable ID for migration and support.

## Firebase data management

The project is `soundboard-95778`. Run the administrator audit from the repository root using a Firebase CLI login:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File soundboard/tool/manage_firestore.ps1 -Mode Audit
```

The migration command requires an explicit destination name and 32-character installation ID. It backs up the full legacy `Sound` collection, then atomically creates device-scoped copies and deletes the originals. Existing target sound IDs and concurrent source changes cause the commit to fail. Read-back verification checks every original field and device ownership. Optional mock data is a playable WAV tone marked `isMock: true`. Private backups are ignored by Git.

### Migration performed on 2026-10-05

- Device name: `SHao`
- Device ID: `cd5ed331684f45eb8ce58cdafcb01667`
- Five old sounds moved from `Sound` to `devices/cd5ed331684f45eb8ce58cdafcb01667/sounds`.
- One mock sound: `mock-device-storage-test`.
- Original IDs, names, audio and creation timestamps preserved and verified.
- Original shared collection verified empty.
- Backup: `.firebase-data-backups/legacy-Sound-20261005T1022390056291Z.json`.

This is a newly created device group. A device name does not identify or automatically bind an actual installation. The SHao installation must be associated with the ID above before it can display these migrated sounds.

The deployed security rules inspected on 2026-10-05 allow client access only before 2026-07-05. Administrator access succeeds independently of those rules; normal app access is blocked. Authentication and ownership rules must be configured before client read/upload verification can succeed. Do not reopen unrestricted access to work around the expiry.

## Daily OneDrive backup

Personal OneDrive `Sound` receives daily Firestore snapshots at 23:59 Malaysia time. Each snapshot groups closed SQLite files by device, and includes a full typed JSON export. Completed backups are numbered `f1`, `f2`, etc.; only the latest three are retained after the replacement has been verified and OneDrive reports its upload complete. See [backup setup and recovery](tool/backup/README.md) for schedules, verification, limitations and recovery instructions.
