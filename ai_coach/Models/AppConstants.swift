import SwiftUI

enum AppConstants {

    // MARK: – Metrics
    static let metrics: [HealthMetric] = [
        HealthMetric(
            id: .hrv,
            name: "Heart Rate Variability",
            value: "38", unit: "ms",
            baseline: "Baseline: 52ms",
            status: .low,
            trend: [55,53,48,44,42,40,39,37,38,39,40,38],
            color: .appAccent,
            shortInsight: "27% below baseline — skip intensity today and prioritize sleep and calm tonight.",
            description: "HRV measures variation between heartbeats. Higher HRV = better recovery. Your 38ms is 27% below your 52ms baseline, indicating accumulated stress or incomplete recovery.",
            coachPrompt: "Explain my HRV score of 38ms (baseline 52ms) and what it means for my training today.",
            actions: [
                MetricAction(icon: "xmark.circle", text: "Skip all intense workouts today", actionType: .info),
                MetricAction(icon: "figure.walk", text: "Easy walk only — 20 min max", actionType: .info),
                MetricAction(icon: "moon.fill", text: "Be in bed by 10:00 pm tonight", actionType: .calendar),
                MetricAction(icon: "cup.and.saucer.fill", text: "No caffeine after 2:00 pm", actionType: .info)
            ]
        ),
        HealthMetric(
            id: .sleep,
            name: "Sleep Score",
            value: "61", unit: "/100",
            baseline: "Baseline: 80/100 · 7.5 hrs avg",
            status: .belowAvg,
            trend: [83,80,72,74,73,65,67,62,69,70,71,73,61],
            color: .appPurple,
            shortInsight: "Only 6.2 hrs after early 5am wake — aim for a 10pm bedtime and screen-free wind-down tonight.",
            description: "Sleep score combines duration, efficiency, deep sleep, REM, and overnight HR. Only 6.2hrs last night (avg 7.5hrs) after waking at 5am. Deep and REM sleep are critical for muscle repair and hormone release.",
            coachPrompt: "Explain my sleep score of 61/100 and only 6.2 hours last night. How is this affecting my recovery and training?",
            actions: [
                MetricAction(icon: "moon.fill", text: "Go to bed by 10:00 pm tonight", actionType: .calendar),
                MetricAction(icon: "iphone.slash", text: "No screens after 9:00 pm", actionType: .info),
                MetricAction(icon: "cup.and.saucer.fill", text: "Caffeine cutoff at 2:00 pm", actionType: .info),
                MetricAction(icon: "wind", text: "5-min box breathing before bed", actionType: .shortcut)
            ]
        ),
        HealthMetric(
            id: .recovery,
            name: "Recovery Score",
            value: "44", unit: "/100",
            baseline: "Baseline: 75/100",
            status: .needsRest,
            trend: [79,76,63,55,58,49,47,46,44,48,46,48,51,44],
            color: .appCoral,
            shortInsight: "Red zone (44/100) — rest or a short walk only, no training load today.",
            description: "Recovery Score weighs HRV, resting HR, sleep quality, training load, and stress signals. Score of 44 is in the red zone — attempting hard training risks deepening the recovery deficit.",
            coachPrompt: "My recovery score is 44/100 (baseline 75/100). Give me a day-by-day plan to get back above 65 within a week.",
            actions: [
                MetricAction(icon: "zzz", text: "Full rest day — no structured training", actionType: .info),
                MetricAction(icon: "figure.walk", text: "20-min easy walk max if restless", actionType: .info),
                MetricAction(icon: "fork.knife", text: "Eat a protein-rich meal today", actionType: .info),
                MetricAction(icon: "moon.fill", text: "Target 9+ hours sleep tonight", actionType: .calendar)
            ]
        ),
        HealthMetric(
            id: .rhr,
            name: "Resting Heart Rate",
            value: "58", unit: "bpm",
            baseline: "Baseline: 52 bpm",
            status: .elevated,
            trend: [51,52,54,56,55,57,58,59,58,57,56,58],
            color: .appPurple,
            shortInsight: "6 bpm above baseline — skip hard efforts, hydrate well, and move lightly today.",
            description: "RHR is measured at complete rest upon waking. Your 52 bpm baseline is healthy for an endurance athlete. Elevated 58 bpm (+12%) is a classic sign of incomplete recovery or sympathetic nervous system dominance.",
            coachPrompt: "My resting heart rate is 58 bpm, 6 beats above my baseline of 52. What does this mean for today's training?",
            actions: [
                MetricAction(icon: "bolt.slash.fill", text: "Skip intervals and tempo efforts", actionType: .info),
                MetricAction(icon: "figure.walk", text: "10-min gentle walk to stay loose", actionType: .info),
                MetricAction(icon: "drop.fill", text: "Drink at least 2 L of water today", actionType: .info),
                MetricAction(icon: "moon.fill", text: "Early bedtime — lights out by 10 pm", actionType: .calendar)
            ]
        ),
        HealthMetric(
            id: .steps,
            name: "Steps Today",
            value: "3,200", unit: "steps",
            baseline: "Goal: 10,000/day",
            status: .low,
            trend: [9240,11300,14800,5100,7600,8200,6900,7100,5400,4200,6300,7800,8900,3200],
            color: .appAccent,
            shortInsight: "Low movement is okay today — a short walk to 5,000 steps supports circulation without stress.",
            description: "Steps proxy for daily movement and NEAT. Low step count today is appropriate given recovery score 44/100. Light walking (up to 5,000 steps) supports circulation without adding training stress.",
            coachPrompt: "I've only done 3,200 steps today. Given my recovery score of 44/100, how much movement should I actually do?",
            actions: [
                MetricAction(icon: "figure.walk", text: "Walk to 5,000 steps — stop there", actionType: .info),
                MetricAction(icon: "timer", text: "Break up sitting every hour with a 2-min walk", actionType: .info),
                MetricAction(icon: "figure.flexibility", text: "5-min light stretch in the evening", actionType: .shortcut)
            ]
        ),
        HealthMetric(
            id: .stress,
            name: "Stress Level",
            value: "High", unit: "",
            baseline: "Index driven by biometrics + context",
            status: .elevated,
            trend: [1,2,3,3,4,5,4,5,4,3,3,3,3,5],
            color: .appCoral,
            shortInsight: "Elevated cortisol from poor sleep — 5-min breathing now, no caffeine this afternoon.",
            description: "Stress index derived from HRV suppression, elevated RHR, poor sleep, and context. 'High' today driven by 6.2hr sleep and involuntary 5am wake. Chronically elevated cortisol suppresses HRV and inhibits training adaptations.",
            coachPrompt: "My stress is showing High. What specific things should I do in the next 24 hours to bring stress down and support recovery?",
            actions: [
                MetricAction(icon: "wind", text: "5-min box breathing — do it now", actionType: .shortcut),
                MetricAction(icon: "cup.and.saucer.fill", text: "No caffeine after 2:00 pm today", actionType: .info),
                MetricAction(icon: "figure.walk.circle", text: "10-min evening walk to unwind", actionType: .info),
                MetricAction(icon: "moon.fill", text: "Lights out by 10:00 pm", actionType: .calendar)
            ]
        ),
        HealthMetric(
            id: .temp,
            name: "Body Temperature",
            value: "Normal", unit: "",
            baseline: "Baseline: Normal range",
            status: .normal,
            trend: [3,3,3,3,3,3,3,3,3,3,3,3,3,3],
            color: .appMint,
            shortInsight: "Normal range — no action needed today.",
            description: "Body temperature is a potential non-invasive glucose proxy. High blood glucose can push temperature upward — similar to an infection response. Currently in Normal range, which means no elevated glucose signal from temperature today. Future hardware integration will provide continuous temperature readings from a wearable sensor.",
            coachPrompt: "How does body temperature relate to blood glucose and my overall recovery? What does my current normal temperature tell you?",
            actions: [
                MetricAction(icon: "checkmark.circle.fill", text: "No action needed — temp is normal", actionType: .info),
                MetricAction(icon: "applewatch", text: "Wearable sensor integration coming soon", actionType: .info)
            ],
            fullWidth: true
        )
    ]

    // MARK: – Workouts
    static let workouts: [WorkoutEntry] = [
        WorkoutEntry(id: 1, date: "Feb 24", type: .run,   typeLabel: "Track Intervals",        duration: "65 min",   distance: "9.2 mi",                         avgHR: "162 bpm",                  effort: "Hard (8/10)",         notes: "8x800m @ 5K pace. Splits 3:02-3:08. Felt strong through rep 6, faded slightly on 7 and 8."),
        WorkoutEntry(id: 2, date: "Feb 26", type: .run,   typeLabel: "Easy Run",               duration: "45 min",   distance: "6.1 mi",                         avgHR: "138 bpm",                  effort: "Easy (4/10)",         notes: "Recovery run. Kept HR in zone 2. Legs felt fresh after Tuesday's track session."),
        WorkoutEntry(id: 3, date: "Feb 27", type: .swim,  typeLabel: "Swim — Aerobic Base",    duration: "55 min",   distance: "2,400m",                         avgHR: "144 bpm",                  effort: "Moderate (5/10)",     notes: "4x400m @ 1:45/100m + drill work. Stroke efficiency good. Flip turns improving."),
        WorkoutEntry(id: 4, date: "Mar 1",  type: .brick, typeLabel: "Brick (Bike + Run)",     duration: "2h 0m",    distance: "28.4 mi bike + 3.8 mi run",      avgHR: "155 bpm bike / 168 bpm run", effort: "Moderate-Hard (7/10)", notes: "Legs heavy on run transition (typical). Power 215W avg on bike. Slight IT band tightness left knee at mile 2. Iced afterward."),
        WorkoutEntry(id: 5, date: "Mar 3",  type: .run,   typeLabel: "Tempo Run (Modified)",   duration: "35 min",   distance: "4.2 mi",                         avgHR: "149 bpm",                  effort: "Moderate (5/10)",     notes: "Cut short at 10 min — legs dead, HR elevated for pace. Dialed back to easy jog. Recovery was 58 — should have rested."),
        WorkoutEntry(id: 6, date: "Mar 5",  type: .swim,  typeLabel: "Easy Swim (Recovery)",   duration: "30 min",   distance: "1,100m",                         avgHR: "132 bpm",                  effort: "Very Easy (3/10)",    notes: "Coach-prescribed recovery swim. Felt sluggish, times slow. Just focused on moving and staying loose."),
        WorkoutEntry(id: 7, date: "Mar 8",  type: .yoga,  typeLabel: "Yoga / Mobility",        duration: "30 min",   distance: "—",                              avgHR: "—",                        effort: "Very Easy (1/10)",    notes: "Hip flexors, IT band, thoracic spine focus. Left knee feeling better with consistent foam rolling."),
        WorkoutEntry(id: 8, date: "Mar 10", type: .run,   typeLabel: "Easy Run",               duration: "30 min",   distance: "3.6 mi",                         avgHR: "135 bpm",                  effort: "Easy (4/10)",         notes: "First real run in 5 days. Conversational pace. Legs more responsive than last week — encouraging sign of recovery beginning."),
        WorkoutEntry(id: 9, date: "Mar 11", type: .swim,  typeLabel: "Swim — Aerobic Easy",    duration: "45 min",   distance: "1,800m",                         avgHR: "140 bpm",                  effort: "Easy-Moderate (4/10)", notes: "6x300m @ 1:55/100m. First decent swim in over a week. Body responding better. Still not back to baseline.")
    ]

    // MARK: – Health Log
    static let healthLog: [HealthLogEntry] = [
        HealthLogEntry(date: "Feb 27", hrv: "55ms", sleep: "83/100", recovery: "79/100", rhr: "51 bpm", steps: "9,240",  stress: "Low",      notes: "Felt well-rested. Morning easy run smooth. HRV trending up."),
        HealthLogEntry(date: "Feb 28", hrv: "53ms", sleep: "80/100", recovery: "76/100", rhr: "52 bpm", steps: "11,300", stress: "Low-Mod",   notes: "Normal training day. Swim went well. Slight fatigue by end of day."),
        HealthLogEntry(date: "Mar 1",  hrv: "48ms", sleep: "72/100", recovery: "63/100", rhr: "54 bpm", steps: "14,800", stress: "Moderate",  notes: "Long brick workout. Legs heavy. Stayed up late with friends."),
        HealthLogEntry(date: "Mar 2",  hrv: "44ms", sleep: "74/100", recovery: "55/100", rhr: "56 bpm", steps: "5,100",  stress: "Low",       notes: "Full rest day. HRV drop typical post-hard effort. Foam rolled IT band."),
        HealthLogEntry(date: "Mar 3",  hrv: "46ms", sleep: "73/100", recovery: "58/100", rhr: "55 bpm", steps: "7,600",  stress: "Mod-High",  notes: "Work stress high (project deadline). Short tempo attempted, felt sluggish. Ate late, poor sleep onset."),
        HealthLogEntry(date: "Mar 4",  hrv: "42ms", sleep: "65/100", recovery: "49/100", rhr: "57 bpm", steps: "8,200",  stress: "High",      notes: "Woke 3am, couldn't sleep (work rumination). HRV declining. Skipped swim. High caffeine (3 cups)."),
        HealthLogEntry(date: "Mar 5",  hrv: "40ms", sleep: "63/100", recovery: "47/100", rhr: "58 bpm", steps: "6,900",  stress: "High",      notes: "Work deadline passed. Still run-down. Short easy swim. Evening meditation helped some."),
        HealthLogEntry(date: "Mar 6",  hrv: "39ms", sleep: "67/100", recovery: "46/100", rhr: "58 bpm", steps: "7,100",  stress: "Mod-High",  notes: "Marginally better sleep. Easy walk + mobility. Appetite increased, craving carbs."),
        HealthLogEntry(date: "Mar 7",  hrv: "37ms", sleep: "62/100", recovery: "44/100", rhr: "59 bpm", steps: "5,400",  stress: "High",      notes: "Woke groggy. Slight sore throat. Skipped training. Extra fluids."),
        HealthLogEntry(date: "Mar 8",  hrv: "38ms", sleep: "69/100", recovery: "48/100", rhr: "58 bpm", steps: "4,200",  stress: "Moderate",  notes: "Intentional rest. Slept in. Sore throat gone. Light yoga. Good nutrition focus."),
        HealthLogEntry(date: "Mar 9",  hrv: "38ms", sleep: "70/100", recovery: "46/100", rhr: "57 bpm", steps: "6,300",  stress: "Moderate",  notes: "Second rest day. Easy walk. HRV stable. Work stress eased. Consistent 10:30pm bedtime."),
        HealthLogEntry(date: "Mar 10", hrv: "39ms", sleep: "71/100", recovery: "48/100", rhr: "57 bpm", steps: "7,800",  stress: "Moderate",  notes: "Easy 30-min jog. Legs better than last week. HRV slowly climbing."),
        HealthLogEntry(date: "Mar 11", hrv: "40ms", sleep: "73/100", recovery: "51/100", rhr: "56 bpm", steps: "8,900",  stress: "Moderate",  notes: "Swim session (45 min easy). Body responding better. Sleep routine improving."),
        HealthLogEntry(date: "Mar 12", hrv: "38ms", sleep: "61/100", recovery: "44/100", rhr: "58 bpm", steps: "3,200",  stress: "High",      notes: "Woke 5am (alarm 6:30). Could not get back to sleep. HRV dipped. Rest day advised.")
    ]

    // MARK: – Frequency Calendar (14 days, Feb 27 – Mar 12)
    // nil = rest day
    static let freqCalendar: [(date: String, type: WorkoutType?)] = [
        ("Feb 27", .run),   ("Feb 28", nil),   ("Mar 1", .brick),
        ("Mar 2",  nil),    ("Mar 3",  .run),   ("Mar 4",  nil),
        ("Mar 5",  .swim),  ("Mar 6",  nil),    ("Mar 7",  nil),
        ("Mar 8",  .yoga),  ("Mar 9",  nil),    ("Mar 10", .run),
        ("Mar 11", .swim),  ("Mar 12", nil)
    ]

    // MARK: – Onboarding Questions
    static let onboardingQuestions: [String] = [
        "Hi! I'm your AI Wellness Coach. I'll guide your daily wellbeing — not just track numbers. What's your name?",
        "What are your primary wellness goals? (e.g., Improve sleep, Reduce stress, Lose weight, Improve cardiovascular fitness, Increase daily movement — pick what resonates most)",
        "How many days per week can you realistically exercise?",
        "What type of exercise do you prefer? (Low impact workouts, HIIT, Walking, Strength training, or a mix)",
        "What time do you normally go to sleep?",
        "Do you regularly consume caffeine? (coffee, tea, energy drinks)",
        "Do you often experience stress during work hours?"
    ]

    // MARK: – Plan Chips
    static let planChips: [String] = [
        "Create my full weekly wellness plan based on my current biometrics and goals",
        "Help me sleep better — create a sleep improvement plan for this week",
        "Create a stress management plan for me based on my current stress levels",
        "Help me increase my daily movement and build a sustainable activity habit"
    ]

    static let planChipLabels: [String] = [
        "My full weekly wellness plan",
        "Help me sleep better",
        "Stress management plan",
        "Increase my daily movement"
    ]

    // MARK: – System Prompt Builder
    static func systemPrompt(for profile: UserProfile, ragContext: String = "") -> String {
        let biometrics = """
  - HRV: 38ms (baseline: 52ms, status: Low)
  - Sleep Score: 61/100 (baseline: 80/100, duration: 6.2 hours, status: Below Average)
  - Recovery Score: 44/100 (baseline: 75/100, status: Needs Rest)
  - Resting HR: 58 bpm (baseline: 52 bpm, status: Elevated)
  - Steps Today: 3,200 (goal: 10,000, status: Low as of midday)
  - Stress Level: High (Elevated — driven by poor sleep and early wake)
  - SpO2: 97% (status: Normal)
"""
        let name = profile.name.isEmpty ? "Alex" : profile.name
        let firstName = profile.firstName.isEmpty ? "Alex" : profile.firstName

        var prompt = """
You are \(name)'s personal AI health coach. You have access to \(firstName)'s real-time biometric data from a wearable smart band, historical health logs, workout history, and nutrition logs.

RESPONSE STYLE RULE:
- If the message is a casual greeting or small talk ("hi", "hey", "thanks", "how are you", "what's up", "cool", "hello", "great", "ok"), respond in 1–2 sentences max. Be warm and brief. Do NOT give health analysis unless asked.
- Only give detailed health/training analysis when the user explicitly asks a health, recovery, training, nutrition, or plan question.

USER PROFILE:
  - Name: \(name)
  - Wellness Goals: \(profile.goals.isEmpty ? "Improve overall wellness" : profile.goals)
  - Exercise Days/Week: \(profile.exerciseDays.isEmpty ? "Not provided" : profile.exerciseDays)
  - Exercise Type: \(profile.exerciseType.isEmpty ? "Not provided" : profile.exerciseType)
  - Sleep Time: \(profile.sleepTime.isEmpty ? "Not provided" : profile.sleepTime)
  - Caffeine: \(profile.caffeine.isEmpty ? "Not provided" : profile.caffeine)
  - Work Stress: \(profile.workStress.isEmpty ? "Not provided" : profile.workStress)

TODAY'S BIOMETRICS (March 12, 2026):
\(biometrics)

COACHING GUIDELINES:
  1. Always reference the actual metric values and baselines when relevant.
  2. Be specific, actionable, and honest — don't sugarcoat poor recovery data.
  3. Prioritize long-term performance over short-term gratification (e.g., advise rest when data warrants it).
  4. Explain the physiological "why" behind your recommendations when helpful.
  5. Keep responses concise but complete — use bullet points for action items.
  6. You have context from \(firstName)'s recent health logs, workouts, and nutrition — reference relevant patterns.
  7. Today's date is March 12, 2026.

Respond naturally as a knowledgeable coach. Address the user by their first name when appropriate. Do NOT return JSON — return plain conversational text with markdown formatting (bold, bullet points) where appropriate.
"""
        if !ragContext.isEmpty {
            prompt += "\n\nRELEVANT HEALTH LOG CONTEXT:\n\(ragContext)"
        }
        return prompt
    }
}
