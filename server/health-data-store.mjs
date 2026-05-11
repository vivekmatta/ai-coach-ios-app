import { access, mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { getMockFixtureById, listMockFixtures, mockHealthFixtures } from "./mock-health-fixtures.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const runtimeStatePath = path.join(repoRoot, "data", "runtime", "health-state.json");

let cachedState;

function normalizeDay(day) {
  return {
    date: day.date,
    sleep: {
      durationMinutes: day.sleep?.durationMinutes ?? 0,
      score: day.sleep?.score ?? 0,
      interruptions: day.sleep?.interruptions ?? 0,
      bedtime: day.sleep?.bedtime ?? null,
      wakeTime: day.sleep?.wakeTime ?? null,
    },
    recovery: {
      score: day.recovery?.score ?? 0,
    },
    heart: {
      restingBpm: day.heart?.restingBpm ?? 0,
      averageBpm: day.heart?.averageBpm ?? 0,
    },
    hrv: {
      dailyValue: day.hrv?.dailyValue ?? 0,
      baseline: day.hrv?.baseline ?? 0,
    },
    steps: {
      count: day.steps?.count ?? 0,
      goal: day.steps?.goal ?? 10000,
      distanceKm: day.steps?.distanceKm ?? 0,
    },
    spo2: {
      average: day.spo2?.average ?? 0,
      min: day.spo2?.min ?? 0,
    },
    temperature: {
      skinC: day.temperature?.skinC ?? 0,
      baselineDeltaC: day.temperature?.baselineDeltaC ?? 0,
    },
    bloodPressure: day.bloodPressure
      ? {
          systolic: day.bloodPressure.systolic ?? 0,
          diastolic: day.bloodPressure.diastolic ?? 0,
        }
      : null,
    stress: {
      score: day.stress?.score ?? 0,
      label: day.stress?.label ?? "Unknown",
    },
    activity: {
      load: day.activity?.load ?? "low",
      activeMinutes: day.activity?.activeMinutes ?? 0,
    },
    hydration: {
      status: day.hydration?.status ?? "fair",
    },
    mealTiming: {
      lateMeal: Boolean(day.mealTiming?.lateMeal),
      eatingWindowHours: day.mealTiming?.eatingWindowHours ?? 12,
    },
  };
}

function normalizePayload(payload) {
  const days = [...(payload.days ?? [])]
    .map(normalizeDay)
    .sort((a, b) => a.date.localeCompare(b.date));

  if (!days.length) {
    throw new Error("A health sync payload must contain at least one day.");
  }

  return {
    scenarioId: payload.scenarioId ?? payload.id ?? "custom-sync",
    scenarioLabel: payload.scenarioLabel ?? payload.label ?? "Custom Sync",
    scenarioSummary: payload.scenarioSummary ?? payload.summary ?? "Imported health sync data.",
    source: payload.source ?? "custom-sync",
    userId: payload.userId ?? "demo-user",
    deviceId: payload.deviceId ?? "unknown-device",
    syncedAt: payload.syncedAt ?? new Date().toISOString(),
    importedAt: new Date().toISOString(),
    days,
  };
}

async function stateExists() {
  try {
    await access(runtimeStatePath);
    return true;
  } catch {
    return false;
  }
}

async function writeState(state) {
  await mkdir(path.dirname(runtimeStatePath), { recursive: true });
  await writeFile(runtimeStatePath, JSON.stringify(state, null, 2));
  cachedState = state;
  return state;
}

export async function ensureHealthState() {
  if (cachedState) {
    return cachedState;
  }

  if (await stateExists()) {
    const raw = await readFile(runtimeStatePath, "utf8");
    cachedState = JSON.parse(raw);
    return cachedState;
  }

  const defaultFixture = mockHealthFixtures[0];
  return importMockFixture(defaultFixture.id);
}

export async function importMockFixture(fixtureId) {
  const fixture = getMockFixtureById(fixtureId);
  if (!fixture) {
    throw new Error(`Unknown mock fixture: ${fixtureId}`);
  }

  const state = normalizePayload({
    ...fixture,
    scenarioId: fixture.id,
    scenarioLabel: fixture.label,
    scenarioSummary: fixture.summary,
  });

  return writeState(state);
}

export async function importHealthPayload(payload) {
  const state = normalizePayload(payload);
  return writeState(state);
}

export async function getHealthState() {
  return ensureHealthState();
}

export function getAvailableMockFixtures() {
  return listMockFixtures();
}
