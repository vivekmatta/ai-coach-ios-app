# AI Health Coach Mobile

This repo contains the `Expo React Native` mobile prototype for AI Coach.

## Run

```bash
npm install
npm run build:vectordb -- "/absolute/path/to/your.pdf"
npm run server
npm start
```

For local AI integration:

- Put the Google service account file at `secrets/google-service-account.json`
- Run `npm run server` to start the local Vertex AI proxy
- Run `npm start` to launch Expo
- Keep your phone and Mac on the same Wi-Fi

The mobile client does not read the credential directly. The local proxy server reads the secret and calls Vertex AI server-side.

Vector database output:

- built file: `data/vector-db/lab5-vectors.json`
- builder script: `npm run build:vectordb -- "/absolute/path/to/your.pdf"`
- retrieval is automatically used by the local AI proxy when that file exists

## Product Direction

The app is an iPhone-first research prototype for a screenless wearable companion. It focuses on:

- action-first daily coaching
- insight-first health summaries instead of raw metric overload
- proxy signals for glucose and nitric oxide
- contextual health guidance across recovery, sleep, stress, movement, and environment

## Main Files

```text
App.tsx
src/MobileApp.tsx
src/components.tsx
src/data.ts
src/storage.ts
src/theme.ts
src/types.ts
src/services/coachApi.ts
server/vertex-proxy.mjs
server/build-vector-db.mjs
server/vector-store.mjs
server/vertex-client.mjs
```

## Screens

- `Today` for the daily summary, key insights, and immediate action plan
- `Activity` for workout and health-log context
- `Plan` for weekly plan generation
- `Coach` for AI coach chat
- `Signals` for research-facing sensor and proxy-signal explanations

## Stack

- React Native
- Expo
- TypeScript
- AsyncStorage

## Design

The UI uses a light, white-first visual system with warm neutrals and calm accent colors. The goal is a clean, modern, user-friendly mobile experience that feels more like a thoughtful coach than a dense analytics dashboard.
