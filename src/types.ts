export type TabKey = "today" | "activity" | "plan" | "coach" | "signals";

export type MetricStatus =
  | "Good"
  | "Normal"
  | "Low"
  | "Elevated"
  | "Below Average"
  | "Needs Rest"
  | "High";

export type MetricKey =
  | "hrv"
  | "sleep"
  | "recovery"
  | "rhr"
  | "steps"
  | "stress"
  | "temp";

export type WorkoutType = "run" | "swim" | "brick" | "yoga" | "rest";

export interface UserProfile {
  name: string;
  goals: string;
  exerciseDays: string;
  exerciseType: string;
  sleepTime: string;
  caffeine: string;
  workStress: string;
}

export interface MetricAction {
  icon: string;
  text: string;
}

export interface MetricSnapshot {
  id: MetricKey;
  name: string;
  value: string;
  unit: string;
  baseline: string;
  status: MetricStatus;
  shortInsight: string;
  description: string;
  coachPrompt: string;
  actions: MetricAction[];
  accent: string;
}

export interface DerivedInsight {
  title: string;
  text: string;
  accent: string;
}

export interface DailyPlan {
  summary: string;
  bedtime: string;
  workout: string;
  hydration: string;
  nutrition: string;
}

export interface WorkoutEntry {
  id: number;
  date: string;
  type: WorkoutType;
  typeLabel: string;
  duration: string;
  distance: string;
  avgHR: string;
  effort: string;
  notes: string;
}

export interface HealthLogEntry {
  date: string;
  hrv: string;
  sleep: string;
  recovery: string;
  rhr: string;
  steps: string;
  stress: string;
  notes: string;
}

export interface CoachMessage {
  id: string;
  role: "assistant" | "user";
  text: string;
}

export interface ResearchSignal {
  title: string;
  summary: string;
  directness: "Direct" | "Proxy" | "Context";
  sensors: string[];
}

export interface SensorDefinition {
  name: string;
  purpose: string;
  notes: string;
}
