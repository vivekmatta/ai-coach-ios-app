export type TabKey = "today" | "insights" | "workouts" | "profile";

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

export type CoachToneMode = "gentle" | "direct" | "hype" | "nice" | "unhinged";

export interface CoachScore {
  id: string;
  label: string;
  score: number;
  status: string;
  explanation: string;
}

export interface CoachTask {
  id: string;
  title: string;
  detail: string;
  category: "hydration" | "breath" | "movement" | "sleep" | "nutrition" | "recovery";
}

export interface CoachAlert {
  id: string;
  title: string;
  detail: string;
  subtle: boolean;
}

export interface CoachWorkout {
  id: string;
  title: string;
  label: string;
  duration: string;
  why: string;
  cues: string[];
  mediaPrompt: string;
  videoAssetKey?: string;
}

export interface CoachTrendInsight {
  id: string;
  title: string;
  status: string;
  explanation: string;
  values: number[];
}

export interface CoachCorrelation {
  id: string;
  title: string;
  explanation: string;
}

export interface CoachPlanResponse {
  headline: string;
  summary: string;
  status: string;
  overallScore: number;
  categoryScores: CoachScore[];
  cards: CoachScore[];
  tasks: CoachTask[];
  alerts: CoachAlert[];
  workoutOfTheDay: CoachWorkout;
  trendInsights: CoachTrendInsight[];
  correlations: CoachCorrelation[];
  coachTone: CoachToneMode;
  personalityStrength: number;
}

export interface DiaryEntry {
  id: string;
  text: string;
  tags: string[];
  createdAt: string;
  voiceNote?: {
    uri: string;
    durationSeconds: number;
  };
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

export type HealthTone = "good" | "caution" | "alert" | "neutral";

export interface MockFixtureOption {
  id: string;
  label: string;
  summary: string;
}

export interface HealthMetricCard {
  id: string;
  label: string;
  value: string;
  context: string;
  tone: HealthTone;
}

export interface HealthInsight {
  title: string;
  text: string;
  tone: HealthTone;
}

export interface HealthActionItem {
  title: string;
  text: string;
}

export interface RiskFlag {
  title: string;
  text: string;
}

export interface SyncStatus {
  syncedAt: string;
  storageWindowDays: number;
  stale: boolean;
  label: string;
}

export interface LatestHealthDay {
  date: string;
  recoveryScore: number;
  sleepScore: number;
  sleepDurationMinutes: number;
  restingHeartRate: number;
  hrv: number;
  hrvBaseline: number;
  steps: number;
  stepGoal: number;
  stressScore: number;
  stressLabel: string;
  temperatureDeltaC: number;
  spo2Average: number;
  bloodPressure: string | null;
  glucoseProxy: string;
  nitricOxideProxy: string;
}

export interface LatestHealthResponse {
  scenarioId: string;
  scenarioLabel: string;
  scenarioSummary: string;
  availableFixtures: MockFixtureOption[];
  syncStatus: SyncStatus;
  headline: string;
  summary: string;
  latestDay: LatestHealthDay;
  insights: HealthInsight[];
  riskFlags: RiskFlag[];
  actionPlan: HealthActionItem[];
  metricCards: HealthMetricCard[];
}

export interface HealthTimelinePoint {
  date: string;
  recoveryScore: number;
  sleepScore: number;
  hrv: number;
  steps: number;
  stressScore: number;
}

export interface HealthTimelineResponse {
  scenarioId: string;
  trendSummary: string;
  points: HealthTimelinePoint[];
}
