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
- reads steps/live measurements
- runs manual tests for supported functions
- saves local JSON sync snapshots
- loads the latest saved JSON into the dashboard on app launch/foreground
- shows latest health values for sleep, HRV, blood oxygen, blood pressure, glucose, heart rate, activity, temperature, ECG, and battery
- opens each dashboard card into a clean detail page with latest data plus saved history
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
- `History` shows saved records grouped by day or timestamp.
- Sleep history shows score, sleep/wake time, duration, deep/light/awake time, and wake events.
- BP, SpO2, glucose, temperature, and heart rate show timestamped saved samples.
- Activity, HRV, and ECG show per-day summaries where the saved payload is count-based.

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
