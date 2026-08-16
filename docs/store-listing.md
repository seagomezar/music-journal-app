# Flute Practice Coach store listing

## Shared positioning

- Name: `Flute Practice Coach`
- Primary category: Music
- Secondary Apple category: Education
- Audience: General / not specifically designed for children
- Monetization: Free, no ads, no in-app purchases
- Account: None; profile and journal are local to the device

## Apple App Store

- Subtitle: `Practice journal for flutists`
- Promotional text: `Build focused routines, organize repertoire, track practice time, and privately review short recordings.`
- Keywords: `flute,practice,journal,routine,repertoire,metronome,music,recording`
- Marketing URL: `https://seagomezar.github.io/music-journal-app/`
- Privacy Policy URL after GitHub Pages deployment: `https://seagomezar.github.io/music-journal-app/privacy-policy.html`
- Support URL after GitHub Pages deployment: `https://seagomezar.github.io/music-journal-app/support.html`
- Terms URL: `https://seagomezar.github.io/music-journal-app/terms-and-conditions.html`

## Google Play

- Short description: `Plan flute routines, track repertoire, and review private practice recordings.`
- App icon: `assets/store/google-play-icon-512.png`
- Feature graphic: `assets/store/google-play-feature-1024x500.png`
- Phone screenshots: five current 1080 x 1920 RGB PNGs under `assets/store/screenshots/google-play/`
- Website: `https://seagomezar.github.io/music-journal-app/`
- Privacy Policy: `https://seagomezar.github.io/music-journal-app/privacy-policy.html`
- Android compatibility: release builds target API 36 and declare the microphone as optional hardware.

## Full description

Flute Practice Coach gives flutists a calm, private place to structure daily practice.

Create technical routines for long tones, scales, articulation, and other exercises. Organize repertoire, attach PDF scores, set target tempos, and track measure progress. During practice, use the visual metronome, time each piece, make notes, and record a short passage for self-evaluation.

Your journal is managed locally by the app and is not uploaded to us. The app has no advertising or online account. The deployed web version may send optional aggregate usage events through Plausible when configured; it never sends journal, profile, audio, or pitch data. Imported scores and recordings are stored in private app storage and can be deleted individually or erased together from Settings. Your operating system may separately include app data in a backup you enable.

Key features:

- Custom technical practice routines
- Repertoire and measure-progress tracking
- PDF score viewer with temporary page annotations
- Visual metronome from 40 to 240 BPM
- Exercise-level tempo controls and optional local pitch tracking with A4 reference adjustment
- Practice timer, notes, statistics, calendar, and streaks
- Optional private self-evaluation recordings
- English and Spanish interface
- Local-first app-managed storage with an in-app erase-data control

## Evidence-informed positioning

The app is designed around structured goals, focused feedback, and reflection—
practice behaviors discussed in music-learning research. Store copy must not
claim that the app itself guarantees faster improvement or makes someone a
better flutist. See the [evidence brief](research/flutist-practice-evidence.md)
and [claim ledger](research/claim-ledger.csv) for approved wording and source
limitations.

## Privacy declarations

- Apple App Privacy: `Data Not Collected`, provided archive inspection confirms no dependency transmits data.
- Google Play Data Safety: no data collected or shared by the app; profile data, notes, PDFs, and recordings are managed locally. Platform backups are controlled separately by the user and operating-system provider.
- Permission purpose: microphone is used only after the user explicitly starts the tuner, pitch tracking, or self-recorder. Tuner audio is analyzed locally and is not saved or transmitted.
- Mobile-app tracking: none; optional aggregate measurement for the deployed web version is described in the Privacy Policy.
- Ads: none.

## Review notes

The app does not require a login. Enter a display name to create a local profile. To test recording: start a practice session, open Self-Evaluation Recorder, grant microphone permission, record, stop, and play the result. On supported mobile builds, recording continues through screen lock and stops when the recorder closes, the session finishes or is discarded, or app data is erased. Settings includes Privacy Policy, Terms and Conditions, Support, and Erase all data.
