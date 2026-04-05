# Project Instructions for Claude

## Git Workflow

After meaningful changes:
1. Update `CLAUDE.md`
2. Stage the changed files
3. Commit with a descriptive message
4. Push to `origin main`

This repo has already been migrated away from Xcode/SwiftUI. The current codebase is React Native + Expo only.

## Security

Never commit secrets.

Ignored secret paths and patterns must include:
- `secrets/`
- `.env`
- `google-api-key.json`
- credential JSON files

Current secret handling:
- Google service account is stored locally at `secrets/google-service-account.json`
- The mobile client never reads that file directly
- The local Node proxy reads it server-side and calls Vertex AI

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
- scan the QR from Expo

## Project Overview

This project is now an iPhone-first Expo React Native prototype for AI Coach.

Main goals:
- clean white-base mobile UI
- action-first health coaching
- Gemini-backed coach chat and plan generation
- retrieval-backed answers using a local vector database

## Current Stack

- React Native
- Expo SDK 54
- TypeScript
- AsyncStorage
- Node local proxy for Vertex AI
- Vertex AI Gemini for generation
- Vertex AI embeddings for retrieval

## Repo Structure

```text
App.tsx
app.json
package.json
src/
  MobileApp.tsx
  components.tsx
  data.ts
  storage.ts
  theme.ts
  types.ts
  services/
    coachApi.ts
server/
  vertex-proxy.mjs
  vertex-client.mjs
  vector-store.mjs
  build-vector-db.mjs
```

## Mobile App Behavior

### Tabs
- `Today`
- `Activity`
- `Plan`
- `Coach`
- `Signals`

### UI direction
- white/light visual base
- calm green/blue/coral accents
- card-based layout
- minimal dashboard clutter
- concise copy

### Coach tab
- uses Gemini through the local proxy
- retrieval is enabled
- bottom tab bar hides while keyboard is open
- keyboard avoidance is implemented so text input remains visible while typing

## AI Integration

### Client side
`src/services/coachApi.ts`

Behavior:
- infers the local proxy base URL from Expo dev host when possible
- sends `/coach/chat` and `/coach/plan` requests to the local Node backend
- falls back to local canned responses if no backend is reachable

### Server side
`server/vertex-proxy.mjs`

Endpoints:
- `GET /health`
- `POST /coach/chat`
- `POST /coach/plan`

The proxy:
- loads Google credentials from `secrets/google-service-account.json`
- gets a server-side Google access token
- calls Vertex AI Gemini
- injects retrieved vector-database context into prompts

## Vector Database

### What it is
The vector database is the searchable knowledge base used to ground AI answers.

It stores:
- chunked source text
- source metadata
- embedding vectors
- token counts

### Current active corpus
The current vector DB is built from:

`/Users/vivekmatta/Desktop/Northwestern_University/Winter 2026/Research with Zaretsky/chatbot/chatbot/data`

That includes:
- `health_log.txt`
- `meal_log.txt`
- `user_profile.txt`
- `workout_log.txt`

### Current build behavior
Implemented in:
- `server/build-vector-db.mjs`
- `server/vector-store.mjs`

Behavior:
- ingests a file or directory
- for the current app, directory ingestion is used
- parses `.txt` and `.pdf`
- chunks text in a style similar to the reference chatbot app
- uses Vertex embeddings (`gemini-embedding-001`)
- stores the built DB at:

`data/vector-db/coach-data-vectors.json`

### Retrieval behavior
At query time:
1. embed the user’s query
2. compare it to stored chunk embeddings
3. retrieve the top relevant chunks
4. include those chunks in the Gemini prompt

This is used for both:
- chat responses
- plan generation

## Reference Implementation Used

The vector DB design was aligned to the reference project at:

`/Users/vivekmatta/Desktop/Northwestern_University/Winter 2026/Research with Zaretsky/chatbot`

What was mirrored conceptually:
- corpus comes from the `chatbot/data` folder, not an arbitrary PDF
- chunking is file/document based
- retrieval is used to provide evidence to the coach

What is different here:
- the reference app uses Python + LangChain + FAISS + `sentence-transformers/all-MiniLM-L6-v2`
- this app uses Node + Vertex embeddings + JSON-backed vector storage

Reason:
- easier fit with the Expo/Node stack already running in this repo
- no Python/LangChain dependency required for the mobile app flow

## Commands

Run local proxy:
```bash
npm run server
```

Run Expo:
```bash
npm start
```

Rebuild vector DB from the reference data folder:
```bash
npm run build:vectordb -- "/Users/vivekmatta/Desktop/Northwestern_University/Winter 2026/Research with Zaretsky/chatbot/chatbot/data"
```

## Important Notes

- The vector DB is for retrieval context, not raw live watch telemetry storage.
- If live wearable data is added later, current biometrics should go into structured storage first.
- The vector DB should hold searchable summaries, logs, historical context, and long-form evidence.
