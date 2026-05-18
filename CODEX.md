# Workspace Notes

Current priority: native iOS Veepoo/ES02 watch data sync.

Always read these before making changes:

1. `docs/veepoo-sdk-ios-api.md`
2. `docs/watch-first-connection.md`
3. `watch-probe-ios/README.md`

Preserve `secrets/google-service-account.json`. Do not print its contents.

The previous Expo app, research dashboard, Node server, mock fixtures, and bundled assets were intentionally removed. The active app is `watch-probe-ios/WatchProbe.xcodeproj`.

## Current State

- Physical watch connection is verified for `ES02 / 1B:89:F9:42:CF:54`.
- The app stores the preferred watch and auto-connects when opened.
- The SwiftUI dashboard shows connection state, battery, steps, manual tests, sync/export controls, and profile controls.
- Local sync snapshots are saved under `Library/Application Support/WatchResearchData`.
- The ES02 crashes inside the vendor SDK when using the bulk daily read path. Keep `veepooSdkStartReadDeviceAllDataWithReadStateChangeBlock` disabled unless the SDK/firmware is changed.
- The implemented sync path uses serial direct reads: steps, sleep, basic data, temperature when supported, sports records, and manual measurements.
- HRV direct reads are skipped because the SDK marks them unavailable and the bulk HRV parser crashed on this device.
- Do not use `veepooSDKClearDeviceData` in the normal cycle. It shuts the bracelet down and has no success callback.

## Verification

Use this build check:

```bash
xcodebuild -project watch-probe-ios/WatchProbe.xcodeproj -scheme WatchProbe -destination 'generic/platform=iOS' -derivedDataPath /tmp/watch-probe-derived CODE_SIGNING_ALLOWED=NO build
```

## Next Work

- On May 19, 2026, test overnight sleep by opening the app after wearing the watch.
- Confirm `directWatchReads.sleep.records` appears for day `1` in the exported JSON.
- Add a sleep summary view after confirming the returned payload structure.
- Add per-data-type watermarks/checkpoints after the direct read payloads are stable.
