# AI Coach Watch Workspace

This repo is now focused on native iOS bring-up for the Veepoo/ES02 watch.

- `secrets/google-service-account.json` is the preserved AI credential JSON.
- `docs/veepoo-sdk-ios-api.md` is the local copy of the manufacturer iOS SDK API document, with local integration notes at the top.
- `docs/watch-first-connection.md` records the hardware milestones and next test checklist.
- `watch-probe-ios/` contains the native iOS watch app for scanning, auto-connecting, reading live metrics, and syncing watch-stored data into local JSON files.

Before doing watch work, read `docs/veepoo-sdk-ios-api.md`, `docs/watch-first-connection.md`, and `watch-probe-ios/README.md`.

## First Connection

Use a physical iPhone. The Veepoo connection flow depends on iOS Bluetooth permissions and the vendor SDK, so a plain terminal BLE connection is not the right first proof.

Open `watch-probe-ios/WatchProbe.xcodeproj` in Xcode, select a physical iPhone, set a signing team if needed, then run the `WatchProbe` scheme. The app scans for Veepoo peripherals, connects on row tap, stores the preferred watch, auto-connects on later app opens, waits for password verification, and reads battery/charge state.

The verified test watch is:

- `ES02 / 1B:89:F9:42:CF:54`

## Current Sync Behavior

The app now stores watch data locally in:

`Library/Application Support/WatchResearchData/<device>/<date>/sync-*.json`

Each sync snapshot includes:

- SDK database daily data after `veepooSdkStartReadDeviceAllData`
- sleep / accurate sleep from the SDK database snapshot
- heart half-hour data
- blood oxygen, blood pressure, blood glucose, temperature, activity, HRV, and ECG summaries where available
- direct-read fallback payloads if SDK base daily sync does not complete
- metadata explaining skipped SDK paths, timeouts, and partial-sync diagnostics

The current sync path runs the vendor SDK base daily sync first, then builds JSON from the SDK database. This fixed the sleep visibility problem: sleep now appears in exported JSON when the SDK database has records. Direct watch reads remain as fallback only, and SDK data commands must stay serial.

Recent ES02 logs show the watch exposing `3/3` saved days during base daily sync. The app writes a new JSON file after completed syncs and does not prune local JSON files. On app launch and foreground, the dashboard immediately loads the newest local JSON, then refreshes again after the next successful watch sync.

The app-side auto-sync interval is 10 minutes while the phone app is open/connected. That is not the same as configuring the watch to measure every 10 minutes. The watch can measure/store supported history offline according to its firmware/settings, but `WatchProbe` does not yet explicitly audit or enable each automatic measurement switch.

Do not use `veepooSDKClearDeviceData` for the normal sync cycle. The SDK header says the bracelet shuts down after clearing and there is no success callback. Keep watch data on-device and avoid duplicate imports with local sync snapshots/watermarks instead.

## Dashboard Behavior

The first page now shows the latest saved values for sleep, HRV, blood oxygen, blood pressure, glucose, heart rate, activity, temperature, ECG, and battery. Each card is tappable and opens a detail page with:

- latest parsed data
- history grouped from saved local JSON files
- sleep score, sleep duration, sleep/wake time, deep/light/awake minutes, and wake events for sleep records

Sleep score is a local Apple-style estimate:

- 50 points for duration against an 8-hour target
- 30 points for bedtime consistency from saved sleep start times
- 20 points for interruptions from awake duration and wake events

Do not use an iPhone simulator for this step. Simulators cannot connect to the real watch over Bluetooth, and this probe links the manufacturer iPhoneOS SDK. If Xcode only shows simulator options or no usable device, plug in an iPhone, unlock it, trust the Mac, and select the phone from the run destination menu.

CLI build check:

```bash
xcodebuild \
  -project watch-probe-ios/WatchProbe.xcodeproj \
  -scheme WatchProbe \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/watch-probe-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Next Work

- Add an automatic measurement settings audit for HR/BP/HRV/SpO2/glucose/temperature and display enabled/disabled state.
- Add optional controls to enable supported watch-side automatic measurement intervals.
- Keep improving card history formatting as more multi-day JSON is collected.
- Add local watermarks by data type once the returned payload shape is confirmed.
