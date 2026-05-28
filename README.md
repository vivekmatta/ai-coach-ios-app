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

## Local AI Proxy For Testing

For testing without Firebase, run the local Gemini proxy from this repo:

```bash
GEMINI_API_KEY=your-key node server/coach-ai-proxy.mjs
```

The proxy can also use the preserved Vertex AI service-account JSON:

```bash
GOOGLE_APPLICATION_CREDENTIALS=secrets/google-service-account.json node server/coach-ai-proxy.mjs
```

On a physical iPhone, enter the Mac's LAN URL in the app under `Profile -> App Settings -> Local AI proxy`, for example:

`http://192.168.1.25:8790`

If only a host is entered, such as `10.105.80.5`, the app normalizes it to `http://10.105.80.5:8790` before calling `/analyze`. iOS must also allow local network access for the app: `Settings -> Privacy & Security -> Local Network -> WatchProbe`. If the app is not listed, reinstall from Xcode and allow the local-network prompt.

The app tries Firebase AI Logic first. If `GoogleService-Info.plist` is missing, it falls back to the local proxy. Do not use the local proxy as a production research backend.

## AI Coach Behavior

After each saved watch sync, the app stores compact metric summaries in SQLite and asks the AI coach for structured Dashboard explanations, category scores, correlations, warnings, and suggested actions. The prompt is non-diagnostic, requires timestamp-backed correlations, and tells the model to explain missing, stale, partial, or uncertain data instead of inventing conclusions.

The coach context now includes timestamp-linked sleep windows and heart-rate samples. This lets the AI distinguish heart-rate readings that happened during recorded sleep from readings outside sleep, and it should say the relationship is unclear when timestamps do not overlap.

Calendar-aware coaching is available from `Profile -> App Settings -> Calendar-aware coaching`. The app can connect to iOS calendars or Google Calendar, lets the user choose which calendars the coach should consider, and stores the selected calendars locally. Google Calendar uses the iOS OAuth client configured in `Info.plist` (`GIDClientID` plus the reversed client-ID URL scheme), restores the previous sign-in on launch, and refreshes calendar availability before AI inference when calendars change.

Calendar data is sent to the AI as availability context rather than as a raw full calendar dump. In busy-only mode, event titles are omitted. In title-aware mode, selected event titles are included so suggested times can explain context such as available time before a meeting. Suggested action detail pages show specific calendar time options, why each option was chosen, and can add or delete app-created calendar events.

Suggested actions now support structured action types, durations, intensity, reminders, and workout categories such as HIIT/mobility/strength when appropriate. Accepted actions can schedule local push notifications for reminders such as hydration or movement prompts.

AI analyses are cached by a SHA-256 fingerprint of the full coach context, including calendar availability when calendar-aware coaching is enabled. If a new sync contains the same health and calendar context as a previous AI-backed sync, the app reuses the saved analysis and marks it as reused. If the watch data or calendar context changes, the app sends the newest context through the current AI prompt. Local fallback explanations are saved, but they do not block a later real AI response.

## Dashboard Behavior

The first page now shows the latest saved values for sleep, HRV, blood oxygen, blood pressure, glucose, heart rate, activity, temperature, ECG, and battery. Each card is tappable and opens a detail page with:

- latest parsed data
- a longer AI explanation backed by previous saved data when available
- a relevant reference range, such as the adolescent resting heart-rate range used for ages 12-18
- organized history grouped from saved local JSON files
- sleep score, sleep duration, sleep/wake time, deep/light/awake minutes, and wake events for sleep records

Suggested actions are displayed as separate cards below the related dashboard metric. Tapping an action card opens an action detail view with the recommendation, why the AI suggested it, latest data, history context, and any reference range available.

For calendar-suitable actions, the action detail view also shows suggested calendar times. Each option includes duration plus a short explanation based on selected calendar availability, for example how long the user is free before the next titled event. Tapping a time adds the action to the configured write calendar and shows confirmation; app-created calendar events can be deleted from the same view.

The top Dashboard coach summary also routes its suggested-action area to the full action detail view when an action is available, using the activity fallback if the AI proxy has not returned a recommendation yet.

The old Insights tab has been removed. The app keeps the main Dashboard and Profile flow, with deeper explanations available by tapping cards.

Sleep score is a local Apple-style estimate:

- 50 points for duration against an 8-hour target
- 30 points for bedtime consistency from saved sleep start times
- 20 points for interruptions from awake duration and wake events

## App Assets

`watch-probe-ios/WatchProbe/Assets.xcassets` contains a `Logo.imageset` slot for project branding. Use `AppIcon.appiconset` for the actual iOS home-screen icon and `Logo.imageset` for in-app logo artwork.

`AppIcon.appiconset` is configured as the iOS app icon in the Xcode project. If the home-screen icon does not update on a device, delete the installed app and reinstall the current build from Xcode so iOS refreshes the icon cache.

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
