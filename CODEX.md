# Workspace Notes

Current priority: native iOS Veepoo/ES02 watch data sync.

Always read these before making changes:

1. `docs/veepoo-sdk-ios-api.md`
2. `docs/watch-first-connection.md`
3. `watch-probe-ios/README.md`

Preserve `secrets/google-service-account.json`. Do not print its contents.

The previous Expo app, research dashboard, Node server, mock fixtures, and bundled assets were intentionally removed. The active app is `watch-probe-ios/WatchProbe.xcodeproj`.

## Current State

- Physical watch connection is verified for `ES02 / 1B:89:F9:42:CF:54`.
- The app stores the preferred watch and auto-connects when opened.
- The SwiftUI app now uses a coach-first four-tab shell: Coach, Plan, Progress, and Profile.
- Coach shows the greeting, Steady/Chill/Beast Mode selector, daily rings, coach message, top checklist items, and compact armband status.
- Plan shows Fuel, Move, Mind, and Recovery task cards. Tapping a row checks/unchecks it; only the `i` info button opens recommendation detail.
- Progress keeps analytics secondary: summary cards first, then tap-through sensor detail views for latest data, AI explanations, references, and saved history.
- Profile keeps non-calendar controls in the same Stitch-style theme: watch sync/connect/disconnect, auto-sync, coach personality, reminders, onboarding replay, local AI proxy, export, and debug log.
- Calendar-aware coaching code remains available but the current UI hides calendar setup and calendar scheduling until a later pass.
- `Profile -> App Settings -> Show onboarding` replays the first-run onboarding by resetting only `WatchProbe.onboardingCompleted`; it preserves synced data and other settings for demos.
- AI coach responses are cached by a SHA-256 hash of the enriched health context. Reuse only AI-backed analyses for matching context; send changed health context through the current prompt.
- AI `suggested_actions` are preserved through response normalization and feed the Plan UI. Local defaults fill missing task categories while testing without AI output.
- Sleep includes a local Apple-style score, duration, sleep/wake time, deep/light/awake minutes, and wake events.
- Local sync snapshots are saved under `Library/Application Support/WatchResearchData`.
- The implemented sync path runs the SDK base daily sync first, then builds JSON from the SDK database snapshot. Direct watch reads remain fallback only.
- SDK data commands must be serialized. Do not start direct reads while base daily sync is running.
- Recent ES02 syncs expose `3/3` saved days. The app does not prune local JSON; history merges the newest saved copy of each exported day.
- The app-side auto-sync timer is 10 minutes while open/connected. The app does not yet configure every watch-side automatic measurement switch.
- The app has `WatchProbe/Assets.xcassets/Logo.imageset` for in-app logo artwork. Use `AppIcon.appiconset` for the actual iOS app icon.
- The Xcode target is configured to use `WatchProbe/Assets.xcassets/AppIcon.appiconset` as the home-screen app icon.
- The Veepoo SDK's internal `automaticConnection` is disabled. The app owns scanning, preferred-watch auto-connect, stale-session cleanup, and one verification retry to avoid duplicate pairing/stalled SDK state.
- Local AI proxy URLs are normalized to port `8790`; iOS Local Network permission is required for device-to-Mac proxy calls.
- Do not use `veepooSDKClearDeviceData` in the normal cycle. It shuts the bracelet down and has no success callback.

## Verification

Use this build check:

```bash
xcodebuild -project watch-probe-ios/WatchProbe.xcodeproj -scheme WatchProbe -configuration Debug -sdk iphoneos -derivedDataPath /private/tmp/WatchProbeDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Next Work

- Add automatic measurement settings audit/readout for HR/BP/HRV/SpO2/glucose/temperature.
- Add optional controls to enable supported watch-side automatic measurement intervals.
- Keep refining card history formatting as more multi-day JSON is collected.
- Add per-data-type watermarks/checkpoints after the direct read payloads are stable.
