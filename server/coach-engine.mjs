function average(numbers) {
  if (!numbers.length) {
    return 0;
  }
  return numbers.reduce((sum, value) => sum + value, 0) / numbers.length;
}

function percentDelta(value, baseline) {
  if (!baseline) {
    return 0;
  }
  return ((value - baseline) / baseline) * 100;
}

function toneForScore(score, inverse = false) {
  if (inverse) {
    if (score >= 70) {
      return "alert";
    }
    if (score >= 55) {
      return "caution";
    }
    return "good";
  }

  if (score >= 75) {
    return "good";
  }
  if (score >= 55) {
    return "caution";
  }
  return "alert";
}

function buildHeadline(day) {
  if (day.recovery.score < 45) {
    return "Your body is asking for a lighter day.";
  }
  if (day.recovery.score < 60) {
    return "Today should be more stable than ambitious.";
  }
  return "You have room to build, not force.";
}

function buildSummary(day) {
  if (day.recovery.score < 45) {
    return "Recovery is low, sleep debt is visible, and stress is high enough that the best trade today is to reduce load and rebuild rhythm.";
  }
  if (day.mealTiming.lateMeal) {
    return "Your routine is not collapsing, but late fuel timing and mild sleep drift are keeping recovery from settling.";
  }
  return "The signal stack is moving in a good direction. Protect the routine that is making recovery, stress, and movement look steadier.";
}

function buildInsights(day, priorDays) {
  const hrvDelta = Math.round(percentDelta(day.hrv.dailyValue, day.hrv.baseline));
  const averageSleep = Math.round(average(priorDays.map((entry) => entry.sleep.score)));
  const insights = [];

  insights.push({
    title: "Recovery sets the tone",
    text:
      day.recovery.score < 50
        ? `Recovery is ${day.recovery.score}/100, so today should protect rhythm rather than chase performance.`
        : `Recovery is ${day.recovery.score}/100, which gives you room for consistent movement without overreaching.`,
    tone: toneForScore(day.recovery.score),
  });

  insights.push({
    title: "Sleep is changing the rest of the stack",
    text:
      day.sleep.score < averageSleep
        ? `Sleep score is ${day.sleep.score}/100 against a recent ${averageSleep}/100 trend, which helps explain the current stress and HRV picture.`
        : `Sleep score is ${day.sleep.score}/100 and is supporting a steadier recovery trend than earlier in the week.`,
    tone: toneForScore(day.sleep.score),
  });

  insights.push({
    title: "HRV is context, not a verdict",
    text:
      hrvDelta < -10
        ? `HRV is ${day.hrv.dailyValue} ms, about ${Math.abs(hrvDelta)}% below baseline, which supports a lower-load day.`
        : `HRV is ${day.hrv.dailyValue} ms and is holding close enough to baseline to support steady training, not heroics.`,
    tone: hrvDelta < -10 ? "caution" : "good",
  });

  if (day.mealTiming.lateMeal) {
    insights.push({
      title: "Meal timing is likely part of the drift",
      text: "Late eating is a reasonable explanation for the glucose-proxy caution flag and the slower overnight recovery pattern.",
      tone: "caution",
    });
  } else {
    insights.push({
      title: "Routine consistency is paying off",
      text: "Earlier meals, steadier sleep timing, and regular movement are lining up with the better recovery pattern.",
      tone: "good",
    });
  }

  return insights.slice(0, 4);
}

function buildRiskFlags(day, stale) {
  const flags = [];

  if (stale) {
    flags.push({
      title: "Recent sync missing",
      text: "This data may be incomplete because the most recent phone sync is getting old relative to the band's storage window.",
    });
  }

  if (day.recovery.score < 45) {
    flags.push({
      title: "Low recovery day",
      text: "The combination of recovery, HRV, and stress suggests that intensity is a poor trade today.",
    });
  }

  if (day.temperature.baselineDeltaC >= 0.5) {
    flags.push({
      title: "Temperature drift",
      text: "Temperature is elevated enough above baseline to justify a more conservative day.",
    });
  }

  if (day.mealTiming.lateMeal) {
    flags.push({
      title: "Late-meal glucose proxy",
      text: "Recent late eating likely contributed to slower overnight recovery and a less stable morning state.",
    });
  }

  return flags.slice(0, 3);
}

function buildActionPlan(day) {
  const actions = [];

  actions.push({
    title: "Protect the next sleep window",
    text:
      day.sleep.score < 70
        ? "Start winding down 45 minutes earlier than usual and remove stimulation from the last part of the evening."
        : "Keep the current sleep routine intact tonight so the recent gains continue.",
  });

  actions.push({
    title: "Match movement to recovery",
    text:
      day.recovery.score < 50
        ? "Keep movement easy: a short walk, mobility, or a low-pressure session is enough."
        : "Use a steady session today, but keep it controlled and stop short of draining yourself.",
  });

  actions.push({
    title: "Stabilize meals and hydration",
    text:
      day.mealTiming.lateMeal
        ? "Move dinner earlier, keep meals more even, and front-load hydration before the afternoon fades."
        : "Keep meals steady and hydration early so the current recovery pattern stays intact.",
  });

  actions.push({
    title: "Reduce stress at the source",
    text:
      day.stress.score >= 60
        ? "Do one deliberate calming intervention before noon: daylight, an easy walk, or five minutes of slow breathing."
        : "Use small movement breaks and daylight exposure to preserve the lower-stress pattern.",
  });

  return actions;
}

function buildMetricCards(day) {
  return [
    {
      id: "recovery",
      label: "Recovery",
      value: `${day.recovery.score}/100`,
      context: "Overall readiness",
      tone: toneForScore(day.recovery.score),
    },
    {
      id: "sleep",
      label: "Sleep",
      value: `${day.sleep.score}/100`,
      context: `${Math.round(day.sleep.durationMinutes / 60)}h ${day.sleep.durationMinutes % 60}m`,
      tone: toneForScore(day.sleep.score),
    },
    {
      id: "hrv",
      label: "HRV",
      value: `${day.hrv.dailyValue} ms`,
      context: `Baseline ${day.hrv.baseline} ms`,
      tone: percentDelta(day.hrv.dailyValue, day.hrv.baseline) < -10 ? "caution" : "good",
    },
    {
      id: "stress",
      label: "Stress",
      value: day.stress.label,
      context: `Score ${day.stress.score}/100`,
      tone: toneForScore(day.stress.score, true),
    },
    {
      id: "steps",
      label: "Steps",
      value: `${day.steps.count.toLocaleString()}`,
      context: `Goal ${day.steps.goal.toLocaleString()}`,
      tone: day.steps.count >= day.steps.goal ? "good" : "caution",
    },
    {
      id: "temperature",
      label: "Temperature",
      value: day.temperature.baselineDeltaC >= 0 ? `+${day.temperature.baselineDeltaC.toFixed(1)}°C` : `${day.temperature.baselineDeltaC.toFixed(1)}°C`,
      context: "Vs your baseline",
      tone: day.temperature.baselineDeltaC >= 0.5 ? "alert" : "neutral",
    },
  ];
}

function clampScore(score) {
  return Math.max(0, Math.min(100, Math.round(score)));
}

function scoreStatus(score, inverse = false) {
  const normalized = inverse ? 100 - score : score;
  if (normalized >= 80) {
    return "Optimized";
  }
  if (normalized >= 65) {
    return "Steady";
  }
  if (normalized >= 50) {
    return "Needs attention";
  }
  return "Reset day";
}

function buildCoachTasks(day) {
  const tasks = [
    {
      id: "hydrate",
      title: "Hydrate",
      detail: "Drink water early and keep it steady before the afternoon slump hits.",
      category: "hydration",
    },
    {
      id: "breathe",
      title: "Breathe",
      detail:
        day.stress.score >= 60
          ? "Take five slow minutes now to downshift your stress signal."
          : "Use one short breathing reset to keep the calm trend intact.",
      category: "breath",
    },
    {
      id: "stand",
      title: "Stand",
      detail: "Break up long sitting blocks so movement supports recovery instead of becoming another workout.",
      category: "movement",
    },
    {
      id: "walk",
      title: "Walk",
      detail:
        day.recovery.score < 50
          ? "Keep it easy; a short walk is enough stimulus for today."
          : "Use a brisk walk to lock in energy without draining the system.",
      category: "movement",
    },
    {
      id: "wind-down",
      title: "Wind down",
      detail: "Protect the last 45 minutes before bed so sleep can do the heavy lifting tonight.",
      category: "sleep",
    },
  ];

  if (day.mealTiming.lateMeal) {
    tasks.splice(4, 0, {
      id: "eat-earlier",
      title: "Eat earlier",
      detail: "Move dinner earlier tonight; late fuel is likely part of the recovery drift.",
      category: "nutrition",
    });
  }

  return tasks.slice(0, 6);
}

function buildCoachAlerts(day) {
  const alerts = [
    {
      id: "water",
      title: "Time for water",
      detail: "A quiet hydration nudge helps the plan work without adding another task to remember.",
      subtle: true,
    },
  ];

  if (day.stress.score >= 60) {
    alerts.push({
      id: "breath",
      title: "Take a deep breath",
      detail: "Stress is high enough that a two-minute reset is worth doing before the day stacks up.",
      subtle: true,
    });
  }

  if (day.steps.count < day.steps.goal * 0.55) {
    alerts.push({
      id: "stand",
      title: "Stand up",
      detail: "Movement is behind pace, so a short standing break is the lowest-friction win.",
      subtle: true,
    });
  }

  if (day.sleep.score < 70) {
    alerts.push({
      id: "sleep",
      title: "Start wind-down early",
      detail: "Sleep is the biggest lever tonight; start earlier instead of trying to fix it at bedtime.",
      subtle: true,
    });
  }

  return alerts.slice(0, 4);
}

function buildWorkoutOfTheDay(day, profile = {}) {
  if (day.recovery.score < 50 || day.stress.score >= 70) {
    return {
      id: "box-breathing-squat-hold",
      title: "Supported squat hold",
      label: "Recovery",
      duration: "8 min",
      why: "Your recovery is low, so this gives you circulation, mobility, and a reset without turning today into a hard session.",
      cues: [
        "Keep your feet flat and chest tall.",
        "Breathe slowly for four counts in and six counts out.",
        "Stop before it feels like a workout.",
      ],
      mediaPrompt:
        "10 second clean loop of a trainer demonstrating a supported bodyweight squat hold in a bright minimalist studio, calm premium wellness style.",
    };
  }

  const prefersStrength = /lift|strength|gym|weights/i.test(profile.exerciseType || profile.goals || "");
  if (prefersStrength) {
    return {
      id: "tempo-push-up",
      title: "Tempo push-up",
      label: "Strength",
      duration: "10 min",
      why: "Recovery gives you room for controlled strength work, and this balances push strength without needing equipment.",
      cues: [
        "Lower for three seconds.",
        "Keep ribs tucked and neck long.",
        "Leave two good reps in reserve.",
      ],
      mediaPrompt:
        "10 second clean loop of a trainer demonstrating a slow tempo push-up on a mat in a bright minimalist gym, premium health app style.",
    };
  }

  return {
    id: "interval-walk",
    title: "Walk-run pickups",
    label: "Interval",
    duration: "12 min",
    why: "Your signals support some intensity, but short pickups keep it productive instead of draining.",
    cues: [
      "Warm up for three easy minutes.",
      "Alternate 30 seconds quick with 90 seconds easy.",
      "Finish feeling better than when you started.",
    ],
    mediaPrompt:
      "10 second clean loop of a runner doing relaxed track pickups on a soft morning, premium calm fitness app style.",
  };
}

function normalizedStrength(strength) {
  return Math.max(1, Math.min(5, Math.round(Number(strength) || 3)));
}

function tonePrefix(tone, strength = 3) {
  const level = normalizedStrength(strength);
  if (tone === "hype") {
    return level >= 4
      ? "Lock in: you have a clean shot at a strong day."
      : "You have a clean shot at a strong day.";
  }
  if (tone === "direct") {
    return level >= 4 ? "Here is the move today, no fluff." : "Here is the move today.";
  }
  if (tone === "nice") {
    return level >= 4
      ? "You are not off track; today just needs a kind reset and a little structure."
      : "You are doing enough; today just needs a little structure.";
  }
  if (tone === "unhinged") {
    if (level >= 5) {
      return "Alright, chaos mode: we are not raw-dogging this day on shaky signals, so here is the damn plan.";
    }
    if (level >= 3) {
      return "Tiny chaos, useful plan: we are steering the ship before the day steals the wheel.";
    }
    return "Slightly chaotic but useful: here is the plan before the day gets weird.";
  }
  return level >= 4
    ? "Keep this very simple and very kind to your system."
    : "Keep this simple and kind to your system.";
}

export function buildStructuredCoachPlan(
  state,
  { profile = {}, tone = "gentle", personalityStrength = 3, diaryEntries = [] } = {}
) {
  const days = state.days;
  const latestDay = days[days.length - 1];
  const strength = normalizedStrength(personalityStrength);
  const priorDays = days.slice(Math.max(0, days.length - 7), days.length);
  const movementScore = clampScore((latestDay.steps.count / latestDay.steps.goal) * 100);
  const stressScore = clampScore(100 - latestDay.stress.score);
  const diaryHasLateMeal = diaryEntries.some((entry) => /late|ate late|dinner/i.test(`${entry.text} ${entry.tags?.join(" ")}`));
  const routineScore = diaryHasLateMeal || latestDay.mealTiming.lateMeal ? 52 : 68;
  const overallScore = clampScore(
    latestDay.recovery.score * 0.3 +
      latestDay.sleep.score * 0.25 +
      stressScore * 0.2 +
      movementScore * 0.15 +
      routineScore * 0.1
  );

  const status = scoreStatus(overallScore);
  const categoryScores = [
    {
      id: "recovery",
      label: "Recovery",
      score: latestDay.recovery.score,
      status: scoreStatus(latestDay.recovery.score),
      explanation:
        latestDay.recovery.score < 55
          ? "Your recovery is asking for a lighter day. The win is to preserve rhythm instead of forcing intensity."
          : "Your recovery gives you room to train, but the coach still wants clean execution over max effort.",
    },
    {
      id: "sleep",
      label: "Sleep",
      score: latestDay.sleep.score,
      status: scoreStatus(latestDay.sleep.score),
      explanation:
        latestDay.sleep.score < 70
          ? "Sleep is the biggest lever tonight. Start winding down earlier so tomorrow is easier to coach."
          : "Sleep is supporting the rest of your health stack. Keep the evening routine boring and repeatable.",
    },
    {
      id: "stress",
      label: "Stress",
      score: stressScore,
      status: scoreStatus(stressScore),
      explanation:
        latestDay.stress.score >= 60
          ? "Stress is loud enough to change the plan. Use a breathing reset and lower the training load."
          : "Stress is not the limiting factor right now. Keep breaks and daylight in the day so it stays that way.",
    },
    {
      id: "movement",
      label: "Movement",
      score: movementScore,
      status: scoreStatus(movementScore),
      explanation:
        movementScore < 60
          ? "Movement is behind pace, but you do not need a huge workout. A few short walks will move the needle."
          : "Movement is doing its job. Keep it steady and avoid adding extra intensity just because the number looks good.",
    },
    {
      id: "routine",
      label: "Nutrition + routine",
      score: routineScore,
      status: scoreStatus(routineScore),
      explanation:
        routineScore < 60
          ? "Late food or routine drift is probably affecting recovery. Eat earlier and make the evening simpler."
          : "Your routine context looks stable enough. Keep meals predictable and hydration front-loaded.",
    },
  ];

  const recoveryValues = priorDays.map((day) => day.recovery.score);
  const sleepValues = priorDays.map((day) => day.sleep.score);
  const stressValues = priorDays.map((day) => 100 - day.stress.score);

  return {
    headline: buildHeadline(latestDay),
    summary: `${tonePrefix(tone, strength)} ${buildSummary(latestDay)}`,
    status,
    overallScore,
    categoryScores,
    cards: categoryScores.slice(0, 3),
    tasks: buildCoachTasks(latestDay),
    alerts: buildCoachAlerts(latestDay),
    workoutOfTheDay: buildWorkoutOfTheDay(latestDay, profile),
    trendInsights: [
      {
        id: "sleep",
        title: "Restorative sleep",
        status: sleepValues[sleepValues.length - 1] >= sleepValues[0] ? "Improving" : "Drifting",
        explanation:
          latestDay.sleep.score < 70
            ? "Sleep is not fully restoring you yet, so the coach is protecting tonight's wind-down window."
            : "Sleep is becoming a stronger base for recovery, which makes the rest of the plan easier.",
        values: sleepValues,
      },
      {
        id: "movement",
        title: "Movement load",
        status: movementScore >= 75 ? "On pace" : "Light",
        explanation:
          movementScore >= 75
            ? "Movement volume is solid, so the plan avoids adding unnecessary load."
            : "Movement is light enough that short walks will help without competing with recovery.",
        values: priorDays.map((day) => clampScore((day.steps.count / day.steps.goal) * 100)),
      },
      {
        id: "recovery",
        title: "System recovery",
        status: recoveryValues[recoveryValues.length - 1] >= recoveryValues[0] ? "Rebuilding" : "Needs reset",
        explanation:
          latestDay.recovery.score < 55
            ? "Recovery is still the limiter, so today's coaching is conservative on purpose."
            : "Recovery is trending well enough to support a controlled training stimulus.",
        values: recoveryValues,
      },
    ],
    correlations: [
      {
        id: "late-meals",
        title: "Late meals",
        explanation:
          latestDay.mealTiming.lateMeal || diaryHasLateMeal
            ? "Late eating is lining up with worse overnight recovery, so the coach is moving dinner earlier."
            : "Earlier meals appear to support steadier sleep and better morning readiness.",
      },
      {
        id: "morning-light",
        title: "Morning sunlight",
        explanation: "Days with daylight and short walks are better candidates for stable afternoon energy.",
      },
    ],
    coachTone: tone,
    personalityStrength: strength,
  };
}

export function buildDailyBrief(state, { availableFixtures = [] } = {}) {
  const days = state.days;
  const latestDay = days[days.length - 1];
  const priorDays = days.slice(Math.max(0, days.length - 4), days.length - 1);
  const syncedAt = new Date(state.syncedAt);
  const now = new Date();
  const stale = (now.getTime() - syncedAt.getTime()) / (1000 * 60 * 60 * 24) > 2;

  return {
    scenarioId: state.scenarioId,
    scenarioLabel: state.scenarioLabel,
    scenarioSummary: state.scenarioSummary,
    availableFixtures,
    syncStatus: {
      syncedAt: state.syncedAt,
      storageWindowDays: 7,
      stale,
      label: stale ? "Sync is getting old" : "Sync is recent",
    },
    headline: buildHeadline(latestDay),
    summary: buildSummary(latestDay),
    latestDay: {
      date: latestDay.date,
      recoveryScore: latestDay.recovery.score,
      sleepScore: latestDay.sleep.score,
      sleepDurationMinutes: latestDay.sleep.durationMinutes,
      restingHeartRate: latestDay.heart.restingBpm,
      hrv: latestDay.hrv.dailyValue,
      hrvBaseline: latestDay.hrv.baseline,
      steps: latestDay.steps.count,
      stepGoal: latestDay.steps.goal,
      stressScore: latestDay.stress.score,
      stressLabel: latestDay.stress.label,
      temperatureDeltaC: latestDay.temperature.baselineDeltaC,
      spo2Average: latestDay.spo2.average,
      bloodPressure: latestDay.bloodPressure ? `${latestDay.bloodPressure.systolic}/${latestDay.bloodPressure.diastolic}` : null,
      glucoseProxy: latestDay.mealTiming.lateMeal ? "Caution" : "Stable",
      nitricOxideProxy: latestDay.steps.count < 6000 ? "Could improve" : "Supported",
    },
    insights: buildInsights(latestDay, priorDays),
    riskFlags: buildRiskFlags(latestDay, stale),
    actionPlan: buildActionPlan(latestDay),
    metricCards: buildMetricCards(latestDay),
  };
}

export function buildTimeline(state) {
  const points = state.days.map((day) => ({
    date: day.date,
    recoveryScore: day.recovery.score,
    sleepScore: day.sleep.score,
    hrv: day.hrv.dailyValue,
    steps: day.steps.count,
    stressScore: day.stress.score,
  }));

  const first = points[0];
  const last = points[points.length - 1];
  const recoveryDelta = last.recoveryScore - first.recoveryScore;
  const sleepDelta = last.sleepScore - first.sleepScore;
  const stressDelta = last.stressScore - first.stressScore;

  let trendSummary = "The past week is relatively stable.";
  if (recoveryDelta <= -8 || stressDelta >= 8) {
    trendSummary = "The last week points to a recovery dip, not a motivation problem.";
  } else if (recoveryDelta >= 8 || sleepDelta >= 8) {
    trendSummary = "The last week shows a steadier routine and a healthier recovery trend.";
  } else if (last.steps < first.steps) {
    trendSummary = "The pattern looks flatter than ideal, with movement slipping more than recovery is improving.";
  }

  return {
    scenarioId: state.scenarioId,
    trendSummary,
    points,
  };
}

export function buildHealthPromptContext(state) {
  const latestDay = state.days[state.days.length - 1];
  return [
    `Latest synced day: ${latestDay.date}`,
    `Recovery: ${latestDay.recovery.score}/100`,
    `Sleep: ${latestDay.sleep.score}/100 for ${latestDay.sleep.durationMinutes} minutes`,
    `HRV: ${latestDay.hrv.dailyValue} ms vs ${latestDay.hrv.baseline} ms baseline`,
    `Resting HR: ${latestDay.heart.restingBpm} bpm`,
    `Stress: ${latestDay.stress.label} (${latestDay.stress.score}/100)`,
    `Steps: ${latestDay.steps.count}`,
    `Temperature delta: ${latestDay.temperature.baselineDeltaC.toFixed(1)} C`,
    `Late meal pattern: ${latestDay.mealTiming.lateMeal ? "yes" : "no"}`,
  ].join("\n");
}
