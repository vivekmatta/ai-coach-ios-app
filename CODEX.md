# Project Instructions for Codex

## Current Direction

This repo is an iPhone-first Expo React Native prototype for an AI health coach built around a screenless wearable companion.

The current implementation is **mock-sync first**:
- no live BLE device integration yet
- no native iOS bridge yet
- no vendor cloud API dependency
- structured wearable data comes from mock post-sync payloads that mirror the expected phone-side SDK flow

Target architecture:

`watch -> phone app via vendor SDK -> normalized app/backend data -> dashboard + coaching`

The manufacturer confirmed:
- the bracelet syncs over Bluetooth to the phone
- data is stored on-device for about 7 days
- the SDK is provided for iOS and Android
- the manufacturer does not collect the data for us

## Git Workflow

After meaningful changes:
1. Update `CODEX.md` if the architecture, run flow, or major constraints changed.
2. Stage the changed files.
3. Commit with a descriptive message.
4. Push only when explicitly requested.

## Security

Never commit secrets.

Ignored secret paths and patterns must include:
- `secrets/`
- `.env`
- `google-api-key.json`
- credential JSON files

Current secret handling:
- Health dashboard and mock sync endpoints do not require secrets.
- Vertex-backed chat and retrieval still use `secrets/google-service-account.json` when configured.
- The mobile client never reads credential files directly.

## How To Run

From the repo root:

```bash
npm install
npm run server
npm start
```

Phone testing:
- keep the Mac and iPhone on the same Wi-Fi
- open Expo Go
- scan the QR code from Expo

## What Exists Now

### Structured mock health data

The backend now supports:
- importing a named mock sync scenario
- storing normalized daily wearable records
- returning the latest synced day
- returning a 7-day timeline
- generating deterministic daily coaching briefs

Main endpoints:
- `GET /health-data/latest`
- `GET /health-data/timeline`
- `POST /health-data/import-mock`
- `POST /coach/daily-brief`

### Mock scenarios

Three fixture scenarios are bundled server-side:
- `recovery-reset`
- `late-fuel-drift`
- `steady-rebuild`

They represent post-sync bracelet data for:
- poor sleep + high stress
- decent sleep + late-meal routine drift
- improving recovery + stable routine

### Coach chat

Chat remains available through:
- `POST /coach/chat`
- `POST /coach/plan`

If Vertex AI is configured, chat uses:
- current structured health context
- optional retrieval context from the vector DB

If the backend is unreachable, the mobile client still falls back to local canned responses.

## Repo Structure

```text
App.tsx
package.json
src/
  MobileApp.tsx
  components.tsx
  data.ts
  storage.ts
  theme.ts
  types.ts
  services/
    apiBase.ts
    coachApi.ts
    healthApi.ts
server/
  coach-engine.mjs
  health-data-store.mjs
  mock-health-fixtures.mjs
  vertex-proxy.mjs
  vertex-client.mjs
  vector-store.mjs
  build-vector-db.mjs
```

## Product Rules

- Structured wearable data is the source of truth for biometrics.
- The vector DB is optional research context, not the primary biometric store.
- Glucose and nitric oxide are proxy outputs only.
- Do not present glucose or nitric oxide as measured values.
- Do not diagnose disease.
- Keep UI action-first and explanation-first.
- Prefer 1-2 sentence insights over metric-heavy dashboards.

## Next Phase

When the actual device and SDK package arrive, the next implementation step should preserve the current normalized payload shape and replace mock imports with real phone-side SDK sync output.

### Local SDK reference

Current local iOS SDK path:

`/Users/vivekmatta/Desktop/iOS_Ble_SDK`

Primary SDK API reference used for planning:

`/Users/vivekmatta/Desktop/iOS_Ble_SDK/iOS_sdk_source/doc/VeepooSDK iOS Api.md`

### Concrete SDK integration steps

When real device integration starts, build around this flow:

1. Initialize `VPBleCentralManage.sharedBleManager()` before using Bluetooth.
2. Use the SDK persistence path:
   `VPBleCentralManage.sharedBleManager().peripheralManage = VPPeripheralManage.shareVPPeripheralManager()`
3. Scan and connect on iPhone through the Veepoo SDK.
4. Sync personal information to the device after connect when needed.
5. Trigger full daily sync with:
   `veepooSdkStartReadDeviceAllData...`
6. Read synced records out of the SDK database with `VPDataBaseOperation`.
7. Normalize Veepoo SDK records into the app’s canonical payload shape.
8. Send that normalized payload into the current dashboard/coaching backend instead of mock fixtures.

### Important SDK constraints

- Prefer SDK DB persistence over app-managed persistence for the first real integration.
- The SDK does not support concurrent data operations.
- Daily sync is the main ingestion path for most health metrics.
- Multiple apps connected to the same device can cause read-loop issues; avoid running the Veepoo demo and the production app against the same device at the same time.

### High-priority real data mappings

The first real adapter should map these SDK-backed datasets into the app model:

- sleep
- HRV
- heart rate raw / half-hour averages
- step data
- blood oxygen
- temperature
- blood pressure
- sport history
- stress
- manual measurement history where supported

### Feature gating notes

Treat these as device-dependent or project-dependent rather than guaranteed:

- glucose and glucose risk level
- ECG
- GSR
- Health Glance / micro-test
- body composition
- blood composition
- AI features
- 4G features

### Recommended implementation shape

- Keep raw Veepoo-shaped data available for research/debugging.
- Keep normalized coach-facing data as the source of truth for the app UI.
- Add a thin iOS adapter layer that converts SDK DB objects into the existing canonical sync payload already used by the mock importer.
