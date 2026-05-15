# AI Health Coach Mobile

This repo contains the `Expo React Native` mobile prototype for AI Coach.

## Run

```bash
npm install
npm run server
npm run start:mobile
```

Use `npm run start:mobile` for Expo on this machine. It forces Node 20 because Expo is unreliable under Node 24 here, and it publishes the Mac Wi-Fi IP to Expo Go instead of `127.0.0.1`.

If Expo Go cannot reach the Mac over campus Wi-Fi, use the tunnel script instead:

```bash
npm run start:mobile:tunnel
```

Metro is configured to ignore the standalone `research-dashboard/`, server, data, and secrets folders when bundling the mobile app.

The current health dashboard flow does not require live device hardware or Google credentials.

Current local flow:
- run the local Node server
- open the Expo app
- switch between built-in mock sync scenarios from the `Today` screen
- inspect the AI-generated daily plan, checklist, workout recommendation, nudges, and insights

Optional AI integration:
- either put the Google service account file at `secrets/google-service-account.json`
- or create `.env` from `.env.example` and set `GEMINI_API_KEY`
- run `npm run server`
- the `Coach` chat endpoint will use the configured AI provider
- the structured `Coach` plan endpoint uses the configured AI provider when available
- if AI is unavailable, the app falls back to deterministic local coaching output

The mobile client does not read credentials directly. The local proxy server reads the secret server-side.

## Research Dashboard

The standalone web dashboard lives in `research-dashboard/` and uses local mock participant data for now.

```bash
cd research-dashboard
npm install
npm run dev
```

Open the local Vite URL, usually `http://localhost:5173/`.

Production check:

```bash
npm run build
```

Dashboard tabs:
- `Overview` for cohort cards, participant selection, selected participant details, trends, and notes
- `Participants` for a focused participant list and detail workflow
- `Research Notes` for follow-up-oriented note review
- `Study Settings` for the current mock study thresholds and signal policy

The dashboard uses responsive card grids so overview cards, metrics, trends, notes, and settings wrap instead of overflowing on narrower screens.

## Product Direction

The mobile app is an iPhone-first research prototype for a screenless wearable companion. The web dashboard is a mock-data research portal for monitoring participant sync quality, trends, and follow-up flags. Together they focus on:

- action-first daily coaching
- insight-first health summaries instead of raw metric overload
- AI-generated daily plans that combine mock biometrics, profile goals, diary context, and coach personality
- coach personality modes with adjustable strength: Gentle, Direct, Hype, Nice, and Unhinged
- proxy signals for glucose and nitric oxide
- contextual health guidance across recovery, sleep, stress, movement, and environment
- a mock-sync-first pipeline that mirrors the expected SDK data flow before the watch hardware arrives
- a clean researcher view for 10-12 participant study operations

## Main Files

```text
index.js
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
server/ai-client.mjs
server/coach-engine.mjs
server/health-data-store.mjs
server/mock-health-fixtures.mjs
server/vertex-proxy.mjs
server/build-vector-db.mjs
server/vector-store.mjs
server/vertex-client.mjs
research-dashboard/
```

## Screens

Mobile:
- `Today` for the AI daily plan, total score, short insight cards, checklist, nudges, workout, diary context, and raw-number details
- `Insights` for weekly focus, trend explanations, pattern snapshot, and observed correlations
- `Workouts` for the AI-selected workout of the day, coaching cues, media prompt, and small workout library
- `Profile` for coach personality, personality strength, notification settings, connected devices, and profile context

Web dashboard:
- cohort overview
- participant search/filter list
- selected participant detail view
- 7-day trend cards
- research notes
- study settings

## Stack

- React Native
- Expo
- TypeScript
- AsyncStorage
- Node local proxy for structured health data and server-side AI chat
- Vite + React for the standalone research dashboard

## Design

The UI uses a light, white-first visual system with warm neutrals and calm accent colors. The goal is a clean, modern, user-friendly mobile experience that feels more like a thoughtful coach than a dense analytics dashboard. Raw metrics remain available, but the first screen prioritizes plain-language coaching, tasks, and the meaning of the data.

## Mock Sync Endpoints

The local server now exposes:

- `GET /health-data/latest`
- `GET /health-data/timeline`
- `POST /health-data/import-mock`
- `POST /coach/daily-brief`
- `POST /coach/plan`

`POST /coach/plan` supports a structured mode used by the mobile app. It combines mock health data, profile goals, diary entries, coach personality, and personality strength into:

- an overall score and status
- 1-2 sentence insight cards
- checkable daily tasks
- subtle in-app notification copy
- one workout recommendation with cues and a cached-media prompt
- trend and correlation explanations

Supported coach personalities:

- `gentle`
- `direct`
- `hype`
- `nice`
- `unhinged`

Personality strength is stored locally from `1` to `5`. The `unhinged` mode is opt-in adult copy and may include profanity, but all modes keep the same health-safety rules: no diagnosis, no shame, and no unsafe workout or nutrition guidance.

Built-in fixtures:

- `recovery-reset`
- `late-fuel-drift`
- `steady-rebuild`

These fixtures represent normalized post-sync wearable records that will later be replaced by real SDK output from the bracelet.
