import {
  CoachPlanResponse,
  CoachToneMode,
  DailyPlan,
  DiaryEntry,
  LatestHealthResponse,
  UserProfile,
} from "../types";
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

export function buildLocalStructuredPlan(
  health: LatestHealthResponse | null,
  profile: UserProfile,
  tone: CoachToneMode,
  personalityStrength: number,
  diaryEntries: DiaryEntry[]
): CoachPlanResponse {
  const latest = health?.latestDay;
  const movementScore = latest ? clampScore((latest.steps / latest.stepGoal) * 100) : 60;
  const stressScore = latest ? clampScore(100 - latest.stressScore) : 60;
  const hasLateContext = diaryEntries.some((entry) =>
    `${entry.text} ${entry.tags.join(" ")}`.toLowerCase().includes("late")
  );
  const routineScore = hasLateContext || health?.latestDay.glucoseProxy === "Caution" ? 52 : 68;
  const recoveryScore = latest?.recoveryScore ?? 60;
  const sleepScore = latest?.sleepScore ?? 60;
  const overallScore = clampScore(
    recoveryScore * 0.3 + sleepScore * 0.25 + stressScore * 0.2 + movementScore * 0.15 + routineScore * 0.1
  );
  const lowRecovery = recoveryScore < 55;
  const first = firstName(profile);

  const categoryScores = [
    {
      id: "recovery",
      label: "Recovery",
      score: recoveryScore,
      status: scoreStatus(recoveryScore),
      explanation: lowRecovery
        ? "Your recovery is asking for a lighter day. The goal is to keep rhythm without forcing intensity."
        : "Your recovery gives you room to move today. Keep the session controlled so it builds you up.",
    },
    {
      id: "sleep",
      label: "Sleep",
      score: sleepScore,
      status: scoreStatus(sleepScore),
      explanation:
        sleepScore < 70
          ? "Sleep is the biggest lever tonight. Start winding down earlier so tomorrow feels easier."
          : "Sleep is supporting the plan. Repeat the same evening rhythm and keep it simple.",
    },
    {
      id: "stress",
      label: "Stress",
      score: stressScore,
      status: scoreStatus(stressScore),
      explanation:
        latest && latest.stressScore >= 60
          ? "Stress is high enough to affect recovery. A breathing reset and lighter load are the best trades."
          : "Stress is not the limiter right now. Short breaks and daylight should keep it stable.",
    },
    {
      id: "movement",
      label: "Movement",
      score: movementScore,
      status: scoreStatus(movementScore),
      explanation:
        movementScore < 60
          ? "Movement is behind pace, but the fix is small. A few short walks will do more than one forced workout."
          : "Movement is on pace. Keep it steady and avoid adding extra effort just to chase a number.",
    },
    {
      id: "routine",
      label: "Nutrition + routine",
      score: routineScore,
      status: scoreStatus(routineScore),
      explanation:
        routineScore < 60
          ? "Routine drift is probably part of the signal. Eat earlier and make the evening easier to follow."
          : "Your routine context looks stable. Keep meals predictable and hydration early.",
    },
  ];

  return {
    headline: health?.headline ?? `Let's build a cleaner day, ${first}.`,
    summary: `${toneIntro(tone, personalityStrength)} ${health?.summary ?? "The coach is combining your signals into a simple plan instead of making you interpret raw numbers."}`,
    status: scoreStatus(overallScore),
    overallScore,
    categoryScores,
    cards: categoryScores.slice(0, 3),
    tasks: [
      {
          id: "hydrate",
          title: "Hydrate",
          detail: taskCopy(tone, personalityStrength, "Drink water early before the afternoon slump hits."),
          category: "hydration",
        },
      {
        id: "breathe",
        title: "Breathe",
        detail: latest && latest.stressScore >= 60 ? "Take five slow minutes now to downshift the stress signal." : "Use one short reset to keep the calm trend intact.",
        category: "breath",
      },
      {
        id: "stand",
        title: "Stand",
        detail: "Break up long sitting blocks so movement supports recovery.",
        category: "movement",
      },
      {
        id: "walk",
        title: "Walk",
        detail: lowRecovery ? "Keep it easy; a short walk is enough stimulus for today." : "Use a brisk walk to lock in energy without draining the system.",
        category: "movement",
      },
      {
        id: "wind-down",
        title: "Wind down",
        detail: "Protect the last 45 minutes before bed so sleep can do the heavy lifting tonight.",
        category: "sleep",
      },
    ],
    alerts: [
      {
        id: "water",
        title: "Time for water",
        detail: alertCopy(tone, personalityStrength, "A quiet hydration nudge helps the plan work without adding another thing to remember."),
        subtle: true,
      },
      {
        id: "breath",
        title: "Take a deep breath",
        detail: "The coach will nudge breathing when stress or recovery starts to drift.",
        subtle: true,
      },
    ],
    workoutOfTheDay: lowRecovery
      ? {
          id: "supported-squat-hold",
          title: "Supported squat hold",
          label: "Recovery",
          duration: "8 min",
          why: "Your recovery is low, so this adds circulation and mobility without turning today into a hard session.",
          cues: ["Keep your feet flat.", "Breathe slowly.", "Stop before it feels like a workout."],
          mediaPrompt: "10 second clean loop of a supported bodyweight squat hold in a bright studio.",
          videoAssetKey: tone,
        }
      : {
          id: "tempo-push-up",
          title: "Tempo push-up",
          label: "Strength",
          duration: "10 min",
          why: "Your signals support controlled strength work, and this gives you useful stimulus without a full circuit.",
          cues: ["Lower for three seconds.", "Keep ribs tucked.", "Leave two reps in reserve."],
          mediaPrompt: "10 second clean loop of a slow tempo push-up in a minimalist gym.",
          videoAssetKey: tone,
        },
    trendInsights: [
      {
        id: "sleep",
        title: "Restorative sleep",
        status: sleepScore >= 70 ? "Improving" : "Drifting",
        explanation: sleepScore >= 70 ? "Sleep is becoming a stronger base for recovery." : "Sleep needs protection before the rest of the plan gets more ambitious.",
        values: [52, 58, 61, sleepScore],
      },
      {
        id: "movement",
        title: "Movement load",
        status: movementScore >= 75 ? "On pace" : "Light",
        explanation: movementScore >= 75 ? "Movement volume is solid, so the plan avoids extra load." : "Movement is light enough that short walks will help without competing with recovery.",
        values: [42, 55, 64, movementScore],
      },
      {
        id: "recovery",
        title: "System recovery",
        status: recoveryScore >= 60 ? "Rebuilding" : "Needs reset",
        explanation: recoveryScore >= 60 ? "Recovery is strong enough for controlled work." : "Recovery is the limiter, so today's coaching is conservative on purpose.",
        values: [50, 55, 58, recoveryScore],
      },
    ],
    correlations: [
      {
        id: "late-meals",
        title: "Late meals",
        explanation: hasLateContext || health?.latestDay.glucoseProxy === "Caution" ? "Late eating is lining up with weaker overnight recovery, so dinner moves earlier." : "Earlier meals appear to support steadier sleep and morning readiness.",
      },
      {
        id: "sunlight",
        title: "Morning sunlight",
        explanation: "Days with daylight and short walks are better candidates for stable afternoon energy.",
      },
    ],
    coachTone: tone,
    personalityStrength,
  };
}

export async function generateStructuredPlan(
  health: LatestHealthResponse | null,
  profile: UserProfile,
  tone: CoachToneMode,
  personalityStrength: number,
  diaryEntries: DiaryEntry[]
): Promise<CoachPlanResponse> {
  const fallback = buildLocalStructuredPlan(health, profile, tone, personalityStrength, diaryEntries);
  const apiBase = inferDevApiBase();
  if (!apiBase) {
    return fallback;
  }

  try {
    const response = await fetch(`${apiBase}/coach/plan`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ structured: true, profile, tone, personalityStrength, diaryEntries }),
    });
    if (response.ok) {
      const payload = (await response.json()) as CoachPlanResponse;
      if (payload.headline && typeof payload.overallScore === "number") {
        return payload;
      }
    }
  } catch {
    // Fall back to local structured output.
  }

  return fallback;
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

function clampScore(score: number) {
  return Math.max(0, Math.min(100, Math.round(score)));
}

function scoreStatus(score: number) {
  if (score >= 80) {
    return "Optimized";
  }
  if (score >= 65) {
    return "Steady";
  }
  if (score >= 50) {
    return "Needs attention";
  }
  return "Reset day";
}

function toneIntro(tone: CoachToneMode, strength: number) {
  switch (tone) {
    case "direct":
      return strength >= 4 ? "Here is the move today, no fluff." : "Here is the move today.";
    case "hype":
      return strength >= 4 ? "Lock in: you have a clean shot at a strong day." : "You have a clean shot at a strong day.";
    case "nice":
      return strength >= 4 ? "You are not off track; today just needs a kind reset and a little structure." : "You are doing enough; today just needs a little structure.";
    case "unhinged":
      if (strength >= 5) {
        return "Alright, chaos mode: we are not raw-dogging this day on shaky signals, so here is the damn plan.";
      }
      if (strength >= 3) {
        return "Tiny chaos, useful plan: we are steering the ship before the day steals the wheel.";
      }
      return "Slightly chaotic but useful: here is the plan before the day gets weird.";
    default:
      return strength >= 4 ? "Keep this very simple and very kind to your system." : "Keep this simple and kind to your system.";
  }
}

function taskCopy(tone: CoachToneMode, strength: number, base: string) {
  if (tone === "unhinged" && strength >= 4) {
    return "Hydrate before your brain starts filing complaints. Simple, boring, annoyingly effective.";
  }
  if (tone === "direct" && strength >= 4) {
    return "Drink water early. Do not wait until you already feel flat.";
  }
  return base;
}

function alertCopy(tone: CoachToneMode, strength: number, base: string) {
  if (tone === "unhinged" && strength >= 4) {
    return "Tiny hydration alarm because apparently bodies need maintenance. Drink the damn water.";
  }
  if (tone === "hype" && strength >= 4) {
    return "Quick water hit. Easy win, better energy, keep moving.";
  }
  return base;
}
