import AsyncStorage from "@react-native-async-storage/async-storage";

import { defaultProfile } from "./data";
import { CoachToneMode, DiaryEntry, UserProfile } from "./types";

const PROFILE_KEY = "ai_coach_profile";
const ONBOARDING_KEY = "ai_coach_onboarding_complete";
const DIARY_KEY = "ai_coach_diary_entries";
const COACH_TONE_KEY = "ai_coach_tone";
const PERSONALITY_STRENGTH_KEY = "ai_coach_personality_strength";

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
