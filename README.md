# Flute Practice Coach

[![Mobile quality and release](https://github.com/seagomezar/music-journal-app/actions/workflows/android-release.yml/badge.svg)](https://github.com/seagomezar/music-journal-app/actions/workflows/android-release.yml)
[![Flutter 3.44.0](https://img.shields.io/badge/Flutter-3.44.0-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Flute Practice Coach is a private, local-only practice journal for flutists. It helps organize technical routines and repertoire, time practice sessions, use a visual metronome, review short self-evaluation recordings, and follow progress over time.

## Features

- Custom technical routines with validated 40–240 BPM targets
- Repertoire catalog with app-managed PDF scores on mobile
- Practice timer, visual metronome, notes, calendar, goals, and streaks
- Manual logging for practice completed on a past date
- Optional self-evaluation recordings stored in private app storage on mobile
- Versioned JSON export/import for routines and practice history (media excluded)
- English and Spanish interface
- No online account, advertising, analytics, or cloud data collection
- In-app privacy policy, support information, and permanent data erasure

## Architecture

Flutter widgets consume `ChangeNotifier` providers. Providers coordinate Hive persistence, app-owned file storage, recording/playback, localization, and session state. The app manages user content locally and does not upload it.

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

Run or build the browser version with:

```bash
flutter run -d chrome
flutter build web --release
```

The browser version keeps profile and journal data in browser storage. PDF importing/viewing is mobile-only, and browser recordings are available only during the active practice session; they are not retained in history. Clearing site data or using private browsing can remove browser-stored journal data.

Android release builds require a configured upload key. Unsigned previews must explicitly set `BUILD_UNSIGNED=true`; release builds never fall back to the debug key.

```bash
flutter build appbundle --release --build-name=1.0.0 --build-number=1
flutter build ios --release --no-codesign
```

The GitHub workflow runs formatting, analysis, tests, an unsigned Android preview, and an unsigned iOS build check. Signed Android store bundles are created only by a manually dispatched workflow with permanent signing secrets and explicit version/build inputs.

## Store preparation

- [Store listing copy](docs/store-listing.md)
- [Submission checklist](docs/store-submission-checklist.md)
- [Privacy policy](docs/privacy-policy.html)
- [Terms and conditions](docs/terms-and-conditions.html)
- [Support page](docs/support.html)
- [Landing page](docs/index.html)
- [Journal backup JSON Schema](docs/journal-backup-schema-v1.json)
- Generated store graphics under `assets/store/`

## License

Licensed under the [MIT License](LICENSE).
