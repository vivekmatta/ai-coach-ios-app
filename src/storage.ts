import AsyncStorage from "@react-native-async-storage/async-storage";

import { defaultProfile } from "./data";
import { CoachPlanResponse, CoachToneMode, DiaryEntry, UserProfile } from "./types";

const PROFILE_KEY = "ai_coach_profile";
const ONBOARDING_KEY = "ai_coach_onboarding_complete";
const DIARY_KEY = "ai_coach_diary_entries";
const COACH_TONE_KEY = "ai_coach_tone";
const PERSONALITY_STRENGTH_KEY = "ai_coach_personality_strength";
const COACH_PLAN_CACHE_KEY = "ai_coach_plan_cache";
const NOTIFICATIONS_ENABLED_KEY = "ai_coach_notifications_enabled";
const NOTIFICATION_IDS_KEY = "ai_coach_notification_ids";

export async function loadProfile(): Promise<UserProfile> {
  const raw = await AsyncStorage.getItem(PROFILE_KEY);
  if (!raw) {
    return defaultProfile;
  }

  try {
    return JSON.parse(raw) as UserProfile;
  } catch {
    return defaultProfile;
  }
}

export async function saveProfile(profile: UserProfile): Promise<void> {
  await AsyncStorage.setItem(PROFILE_KEY, JSON.stringify(profile));
}

export async function loadOnboardingComplete(): Promise<boolean> {
  const raw = await AsyncStorage.getItem(ONBOARDING_KEY);
  return raw === "true";
}

export async function saveOnboardingComplete(done: boolean): Promise<void> {
  await AsyncStorage.setItem(ONBOARDING_KEY, String(done));
}

export async function loadDiaryEntries(): Promise<DiaryEntry[]> {
  const raw = await AsyncStorage.getItem(DIARY_KEY);
  if (!raw) {
    return [];
  }

  try {
    const entries = JSON.parse(raw) as DiaryEntry[];
    return Array.isArray(entries) ? entries : [];
  } catch {
    return [];
  }
}

export async function saveDiaryEntries(entries: DiaryEntry[]): Promise<void> {
  await AsyncStorage.setItem(DIARY_KEY, JSON.stringify(entries.slice(0, 20)));
}

export async function loadCoachTone(): Promise<CoachToneMode> {
  const raw = await AsyncStorage.getItem(COACH_TONE_KEY);
  if (raw === "gentle" || raw === "direct" || raw === "hype" || raw === "nice" || raw === "unhinged") {
    return raw;
  }
  return "gentle";
}

export async function saveCoachTone(tone: CoachToneMode): Promise<void> {
  await AsyncStorage.setItem(COACH_TONE_KEY, tone);
}

export async function loadPersonalityStrength(): Promise<number> {
  const raw = await AsyncStorage.getItem(PERSONALITY_STRENGTH_KEY);
  const parsed = Number(raw);
  if (Number.isFinite(parsed)) {
    return Math.max(1, Math.min(5, Math.round(parsed)));
  }
  return 3;
}

export async function savePersonalityStrength(strength: number): Promise<void> {
  await AsyncStorage.setItem(
    PERSONALITY_STRENGTH_KEY,
    String(Math.max(1, Math.min(5, Math.round(strength))))
  );
}

type CachedPlanRecord = {
  key: string;
  plan: CoachPlanResponse;
  cachedAt: string;
};

async function loadPlanCache(): Promise<CachedPlanRecord[]> {
  const raw = await AsyncStorage.getItem(COACH_PLAN_CACHE_KEY);
  if (!raw) {
    return [];
  }

  try {
    const records = JSON.parse(raw) as CachedPlanRecord[];
    return Array.isArray(records) ? records : [];
  } catch {
    return [];
  }
}

export async function loadCachedCoachPlan(key: string): Promise<CoachPlanResponse | null> {
  const records = await loadPlanCache();
  return records.find((record) => record.key === key)?.plan ?? null;
}

export async function saveCachedCoachPlan(key: string, plan: CoachPlanResponse): Promise<void> {
  const records = await loadPlanCache();
  const nextRecords = [
    {
      key,
      plan,
      cachedAt: new Date().toISOString(),
    },
    ...records.filter((record) => record.key !== key),
  ].slice(0, 30);

  await AsyncStorage.setItem(COACH_PLAN_CACHE_KEY, JSON.stringify(nextRecords));
}

export async function loadNotificationsEnabled(): Promise<boolean> {
  return (await AsyncStorage.getItem(NOTIFICATIONS_ENABLED_KEY)) === "true";
}

export async function saveNotificationsEnabled(enabled: boolean): Promise<void> {
  await AsyncStorage.setItem(NOTIFICATIONS_ENABLED_KEY, String(enabled));
}

export async function loadScheduledNotificationIds(): Promise<string[]> {
  const raw = await AsyncStorage.getItem(NOTIFICATION_IDS_KEY);
  if (!raw) {
    return [];
  }

  try {
    const ids = JSON.parse(raw) as string[];
    return Array.isArray(ids) ? ids.filter((id) => typeof id === "string") : [];
  } catch {
    return [];
  }
}

export async function saveScheduledNotificationIds(ids: string[]): Promise<void> {
  await AsyncStorage.setItem(NOTIFICATION_IDS_KEY, JSON.stringify(ids));
}
