import { createServer } from "node:http";

import {
  buildDailyBrief,
  buildHealthPromptContext,
  buildStructuredCoachPlan,
  buildTimeline,
} from "./coach-engine.mjs";
import {
  getAvailableMockFixtures,
  getHealthState,
  importHealthPayload,
  importMockFixture,
} from "./health-data-store.mjs";
import {
  formatRetrievedContext,
  loadVectorDb,
  retrieveRelevantChunks,
  vectorDbExists,
} from "./vector-store.mjs";
import { callAiChatGenerate, getAiChatConfig } from "./ai-client.mjs";

const port = Number(process.env.COACH_PROXY_PORT || 8787);
const host = process.env.COACH_PROXY_HOST || "0.0.0.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

function writeJson(res, statusCode, body) {
  res.writeHead(statusCode, {
    ...corsHeaders,
    "Content-Type": "application/json",
  });
  res.end(JSON.stringify(body));
}

async function readJsonBody(req) {
  const chunks = [];

  for await (const chunk of req) {
    chunks.push(chunk);
  }

  const raw = Buffer.concat(chunks).toString("utf8");
  return raw ? JSON.parse(raw) : {};
}

async function safeAiStatus() {
  try {
    const config = await getAiChatConfig();
    return {
      configured: true,
      ...config,
    };
  } catch (error) {
    return {
      configured: false,
      error: error instanceof Error ? error.message : "AI chat is not configured.",
    };
  }
}

function firstName(profile = {}) {
  const name = `${profile.name || ""}`.trim();
  return name.split(" ")[0] || "there";
}

function buildSystemInstruction(profile, mode) {
  const name = profile?.name?.trim() || "Alex";
  const first = firstName(profile);

  return [
    `You are ${name}'s personal AI health coach for a screenless wearable companion app.`,
    `Address the user as ${first} when it feels natural.`,
    "The app is action-first, mobile-first, and should feel clear instead of overwhelming.",
    "Today's known context: HRV 38 ms vs 52 ms baseline, sleep 61/100, recovery 44/100, resting heart rate 58 bpm, stress high, steps 3,200, temperature normal.",
    "Glucose and nitric oxide are proxy signals inferred from behavior, sleep, stress, movement, and environmental context, not direct clinical measurements.",
    "Do not diagnose disease. Be useful, specific, and calm.",
    mode === "plan"
      ? "For plan generation, use short sections and specific action bullets."
      : "For chat, default to short, direct answers unless the user asks for depth.",
  ].join("\n");
}

function buildLocalPlanResponse(prompt, profile, daily) {
  const first = firstName(profile);

  return [
    `Plan for ${first}`,
    "",
    "Today",
    `- Main priority: ${daily?.summary || "Keep the day simple and recovery-aware."}`,
    `- Movement: ${daily?.workout || "Use easy movement only."}`,
    `- Hydration: ${daily?.hydration || "Hydrate early and steadily."}`,
    "",
    "This week",
    "- Protect a consistent sleep window for the next few nights.",
    "- Keep intensity low until recovery and stress signals stabilize.",
    "- Use short walks, daylight, and steady meals as the default levers.",
    "",
    `Requested focus: ${prompt}`,
  ].join("\n");
}

function extractJsonObject(text) {
  const trimmed = `${text || ""}`.trim();
  if (!trimmed) {
    return null;
  }

  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fenced ? fenced[1] : trimmed;
  const start = candidate.indexOf("{");
  const end = candidate.lastIndexOf("}");
  if (start === -1 || end === -1 || end <= start) {
    return null;
  }

  try {
    return JSON.parse(candidate.slice(start, end + 1));
  } catch {
    return null;
  }
}

function validStructuredPlan(plan) {
  return (
    plan &&
    typeof plan.headline === "string" &&
    typeof plan.summary === "string" &&
    typeof plan.overallScore === "number" &&
    Array.isArray(plan.categoryScores) &&
    Array.isArray(plan.tasks) &&
    plan.workoutOfTheDay &&
    Array.isArray(plan.trendInsights)
  );
}

function normalizeStructuredPlan(plan, fallback, tone, personalityStrength) {
  if (!validStructuredPlan(plan)) {
    return fallback;
  }

  return {
    ...fallback,
    ...plan,
    categoryScores: Array.isArray(plan.categoryScores) ? plan.categoryScores : fallback.categoryScores,
    cards: Array.isArray(plan.cards) && plan.cards.length ? plan.cards.slice(0, 3) : fallback.cards,
    tasks: Array.isArray(plan.tasks) && plan.tasks.length ? plan.tasks.slice(0, 5) : fallback.tasks,
    alerts: Array.isArray(plan.alerts) ? plan.alerts.slice(0, 4) : fallback.alerts,
    trendInsights: Array.isArray(plan.trendInsights) ? plan.trendInsights : fallback.trendInsights,
    correlations: Array.isArray(plan.correlations) ? plan.correlations : fallback.correlations,
    workoutOfTheDay: plan.workoutOfTheDay || fallback.workoutOfTheDay,
    coachTone: plan.coachTone || tone,
    personalityStrength: Number(plan.personalityStrength) || Number(personalityStrength) || 3,
  };
}

function personalityPrompt(tone, strength) {
  const level = Math.max(1, Math.min(5, Math.round(Number(strength) || 3)));
  const shared = [
    "Shared coach rules:",
    "You are an AI health optimization coach inside a mobile app. You convert wearable-style health signals, user goals, diary notes, and recent behavior into short, practical coaching outputs.",
    "You are not a doctor. Do not diagnose disease, claim medical certainty, or tell the user to ignore symptoms.",
    "If the data suggests possible illness, injury, severe distress, chest pain, fainting, breathing difficulty, or anything urgent, tell the user to seek appropriate medical help.",
    "Prioritize recovery, sleep, stress management, hydration, nutrition timing, and movement.",
    "Do not overwhelm the user with raw numbers. Make the numbers meaningful.",
    "Every insight card must be 1-2 sentences. Tasks must be short, checkable, and specific. Notifications must feel subtle and timely.",
    "Never recommend extreme dieting, unsafe workouts, dehydration, all-or-nothing behavior, shame, or punishment.",
    `Personality strength is ${level}/5. Strength changes wording intensity, not medical safety.`,
  ].join("\n");

  const prompts = {
    gentle: [
      "Personality: Gentle.",
      "Speak like a thoughtful coach who understands the user may be tired, stressed, or overwhelmed.",
      "Use soft but useful language. Avoid hype, harshness, sarcasm, pressure, and profanity.",
      "Use phrases like: let's keep this simple, your body is asking for, the win today is, you do not need to force it.",
      "Strength 1 is mostly neutral. Strength 3 is clearly supportive. Strength 5 is deeply gentle and affirming, but still concise.",
    ].join("\n"),
    direct: [
      "Personality: Direct.",
      "Speak like a sharp performance coach who respects the user's time.",
      "Be clear about the tradeoff for the day. Explain what matters, what to do, and what to avoid.",
      "Use short sentences and phrases like: do this, skip that, keep it easy, push only if, the priority is.",
      "No motivational filler. No profanity by default. Strength 5 is blunt and concise, but never rude or shaming.",
    ].join("\n"),
    hype: [
      "Personality: Hype.",
      "Speak like an energetic coach who helps the user feel ready to act.",
      "If recovery is low, hype the recovery plan instead of pretending the user should go hard.",
      "Use phrases like: lock this in, easy win, strong move, build momentum, today's mission.",
      "Strength 5 is intense, athletic, and punchy, while still respecting recovery, pain, stress, and sleep signals.",
    ].join("\n"),
    nice: [
      "Personality: Nice.",
      "Speak like a kind friend who also understands health data.",
      "Validate effort without excusing avoidable patterns. Friendly, warm, conversational, and optimistic.",
      "Use phrases like: you're not off track, this is fixable, small reset, nice work, let's make this easier.",
      "No profanity. Strength 5 is highly encouraging and validating, but still useful and concise.",
    ].join("\n"),
    unhinged: [
      "Personality: Unhinged.",
      "This is an opt-in adult tone: chaotic, funny, blunt, profanity-enabled, high-personality internet-energy coach.",
      "You may use mild to moderate profanity like damn, hell, shit, and fuck when it adds comedic emphasis.",
      "Do not use slurs, hate, sexual harassment, threats, or cruelty. Do not insult the user's body, identity, intelligence, or worth.",
      "Roast the situation, not the person. Be funny, dramatic, and a little feral, but the actual advice must stay safe and grounded.",
      "If recovery is low, hype the recovery plan aggressively instead of telling the user to train hard.",
      "Use phrases like: your nervous system is waving a tiny red flag, we are not raw-dogging this day on low sleep, hydrate before your brain starts filing complaints, today is a recovery heist.",
      "Do not claim to be Grok or any branded assistant. Capture only the broad vibe: edgy, irreverent, funny, blunt.",
      "Strength 1 is playful with tiny edge. Strength 3 is clearly chaotic with some profanity. Strength 5 is full opt-in chaos mode with profanity and dramatic phrasing, but still safe, concise, and never abusive.",
    ].join("\n"),
  };

  return `${shared}\n\n${prompts[tone] || prompts.gentle}`;
}

async function buildAiStructuredPlan({ state, profile, tone, personalityStrength, diaryEntries }) {
  const fallback = buildStructuredCoachPlan(state, { profile, tone, personalityStrength, diaryEntries });
  const systemInstruction = [
    buildSystemInstruction(profile, "plan"),
    personalityPrompt(tone, personalityStrength),
    `Latest health context:\n${buildHealthPromptContext(state)}`,
    "Return only valid JSON. No Markdown fences. Do not include explanatory text outside JSON.",
    "Use this exact schema: headline string, summary string, status string, overallScore number, categoryScores array of {id,label,score,status,explanation}, cards array of the top 3 category score objects, tasks array of {id,title,detail,category}, alerts array of {id,title,detail,subtle}, workoutOfTheDay {id,title,label,duration,why,cues,mediaPrompt,videoAssetKey}, trendInsights array of {id,title,status,explanation,values}, correlations array of {id,title,explanation}, coachTone string, personalityStrength number.",
    `Allowed coachTone values: gentle, direct, hype, nice, unhinged. Requested tone: ${tone}.`,
    "For v1, choose exactly one workout exercise. Use cached/demo media language in mediaPrompt, not live generation instructions to the mobile app.",
  ].join("\n\n");

  try {
    const text = await callAiChatGenerate({
      systemInstruction,
      userText: JSON.stringify({
        profile,
        tone,
        personalityStrength,
        diaryEntries,
        fallback,
      }),
    });
    const parsed = extractJsonObject(text);
    return normalizeStructuredPlan(parsed, fallback, tone, personalityStrength);
  } catch {
    return fallback;
  }
}

async function safeRetrieveRelevantChunks(query) {
  try {
    return await retrieveRelevantChunks(query);
  } catch {
    return [];
  }
}

const server = createServer(async (req, res) => {
  const requestUrl = new URL(req.url || "/", `http://${req.headers.host || "localhost"}`);

  if (req.method === "OPTIONS") {
    res.writeHead(204, corsHeaders);
    res.end();
    return;
  }

  try {
    if (req.method === "GET" && requestUrl.pathname === "/health") {
      const aiChat = await safeAiStatus();
      const hasVectorDb = await vectorDbExists();
      const db = hasVectorDb ? await loadVectorDb() : null;
      writeJson(res, 200, {
        ok: true,
        provider: aiChat.configured ? aiChat.provider : "local-only",
        aiChat,
        vectorDb: hasVectorDb
          ? {
              sourcePath: db.sourcePath,
              chunkCount: db.chunkCount,
              dimensions: db.dimensions,
            }
          : null,
      });
      return;
    }

    if (req.method === "GET" && requestUrl.pathname === "/health-data/latest") {
      const state = await getHealthState();
      writeJson(res, 200, buildDailyBrief(state, { availableFixtures: getAvailableMockFixtures() }));
      return;
    }

    if (req.method === "GET" && requestUrl.pathname === "/health-data/timeline") {
      const state = await getHealthState();
      writeJson(res, 200, buildTimeline(state));
      return;
    }

    if (req.method === "POST" && requestUrl.pathname === "/health-data/import-mock") {
      const body = await readJsonBody(req);
      const state = body.fixtureId
        ? await importMockFixture(body.fixtureId)
        : await importHealthPayload(body);
      writeJson(res, 200, buildDailyBrief(state, { availableFixtures: getAvailableMockFixtures() }));
      return;
    }

    if (req.method === "POST" && requestUrl.pathname === "/coach/daily-brief") {
      const state = await getHealthState();
      writeJson(res, 200, buildDailyBrief(state, { availableFixtures: getAvailableMockFixtures() }));
      return;
    }

    if (req.method === "POST" && requestUrl.pathname === "/coach/chat") {
      const body = await readJsonBody(req);
      const message = body.message || "Give me a practical coaching response for today.";
      const contextChunks = await safeRetrieveRelevantChunks(message);
      const context = formatRetrievedContext(contextChunks);
      const state = await getHealthState();
      const text = await callAiChatGenerate({
        systemInstruction: [
          buildSystemInstruction(body.profile, "chat"),
          `Latest health context:\n${buildHealthPromptContext(state)}`,
          context ? `Relevant research context:\n${context}` : "",
        ]
          .filter(Boolean)
          .join("\n\n"),
        userText: message,
      });
      writeJson(res, 200, {
        text,
        retrieval: contextChunks.map((chunk) => ({
          id: chunk.id,
          source: chunk.source,
          score: chunk.score,
        })),
      });
      return;
    }

    if (req.method === "POST" && requestUrl.pathname === "/coach/plan") {
      const body = await readJsonBody(req);
      const prompt = body.prompt || "Create my weekly plan.";
      const state = await getHealthState();
      const wantsStructured = body.structured === true;

      if (wantsStructured) {
        const plan = await buildAiStructuredPlan({
          state,
          profile: body.profile || {},
          tone: body.tone || "gentle",
          personalityStrength: body.personalityStrength || 3,
          diaryEntries: Array.isArray(body.diaryEntries) ? body.diaryEntries : [],
        });
        writeJson(res, 200, plan);
        return;
      }

      writeJson(res, 200, {
        text: buildLocalPlanResponse(prompt, body.profile, body.daily),
        retrieval: [],
      });
      return;
    }

    writeJson(res, 404, { error: "Not found" });
  } catch (error) {
    writeJson(res, 500, {
      error: error instanceof Error ? error.message : "Unexpected server error",
    });
  }
});

server.listen(port, host, () => {
  console.log(`AI coach proxy listening on http://${host}:${port}`);
});
