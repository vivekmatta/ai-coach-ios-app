export type SyncStatus = "synced" | "stale" | "missing";
export type FilterKey = "all" | "sync-risk" | "recovery" | "flagged";

export interface TrendPoint {
  day: string;
  recovery: number;
  sleep: number;
  hrv: number;
  stress: number;
  steps: number;
}

export interface Participant {
  id: string;
  deviceId: string;
  lastSync: string;
  syncStatus: SyncStatus;
  completeness: boolean[];
  recovery: number;
  sleepScore: number;
  sleepHours: number;
  hrv: number;
  restingHr: number;
  stress: "Low" | "Moderate" | "High";
  stressScore: number;
  steps: number;
  spo2: number;
  tempDelta: number;
  bloodPressure: string | null;
  glucoseProxy: "Stable" | "Caution";
  nitricOxideProxy: "Supported" | "Could improve";
  flags: string[];
  summary: string;
  recommendation: string;
  note: string;
  trend: TrendPoint[];
}

const baseTrend = [
  { day: "Mon", recovery: 62, sleep: 70, hrv: 44, stress: 54, steps: 7420 },
  { day: "Tue", recovery: 58, sleep: 68, hrv: 42, stress: 57, steps: 8010 },
  { day: "Wed", recovery: 64, sleep: 72, hrv: 46, stress: 51, steps: 8740 },
  { day: "Thu", recovery: 60, sleep: 69, hrv: 43, stress: 55, steps: 9320 },
  { day: "Fri", recovery: 67, sleep: 75, hrv: 48, stress: 49, steps: 9880 },
  { day: "Sat", recovery: 72, sleep: 80, hrv: 51, stress: 42, steps: 10120 },
  { day: "Sun", recovery: 70, sleep: 78, hrv: 50, stress: 44, steps: 9630 },
];

function trend(offset: number): TrendPoint[] {
  return baseTrend.map((point, index) => ({
    day: point.day,
    recovery: Math.max(30, Math.min(95, point.recovery + offset - index)),
    sleep: Math.max(35, Math.min(94, point.sleep + offset)),
    hrv: Math.max(24, point.hrv + Math.round(offset / 2)),
    stress: Math.max(22, Math.min(88, point.stress - offset + index)),
    steps: Math.max(2400, point.steps + offset * 130 - index * 90),
  }));
}

export const participants: Participant[] = [
  {
    id: "P-001",
    deviceId: "ES02-001",
    lastSync: "Today, 9:42 AM",
    syncStatus: "synced",
    completeness: [true, true, true, true, true, true, true],
    recovery: 72,
    sleepScore: 78,
    sleepHours: 7.4,
    hrv: 50,
    restingHr: 55,
    stress: "Low",
    stressScore: 42,
    steps: 9630,
    spo2: 97,
    tempDelta: 0.1,
    bloodPressure: "116/74",
    glucoseProxy: "Stable",
    nitricOxideProxy: "Supported",
    flags: [],
    summary: "Recovery and sleep are stable with consistent movement across the last week.",
    recommendation: "Keep current sleep timing and movement consistency unchanged.",
    note: "Good control pattern for steady routine comparison.",
    trend: trend(4),
  },
  {
    id: "P-002",
    deviceId: "ES02-002",
    lastSync: "2d ago",
    syncStatus: "stale",
    completeness: [true, true, false, true, false, false, false],
    recovery: 45,
    sleepScore: 54,
    sleepHours: 4.9,
    hrv: 34,
    restingHr: 63,
    stress: "High",
    stressScore: 76,
    steps: 3180,
    spo2: 94,
    tempDelta: 0.5,
    bloodPressure: "124/82",
    glucoseProxy: "Caution",
    nitricOxideProxy: "Could improve",
    flags: ["Stale sync", "Low recovery", "High stress"],
    summary: "Low recovery and missing syncs make this participant a priority follow-up.",
    recommendation: "Confirm device sync and review sleep/stress pattern before interpreting trend.",
    note: "Follow up on adherence and Bluetooth sync reliability.",
    trend: trend(-16),
  },
  {
    id: "P-003",
    deviceId: "ES02-003",
    lastSync: "Today, 7:18 AM",
    syncStatus: "synced",
    completeness: [true, true, true, true, true, false, true],
    recovery: 61,
    sleepScore: 67,
    sleepHours: 6.3,
    hrv: 43,
    restingHr: 58,
    stress: "Moderate",
    stressScore: 57,
    steps: 7920,
    spo2: 96,
    tempDelta: 0.2,
    bloodPressure: "118/76",
    glucoseProxy: "Caution",
    nitricOxideProxy: "Supported",
    flags: ["Late-meal proxy"],
    summary: "Routine is mostly intact, but late-meal proxy is recurring.",
    recommendation: "Flag for evening routine review if late-meal proxy persists another two days.",
    note: "",
    trend: trend(-3),
  },
  {
    id: "P-004",
    deviceId: "ES02-004",
    lastSync: "Today, 11:03 AM",
    syncStatus: "synced",
    completeness: [true, true, true, true, true, true, true],
    recovery: 82,
    sleepScore: 84,
    sleepHours: 8.1,
    hrv: 56,
    restingHr: 52,
    stress: "Low",
    stressScore: 35,
    steps: 10480,
    spo2: 98,
    tempDelta: 0,
    bloodPressure: "115/73",
    glucoseProxy: "Stable",
    nitricOxideProxy: "Supported",
    flags: [],
    summary: "Strong recovery, sleep, and movement consistency across the study window.",
    recommendation: "No follow-up needed unless the participant reports subjective issues.",
    note: "",
    trend: trend(10),
  },
  {
    id: "P-005",
    deviceId: "ES02-005",
    lastSync: "Today, 10:15 AM",
    syncStatus: "synced",
    completeness: [true, true, true, true, true, true, true],
    recovery: 70,
    sleepScore: 65,
    sleepHours: 6.5,
    hrv: 55,
    restingHr: 57,
    stress: "Low",
    stressScore: 44,
    steps: 8400,
    spo2: 98,
    tempDelta: 0.2,
    bloodPressure: "117/75",
    glucoseProxy: "Caution",
    nitricOxideProxy: "Supported",
    flags: ["Low sleep duration", "Late-meal proxy"],
    summary: "Recovery is stable but sleep duration is below baseline. HRV shows slight downward drift.",
    recommendation: "Recommend earlier evening wind-down based on late-meal proxy detection.",
    note: "Interesting pattern: recovery remains stable despite shorter sleep.",
    trend: trend(1),
  },
  {
    id: "P-006",
    deviceId: "ES02-006",
    lastSync: "Yesterday, 8:04 PM",
    syncStatus: "synced",
    completeness: [true, true, true, false, true, true, true],
    recovery: 58,
    sleepScore: 61,
    sleepHours: 5.8,
    hrv: 39,
    restingHr: 60,
    stress: "Moderate",
    stressScore: 63,
    steps: 6120,
    spo2: 95,
    tempDelta: 0.3,
    bloodPressure: null,
    glucoseProxy: "Caution",
    nitricOxideProxy: "Could improve",
    flags: ["Moderate stress"],
    summary: "Mild recovery drift with movement below goal and rising stress.",
    recommendation: "Watch for continued HRV decline before marking high priority.",
    note: "",
    trend: trend(-8),
  },
  {
    id: "P-007",
    deviceId: "ES02-007",
    lastSync: "No sync",
    syncStatus: "missing",
    completeness: [false, false, false, false, false, false, false],
    recovery: 0,
    sleepScore: 0,
    sleepHours: 0,
    hrv: 0,
    restingHr: 0,
    stress: "High",
    stressScore: 0,
    steps: 0,
    spo2: 0,
    tempDelta: 0,
    bloodPressure: null,
    glucoseProxy: "Caution",
    nitricOxideProxy: "Could improve",
    flags: ["Missing sync"],
    summary: "No usable data in the current 7-day window.",
    recommendation: "Contact participant to confirm bracelet wear and phone sync setup.",
    note: "Likely setup issue.",
    trend: trend(-35),
  },
  {
    id: "P-008",
    deviceId: "ES02-008",
    lastSync: "1h ago",
    syncStatus: "synced",
    completeness: [true, true, true, true, true, true, true],
    recovery: 90,
    sleepScore: 88,
    sleepHours: 8.3,
    hrv: 61,
    restingHr: 50,
    stress: "Low",
    stressScore: 29,
    steps: 11240,
    spo2: 98,
    tempDelta: -0.1,
    bloodPressure: "112/72",
    glucoseProxy: "Stable",
    nitricOxideProxy: "Supported",
    flags: [],
    summary: "Best current recovery profile in the cohort.",
    recommendation: "Use as a clean high-adherence example for dashboard demos.",
    note: "",
    trend: trend(14),
  },
  {
    id: "P-009",
    deviceId: "ES02-009",
    lastSync: "Today, 6:55 AM",
    syncStatus: "synced",
    completeness: [true, true, true, true, false, true, true],
    recovery: 64,
    sleepScore: 71,
    sleepHours: 6.9,
    hrv: 47,
    restingHr: 56,
    stress: "Moderate",
    stressScore: 52,
    steps: 9310,
    spo2: 97,
    tempDelta: 0.1,
    bloodPressure: "119/77",
    glucoseProxy: "Stable",
    nitricOxideProxy: "Supported",
    flags: [],
    summary: "Stable middle-of-cohort pattern with one missing day.",
    recommendation: "No immediate follow-up needed.",
    note: "",
    trend: trend(0),
  },
  {
    id: "P-010",
    deviceId: "ES02-010",
    lastSync: "3d ago",
    syncStatus: "stale",
    completeness: [true, false, true, false, false, false, false],
    recovery: 39,
    sleepScore: 53,
    sleepHours: 5.6,
    hrv: 34,
    restingHr: 61,
    stress: "High",
    stressScore: 77,
    steps: 3180,
    spo2: 94,
    tempDelta: 0.6,
    bloodPressure: "124/82",
    glucoseProxy: "Caution",
    nitricOxideProxy: "Could improve",
    flags: ["Stale sync", "Low recovery", "Temperature drift"],
    summary: "High-risk pattern, but stale sync means recent interpretation is uncertain.",
    recommendation: "Resolve sync first, then review temperature and recovery drift.",
    note: "",
    trend: trend(-20),
  },
  {
    id: "P-011",
    deviceId: "ES02-011",
    lastSync: "Today, 12:11 PM",
    syncStatus: "synced",
    completeness: [true, true, true, true, true, true, true],
    recovery: 76,
    sleepScore: 73,
    sleepHours: 7.0,
    hrv: 52,
    restingHr: 54,
    stress: "Low",
    stressScore: 40,
    steps: 10020,
    spo2: 97,
    tempDelta: 0,
    bloodPressure: "116/75",
    glucoseProxy: "Stable",
    nitricOxideProxy: "Supported",
    flags: [],
    summary: "Healthy routine consistency and complete data capture.",
    recommendation: "No research action required.",
    note: "",
    trend: trend(6),
  },
  {
    id: "P-012",
    deviceId: "ES02-012",
    lastSync: "Yesterday, 11:38 PM",
    syncStatus: "synced",
    completeness: [true, true, true, true, true, false, true],
    recovery: 55,
    sleepScore: 59,
    sleepHours: 5.7,
    hrv: 38,
    restingHr: 62,
    stress: "High",
    stressScore: 69,
    steps: 5900,
    spo2: 95,
    tempDelta: 0.4,
    bloodPressure: "121/78",
    glucoseProxy: "Caution",
    nitricOxideProxy: "Could improve",
    flags: ["High stress", "Low sleep duration"],
    summary: "Consistent data but elevated stress and short sleep merit review.",
    recommendation: "Mark for follow-up if stress remains high after next sync.",
    note: "",
    trend: trend(-10),
  },
];

export function cohortStats(list: Participant[]) {
  const synced = list.filter((participant) => participant.syncStatus === "synced").length;
  const missing = list.filter((participant) => participant.syncStatus !== "synced").length;
  const activeFlags = list.reduce((sum, participant) => sum + participant.flags.length, 0);
  const measured = list.filter((participant) => participant.recovery > 0);
  const averageRecovery = Math.round(
    measured.reduce((sum, participant) => sum + participant.recovery, 0) / measured.length
  );
  const averageSleep = Math.round(
    measured.reduce((sum, participant) => sum + participant.sleepScore, 0) / measured.length
  );

  return {
    enrolled: list.length,
    synced,
    missing,
    activeFlags,
    averageRecovery,
    averageSleep,
  };
}
