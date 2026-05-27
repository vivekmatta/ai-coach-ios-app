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
- The SwiftUI dashboard shows latest saved values for sleep, HRV, blood oxygen, blood pressure, glucose, heart rate, activity, temperature, ECG, battery, sync/export controls, and profile controls.
- The dashboard loads the newest local JSON on app launch/foreground, then refreshes after sync.
- Each metric card opens a detail page with latest data, a longer AI explanation, reference range context where available, and saved history grouped from local JSON.
- Suggested actions are separate dashboard cards below the related metric. Tapping one opens an action detail page explaining why the action was recommended.
- The top dashboard suggested-action area also opens the action detail page when a recommendation is available; Activity has a local fallback action when AI is unavailable.
- The old Insights tab has been removed; keep the Dashboard/Profile structure unless the product direction changes.
- AI coach responses are cached by a SHA-256 hash of the non-volatile coach context. Reuse only AI-backed analyses for matching data; send changed data through the current prompt.
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
