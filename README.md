# Flute Practice Coach

[![Mobile quality and release](https://github.com/seagomezar/music-journal-app/actions/workflows/android-release.yml/badge.svg)](https://github.com/seagomezar/music-journal-app/actions/workflows/android-release.yml)
[![Flutter 3.44.0](https://img.shields.io/badge/Flutter-3.44.0-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Flute Practice Coach is a private, local-only practice journal for flutists. It helps organize technical routines and repertoire, time practice sessions, use a metronome and tuner, measure exercise intonation, review short self-evaluation recordings, and follow progress over time.

## Features

- Custom technical routines with exercises you can create, edit, delete, reorder, set to 30–252 BPM, and attach to scores
- Folder-organized repertoire with app-managed PDF scores on mobile, persistent annotations, annotated export, saved display options, and performance mode
- Practice timer, visual metronome, notes, calendar, goals, and streaks
- Manual logging for practice completed on a past date
- Edit saved session notes, dates, and duration while preserving recordings and exercise results
- Recover unfinished sessions after relaunch, paused until you resume
- Compare tempo and intonation across sessions from History > Practice progress
- Optional self-evaluation recordings with multiple takes and playback, rename, and delete controls; stored locally on mobile and in browser storage on web
- Versioned JSON export/import for routines and practice history (media excluded)
- Full ZIP backup and restore for profile, settings, repertoire, folders, PDFs, annotations, recordings, routines, and history (up to 256 MB)
- English and Spanish interface
- No online account, advertising, or cloud journal data collection; the deployed web build may send optional aggregate usage events when configured
- In-app privacy policy, support information, and permanent data erasure

## Releases & Distribution

Latest release binaries are available under [GitHub Releases](https://github.com/seagomezar/music-journal-app/releases):
- **Android:** Download the standalone release APK (`flute-practice-coach-v1.0.0-build5.apk`) directly from [Releases](https://github.com/seagomezar/music-journal-app/releases/latest) for direct installation or sideloading.
- **iOS:** Distributed via Apple TestFlight on App Store Connect.

## Architecture

Flutter widgets consume `ChangeNotifier` providers. Providers coordinate Hive CE persistence, app-owned file storage, recording/playback, localization, and session state. The app manages user content locally and does not upload it. The deployed web build can send only aggregate app-launch, onboarding, and session-start events through Plausible when `PLAUSIBLE_DOMAIN` is configured; journal, profile, audio, and pitch data are never included.

Session checkpoints are stored locally and restored in a paused state; an interrupted recording may be incomplete.
Cross-box imports use a durable undo log, replayed before opening the journal after an interruption.
Media references are portable identifiers resolved against the current storage location.
The input meter shows relative microphone level and estimated dynamics, not calibrated sound pressure.

Full backups contain private content and are not encrypted.
Restoring a full backup replaces the current journal and settings after a preview and confirmation; export the current journal first if you want to retain it.
Lightweight JSON exports merge into existing data and are limited to 20 MB; oversized or otherwise non-importable exports are rejected before download.
The startup recovery screen can restore into a fresh database while retaining the original database files until you choose Erase all data.

## Development

See the [gap remediation and verification report](docs/improvement-status.md) for implemented improvements, test evidence, and remaining release checks.

The project is pinned to Flutter 3.44.0 in `.flutter-version` and requires Dart 3.11.5 or later.

```bash
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter run
```

Run the repeatable core journey (onboarding through recording, history, legal
pages, and local-data erasure) in Chrome, an Android emulator, or an iOS
simulator with:

```bash
flutter devices
flutter test integration_test/app_smoke_test.dart -d <device-id>
```

Run the platform-sensitive routine, repertoire, score, recording, backup, and
appearance regressions, including the real-PDF score rotation regression, in
both native runners with:

```bash
flutter test integration_test/ios_feature_suite_test.dart -d <ios-simulator-id>
flutter test integration_test/ios_feature_suite_test.dart -d <android-emulator-id>
```

The simulator cannot accept the native iOS microphone permission sheet from
Flutter's widget harness. Use this variant for a deterministic simulator run;
run without the define on a physical device (or after granting microphone
permission) to exercise native pitch capture and recording:

```bash
flutter test integration_test/app_smoke_test.dart -d <ios-simulator-id> \
  --dart-define=FLUTE_SKIP_NATIVE_AUDIO=true
```

The automated journeys do not operate native document-picker or share sheets,
verify physical-device background audio, or replace final checks on physical
tablets; keep those as manual platform checks. Flutter web exposes each routine
row as one composite expansion action, so accessibility checks should target
the row rather than expecting separate semantics nodes for its children.

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

Shared quality checks run formatting, analysis, host tests, Chrome interaction tests, and selected visual baselines before Pages deployment or mobile preview builds.
Platform journeys additionally run on Android and iOS simulators; native audio is skipped in the deterministic smoke journey and remains a physical-device release check.
Signed Android store bundles are created only by a manually dispatched workflow with permanent signing secrets and explicit version/build inputs.

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
