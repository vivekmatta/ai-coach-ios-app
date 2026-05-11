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
