# AI Coach Watch Workspace

Native iOS research prototype for a Veepoo/ES02 smartwatch. The app connects to the watch through the bundled manufacturer iOS SDK, syncs locally stored health data, saves research JSON snapshots on the phone, and presents a coach-first iOS interface with AI-generated explanations and suggested actions.

The active app is `watch-probe-ios/WatchProbe.xcodeproj`. The Node script in `server/coach-ai-proxy.mjs` is the local AI proxy used during development and must be running when you want AI responses in the app.

## Repository Layout

- `watch-probe-ios/` - native iOS app, Xcode project, Swift/SwiftUI source, bundled vendor frameworks, and app assets.
- `server/coach-ai-proxy.mjs` - local HTTP proxy that calls Gemini or Vertex AI and returns structured coach analysis.
- `docs/veepoo-sdk-ios-api.md` - copied vendor SDK API reference with local integration notes.
- `docs/watch-first-connection.md` - hardware connection notes, verified watch behavior, and debugging checklist.
- `CODEX.md` - working notes for future coding agents or maintainers.

## Prerequisites

- macOS with Xcode installed.
- Node.js for the local proxy. Node 18 or newer is a safe default.
- For full watch testing: a physical iPhone, a Veepoo/ES02 watch, and an Apple developer team that can sign an iOS app. An Apple Developer Program account is the cleanest path for professor/lab handoff and repeated device installs.
- A Gemini API key or Vertex AI service-account JSON for the proxy. Credentials are not included in this repo.

The iOS target is set to iOS 15.0 and links device-only watch SDK frameworks. The physical iPhone path is the real research path because the simulator cannot connect to the watch over Bluetooth.

## Clone The Repo

```bash
git clone <repo-url>
cd ai_coach
```

After cloning, open the Xcode project once so Xcode can resolve Swift Package dependencies such as Firebase and Google Sign-In:

```bash
open watch-probe-ios/WatchProbe.xcodeproj
```

If Xcode asks to trust the package dependencies or resolve packages, allow it. Do not add credential files to Git while doing setup.

## Start The Local AI Proxy

Run the proxy from the repo root before using the app's AI coach features.

Gemini API-key mode:

```bash
GEMINI_API_KEY="<your-gemini-api-key>" node server/coach-ai-proxy.mjs
```

Vertex AI service-account mode:

```bash
GOOGLE_APPLICATION_CREDENTIALS="/absolute/path/to/service-account.json" node server/coach-ai-proxy.mjs
```

The proxy listens on `http://0.0.0.0:8790` by default and exposes:

- `GET /health`
- `POST /analyze`

Optional environment variables:

- `COACH_PROXY_PORT` - defaults to `8790`.
- `COACH_PROXY_HOST` - defaults to `0.0.0.0`.
- `GEMINI_MODEL` or `VERTEXAI_MODEL` - defaults to `gemini-2.5-flash`.
- `VERTEXAI_PROJECT` and `VERTEXAI_LOCATION` - useful when using Vertex AI credentials.

Keep the proxy terminal open while the app is running. If the proxy is not reachable, the app can still show local watch data, but AI-backed coach messages and suggested actions will fall back or fail.

## Run On A Physical iPhone

Use this path for real watch sync, Bluetooth testing, and research data collection.

1. Start the local proxy on the Mac.
2. Find the Mac's LAN IP address, for example with `ipconfig getifaddr en0`.
3. Connect the iPhone by USB, unlock it, and trust the Mac if iOS asks.
4. Open `watch-probe-ios/WatchProbe.xcodeproj` in Xcode.
5. Select the `WatchProbe` scheme.
6. Select the physical iPhone as the run destination.
7. In `Signing & Capabilities`, choose your Apple developer team.
8. If Xcode says the bundle identifier is unavailable, change `PRODUCT_BUNDLE_IDENTIFIER` to a unique reverse-DNS value for your team, such as `edu.yourlab.watchprobe`.
9. Build and run from Xcode.
10. On the iPhone, allow Bluetooth, Local Network, and notification permissions when prompted.
11. In the app, open `Profile -> App Settings -> Local AI proxy` and enter the Mac LAN URL, for example `http://192.168.1.25:8790`.
12. Scan for the watch, connect, wait for password verification, then let auto-sync finish or tap sync manually.

Do not enter `localhost` or `127.0.0.1` in the iPhone app. On a physical iPhone, those addresses point to the phone, not the Mac. Use the Mac's LAN IP address and make sure the Mac and iPhone are on the same network. If iOS blocks the request, enable `Settings -> Privacy & Security -> Local Network -> WatchProbe`; if WatchProbe is missing there, delete the app and reinstall from Xcode so iOS shows the permission prompt again.

The verified test watch during development was `ES02 / 1B:89:F9:42:CF:54`.

## Simulator Option

The simulator is useful only for limited UI work. It cannot connect to the physical watch over Bluetooth, and this project currently links vendor frameworks built for `iphoneos`, not `iphonesimulator`.

If a future maintainer needs full simulator support, they should add a simulator-safe build target that compiles out or stubs the Veepoo SDK calls. For that UI-only target, the local proxy URL can be `http://127.0.0.1:8790` because the simulator runs on the Mac. For current research testing, use a physical iPhone.

## What The App Does

- Scans for Veepoo peripherals through `VPBleCentralManage`.
- Connects to the selected watch and waits for SDK password verification.
- Stores the preferred watch and auto-connects on later app opens.
- Runs the SDK base daily sync first, then builds local JSON snapshots from the SDK database.
- Uses direct watch reads only as fallback if SDK base daily sync does not complete.
- Saves sync files inside the app sandbox at `Library/Application Support/WatchResearchData/<device>/<date>/sync-*.json`.
- Shows a coach-first four-tab interface: Coach, Plan, Progress, and Profile.
- Sends compact watch summaries to Firebase AI Logic when configured, otherwise to the local proxy.
- Caches AI analyses by a SHA-256 hash of the health context and selected coach personality.
- Exports the latest sync snapshot through the iOS share sheet.

The app-side auto-sync timer runs every 10 minutes while the phone app is open and connected. That is separate from watch-side automatic measurement settings, which are not fully audited or configured yet.

## Build Check

This command checks that the device build compiles without requiring signing:

```bash
xcodebuild \
  -project watch-probe-ios/WatchProbe.xcodeproj \
  -scheme WatchProbe \
  -configuration Debug \
  -sdk iphoneos \
  -derivedDataPath /private/tmp/WatchProbeDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Secrets And Git Hygiene

Do not commit secrets, credentials, exported research data, local databases, provisioning profiles, or personal signing settings.

Keep these local only:

- `.env`, `.env.*`
- `secrets/`
- service-account JSON files
- `GoogleService-Info.plist`
- Gemini or Google API keys
- `COACH_PROXY_TOKEN`
- Apple `.p8`, `.pem`, `.key`, `.mobileprovision`, and certificate files
- exported `sync-*.json` files and local SQLite databases

Before pushing or sharing the repo, run:

```bash
git status --ignored --short
git ls-files secrets .env .env.local watch-probe-ios/WatchProbe/GoogleService-Info.plist
rg -n "AIza[0-9A-Za-z_-]{20,}|-----BEGIN (RSA |EC |OPENSSH |PRIVATE )?PRIVATE KEY-----|\"private_key\"\\s*:|client_secret\\s*[:=]" .
rg -n "GEMINI_API_KEY\\s*=\\s*['\"]?[A-Za-z0-9_-]{10,}|GOOGLE_API_KEY\\s*=\\s*['\"]?[A-Za-z0-9_-]{10,}|COACH_PROXY_TOKEN\\s*=\\s*['\"]?[A-Za-z0-9_-]{10,}" .
```

Expected result: credential paths should be ignored or absent from `git ls-files`, and the searches should return no real credential values. Never paste credential contents into README files, issues, commits, or debug logs.

The Google OAuth client ID currently in `Info.plist` is not a private secret, but future maintainers should replace Google/Firebase configuration with their own project values before re-enabling calendar or Firebase-backed flows.

## Useful Docs

Read these before changing watch sync behavior:

1. `docs/veepoo-sdk-ios-api.md`
2. `docs/watch-first-connection.md`
3. `watch-probe-ios/README.md`

Important implementation rule: SDK data commands must stay serialized. Do not start multiple watch data reads at the same time, and do not use `veepooSDKClearDeviceData` in the normal sync cycle because the SDK notes that it shuts the bracelet down and has no success callback.

## Next Work

- Add an automatic measurement settings audit for HR/BP/HRV/SpO2/glucose/temperature.
- Add optional controls to enable supported watch-side automatic measurement intervals.
- Add per-data-type sync watermarks after returned payload shapes are stable.
- Add a simulator-safe UI target only if future UI iteration requires simulator support.
