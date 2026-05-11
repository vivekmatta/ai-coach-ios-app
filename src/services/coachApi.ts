import { DailyPlan, UserProfile } from "../types";
import { inferDevApiBase } from "./apiBase";

function firstName(profile: UserProfile) {
  return profile.name.trim().split(" ")[0] || "there";
}

export async function generatePlan(
  prompt: string,
  profile: UserProfile,
  daily: DailyPlan
): Promise<string> {
  const apiBase = inferDevApiBase();
  if (apiBase) {
    try {
      const response = await fetch(`${apiBase}/coach/plan`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ prompt, profile, daily }),
      });
      if (response.ok) {
        const payload = (await response.json()) as { text?: string };
        if (payload.text) {
          return payload.text;
        }
      }
    } catch {
      // Fall back to local prototype output.
    }
  }

  await delay(700);

  return [
    `Plan for ${firstName(profile)}`,
    "",
    "Today",
    `- Main priority: ${daily.summary}`,
    `- Movement: ${daily.workout}`,
    `- Hydration: ${daily.hydration}`,
    "",
    "This week",
    "- Protect a consistent sleep window for the next 4 nights.",
    "- Keep 2 days truly easy before adding any harder training.",
    "- Front-load daylight, movement snacks, and hydration during the morning.",
    "- Review whether late eating or high caffeine is making recovery worse.",
    "",
    `Requested focus: ${prompt}`,
  ].join("\n");
}

export async function sendCoachMessage(
  message: string,
  profile: UserProfile
): Promise<string> {
  const apiBase = inferDevApiBase();
  if (apiBase) {
    try {
      const response = await fetch(`${apiBase}/coach/chat`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ message, profile }),
      });
      if (response.ok) {
        const payload = (await response.json()) as { text?: string };
        if (payload.text) {
          return payload.text;
        }
      }
    } catch {
      // Fall back to local prototype output.
    }
  }

  await delay(800);
  const name = firstName(profile);

  if (/plan|today/i.test(message)) {
    return `${name}, today should be a low-load day. Keep movement easy, hydrate early, and protect a 10 pm bedtime so recovery can rebound.`;
  }

  if (/sleep/i.test(message)) {
    return `Your sleep is likely driving the rest of the signal stack today. The fastest fix is an earlier wind-down, lower late-day stimulation, and no attempt to “train through” the fatigue.`;
  }

  if (/stress/i.test(message)) {
    return `The stress pattern looks physiological, not just mental. Do one short reset now, reduce unnecessary effort this afternoon, and make tonight boring in the best way.`;
  }

  return `I’d treat today as a restore-and-stabilize day, ${name}. Keep the plan simple: easy movement, steady meals, lower stimulation, and an early night.`;
}

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
