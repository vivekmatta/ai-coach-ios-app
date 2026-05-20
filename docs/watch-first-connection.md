# Watch First Connection And Sync Notes

## Goal

Prove the new watch can complete the manufacturer SDK connection flow from a physical iPhone.

Success means:

- the app scans and displays the watch
- tapping the watch reaches `BleConnectSuccess`
- SDK password verification reaches `BleVerifyPasswordSuccess`
- the app reads battery/charge state through `veepooSDKReadDeviceBatteryAndChargeInfo`
- the app can auto-connect later and save watch data into local JSON

Latest verified result:

- device name/address: `ES02 / 1B:89:F9:42:CF:54`
- password verification: succeeded
- battery read: succeeded
- charge state: `0`, normal/not charging
- local sync files: saved under `Library/Application Support/WatchResearchData`
- current sync mode: SDK base daily sync first, direct reads as fallback
- dashboard: loads latest saved JSON on app launch/foreground and shows tappable metric detail/history pages

## Why Native iOS First

The manufacturer provides an iOS framework, not a JavaScript BLE protocol. The SDK handles device discovery, password verification, command sequencing, persistence, and model parsing. Plain Expo Go cannot load this framework, and a terminal-only BLE scan cannot prove the Veepoo SDK handshake.

Use `watch-probe-ios/WatchProbe.xcodeproj` as the first probe. Once the SDK flow is proven, the product app can either stay native iOS or wrap the same native code behind a React Native dev-client module.

The iPhone simulator is not a valid target for this first test. It cannot connect to the physical watch over Bluetooth, and the vendor framework is packaged for iPhoneOS device builds.

## Connection Rules From The SDK

- Initialize `VPBleCentralManage.sharedBleManager()` before Bluetooth work.
- Set persistence with `VPPeripheralManage.shareVPPeripheralManager()`.
- Do not run SDK commands concurrently. Wait for one operation to complete before starting another.
- Do not connect the same watch from H Band, the SDK demo, and this probe at the same time.
- Stop scanning before leaving the scan screen or when a connection is no longer needed.
- Do not clear the watch after each sync. `veepooSDKClearDeviceData` shuts the bracelet down and has no success callback.

## Probe Flow

1. Build/run `WatchProbe` on a physical iPhone.
2. Grant Bluetooth permission.
3. Put the watch into its normal pairing/advertising state.
4. Tap `Start Scan`.
5. Tap the watch row.
6. Watch the status log for connection and password verification states.
7. Confirm battery output appears after verification.
8. Let auto-sync finish or tap sync now.
9. Export the latest JSON snapshot when needed.
10. Tap any dashboard card to inspect latest data and local history for that metric.

## What Changed On May 18-19, 2026

- Replaced the first-connection-only app with a SwiftUI-style dashboard hosted in the native UIKit app.
- Added preferred-watch persistence and app-open auto-connect.
- Added local JSON snapshots through `WatchResearchStore`.
- Changed sync to run the SDK base daily read first so the vendor SDK database can populate sleep and daily records.
- Kept serial direct watch reads as fallback if the base daily sync does not complete.
- Added timeout-based partial saves for stalled vendor SDK callbacks.
- Added dashboard loading from the latest local JSON on app launch and foreground.
- Added main-card values for sleep, HRV, blood oxygen, blood pressure, glucose, heart rate, activity, temperature, ECG, and battery.
- Added tappable metric cards with latest data plus history sections grouped from saved local JSON.
- Added local Apple-style sleep score, sleep duration, sleep time, wake time, deep/light/awake time, and wake event display.
- Removed the direct `JL_BLEKit` app link while keeping the vendor-required dial/DFU frameworks embedded.

## Vendor Demo Cross-Check

The company SDK documentation confirms the recommended daily-data path is SDK persistence:

1. Use `VPPeripheralManage.shareVPPeripheralManager()`.
2. Call `veepooSdkStartReadDeviceAllData`.
3. Query accurate sleep with `VPDataBaseOperation.veepooSDKGetAccurateSleepData(...)`.

The same documentation warns that SDK data operations are not concurrent. `WatchProbe` now honors that by running the base daily sync before any direct fallback read. If the base daily sync succeeds, direct daily reads are skipped for that sync and the JSON is created from the SDK database snapshot.

Clean vendor-demo test:

1. Force-close `WatchProbe`, H Band, and any Veepoo/HBand demo app.
2. Open `/Users/vivekmatta/Desktop/iOS_Ble_SDK/iOS_sdk_source/Demo/VeepooBleSDKDemo/VeepooBleSDKDemo.xcworkspace` in Xcode.
3. Use the `.xcworkspace`, not the `.xcodeproj`, because the demo includes CocoaPods.
4. Select scheme `VeepooBleSDKDemo` and a physical iPhone.
5. In `Signing & Capabilities`, set the team to the local Apple developer team and change the bundle id if Xcode requires it, for example `com.vivekmatta.VeepooBleSDKDemoTest`.
6. Run the demo, scan/connect to `ES02`, wait for password verification, let the demo run its automatic daily read, then check the sleep screen/function.

If the vendor demo crashes with `VPAccurateSleepModel parseA3HeaderWithData:andModel:dayNumber:`, that is strong evidence of a vendor SDK accurate-sleep parser bug for this watch payload. If the vendor demo succeeds, `WatchProbe` should continue to match the fresh-start SDK DB sync flow.

## Sleep And Dashboard Checks

Use this for overnight sleep checks:

1. Wear `ES02 / 1B:89:F9:42:CF:54` overnight.
2. Keep H Band and the vendor demo disconnected from the same watch.
3. Open `WatchProbe` on the physical iPhone.
4. Wait for auto-connect and base daily sync completion.
5. Export/open the latest sync JSON.
6. Check sleep records in the exported `days` payload.
7. Tap the Sleep card in the dashboard and verify the detail page shows latest sleep data plus any saved history.

Expected behavior: if the SDK base daily sync succeeds, sleep should populate through the SDK database and appear in the JSON and dashboard. If a later read stalls, the app should still save a partial sync with timeout diagnostics.

If no sleep data appears, next checks are:

- confirm the watch recorded sleep on-device
- confirm the watch stayed worn long enough overnight
- confirm auto-sync ran after password verification
- inspect debug log lines for base daily sync progress
- retest with only one watch data path enabled if the SDK appears busy

## Sync Timing

The phone app starts sync after verified connect, on foreground when auto-sync is enabled, and on manual sync. While open/connected, the app-side timer schedules another sync every 10 minutes.

The watch can keep measuring/storing supported data while disconnected, but this app does not yet explicitly configure the watch's automatic measurement interval. SDK docs describe automatic measurement switches for HR, BP, HRV, temperature, glucose, and oxygen; adding a startup audit for those switches is the next step.

## Xcode Device Selection

If Xcode does not show a clickable iPhone simulator, that is not blocking for this task. The probe should run on a real iPhone.

For a physical iPhone:

- connect the phone by USB
- unlock the phone
- tap Trust This Computer if prompted
- in Xcode, open the run destination menu and select the phone under iOS Device
- set the signing team in the `WatchProbe` target if Xcode asks

If no simulators appear even in a fresh template project, CoreSimulator is broken or not fully initialized on the Mac. That affects simulator testing only; it does not change the need for a physical iPhone for watch Bluetooth.

## Source SDK Location

Local manufacturer SDK source:

`/Users/vivekmatta/Desktop/iOS_Ble_SDK`

The copied API document in this repo is:

`docs/veepoo-sdk-ios-api.md`
