# Landing-page measurement specification

## Privacy boundary

Plausible Cloud is loaded only when the deployment supplies a non-empty site
domain. Local previews, forks, and builds without that configuration do not send
events. Events contain no name, journal text, recording, score, pitch stream,
or persistent user identifier.

## Events

| Event | Where | Allowed properties | Success meaning |
| --- | --- | --- | --- |
| `locale_selected` | Landing page and app | `locale` (`en`/`es`) | Language preference observed in aggregate |
| `landing_cta_click` | Landing page | `target` (`web_app`/`research`/`support`) | Visitor chooses a next step |
| `app_launch` | Flutter web app | none | App loaded successfully |
| `onboarding_complete` | Flutter web app | none | Local profile created |
| `practice_session_started` | Flutter web app | `routine` (`routine`/`quick_start`) | First structured practice action |

## Funnel

1. Landing-page visit.
2. `landing_cta_click` with `target=web_app`.
3. `app_launch`.
4. `onboarding_complete`.
5. `practice_session_started`.

Review aggregate conversion weekly. Do not use the funnel to claim learning
outcomes. A later consented research study must collect outcome measures
separately.

## UTM convention

Use `utm_source`, `utm_medium`, `utm_campaign`, and `utm_content` for public
links. Recommended campaigns are `research_launch`, `teacher_outreach`,
`reddit_flute`, `youtube_flute`, `instagram_flute`, and `spanish_launch`.
