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
- shows latest health values for sleep, HRV, blood oxygen, blood pressure, glucose, heart rate, activity, temperature, ECG, and battery
- opens each dashboard card into a clean detail page with latest data plus saved history
- shows AI suggested actions as separate dashboard cards under the related metric
- opens suggested action cards into a detail view explaining why the action was recommended
- connects to iOS Calendar or Google Calendar for calendar-aware suggested action times
- restores the previous Google Calendar sign-in and locally saves selected calendars/write calendar
- shows specific calendar time options with explanations based on nearby busy events
- adds accepted suggested actions to the selected calendar and can delete app-created calendar events
- schedules local notifications for reminder-style suggested actions
- opens the top dashboard suggested-action area into the full action view when a recommendation is available
- caches AI analyses for unchanged sync data and sends changed data through the newest coach prompt
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

## Dashboard

The first page shows the latest values loaded from the newest local JSON immediately on launch, then refreshes after a completed sync. Tapping a metric card opens a detail page:

- `Latest Data` shows the most recent parsed value.
- AI explanation cards show the score context, a longer explanation, and previous data when available.
- Reference ranges are shown where the app has a useful non-diagnostic range, including ages 12-18 resting heart-rate context.
- `History` shows saved records grouped by day or timestamp in an organized expandable section.
- Sleep history shows score, sleep/wake time, duration, deep/light/awake time, and wake events.
- BP, SpO2, glucose, temperature, and heart rate show timestamped saved samples.
- Activity, HRV, and ECG show per-day summaries where the saved payload is count-based.

Suggested actions are no longer embedded inside the metric card. Each action appears as its own smaller card below the related dashboard metric. Tapping that card opens an action page with the recommendation, why it fits the synced data, latest values, prior history, and any available range context.

Suggested action pages can show calendar-aware time options for actions that fit a calendar block, such as walks, workouts, breathing, hydration check-ins, and sleep wind-down tasks. The app checks selected calendars, avoids overlapping busy blocks and repeated unavailable patterns, and explains each option using nearby events. If title-aware calendar mode is enabled, explanations can include selected event titles, such as free time before a meeting.

When a user taps a suggested time, the app creates the event in the selected write calendar and displays a confirmation. App-created events are listed on the action page and can be deleted from the calendar from the same screen. Reminder-style actions can also schedule local push notifications.

The main coach summary card also links to the action page. If live watch data exists but the AI proxy is unavailable, the app can still show a local Activity recommendation so the action screen is reachable during testing.

The separate Insights tab was removed. The dashboard is the main place for summaries, metric detail, and suggested actions; Profile remains available for settings.

## Calendar-Aware Coaching

Open `Profile -> App Settings -> Calendar-aware coaching` to connect calendars.

- `iOS Calendar` requests EventKit access and imports local iOS calendars.
- `Google` starts Google Sign-In and imports Google Calendar lists/events.
- `Busy only` sends only busy/free blocks to the coach.
- `Use titles` includes selected event titles so time suggestions can explain why a slot fits.

The Google setup requires the app's iOS OAuth client in `WatchProbe/Info.plist`:

- `GIDClientID` must be the iOS OAuth client ID.
- `CFBundleURLTypes` must include the reversed client ID URL scheme.

The current project is configured with the development Google iOS client ID already provided for this app. Google Sign-In persists through the GoogleSignIn SDK; on launch the app restores the previous sign-in, refreshes Google calendars, and keeps selected calendar IDs/write-calendar ID in `UserDefaults`.

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

After each saved sync, the app builds a compact coach context from metric summaries, timestamp-linked sleep/heart-rate correlation data, and calendar availability when calendar-aware coaching is connected. It hashes the enriched context with SHA-256 and stores that hash with the AI analysis in SQLite.

If a later sync produces the same health/calendar context hash, the app reuses the previous AI-backed analysis for the new sync and shows `AI reused`. If the health data or selected calendar availability changes, the app calls Firebase AI Logic or the configured local proxy with the current prompt. Local fallback explanations are saved for display, but only AI-backed analyses are reused across matching syncs.

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
