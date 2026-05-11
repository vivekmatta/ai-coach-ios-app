# AI Health Coach Mobile

This repo contains the `Expo React Native` mobile prototype for AI Coach.

## Run

```bash
npm install
npm run server
npm start
```

The current health dashboard flow does not require live device hardware or Google credentials.

Current local flow:
- run the local Node server
- open the Expo app
- switch between built-in mock sync scenarios from the `Today` screen
- inspect the daily brief and 7-day trend surfaces

Optional AI chat integration:
- put the Google service account file at `secrets/google-service-account.json`
- run `npm run server`
- retrieval-backed chat and plan endpoints will use Vertex AI when configured

The mobile client does not read credentials directly. The local proxy server reads the secret server-side.

## Product Direction

The app is an iPhone-first research prototype for a screenless wearable companion. It focuses on:

- action-first daily coaching
- insight-first health summaries instead of raw metric overload
- proxy signals for glucose and nitric oxide
- contextual health guidance across recovery, sleep, stress, movement, and environment
- a mock-sync-first pipeline that mirrors the expected SDK data flow before the watch hardware arrives

## Main Files

```text
App.tsx
src/MobileApp.tsx
src/components.tsx
src/data.ts
src/storage.ts
src/theme.ts
src/types.ts
src/services/apiBase.ts
src/services/coachApi.ts
src/services/healthApi.ts
server/coach-engine.mjs
server/health-data-store.mjs
server/mock-health-fixtures.mjs
server/vertex-proxy.mjs
server/build-vector-db.mjs
server/vector-store.mjs
server/vertex-client.mjs
```

## Screens

- `Today` for the latest synced mock wearable summary, key insights, and action plan
- `Progress` for the 7-day trend view
- `You` for profile and research-facing signal explanations
- `Coach` for AI coach chat

## Stack

- React Native
- Expo
- TypeScript
- AsyncStorage
- Node local proxy for structured health data and optional Vertex chat

## Design

The UI uses a light, white-first visual system with warm neutrals and calm accent colors. The goal is a clean, modern, user-friendly mobile experience that feels more like a thoughtful coach than a dense analytics dashboard.

## Mock Sync Endpoints

The local server now exposes:

- `GET /health-data/latest`
- `GET /health-data/timeline`
- `POST /health-data/import-mock`
- `POST /coach/daily-brief`

Built-in fixtures:

- `recovery-reset`
- `late-fuel-drift`
- `steady-rebuild`

These fixtures represent normalized post-sync wearable records that will later be replaced by real SDK output from the bracelet.
