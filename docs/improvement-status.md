# Gap remediation status

Implementation and local verification: September 6, 2026.
No release, push, or deployment was performed.

## Prioritized improvements

P1 means data-safety or release-blocking work, P2 means important functionality or quality, and P3 means maintainability or longer-term scaling.
Implemented means the described change exists and has local test coverage, not that all physical-device release checks are complete.

| # | Category | Gap | Priority | Implementation | Status and remaining work |
|---|---|---|---|---|---|
| 1 | Data safety | Unfinished practice disappeared on relaunch | P1 | Throttled durable checkpoints retain notes, elapsed time, exercise tempo/results, piece work and recording references; resume is paused and microphone-off with a stable session ID | Implemented; the latest unflushed second and an interrupted audio file may be incomplete |
| 2 | Data safety | Cross-box import rollback was not restart-safe | P1 | Serialized undo log is flushed before mutations, restores only touched keys and replays before startup | Implemented; interruption and failed-rollback tests pass |
| 3 | Backup | Journal exports omitted media and other local data | P1 | Separate full ZIP backup includes profile, settings, repertoire, folders, PDFs, annotations, display preferences, recordings, routines and sessions; validates media hashes before restore | Implemented; full backups are unencrypted, replace existing data, exclude unfinished drafts, and support at most 256 MB |
| 4 | Resilience | Startup failure and damaged records had no recovery experience | P1 | Retry/full-restore screen, fresh recovery database namespace, original database retention, damaged-record banner and safe preference defaults | Implemented; retained databases are removed by Erase all data |
| 5 | Delivery | Pages could publish without passing quality checks | P1 | Shared formatting, analysis, host, browser and visual checks are a dependency of Pages publishing and mobile previews | Implemented; hosted workflow execution remains pending |
| 6 | Platform quality | Native/browser journeys were not routinely exercised by CI | P1 | Android emulator and iOS simulator workflows plus Chrome checks; added native recovery/media restore journey | Implemented; physical audio, system document pickers and signed-release checks remain required |
| 7 | Measurement | Input level suggested calibrated sound-pressure accuracy | P2 | Relative 0-100 input level, estimated-dynamics explanation and removal of SPL-equivalence claims | Implemented; not a sound-level meter |
| 8 | Portability | Absolute attachment paths could break after migration | P1 | Portable media identifiers, legacy-path rebasing and content-addressed restore; verifies file bytes after writes | Implemented; directory-move and integrity tests pass |
| 9 | Data safety | Recording files could be deleted before a failed metadata save | P1 | Durable cleanup queue, metadata-first deletion and reference checks before file removal | Implemented; failed-delete regression confirms the playable take survives |
| 10 | Backup | Export could produce a file that import rejects | P1 | Lightweight exports pass the same size/schema contract as imports before download | Implemented; oversized export regression passes; multipart export is not included |
| 11 | Contract | Published BPM limits disagreed with supported values | P2 | Version 3 schema accepts target/practiced BPM from 30 through 252 | Implemented; endpoint contract tests pass; historical schemas remain version-specific |
| 12 | Performance | Audio work could accumulate and rebuild unrelated UI | P2 | Three-frame maximum analysis backlog; dedicated audio-reading notifier and selected root theme updates | Implemented; 100-frame burst drops 97 excess analysis frames; physical-device frame profiling remains advisable |
| 13 | Accessibility | Large text and visuals lacked repeatable coverage | P2 | English/Spanish 200% tuner text and tap-target checks, relative-meter semantics, system reduced-motion support, recovery-screen golden and keyboard-safe scrolling | Expanded coverage; VoiceOver/TalkBack and broader screen goldens remain follow-up work |
| 14 | Localization | Built-in practice content and take names remained English | P2 | Localized seed routine names/descriptions/exercises, sample-piece notes and automatic recording names without replacing customized content | Implemented; English/Spanish tests pass |
| 15 | Journal workflow | Saved sessions could not be corrected | P2 | Edit date, duration and notes while retaining exercise results, pitch data and recordings; unchanged timing keeps exact seconds | Implemented; guards against duration shorter than tracked work; undo is not included |
| 16 | Practice feedback | No cross-session comparisons or meaningful measures-worked entry | P2 | History progress view compares exercise tempo and compatible intonation summaries; finish-session measures input is persisted | Implemented; comparisons are descriptive, not an assessment of musical improvement |
| 17 | Scalability | Journal statistics repeatedly decoded/scanned all history | P3 | Session cache and derived day, duration and exercise indexes; weekly totals use seven indexed lookups and streaks use day membership | Improved; 100,000-session aggregate benchmark passes; cold loads still read all sessions, with no paginated database query layer |
| 18 | Architecture | Practice and score responsibilities were concentrated in large files | P3 | Extracted draft recovery, backup/transaction services, history summary, recorder panel and annotation painter | Partial refactoring; large practice/score widgets remain and further controller extraction is a separate incremental task |

## Verification

Local tooling: Flutter 3.44.8, Dart 3.12.2, macOS, Chrome, a dedicated iPhone 17 Pro simulator running iOS 26.1, and a dedicated Android API 37 arm64 emulator with 16 KB pages.
Hosted Android CI targets API 35 x86_64 instead of the preview system image available locally.
The repository and hosted workflows remain pinned to Flutter 3.44.0; that exact SDK's hosted run has not been observed.

- `flutter analyze --no-pub`: no issues.
- `dart format --output=none --set-exit-if-changed lib test integration_test`: passed.
- `flutter test --no-pub --coverage --exclude-tags golden`: 156 passed, three platform-specific skips.
- `flutter test --no-pub --tags golden`: one passed; baseline uses real Flutter SDK fonts and was visually reviewed.
- Explicit Chrome settings/routine/analytics/dashboard tests: nine passed.
- `flutter build web --release --wasm --no-pub`: passed.
- iOS core smoke journey: passed with `FLUTE_SKIP_NATIVE_AUDIO=true`.
- iOS feature suite: 42 passed, one web-only skip; includes real PDF rendering and rotation.
- Native recovery/media journey: passed on iOS and Android, including real playback of a restored silent WAV attachment.
- Android core smoke journey: passed with `FLUTE_SKIP_NATIVE_AUDIO=true`.
- Android feature journey: 42 passed, one web-only skip; includes real PDF rendering and rotation.

New regression coverage includes failed recording deletion, unsupported export size, damaged preferences, interrupted rollback, unfinished-session recovery, full media restoration, attachment hash mismatch, missing media, moved storage roots, session-edit preservation, schema endpoints, large-text layouts and bounded audio analysis.
The native round-trip reproduced iOS rejecting generic `.audio` filenames; exports now inspect audio-container signatures and preserve recognized extensions.

## Release checks still requiring a real device or hosted runner

- Run the configured workflows at the repository's pinned Flutter version and inspect their artifacts before publishing.
- Test real AAC recordings and cross-platform codec support, microphone permission denial, interruptions, screen locking and long background sessions.
- Exercise native document-picker and share sheets, including cancellation, insufficient storage and larger private-media backups.
- Perform VoiceOver/TalkBack navigation and physical tablet/multitasking review.
- Verify signed Android/iOS release builds with the project's existing store checklist.

Run integration journeys only on disposable test devices: they deliberately erase the test app's data.

```bash
flutter test integration_test/app_smoke_test.dart -d <test-device> --dart-define=FLUTE_SKIP_NATIVE_AUDIO=true
flutter test integration_test/ios_feature_suite_test.dart -d <test-device>
flutter test integration_test/recovery_journey_test.dart -d <test-device>
```
