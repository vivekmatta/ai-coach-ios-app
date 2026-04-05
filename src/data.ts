import { palette } from "./theme";
import {
  DailyPlan,
  DerivedInsight,
  HealthLogEntry,
  MetricSnapshot,
  ResearchSignal,
  SensorDefinition,
  UserProfile,
  WorkoutEntry,
} from "./types";

export const defaultProfile: UserProfile = {
  name: "",
  goals: "",
  exerciseDays: "",
  exerciseType: "",
  sleepTime: "",
  caffeine: "",
  workStress: "",
};

export const onboardingQuestions = [
  "What should I call you?",
  "What are your main wellness goals right now?",
  "How many days per week can you realistically exercise?",
  "What kind of movement do you prefer?",
  "What time do you usually try to sleep?",
  "How does caffeine show up in your week?",
  "How stressful are your work or school days?",
];

export const planPrompts = [
  "Create my full weekly wellness plan based on my current biometrics and goals",
  "Help me sleep better this week",
  "Create a stress management plan based on my current stress signals",
  "Help me increase my movement without hurting recovery",
];

export const dailyPlan: DailyPlan = {
  summary:
    "Your body looks under-recovered today. Keep the day simple, lower the load, and use tonight to regain rhythm.",
  bedtime: "Begin winding down by 9:15 pm and aim to be asleep by 10:00 pm.",
  workout: "Skip intensity. A 20-minute walk and 5 minutes of mobility is enough.",
  hydration: "Front-load hydration before noon and pair it with one electrolyte serving.",
  nutrition:
    "Keep meals steady and earlier. Favor protein, fiber, and a calmer evening meal instead of late sugar-heavy snacks.",
};

export const topInsights: DerivedInsight[] = [
  {
    title: "Recovery is the limiter today",
    text: "HRV is 38 ms against a 52 ms baseline and recovery is 44/100. Push less today so tomorrow can be better.",
    accent: palette.coral,
  },
  {
    title: "Sleep debt is carrying into stress",
    text: "Only 6.2 hours with an early wake-up is likely amplifying the high-stress pattern showing up this morning.",
    accent: palette.blue,
  },
  {
    title: "Glucose and nitric oxide are best treated as behavior signals",
    text: "Nothing suggests direct danger, but late eating, poor sleep, and low movement are the exact levers to coach today.",
    accent: palette.sage,
  },
];

export const metrics: MetricSnapshot[] = [
  {
    id: "hrv",
    name: "Heart Rate Variability",
    value: "38",
    unit: "ms",
    baseline: "Baseline: 52 ms",
    status: "Low",
    shortInsight: "Skip intensity today and use tonight to rebuild recovery.",
    description:
      "HRV is 27% below baseline, which usually means your system is carrying stress or incomplete recovery. That makes high-intensity work a poor trade today.",
    coachPrompt: "Explain why my HRV is low and what I should do today.",
    actions: [
      { icon: "moon", text: "Protect tonight's sleep window" },
      { icon: "walk", text: "Keep movement easy and short" },
      { icon: "coffee", text: "Use a firm caffeine cutoff" },
    ],
    accent: palette.blue,
  },
  {
    id: "sleep",
    name: "Sleep Score",
    value: "61",
    unit: "/100",
    baseline: "Baseline: 80 / 100",
    status: "Below Average",
    shortInsight: "Sleep is the biggest reason today should be lighter.",
    description:
      "Only 6.2 hours with an early wake is showing up across recovery and stress. The most important intervention is an earlier, calmer night routine.",
    coachPrompt: "How is my sleep affecting recovery and stress today?",
    actions: [
      { icon: "bed", text: "Start a screen-light wind-down by 9:15 pm" },
      { icon: "breath", text: "Take 5 minutes to downshift before bed" },
    ],
    accent: palette.sand,
  },
  {
    id: "recovery",
    name: "Recovery Score",
    value: "44",
    unit: "/100",
    baseline: "Baseline: 75 / 100",
    status: "Needs Rest",
    shortInsight: "Treat today as a restoration day, not a performance day.",
    description:
      "A red-zone recovery score means your body is asking for lower load. The best move is to preserve consistency instead of chasing a workout win.",
    coachPrompt: "Give me a recovery-first plan for today.",
    actions: [
      { icon: "pause", text: "Remove hard training from today's schedule" },
      { icon: "meal", text: "Eat a solid protein-forward lunch" },
      { icon: "moon", text: "Aim for 9 hours of time in bed tonight" },
    ],
    accent: palette.coral,
  },
  {
    id: "rhr",
    name: "Resting Heart Rate",
    value: "58",
    unit: "bpm",
    baseline: "Baseline: 52 bpm",
    status: "Elevated",
    shortInsight: "Your baseline is elevated enough to justify a lighter day.",
    description:
      "Resting heart rate is 6 bpm above baseline, a common signal that recovery, stress, or sleep quality has drifted off target.",
    coachPrompt: "What does my elevated resting heart rate mean for today?",
    actions: [
      { icon: "water", text: "Hydrate earlier than usual" },
      { icon: "walk", text: "Use light movement to stay loose" },
    ],
    accent: palette.mint,
  },
  {
    id: "steps",
    name: "Steps Today",
    value: "3,200",
    unit: "steps",
    baseline: "Goal: 10,000 steps",
    status: "Low",
    shortInsight: "Low steps are acceptable today if the movement is intentional and easy.",
    description:
      "A softer movement goal fits the current recovery picture better than forcing a high step count just to hit a target.",
    coachPrompt: "How much should I move today given my low recovery?",
    actions: [
      { icon: "walk", text: "Aim for an easy path toward 5,000 steps" },
      { icon: "timer", text: "Break sitting every hour with 2 minutes of movement" },
    ],
    accent: palette.sage,
  },
  {
    id: "stress",
    name: "Stress",
    value: "High",
    unit: "",
    baseline: "Derived from sleep, HRV, and context",
    status: "High",
    shortInsight: "Do one calming intervention now instead of waiting for tonight.",
    description:
      "The current stress state is likely downstream of sleep loss and physiological strain. One deliberate reset during the day can reduce the spiral.",
    coachPrompt: "What should I do in the next 24 hours to lower stress?",
    actions: [
      { icon: "breath", text: "Take 5 minutes for box breathing now" },
      { icon: "sun", text: "Step outside for daylight and a short walk" },
    ],
    accent: palette.coral,
  },
  {
    id: "temp",
    name: "Body Temperature",
    value: "Normal",
    unit: "",
    baseline: "Baseline: normal range",
    status: "Normal",
    shortInsight: "No temperature-based warning signal is standing out today.",
    description:
      "Temperature can become part of illness and glucose-proxy interpretation, but today it stays in a steady range and does not demand action.",
    coachPrompt: "How should I interpret my normal temperature today?",
    actions: [
      { icon: "check", text: "No special temperature action needed today" },
      { icon: "sensor", text: "Future band sensors can make this more useful" },
    ],
    accent: palette.blue,
  },
];

export const workouts: WorkoutEntry[] = [
  {
    id: 1,
    date: "Feb 24",
    type: "run",
    typeLabel: "Track Intervals",
    duration: "65 min",
    distance: "9.2 mi",
    avgHR: "162 bpm",
    effort: "Hard (8/10)",
    notes: "Strong through rep 6, then fade late. High-quality session but expensive.",
  },
  {
    id: 2,
    date: "Feb 26",
    type: "run",
    typeLabel: "Easy Run",
    duration: "45 min",
    distance: "6.1 mi",
    avgHR: "138 bpm",
    effort: "Easy (4/10)",
    notes: "Kept it in zone 2. Good example of controlled recovery work.",
  },
  {
    id: 3,
    date: "Mar 1",
    type: "brick",
    typeLabel: "Long Brick",
    duration: "1 hr 55 min",
    distance: "28.4 mi bike + 3.8 mi run",
    avgHR: "155 / 168 bpm",
    effort: "Moderate-Hard (7/10)",
    notes: "Big load day. Useful context for the slow recovery trend that followed.",
  },
  {
    id: 4,
    date: "Mar 5",
    type: "swim",
    typeLabel: "Recovery Swim",
    duration: "30 min",
    distance: "1,100 m",
    avgHR: "132 bpm",
    effort: "Very Easy (3/10)",
    notes: "Movement-first, not performance-first. Good template for today.",
  },
  {
    id: 5,
    date: "Mar 8",
    type: "yoga",
    typeLabel: "Yoga and Mobility",
    duration: "30 min",
    distance: "—",
    avgHR: "—",
    effort: "Very Easy (1/10)",
    notes: "Mobility focus. Helpful for nervous-system downshifting too.",
  },
  {
    id: 6,
    date: "Mar 11",
    type: "swim",
    typeLabel: "Aerobic Easy Swim",
    duration: "45 min",
    distance: "1,800 m",
    avgHR: "140 bpm",
    effort: "Easy-Moderate (4/10)",
    notes: "Body was responding better, but not fully back to baseline.",
  },
];

export const healthLog: HealthLogEntry[] = [
  {
    date: "Mar 4",
    hrv: "42 ms",
    sleep: "65/100",
    recovery: "49/100",
    rhr: "57 bpm",
    steps: "8,200",
    stress: "High",
    notes: "Poor sleep onset and elevated caffeine. Recovery trend started breaking down.",
  },
  {
    date: "Mar 7",
    hrv: "37 ms",
    sleep: "62/100",
    recovery: "44/100",
    rhr: "59 bpm",
    steps: "5,400",
    stress: "High",
    notes: "Woke groggy with mild illness-like strain. Extra fluids and rest helped.",
  },
  {
    date: "Mar 10",
    hrv: "39 ms",
    sleep: "71/100",
    recovery: "48/100",
    rhr: "57 bpm",
    steps: "7,800",
    stress: "Moderate",
    notes: "Easy jog felt better than expected. Trend was improving, but still fragile.",
  },
  {
    date: "Mar 12",
    hrv: "38 ms",
    sleep: "61/100",
    recovery: "44/100",
    rhr: "58 bpm",
    steps: "3,200",
    stress: "High",
    notes: "Early wake and poor recovery. Best interpreted as a low-load day.",
  },
];

export const researchSignals: ResearchSignal[] = [
  {
    title: "Glucose proxy",
    summary:
      "Estimated through sleep timing, HRV shifts, temperature trends, meal timing, and stress patterns rather than direct glucose measurement.",
    directness: "Proxy",
    sensors: ["PPG", "Skin Temp", "IMU", "Manual meal context"],
  },
  {
    title: "Nitric oxide proxy",
    summary:
      "Inferred from recovery patterns, pulse characteristics, sleep timing, activity, and environmental context because direct NO sensing is not part of the current prototype.",
    directness: "Proxy",
    sensors: ["PPG/ECG", "IMU", "Temp", "Environment"],
  },
  {
    title: "Stress state",
    summary:
      "Combines HRV suppression, elevated resting heart rate, sleep disruption, and contextual strain to classify the likely stress burden.",
    directness: "Proxy",
    sensors: ["EDA", "PPG", "IMU", "Sleep context"],
  },
  {
    title: "Sleep environment",
    summary:
      "Tracks noise, movement, and routine patterns to explain why sleep quality improved or deteriorated.",
    directness: "Context",
    sensors: ["Microphone", "IMU", "Ambient context"],
  },
];

export const sensors: SensorDefinition[] = [
  {
    name: "MAX86150",
    purpose: "Heart rate, HRV, optional ECG support",
    notes: "Primary physiological signal source for recovery, stress, and sleep-related inference.",
  },
  {
    name: "BMI270",
    purpose: "Motion and activity classification",
    notes: "Critical for distinguishing exercise from stress and for sleep movement context.",
  },
  {
    name: "MAX30208",
    purpose: "Skin temperature",
    notes: "Useful for illness trend detection and glucose-proxy interpretation.",
  },
  {
    name: "MAX30001G + electrodes",
    purpose: "EDA and conductivity",
    notes: "Supports stress response and hydration-adjacent interpretation.",
  },
  {
    name: "TDK T5838",
    purpose: "Microphone for sleep environment",
    notes: "Targets noise, apnea-like events, and sleep disruption context.",
  },
  {
    name: "BME688",
    purpose: "Ambient environment and air quality",
    notes: "Supports environment-aware coaching and nitric-oxide-related context.",
  },
];
