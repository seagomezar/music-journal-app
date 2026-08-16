# Flute Practice Coach

[![Mobile quality and release](https://github.com/seagomezar/music-journal-app/actions/workflows/android-release.yml/badge.svg)](https://github.com/seagomezar/music-journal-app/actions/workflows/android-release.yml)
[![Flutter 3.44.0](https://img.shields.io/badge/Flutter-3.44.0-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Flute Practice Coach is a private, local-only practice journal for flutists. It helps organize technical routines and repertoire, time practice sessions, use a metronome and tuner, measure exercise intonation, review short self-evaluation recordings, and follow progress over time.

## Features

- Custom technical routines with validated 40–240 BPM targets
- Repertoire catalog with app-managed PDF scores on mobile
- Practice timer, visual metronome, notes, calendar, goals, and streaks
- Manual logging for practice completed on a past date
- Optional self-evaluation recordings with multiple takes and playback, rename, and delete controls; stored locally on mobile and in browser storage on web
- Versioned JSON export/import for routines and practice history (media excluded)
- English and Spanish interface
- No online account, advertising, or cloud journal data collection; the deployed web build may send optional aggregate usage events when configured
- In-app privacy policy, support information, and permanent data erasure

## Architecture

Flutter widgets consume `ChangeNotifier` providers. Providers coordinate Hive CE persistence, app-owned file storage, recording/playback, localization, and session state. The app manages user content locally and does not upload it. The deployed web build can send only aggregate app-launch, onboarding, and session-start events through Plausible when `PLAUSIBLE_DOMAIN` is configured; journal, profile, audio, and pitch data are never included.

## Development

The project is pinned to Flutter 3.44.0 in `.flutter-version` and requires Dart 3.11.5 or later.

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter run
```

Run the repeatable iOS simulator journey (onboarding through recording,
history, legal pages, and local-data erasure) with:

```bash
flutter devices
flutter test integration_test/app_smoke_test.dart -d <ios-simulator-id>
```

The simulator cannot accept the native iOS microphone permission sheet from
Flutter's widget harness. Use this variant for a deterministic simulator run;
run without the define on a physical device (or after granting microphone
permission) to exercise native pitch capture and recording:

```bash
flutter test integration_test/app_smoke_test.dart -d <ios-simulator-id> \
  --dart-define=FLUTE_SKIP_NATIVE_AUDIO=true
```

Run or build the browser version with:

```bash
flutter run -d chrome --wasm
flutter build web --release --wasm
```

The sample-accurate browser metronome requires the WASM build. A JavaScript
build is supported only when its server sends `Cross-Origin-Opener-Policy:
same-origin` and `Cross-Origin-Embedder-Policy: require-corp`.

The browser version keeps profile, journal, and saved recordings in browser storage. PDF importing/viewing is mobile-only, and recordings remain available in session history after a reload. See the [privacy policy](docs/privacy-policy.html) for storage-retention details.

On Android and iOS, an explicitly started recording or tuner measurement continues through supported screen-lock and background audio states. The app shows a native capture indicator while microphone capture is active. Browsers may suspend microphone capture while a hidden tab is inactive; the app preserves any measurement completed before that interruption.

Android release builds require a configured upload key. Unsigned previews must explicitly set `BUILD_UNSIGNED=true`; release builds never fall back to the debug key.

```bash
flutter build appbundle --release --build-name=1.0.0 --build-number=1
flutter build ios --release --no-codesign
```

The GitHub workflow runs formatting, analysis, tests, an unsigned Android preview, an unsigned iOS build check, and a WASM web build. Signed Android store bundles are created only by a manually dispatched workflow with permanent signing secrets and explicit version/build inputs.

The Pages workflow publishes the static landing page and the Flutter web app at
`/music-journal-app/app/`. Set the repository variable `PLAUSIBLE_DOMAIN` to
enable optional aggregate landing-page and web-app events; without it, both
pages remain analytics-free.

## Store preparation

- [Store listing copy](docs/store-listing.md)
- [Submission checklist](docs/store-submission-checklist.md)
- [Privacy policy](docs/privacy-policy.html)
- [Terms and conditions](docs/terms-and-conditions.html)
- [Support page](docs/support.html)
- [Landing page](docs/index.html)
- [Flutist practice evidence brief](docs/research/flutist-practice-evidence.md)
- [Landing-page measurement specification](docs/research/measurement.md)
- [Journal backup JSON Schema](docs/journal-backup-schema-v3.json)
- Generated store graphics under `assets/store/`

## License

Licensed under the [MIT License](LICENSE).
