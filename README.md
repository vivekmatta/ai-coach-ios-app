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

- SDK database snapshot fields where available
- `directWatchReads.steps`
- `directWatchReads.sleep`
- `directWatchReads.basicData`
- supported temperature records
- sports records
- manual measurement records
- a capped raw RR-interval probe for HRV investigation
- metadata explaining skipped SDK paths
- timeout and partial-sync diagnostics when a vendor SDK callback stalls

The app intentionally avoids `veepooSdkStartReadDeviceAllDataWithReadStateChangeBlock` on the ES02 because it has crashed inside vendor SDK parsers:

`-[NSTaggedPointerString hour]: unrecognized selector`
`-[__NSCFString year]: unrecognized selector`

The safer path reads yesterday's sleep first, uses the SDK direct/self-storage APIs serially, skips the unavailable direct HRV day read, and saves partial JSON if a read times out.

The vendor docs still matter: they recommend the SDK persistence flow of `VPPeripheralManage.shareVPPeripheralManager()`, then `veepooSdkStartReadDeviceAllData`, then `VPDataBaseOperation.veepooSDKGetAccurateSleepData(...)`. Because the SDK also warns that data commands are not concurrent, the next clean sleep check is to run the vendor demo from a fresh launch before trying another recovery mode in `WatchProbe`.

Vendor demo workspace:

`/Users/vivekmatta/Desktop/iOS_Ble_SDK/iOS_sdk_source/Demo/VeepooBleSDKDemo/VeepooBleSDKDemo.xcworkspace`

Use the workspace in Xcode, select scheme `VeepooBleSDKDemo`, run on a physical iPhone, update signing if needed, connect to `ES02`, let the demo complete its automatic daily read, then check its sleep screen. If the demo succeeds, `WatchProbe` should add a fresh-start SDK DB sync mode; if it crashes in `VPAccurateSleepModel parseA3HeaderWithData:andModel:dayNumber:`, send that log to the vendor.

Do not use `veepooSDKClearDeviceData` for the normal sync cycle. The SDK header says the bracelet shuts down after clearing and there is no success callback. Keep watch data on-device and avoid duplicate imports with local sync snapshots/watermarks instead.

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

- Wear the ES02 overnight and open the app the morning of May 19, 2026.
- Wait for `Watch storage read complete`.
- Export/open the latest JSON and inspect `directWatchReads.sleep.records` for day `1`.
- If sleep records are present, build a first sleep summary UI from the JSON.
- If basic-data direct reads crash or return empty on hardware, disable that one path and keep step/sleep/manual sync active.
- Add local watermarks by data type once the returned payload shape is confirmed.
