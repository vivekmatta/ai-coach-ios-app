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

## What Changed On May 18, 2026

- Replaced the first-connection-only app with a SwiftUI-style dashboard hosted in the native UIKit app.
- Added preferred-watch persistence and app-open auto-connect.
- Added local JSON snapshots through `WatchResearchStore`.
- Added safe direct watch reads for steps, sleep, basic data, supported temperature, sports records, and manual measurements.
- Disabled the vendor SDK bulk daily read on ES02 because it crashed inside HRV parsing with `-[NSTaggedPointerString hour]: unrecognized selector`.
- Kept HRV direct reads disabled because the SDK marks that path unavailable and this watch already exposed an HRV parser crash.

## Sleep Test Plan

Use this for the May 19, 2026 morning test:

1. Wear `ES02 / 1B:89:F9:42:CF:54` overnight.
2. Keep H Band and the vendor demo disconnected from the same watch.
3. Open `WatchProbe` on the physical iPhone.
4. Wait for auto-connect and `Watch storage read complete`.
5. Export/open the latest sync JSON.
6. Check `days[].directWatchReads.sleep.records` for day `1`.

Expected behavior: sleep records should appear under day `1`, because the SDK header says sleep day `0` is not the display target and sleep reads should use day `1...saveDays`.

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
