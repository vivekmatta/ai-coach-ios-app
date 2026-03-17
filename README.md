# AI Health Coach — iOS App

A native SwiftUI iOS application that brings the [AI Health Coach web dashboard](https://github.com/vivekmatta) to mobile. Built as a personal biometric coaching experience powered by Google Gemini AI and a FAISS-backed RAG pipeline.

---

## Overview

This iOS app is the mobile counterpart to the AI Health Coach web app (built with Flask + HTML/CSS/JS). Both versions share the same backend AI logic, data files, and coaching philosophy — the iOS app delivers the same experience natively on iPhone with SwiftUI, smooth animations, and a dark-first design.

**Demo user:** Alex Rivera — age 26, triathlete training for a Half-Ironman.

---

## Web Version

The original web app lives at:
```
Research with Zaretsky/chatbot/chatbot/html/coach.html
```
It is a single-file Flask-served SPA with a Python/FAISS RAG backend and Google Vertex AI (Gemini).

The iOS app replicates all major features of the web dashboard:

| Web Feature | iOS Equivalent |
|---|---|
| 7 metric cards (home tab) | `MetricCardView` — insight text on card, score revealed on tap |
| Wellness score gauge | `WellnessGaugeView` — animated SVG-style arc |
| Metric detail drawers | `MetricDetailSheetView` + per-metric detail views |
| AI chat panel | `ChatView` + `ChatViewModel` → Gemini API |
| Activity tab (workout table + health log) | `ActivityView` |
| Personalized Plan tab | `PlanView` |
| Onboarding flow (8 questions) | `OnboardingView` |
| Glucose risk insight card | `GlucoseInsightView` |

---

## Features

### Home Dashboard
- **Wellness Score Gauge** — animated arc showing composite score (62/100), tap for weighted breakdown
- **7 Metric Cards** — each card shows a 1–2 sentence coaching insight instead of a raw number; tap to reveal the score and full analysis
  - Heart Rate Variability (HRV)
  - Sleep Score
  - Recovery Score
  - Resting Heart Rate
  - Steps Today
  - Stress Level
  - Body Temperature
- **Glucose Risk Card** — qualitative inference from biometrics (no sensor required)
- **AI Chat** — real-time conversation with the coach, context-aware from biometrics + RAG

### Activity Tab
- Workout history table with inline expand, edit, and delete
- 14-day workout frequency dot calendar
- Collapsible daily health log

### Plan Tab
- Free-form wellness plan generator
- Quick-start chips (sleep plan, stress plan, weekly training, etc.)
- Plans rendered with markdown formatting
- "Refine in Chat" — sends plan to chat for follow-up

### Onboarding
- 7-question conversational flow to capture: name, goals, exercise days/type, sleep time, caffeine, work stress
- Profile stored locally and injected into every AI prompt for personalization

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| AI Model | Google Gemini (`gemini-2.0-flash`) via REST API |
| RAG | FAISS + `sentence-transformers` (Python backend) |
| Local Storage | `UserDefaults` via `PersistenceService` |
| Minimum iOS | iOS 17+ |

---

## Project Structure

```
ai_coach/
├── ai_coach/
│   ├── ai_coachApp.swift
│   ├── ContentView.swift
│   ├── Models/
│   │   ├── AppConstants.swift       ← all metric data, onboarding questions, plan chips
│   │   ├── HealthMetric.swift       ← metric model (value, insight, trend, status)
│   │   ├── WellnessBreakdown.swift
│   │   └── ...
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift      ← Gemini API calls + message history
│   │   └── HomeViewModel.swift
│   ├── Views/
│   │   ├── MainTabView.swift        ← 3-tab navigation (Home / Activity / Plan)
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   ├── MetricCardView.swift ← insight-first card design
│   │   │   ├── MetricDetail/        ← per-metric detail sheets (HRV, Sleep, etc.)
│   │   │   ├── WellnessGaugeView.swift
│   │   │   ├── GlucoseInsightView.swift
│   │   │   └── SparklineView.swift
│   │   ├── Activity/
│   │   ├── Plan/
│   │   ├── Chat/
│   │   └── Onboarding/
│   ├── Services/
│   │   ├── GeminiService.swift      ← AI API integration
│   │   ├── VectorDBService.swift    ← RAG queries
│   │   └── PersistenceService.swift
│   └── Theme/
│       └── AppTheme.swift           ← color palette, font scale, border radius
```

---

## Design System

Dark-first with a teal/deep-green background palette:

| Token | Hex | Usage |
|---|---|---|
| `appBg` | `#001514` | Main background |
| `appCard` | `#042b28` | Card surfaces |
| `appAccent` | `#456990` | Buttons, links, HRV/Steps |
| `appCoral` | `#eb5e55` | Alerts, Recovery, Stress, RHR |
| `appMint` | `#e4fde1` | Good/Normal states, Body Temp |
| `appPurple` | `#c0a9b0` | Sleep, RHR secondary |
| `appText` | `#D7D9CE` | Primary text |
| `appBorder` | `#0a3d38` | Card borders |

---

## Running the App

1. Open `ai_coach.xcodeproj` in Xcode
2. Add your Gemini API key in **Profile & Settings** (tap the avatar icon in the top-right)
3. Run on a simulator or physical device (iOS 17+)

> The RAG backend (FAISS) requires the Python server to be running locally. See the web app repo for setup instructions.

---

## Relationship to the Web App

```
Web App (Flask + coach.html)          iOS App (SwiftUI)
─────────────────────────────         ──────────────────────────────
/coach-query  POST endpoint     ←───  GeminiService.swift (direct API)
coach.html metric cards         ←───  MetricCardView.swift
Drawer (click card)             ←───  MetricDetailSheetView.swift
Chat panel                      ←───  ChatView.swift
Activity tab                    ←───  ActivityView.swift
Plan tab                        ←───  PlanView.swift
Onboarding overlay              ←───  OnboardingView.swift
localStorage userProfile        ←───  PersistenceService (UserDefaults)
```

The iOS app calls the Gemini API directly (no Flask middleware) while the web app routes through Python. Both use the same system prompt structure and biometric context injection.
