# Soundboard

A Flutter soundboard with name-based libraries. Enter a name to open its sounds; capitalization and repeated spaces are ignored. No password is required. Anyone using the same name can access that library. Check **Remember me** to reopen it automatically on this browser or installation; leave it unchecked to enter a name next launch. **Switch name** clears the remembered name and returns to entry.

**Login** is selected by default and checks that the name exists in Firestore, including when restoring a remembered name. **Register** immediately creates a profile in Firestore and opens its empty library; duplicate names are rejected using a transaction. Remember me appears only under Login. Existing name-based library profiles also count as registered names. Connection or permission errors keep the entry screen open.

Library IDs use a `name_` prefix and a URL-safe encoding of the normalized name. The existing Firestore collection location `devices/{libraryId}/sounds` is retained for saved-library compatibility; its historical label no longer represents a device. New records contain only `libraryId` and `userName` ownership metadata. The app does not collect hardware names or create installation IDs, and removes the old saved installation ID at startup. Old device libraries are preserved but require an explicit migration to appear under a name. This selector does not provide Firebase authentication or change security rules.

## Code organization

- `lib/main.dart`: Firebase initialization and startup.
- `lib/app.dart`: App theme and initial screen.
- `lib/models/`: Stored sounds and selected audio file data.
- `lib/pages/`: Identity loading, sound list, and upload form.
- `lib/widgets/`: Reusable audio player card.
- `lib/services/name_identity.dart`: Name-based library selection and optional remembered name.
- `lib/services/sound_repository.dart`: Firestore access and upload validation.
- `lib/services/audio_file_picker.dart`: Platform file selection.
- `lib/services/audio_playback_controller.dart`: Player state and resource lifecycle.
- `lib/firebase_options.dart`: Generated Firebase configuration.

Pages own UI state and delegate persistence and platform operations to services. Models represent data independently of widgets. The playback controller owns one completion subscription and is disposed by its card. The repository validates uploads before writing.

Existing Firestore fields and Base64/URL playback remain supported. Raw audio uploads are limited to 700 KB to leave room for Base64 and document metadata. Firebase must be configured for the target platform.

## Verification

## Mobile and Web App views

Mobile installations keep the original soundboard view. Browser builds automatically
open the separate **Web App** workspace with sound search, a responsive library,
and an upload form. Wide browser windows also show a workspace sidebar.

From this directory, start the browser version with:

```sh
flutter run -d chrome
```

Create a deployable website with `flutter build web --release`. Serve the contents
of `build/web` using a web server; opening `index.html` directly is unsupported.
For a host without Chrome, use `flutter run -d web-server` and open the printed URL.

The same name opens the same library on web and mobile. Clearing browser site
data forgets the remembered name; entering it again opens the same library.
Firebase access rules must permit the app's reads and writes. Browser-supported
audio formats and remote audio servers' CORS policies determine playback support.

## Checks

Run from this directory:

```sh
flutter analyze
flutter test
flutter run
```

Tests cover removal of the legacy installation ID, name entry and persistence, shared name libraries, sound mapping, and upload validation. File selection, actual playback, and live Firestore writes require manual testing in a configured app.

## Device names

The entered name selects the library on every platform. Hardware-name lookup, installation-ID generation, and the Android device-name channel have been removed. Only the optional remembered name is saved locally.

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

The previous security rules expired on 2026-07-05. A live unauthenticated profile read returned `403 PERMISSION_DENIED`, which blocked both registration and login. After owner approval on 2026-10-17, the replacement rules were deployed to `soundboard-95778`. Live checks confirmed profile creation, login lookup, saved `userName`/`libraryId`/`createdAt` attributes, and duplicate protection. The temporary verification profile was removed. The app now distinguishes permission failures from invalid usernames.

The deployed `firestore.rules` replaces the expired blanket rule with access limited to `name_` libraries. It permits individual profile lookup and validated creation, restricted profile updates, sound reads and validated sound creation. Profile listing, deletion, legacy installation libraries and unrelated collections remain denied. This implements the requested name-only sharing model, not private authenticated accounts: anyone knowing a name can access its library. Future rule deployments require owner approval; deploy only these rules from this directory using `firebase deploy --only firestore:rules --project soundboard-95778`.

With a valid Firebase CLI session, run `node tool/check_firestore_rules.mjs` to compile the proposed rules and check six access cases using Firebase's test API. It does not deploy rules or write database data.

For an authorized live registration check, run `node tool/verify_name_registration.mjs --live`. It creates one unique temporary name profile, verifies its attributes and duplicate protection through client requests, and removes that profile using the administrator session. It never changes existing user profiles.

## Daily OneDrive backup

Personal OneDrive `Sound` receives daily Firestore snapshots at 23:59 Malaysia time. Each snapshot groups closed SQLite files by device, and includes a full typed JSON export. Completed backups are numbered `f1`, `f2`, etc.; only the latest three are retained after the replacement has been verified and OneDrive reports its upload complete. See [backup setup and recovery](tool/backup/README.md) for schedules, verification, limitations and recovery instructions.
