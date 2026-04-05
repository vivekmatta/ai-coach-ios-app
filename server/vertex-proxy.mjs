import { createServer } from "node:http";

import {
  formatRetrievedContext,
  loadVectorDb,
  retrieveRelevantChunks,
  vectorDbExists,
} from "./vector-store.mjs";
import { callVertexGenerate, getVertexConfig } from "./vertex-client.mjs";

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

function buildPlanPrompt(prompt, profile, daily) {
  return [
    `User request: ${prompt}`,
    "",
    "User profile:",
    `- Name: ${profile?.name || "Alex"}`,
    `- Goals: ${profile?.goals || "Improve overall wellness"}`,
    `- Exercise days/week: ${profile?.exerciseDays || "Not provided"}`,
    `- Preferred movement: ${profile?.exerciseType || "Not provided"}`,
    `- Sleep time: ${profile?.sleepTime || "Not provided"}`,
    `- Caffeine: ${profile?.caffeine || "Not provided"}`,
    `- Work stress: ${profile?.workStress || "Not provided"}`,
    "",
    "Current daily guidance:",
    `- Summary: ${daily?.summary || "Recovery is low today."}`,
    `- Bedtime: ${daily?.bedtime || "10:00 pm target."}`,
    `- Workout: ${daily?.workout || "Keep movement easy."}`,
    `- Hydration: ${daily?.hydration || "Hydrate earlier in the day."}`,
    `- Nutrition: ${daily?.nutrition || "Prefer steady meals and avoid late heavy eating."}`,
  ].join("\n");
}

const server = createServer(async (req, res) => {
  if (req.method === "OPTIONS") {
    res.writeHead(204, corsHeaders);
    res.end();
    return;
  }

  try {
    if (req.method === "GET" && req.url === "/health") {
      const { projectId, chatModel, location, credentialsPath } = await getVertexConfig();
      const hasVectorDb = await vectorDbExists();
      const db = hasVectorDb ? await loadVectorDb() : null;
      writeJson(res, 200, {
        ok: true,
        provider: "vertex-ai",
        projectId,
        model: chatModel,
        location,
        credentialsPath,
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

    if (req.method === "POST" && req.url === "/coach/chat") {
      const body = await readJsonBody(req);
      const message = body.message || "Give me a practical coaching response for today.";
      const contextChunks = await retrieveRelevantChunks(message);
      const context = formatRetrievedContext(contextChunks);
      const text = await callVertexGenerate({
        systemInstruction: [buildSystemInstruction(body.profile, "chat"), context ? `Relevant research context:\n${context}` : ""]
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

    if (req.method === "POST" && req.url === "/coach/plan") {
      const body = await readJsonBody(req);
      const prompt = body.prompt || "Create my weekly plan.";
      const contextChunks = await retrieveRelevantChunks(prompt);
      const context = formatRetrievedContext(contextChunks);
      const text = await callVertexGenerate({
        systemInstruction: [buildSystemInstruction(body.profile, "plan"), context ? `Relevant research context:\n${context}` : ""]
          .filter(Boolean)
          .join("\n\n"),
        userText: buildPlanPrompt(prompt, body.profile, body.daily),
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
