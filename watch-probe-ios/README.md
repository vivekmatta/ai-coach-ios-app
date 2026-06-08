# WatchProbe iOS App

`WatchProbe` is the native iOS app in this repo. It connects to a Veepoo/ES02 smartwatch with the manufacturer SDK, syncs watch-stored health data, writes local JSON snapshots, and presents a coach-first SwiftUI interface.

Open this project in Xcode:

```bash
open watch-probe-ios/WatchProbe.xcodeproj
```

Run the `WatchProbe` scheme on a physical iPhone for real watch testing. The simulator cannot connect to the watch and the current target links device-only SDK frameworks.

## Physical iPhone Setup

1. Start the local proxy from the repo root:

   ```bash
   GEMINI_API_KEY="<your-gemini-api-key>" node server/coach-ai-proxy.mjs
   ```

   or:

   ```bash
   GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/to/service-account.json" node server/coach-ai-proxy.mjs
   ```

2. Connect an iPhone to the Mac, unlock it, and trust the Mac.
3. In Xcode, select the `WatchProbe` scheme and the physical iPhone destination.
4. In `Signing & Capabilities`, choose your Apple developer team.
5. Change the bundle identifier if Xcode says it is already registered to another team.
6. Run the app and allow Bluetooth and Local Network permissions.
7. In `Profile -> App Settings -> Local AI proxy`, enter the Mac LAN URL, for example `http://192.168.1.25:8790`.
8. Scan, connect to the watch, wait for password verification, and sync.

The phone cannot use `localhost` for the Mac proxy. Use the Mac's LAN IP address. If local network access fails, check `Settings -> Privacy & Security -> Local Network -> WatchProbe` on the iPhone.

## What The App Does

- Initializes `VPBleCentralManage`.
- Scans with `veepooSDKStartScanDeviceAndReceiveScanningDevice`.
- Connects with `veepooSDKConnectDevice`.
- Waits for `BleVerifyPasswordSuccess`.
- Reads battery and charge state.
- Stores the preferred watch and auto-connects on later app opens.
- Disables the Veepoo SDK's internal `automaticConnection` so the app owns one scan/connect flow.
- Runs SDK base daily sync first and serializes all SDK data commands.
- Saves local JSON sync snapshots.
- Loads the latest saved JSON on launch and foreground.
- Presents Coach, Plan, Progress, and Profile tabs.
- Sends changed watch summaries to Firebase AI Logic when configured or to the local proxy.
- Caches AI analyses by health-context hash and selected coach personality.
- Exports the latest sync snapshot through the iOS share sheet.

The verified development watch was `ES02 / 1B:89:F9:42:CF:54`.

## Local Data

The app writes sync files inside the app sandbox:

```text
Library/Application Support/WatchResearchData/<device>/<date>/sync-*.json
```

The sync payload contains SDK database fields plus direct-read fallback data where available:

- steps
- accurate sleep / sleep
- heart half-hour data
- blood oxygen
- blood pressure
- blood glucose
- HRV counts or skipped diagnostics
- ECG counts
- temperature when supported
- sports records in metadata
- manual measurements in metadata

The current base daily sync reads up to the watch-reported saved days. Recent ES02 runs exposed `3/3`, so JSON usually contains the latest three on-watch days. Local JSON files are not pruned.

Do not clear the watch as part of normal sync. `veepooSDKClearDeviceData` shuts the bracelet down and has no success callback. Use local snapshots and future watermarks instead.

## Coach UI

The first screen is coach-first rather than analytics-first:

- `Coach` shows greeting, daily progress, coach message, top checklist items, and compact watch status.
- `Plan` shows Fuel, Move, Mind, and Recovery task cards.
- `Progress` shows summaries first, then sensor detail entry points.
- `Profile` keeps watch controls, auto-sync, coach personality, reminders, onboarding replay, local AI proxy, export, and debug log.

Raw analytics remain available from Progress and metric detail views for sleep, HRV, SpO2, blood pressure, glucose, heart rate, activity, temperature, ECG, battery, and sync metadata.

For demos, open `Profile -> App Settings -> Show onboarding`. This resets only `WatchProbe.onboardingCompleted`; saved sync snapshots, preferred watch state, calendar settings, and local proxy settings are preserved.

## Local AI Proxy

The proxy listens on port `8790` by default. The app calls `/analyze` after it has a saved sync snapshot and a compact coach context. If the app cannot reach Firebase AI Logic or the local proxy, it keeps local watch data visible but cannot produce fresh AI-backed coaching.

Entering only a host such as `192.168.1.25` is accepted; the app normalizes it to `http://192.168.1.25:8790`.

## Build Check

```bash
xcodebuild \
  -project watch-probe-ios/WatchProbe.xcodeproj \
  -scheme WatchProbe \
  -configuration Debug \
  -sdk iphoneos \
  -derivedDataPath /private/tmp/WatchProbeDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Notes For Future Maintainers

- SDK data commands must remain serial.
- Physical watch sync requires a real iPhone.
- Simulator support would require a separate simulator-safe target or SDK stubs.
- Keep credentials and exported research data out of Git.
- Replace Google/Firebase configuration with lab-owned values before re-enabling calendar or Firebase-backed flows.
