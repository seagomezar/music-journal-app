# Store submission checklist

## Repository gates

- [x] `dart format --output=none --set-exit-if-changed lib test`
- [x] `flutter analyze`
- [x] `flutter test`
- [x] Android API 36 unsigned release AAB and APK build successfully
- [ ] Android release app bundle succeeds with permanent upload-key signing
- [ ] iOS release archive succeeds with the distribution team and a matching installed iOS/Xcode platform
- [ ] Test the exact signed builds on physical Android and iPhone devices
- [x] Inspect the unsigned Android merged manifest (optional microphone permission plus wake-lock and foreground-service/media-playback permissions for the background metronome)
- [ ] Inspect the signed iOS archive privacy report

## Product checks

- [x] Recording stops after close, finish, discard, and background (automated tests and Android smoke test)
- [ ] Verify recording cleanup after forced process termination on physical devices
- [x] Permission denial is recoverable and microphone-independent features remain usable
- [x] Session-save failures do not exit or discard the active session
- [ ] Imported PDF and recording survive relaunch
- [x] Deleting a session removes its managed recording (automated test and Android smoke test)
- [ ] Deleting a repertoire piece removes its managed PDF on a physical device
- [x] Erase all data removes the profile, database content, and app-managed files (Android smoke test)
- [ ] English and Spanish, large text, VoiceOver/TalkBack, and small-screen layouts pass

## External setup

- [ ] Confirm ownership of `com.seagomezar.flutepracticecoach` in Play Console and App Store Connect before first upload
- [ ] Configure Play App Signing and store the permanent upload key in GitHub Actions secrets
- [ ] Configure the Apple distribution certificate, provisioning profile, team, and App Store Connect API access
- [ ] Enable GitHub Pages for the `docs/` directory and verify the landing, privacy, terms, and support URLs are public
- [ ] Complete Apple App Privacy, age-rating, export-compliance, category, territories, and reviewer-contact fields
- [ ] Complete Play Data Safety, content rating, target audience, ads, app access, and developer-contact fields
- [ ] For a personal Play account created after November 13, 2023, complete a closed test with at least 12 opted-in testers for 14 continuous days
- [x] Target Android API 36 for the August 31, 2026 Play requirement

## Store assets

- [x] Build and browser-validate responsive landing, privacy, terms, and support pages
- [x] Native launcher icons replaced
- [x] Google Play 512 x 512 icon created
- [x] Google Play 1024 x 500 feature graphic created
- [x] Capture at least four current 1080 x 1920 Android screenshots from the final build
- [ ] Capture 6.9-inch iPhone screenshots from the final iOS build at an accepted size (1260 x 2736, 1290 x 2796, or 1320 x 2868 portrait)
- [ ] Localize promotional text embedded in any screenshots
- [ ] Add screenshot alt text in Play Console

## Release control

- [ ] Choose a public version and a store build number greater than every previous upload
- [ ] Run the manual `Mobile quality and release` workflow with those exact values
- [ ] Upload the generated AAB and separately archive/upload the signed iOS build
- [ ] Run Play pre-launch reports and TestFlight external testing
- [ ] Resolve all crashes, privacy warnings, broken links, and reviewer-access issues
- [ ] Use a staged Android rollout and monitor store diagnostics after release
