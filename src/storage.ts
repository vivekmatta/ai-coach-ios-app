import AsyncStorage from "@react-native-async-storage/async-storage";

import { defaultProfile } from "./data";
import { UserProfile } from "./types";

const PROFILE_KEY = "ai_coach_profile";
const ONBOARDING_KEY = "ai_coach_onboarding_complete";

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
