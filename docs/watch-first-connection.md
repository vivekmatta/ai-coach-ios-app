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
- battery read: `100%`
- charge state: `0`, normal/not charging
- local sync files: saved under `Library/Application Support/WatchResearchData`
- current sync mode: safe direct watch reads, not vendor bulk daily read

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

## What Changed On May 18-19, 2026

- Replaced the first-connection-only app with a SwiftUI-style dashboard hosted in the native UIKit app.
- Added preferred-watch persistence and app-open auto-connect.
- Added local JSON snapshots through `WatchResearchStore`.
- Added safe direct watch reads for steps, sleep, basic data, supported temperature, sports records, and manual measurements.
- Prioritized day `1` sleep before heavier reads and added timeout-based partial saves.
- Sleep direct reads get a longer timeout than other small reads because accurate sleep (`sleepType` 1 or 3) can be slower or may not callback on some ES02 firmware.
- Disabled the vendor SDK bulk daily read on ES02 because it crashed inside HRV parsing with `-[NSTaggedPointerString hour]: unrecognized selector`.
- Kept HRV direct reads disabled because the SDK marks that path unavailable and this watch already exposed an HRV parser crash.
- Added a capped raw RR-interval probe for HRV investigation after the safe reads.
- Removed the manual accurate-sleep recovery action after testing showed the SDK database daily read also crashes inside `VPAccurateSleepModel parseA3HeaderWithData:andModel:dayNumber:`.

## Vendor Demo Cross-Check

The company SDK documentation confirms the recommended daily-data path is SDK persistence:

1. Use `VPPeripheralManage.shareVPPeripheralManager()`.
2. Call `veepooSdkStartReadDeviceAllData`.
3. Query accurate sleep with `VPDataBaseOperation.veepooSDKGetAccurateSleepData(...)`.

The same documentation warns that SDK data operations are not concurrent. That matters for the May 19 recovery crash because the recovery attempt started after `veepooSDK_readSleepData(withDayNumber: 1)` had already timed out. The SDK may still have considered that direct read active internally, so starting the bulk daily read immediately afterward may have violated the vendor sequencing rule.

Clean vendor-demo test:

1. Force-close `WatchProbe`, H Band, and any Veepoo/HBand demo app.
2. Open `/Users/vivekmatta/Desktop/iOS_Ble_SDK/iOS_sdk_source/Demo/VeepooBleSDKDemo/VeepooBleSDKDemo.xcworkspace` in Xcode.
3. Use the `.xcworkspace`, not the `.xcodeproj`, because the demo includes CocoaPods.
4. Select scheme `VeepooBleSDKDemo` and a physical iPhone.
5. In `Signing & Capabilities`, set the team to the local Apple developer team and change the bundle id if Xcode requires it, for example `com.vivekmatta.VeepooBleSDKDemoTest`.
6. Run the demo, scan/connect to `ES02`, wait for password verification, let the demo run its automatic daily read, then check the sleep screen/function.

If the vendor demo also crashes with `VPAccurateSleepModel parseA3HeaderWithData:andModel:dayNumber:`, that is strong evidence of a vendor SDK accurate-sleep parser bug for this watch payload. If the vendor demo succeeds, add a fresh-start SDK DB sync mode in `WatchProbe` that runs the bulk daily sync first, before any direct sleep read can time out and leave the SDK busy.

## Sleep Test Plan

Use this for the May 19, 2026 morning test:

1. Wear `ES02 / 1B:89:F9:42:CF:54` overnight.
2. Keep H Band and the vendor demo disconnected from the same watch.
3. Open `WatchProbe` on the physical iPhone.
4. Wait for auto-connect and `Watch storage read complete` or `Saving partial watch sync`.
5. Export/open the latest sync JSON.
6. Check `days[].directWatchReads.sleep.records` for day `1`.

Expected behavior with the current Veepoo SDK: the app should save a partial sync if the direct sleep callback never returns. On this ES02, the SDK database daily read is not a safe fallback because it crashes while parsing accurate sleep.
If a later read stalls, the app should still save a partial sync with `metadata.directWatchSync.timedOutReads`.

If no sleep data appears, next checks are:

- confirm the watch recorded sleep on-device
- confirm the watch stayed worn long enough overnight
- confirm auto-sync ran after password verification
- inspect debug log lines for `Direct sleep read day 1`
- retest with only the sleep direct read enabled if another direct read causes device-side busy behavior

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
