# WatchProbe

Native iOS app for the Veepoo/ES02 watch.

Open `WatchProbe.xcodeproj`, select a physical iPhone, choose the `WatchProbe` scheme, set signing if Xcode asks, and run.

The simulator is not useful for this probe. It cannot talk to the real watch over Bluetooth.

## What The App Does

- initializes `VPBleCentralManage`
- scans with `veepooSDKStartScanDeviceAndReceiveScanningDevice`
- connects with `veepooSDKConnectDevice`
- logs SDK connection states
- reads battery/charge state after `BleVerifyPasswordSuccess`
- remembers the preferred watch after a successful verification
- auto-connects on app open
- disables the Veepoo SDK's internal `automaticConnection` so the app owns one clean scan/connect flow
- reads steps/live measurements
- runs manual tests for supported functions
- saves local JSON sync snapshots
- loads the latest saved JSON into the dashboard on app launch/foreground
- presents a four-tab coach-first UI: Coach, Plan, Progress, and Profile
- shows Apple-style daily rings, an AI coach message, and a task checklist before raw analytics
- groups daily actions into Fuel, Move, Mind, and Recovery cards
- keeps raw sensor analytics hidden until the user opens Progress or a metric detail view
- opens each metric detail page into latest data, AI explanation, reference context, and saved history
- opens recommendation details only from the task row `i` info button; tapping a task row checks or unchecks it
- schedules local notifications for reminder-style suggested actions
- replays onboarding from `Profile -> App Settings -> Show onboarding` without deleting saved app data
- caches AI analyses for unchanged sync data and sends changed data through the newest coach prompt
- preserves calendar-aware coaching code, but hides calendar setup/scheduling UI until a later pass
- includes an asset catalog logo slot at `WatchProbe/Assets.xcassets/Logo.imageset`
- includes `WatchProbe/Assets.xcassets/AppIcon.appiconset` for the iOS home-screen icon
- exports the latest sync snapshot through the iOS share sheet

The verified watch is `ES02 / 1B:89:F9:42:CF:54`.

## Local Data Sync

The app writes sync files to the app sandbox:

`Library/Application Support/WatchResearchData/<device>/<date>/sync-*.json`

The sync payload contains SDK database fields plus direct-read fallback data. The app now runs the SDK base daily sync first because the vendor demo uses that path to populate the SDK database for accurate sleep. After a successful base sync, the JSON is built from the SDK database snapshot.

- `steps`
- accurate sleep / sleep
- heart half-hour data
- blood oxygen
- blood pressure
- blood glucose
- HRV counts or skipped diagnostics
- ECG counts
- temperature when supported
- `temperature` when supported
- sports records in metadata
- manual measurements in metadata

The earlier direct-read-only path is still used as a fallback if the SDK base daily sync does not complete. SDK data commands must remain serial; do not run watch data reads concurrently.

The current base daily sync reads up to the watch-reported saved days. Recent ES02 runs exposed `3/3`, so JSON usually contains the latest three on-watch days. Local JSON files are not pruned, and the dashboard merges the newest saved copy of each day across local sync files for card history.

The app-side auto-sync timer runs every 10 minutes while the app is open/connected. That is separate from the watch's own offline measurement interval. The watch can store supported data while disconnected, but this app does not yet explicitly enable or configure every automatic measurement switch.

Do not clear the watch as part of normal sync. `veepooSDKClearDeviceData` shuts the bracelet down and has no success callback. Use local snapshots and later watermarks instead.

## Coach-First UI

The first screen is intentionally coach-first rather than analytics-first. It loads the newest local JSON immediately on launch, then refreshes after a completed sync, but it summarizes the data as goals and actions:

- `Coach` shows a greeting, Steady/Chill/Beast Mode selector, daily rings, a coach message, top checklist items, and compact armband status.
- `Plan` shows Fuel, Move, Mind, and Recovery task cards.
- `Progress` shows a coach insight bubble, seven-day ring history, summary cards, and sensor detail entry points.
- `Profile` keeps watch controls, auto-sync, coach personality, reminders, onboarding replay, local AI proxy, export, and debug log.

Raw analytics are still preserved for every supported sensor, but they do not dominate the first-level UI. Progress/detail views expose the latest values, saved history, AI explanations, and reference ranges for sleep, HRV, SpO2, blood pressure, glucose, heart rate, activity, temperature, ECG, battery, and sync metadata.

Task rows behave like a checklist. Tapping the row checks or unchecks it. Tapping the `i` info button opens the recommendation page with rationale, related data, available reference context, alternatives, and reminders.

AI-backed tasks come from the proxy/Firebase `suggested_actions` response. If the AI has not returned enough tasks yet, the app fills the plan with local defaults such as hydration, steps, protein lunch, breathing, journaling, bedtime, and dim lights.

For demos, open `Profile -> App Settings -> Show onboarding` to present the first-run onboarding again. This only resets `WatchProbe.onboardingCompleted`; saved sync snapshots, preferred watch state, calendar settings, and local proxy settings are preserved.

## Calendar-Aware Coaching

Calendar-aware coaching code remains in the app, but the current UI hides calendar setup and calendar scheduling. Re-enable it in a later pass when the product is ready to introduce schedule-aware recommendations.

The Google setup values remain in `WatchProbe/Info.plist` for future use.

## Local AI Proxy

Run the development proxy from the repo root:

```bash
GOOGLE_APPLICATION_CREDENTIALS=secrets/google-service-account.json node server/coach-ai-proxy.mjs
```

The proxy listens on port `8790`. In the app's Profile settings, enter the Mac LAN address with the port, for example:

`http://10.105.80.5:8790`

Entering only `10.105.80.5` is also accepted; the app normalizes it to `http://10.105.80.5:8790` before calling `/analyze`.

On iPhone, allow local network access for WatchProbe in `Settings -> Privacy & Security -> Local Network`. If iOS previously denied it and the app is missing from that list, delete the app, reinstall from Xcode, and tap Allow when prompted.

## AI Coach Cache

After each saved sync, the app builds a compact coach context from metric summaries and timestamp-linked sleep/heart-rate correlation data. It hashes the enriched context with SHA-256 and stores that hash with the AI analysis in SQLite.

If a later sync produces the same health context hash, the app reuses the previous AI-backed analysis for the new sync and shows `AI reused`. If the health data changes, the app calls Firebase AI Logic or the configured local proxy with the current prompt. Local fallback explanations are saved for display, but only AI-backed analyses are reused across matching syncs.

Sleep score is an Apple-style local estimate on a 100-point scale:

- duration: up to 50 points against an 8-hour target
- bedtime consistency: up to 30 points from saved sleep start times
- interruptions: up to 20 points from awake duration and wake events

## Build Check

```bash
xcodebuild -project watch-probe-ios/WatchProbe.xcodeproj -scheme WatchProbe -configuration Debug -sdk iphoneos -derivedDataPath /private/tmp/WatchProbeDerivedData CODE_SIGNING_ALLOWED=NO build
```

## Next Work

- Add an automatic measurement settings audit that reads HR/BP/HRV/SpO2/glucose/temperature switch state and shows enabled/disabled on the dashboard.
- Add optional enable/configure controls for supported automatic watch-side measurement intervals.
- Add per-type sync watermarks after direct read timestamps/CRCs are confirmed.
- Improve export flow if iOS share-sheet provider warnings continue on device.

The bundled `VeepooBleSDK.framework` was copied from:

`/Users/vivekmatta/Desktop/iOS_Ble_SDK/iOS_sdk_source/Demo/VeepooBleSDKDemo/VeepooBleSDKDemo/VeepooBleSDK.framework`
