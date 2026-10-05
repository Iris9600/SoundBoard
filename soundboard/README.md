# Soundboard

A Flutter soundboard with persistent installation identity. Each device reads and uploads sounds under `devices/{deviceId}/sounds` in Firestore.

## Code organization

- `lib/main.dart`: Firebase initialization and startup.
- `lib/app.dart`: App theme and initial screen.
- `lib/models/`: Stored sounds and selected audio file data.
- `lib/pages/`: Identity loading, sound list, and upload form.
- `lib/widgets/`: Reusable audio player card.
- `lib/services/device_identity.dart`: Persistent installation identity.
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
