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
- exports the latest sync snapshot through the iOS share sheet

The verified watch is `ES02 / 1B:89:F9:42:CF:54`.

## Local Data Sync

The app writes sync files to the app sandbox:

`Library/Application Support/WatchResearchData/<device>/<date>/sync-*.json`

The sync payload contains SDK database fields plus a `directWatchReads` section per day. `directWatchReads` is the important path for the ES02 right now:

- `steps`
- `sleep`
- `basicData`
- `temperature` when supported
- sports records in metadata
- manual measurements in metadata

The SDK bulk daily read is intentionally disabled because this ES02 crashed in the vendor HRV parser:

`-[NSTaggedPointerString hour]: unrecognized selector`

The current implementation avoids full daily/HRV reads and uses direct watch-storage APIs serially. Do not run SDK data commands concurrently.

Do not clear the watch as part of normal sync. `veepooSDKClearDeviceData` shuts the bracelet down and has no success callback. Use local snapshots and later watermarks instead.

## Sleep Test Checklist

For the May 19, 2026 sleep test:

1. Wear the ES02 overnight.
2. Open the app in the morning and let it auto-connect.
3. Wait for `Watch storage read complete`.
4. Tap export/open latest sync.
5. Inspect `directWatchReads.sleep.records` for day `1`.

The SDK documentation says sleep should be read from day `1` or later; day `0` is skipped intentionally.

## Build Check

```bash
xcodebuild -project WatchProbe.xcodeproj -scheme WatchProbe -destination 'generic/platform=iOS' -derivedDataPath /tmp/watch-probe-derived CODE_SIGNING_ALLOWED=NO build
```

## Next Work

- Confirm sleep payload shape after the overnight test.
- Add a first sleep card/summary once real records are captured.
- Add per-type sync watermarks after direct read timestamps/CRCs are confirmed.
- If direct basic-data reads crash on hardware, disable that one reader and keep step/sleep/manual sync active.

The bundled `VeepooBleSDK.framework` was copied from:

`/Users/vivekmatta/Desktop/iOS_Ble_SDK/iOS_sdk_source/Demo/VeepooBleSDKDemo/VeepooBleSDKDemo/VeepooBleSDK.framework`
