# Project Instructions for Claude

## Git: Auto-commit and Push

After every meaningful change (new feature, bug fix, refactor, or any file edit), automatically:
1. Update `CLAUDE.md` to reflect any new features, removed features, or changed behavior
2. Stage the relevant changed files **including `CLAUDE.md`**
3. Commit with a descriptive message
4. Push to `origin main`

Do this without waiting to be asked. Do NOT let work accumulate without committing. The goal is to never lose progress.

```bash
git add CLAUDE.md <changed files>
git commit -m "descriptive message"
git push origin main
```

**CLAUDE.md must stay in sync with the codebase.** Before committing, review what changed and update the relevant sections — feature descriptions, known limitations, etc. Never let CLAUDE.md describe features that no longer exist or omit features that do.

## Security: Never Expose Secrets

The following files and patterns must ALWAYS be in `.gitignore` and must NEVER be committed or pushed:

- `google-api-key.json` (Google / Vertex AI credentials)
- Any `*.json` credential or key files
- Any file containing API keys, tokens, or passwords
- `.env` files
- `*.xcuserstate` (Xcode user state)
- `DerivedData/`

Before every commit, verify these files are not staged:
```bash
git status  # confirm no secret files appear
```

The `.gitignore` must always contain at minimum:
```
*.json
.env
DerivedData/
*.xcuserstate
xcuserdata/
.build/
```

Never remove or loosen these gitignore rules.

---

## How to Run the App

Open `ai_coach.xcodeproj` in Xcode, select a simulator or device, and press **Run (⌘R)**.

The app requires a valid Gemini/Vertex AI API key configured in `GeminiService.swift`.

---

## Project Overview

This is the **iOS app version** of the AI Health Coach — the mobile counterpart to the web app in `Research with Zaretsky/chatbot/`. Both apps share the same product concept, data model, and AI backend (Gemini via Vertex AI), but this version is a native SwiftUI app targeting iPhone.

The demo user is "Alex Rivera" (triathlete, age 26) but all AI interactions are personalized to whoever completes onboarding.

### Tech Stack
- **Language:** Swift / SwiftUI
- **Architecture:** MVVM (ViewModels + Views + Models + Services)
- **AI Model:** Google Gemini (`GeminiService.swift`) — same model as web app; API key configured via Xcode env var `GEMINI_API_KEY` only (no in-app key entry)
- **RAG:** `VectorDBService.swift` — local vector similarity search over health/workout/meal data
- **Persistence:** `PersistenceService.swift` — stores user profile and onboarding state locally
- **Markdown:** `MarkdownRenderer.swift` — renders AI responses with bold/italic/headers
- **Color palette:** teal/sage theme — `#476A6F` bg, `#519E8A` accent, `#7EB09B` mint, `#C5C9A4` sage, `#ECBEB4` blush

### File Structure
```
ai_coach/
  CLAUDE.md                          ← this file
  ai_coach.xcodeproj/
  ai_coach/
    ai_coachApp.swift                ← App entry point
    Models/
      AppConstants.swift             ← Shared constants, hardcoded biometrics
      ChatMessage.swift              ← Chat message model
      HealthLogEntry.swift           ← Daily health log entry
      HealthMetric.swift             ← Metric model (HRV, sleep, etc.)
      UserProfile.swift              ← Onboarding user profile model
      WellnessBreakdown.swift        ← Wellness score breakdown model
      WorkoutEntry.swift             ← Workout session model
    Services/
      GeminiService.swift            ← Vertex AI / Gemini API calls
      MarkdownRenderer.swift         ← AI response markdown rendering
      PersistenceService.swift       ← Local storage for profile/onboarding
      VectorDBService.swift          ← Local RAG / vector similarity search
    ViewModels/
      OnboardingViewModel.swift      ← Onboarding flow logic
      HomeViewModel.swift            ← Home tab state (metrics, wellness score)
      ChatViewModel.swift            ← Chat history and AI query logic
      ActivityViewModel.swift        ← Workout/health log state
      PlanViewModel.swift            ← Plan generation logic
    Views/
      MainTabView.swift              ← Root tab bar (Home / Activity / Plan)
      Onboarding/
        OnboardingView.swift         ← 8-question onboarding overlay
      Home/
        HomeView.swift               ← Main dashboard
        WellnessGaugeView.swift      ← Animated wellness score ring
        MetricCardView.swift         ← Individual metric card
        SparklineView.swift          ← Sparkline chart for metric cards
        GlucoseInsightView.swift     ← Glucose risk estimate card
        MetricDetail/
          MetricDetailSheetView.swift ← Sheet container for metric drilldown
          HRVDetailView.swift
          SleepDetailView.swift
          RHRDetailView.swift
          StepsDetailView.swift
          StressDetailView.swift
          TrendChartView.swift
      Activity/
        ActivityView.swift           ← Activity tab root
        WorkoutTableView.swift       ← Workout session list
        WorkoutRowView.swift         ← Individual workout row (expandable)
        WorkoutEditView.swift        ← Inline workout editor
        FrequencyChartView.swift     ← 14-day dot calendar
        HealthLogView.swift          ← Collapsible daily health log table
      Plan/
        PlanView.swift               ← Personalized plan generator
      Chat/                          ← Chat panel (used within HomeView)
    Theme/
      AppTheme.swift                 ← Colors, fonts, spacing constants
  ai_coachTests/
  ai_coachUITests/
```

---

## AI / Gemini Integration (`GeminiService.swift`)

- Calls the same Gemini model as the web app (Vertex AI)
- Used by `ChatViewModel` for the chat panel and by `PlanViewModel` for plan generation
- Accepts a messages array + optional `userProfile` dict injected into the system prompt
- System prompt rules mirror the web app:
  - Casual greetings → 1–2 sentence warm reply, no health analysis
  - Health/training/nutrition/recovery questions → full detailed analysis

---

## RAG (`VectorDBService.swift`)

- Local vector similarity search over health, workout, and meal data
- Used to ground AI responses with relevant context from the user's logs
- Mirrors the FAISS RAG in the web app's `chatbot.py`

---

## Onboarding Flow (`OnboardingView.swift` / `OnboardingViewModel.swift`)

**Trigger:** `PersistenceService` — if onboarding not complete, full-screen overlay shown at launch.

**8 Questions (same as web app):**
1. Name
2. Age
3. Height (e.g., 5'10" or 178 cm)
4. Weight (e.g., 165 lbs or 75 kg)
5. Sport or fitness activity
6. Primary training goal
7. Specific milestone (lose weight, sleep better, run a 5K, etc.)
8. Health concerns or injuries

After all answers, AI generates a personalized welcome message. Profile stored via `PersistenceService` and used in all subsequent AI calls.

**To reset onboarding** (for testing): Delete app data or call `PersistenceService.clearAll()`.

---

## Home Tab (`HomeView.swift`)

### Wellness Score Gauge (`WellnessGaugeView.swift`)
- Animated ring showing **62/100** (weighted from biometrics)
- Color: green >75, amber 50–75, red <50 — currently amber
- Tap → breakdown sheet with each metric's weighted contribution:
  - HRV: 73% (weight 0.25)
  - Sleep: 61% (weight 0.25)
  - Recovery: 44% (weight 0.25)
  - Resting HR: 90% (weight 0.15)
  - Steps: 32% (weight 0.05)
  - Stress: 25% (weight 0.05)

### 7 Metric Cards (`MetricCardView.swift`)
Cards: HRV | Sleep Score | Recovery Score | Resting HR | Steps | Stress Level | Body Temperature

Each card: metric name (14pt semibold), full insight text (no line limit), status badge, sparkline, baseline. Tap → `MetricDetailSheetView` (bottom sheet).

Cards are displayed in a **single-column** full-width grid (changed from 2-column). The press animation uses `CardPressStyle` (a `ButtonStyle`) instead of `DragGesture` so that scroll gestures are not intercepted.

**Detail sheet contents per metric (mirrors web app drawers):**

| Metric | Enhanced Panel |
|---|---|
| HRV | Autonomic balance bar (sympathetic 65% vs parasympathetic 35%), 7-day table, contributing factors |
| Sleep | Stages donut (Deep 18%, REM 22%, Light 45%, Awake 15%), bedtime/wake times, streak |
| Recovery | Contribution bars: HRV 38%, Sleep 45%, Stress 30%, RHR 72% |
| Resting HR | Dual-line chart vs 52 bpm baseline |
| Steps | Hourly distribution bars, active minutes, weekly avg |
| Stress | Day timeline (Morning High → Night —), contributing factors |
| Body Temperature | Qualitative "Normal" — future wearable sensor |

All sheets: trend chart, "What This Means", "Ask Coach About This" button (pre-fills chat).

### Glucose Insight Card (`GlucoseInsightView.swift`)
- Biometric-based qualitative glucose risk estimate ("Elevated Risk")
- 3 signal rows: Sleep / Stress / HRV with one-phrase notes
- "Ask Coach" button — pre-fills chat with glucose query
- Disclaimer: no sensor required, qualitative only

### Chat Panel
- Embedded in Home tab
- Rolling history (last 10 messages) + `userProfile` sent to Gemini on each query
- Typing indicator, quick prompt buttons, markdown rendering via `MarkdownRenderer`

---

## Activity Tab (`ActivityView.swift`)

**Summary strip:** Total Workouts (9) | Total Distance (55.1 mi) | Total Active Time (7h 55m)

**Frequency Chart (`FrequencyChartView.swift`):** 14-day dot calendar (Feb 27 – Mar 12). Dot colors: run=blue, swim=teal, brick=orange, yoga=green, rest=empty.

**Workout Table (`WorkoutTableView.swift`):** 9 entries from `AppConstants` (matching `workout_log.txt`):
- Tap row → expands with full notes
- Edit → inline form, Save updates local array
- Delete → confirm, removes from array (in-memory only, no server sync)

**Health Log (`HealthLogView.swift`):** Collapsible, 14 entries. Tap row → daily notes.

---

## Plan Tab (`PlanView.swift`)

**Quick-start chips** (4 preset prompts):
- "Full recovery & training plan"
- "Fix my sleep"
- "This week's training schedule"
- "Marathon in 4 weeks — full plan"

**Generate Plan flow:**
1. User types request (or picks chip)
2. `PlanViewModel` reads stored `userProfile` + full biometric context
3. Constructs prompt with real name, sport, goal, milestone, concerns + biometrics
4. Calls `GeminiService` via `/coach-query` equivalent
5. Response rendered with markdown in plan display area
6. Buttons: Regenerate | Refine in Chat (switches to Home tab, pre-fills chat)

---

## Hardcoded Demo Biometrics (in `AppConstants.swift`)

These mirror the web app's hardcoded values (March 12, 2026):
- HRV: 38ms (baseline 52ms) — Low
- Sleep Score: 61/100 (baseline 80/100) — Below Average
- Recovery Score: 44/100 (baseline 75/100) — Needs Rest
- Resting HR: 58 bpm (baseline 52 bpm) — Elevated
- Steps: 3,200 (goal 10,000) — Low
- Stress: High
- SpO2: 97%

---

## Known Limitations / Future Work

- Biometric values are **hardcoded** — replace `AppConstants` metrics with live HealthKit or wearable sensor reads when hardware arrives
- Workout edits/deletions are **in-memory only** — page re-launch resets to original data; `PersistenceService` should be extended to persist workout edits
- Glucose risk is **deterministic from hardcoded biometrics** — will become dynamic with real sensor data
- Body Temperature is qualitative "Normal" — future wearable sensor will provide continuous values
- No backend sync — this app is fully local/on-device; the web app's Flask server is not called
