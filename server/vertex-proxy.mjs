import { createServer } from "node:http";

import { buildDailyBrief, buildHealthPromptContext, buildTimeline } from "./coach-engine.mjs";
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
    const config = getAiChatConfig();
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
