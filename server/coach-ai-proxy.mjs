import http from "node:http";
import https from "node:https";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const port = Number(process.env.COACH_PROXY_PORT || 8790);
const host = process.env.COACH_PROXY_HOST || "0.0.0.0";
const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;
const serviceAccountPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || "secrets/google-service-account.json";
const model = process.env.VERTEXAI_MODEL || process.env.GEMINI_MODEL || "gemini-2.5-flash";
const vertexLocation = process.env.VERTEXAI_LOCATION || "us-central1";
const token = process.env.COACH_PROXY_TOKEN || "";
let serviceAccount = null;
let accessTokenCache = null;

try {
  const resolvedPath = path.resolve(serviceAccountPath);
  if (fs.existsSync(resolvedPath)) {
    serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, "utf8"));
  }
} catch (error) {
  console.warn(`Could not load service account JSON: ${error.message}`);
}

function sendJSON(response, statusCode, payload) {
  const body = JSON.stringify(payload);
  response.writeHead(statusCode, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "content-type, authorization, x-coach-proxy-token",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  });
  response.end(body);
}

function readBody(request) {
  return new Promise((resolve, reject) => {
    let body = "";
    request.setEncoding("utf8");
    request.on("data", (chunk) => {
      body += chunk;
      if (body.length > 2_000_000) {
        request.destroy(new Error("Request body is too large."));
      }
    });
    request.on("end", () => resolve(body));
    request.on("error", reject);
  });
}

function isAuthorized(request) {
  if (!token) {
    return true;
  }
  const authorization = request.headers.authorization || "";
  const headerToken = request.headers["x-coach-proxy-token"] || "";
  return authorization === `Bearer ${token}` || headerToken === token;
}

function base64url(input) {
  const buffer = Buffer.isBuffer(input) ? input : Buffer.from(input);
  return buffer
    .toString("base64")
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}

function signJWT(payload, privateKey) {
  const header = { alg: "RS256", typ: "JWT" };
  const encodedHeader = base64url(JSON.stringify(header));
  const encodedPayload = base64url(JSON.stringify(payload));
  const unsigned = `${encodedHeader}.${encodedPayload}`;
  const signature = crypto.createSign("RSA-SHA256").update(unsigned).sign(privateKey);
  return `${unsigned}.${base64url(signature)}`;
}

function postJSON({ hostname, path, headers = {}, body }) {
  return new Promise((resolve, reject) => {
    const serializedBody = typeof body === "string" ? body : JSON.stringify(body);
    const request = https.request(
      {
        hostname,
        path,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(serializedBody),
          ...headers,
        },
      },
      (response) => {
        let data = "";
        response.setEncoding("utf8");
        response.on("data", (chunk) => {
          data += chunk;
        });
        response.on("end", () => {
          if (response.statusCode < 200 || response.statusCode >= 300) {
            reject(new Error(`HTTP ${response.statusCode}: ${data}`));
            return;
          }
          try {
            resolve(JSON.parse(data));
          } catch (error) {
            reject(error);
          }
        });
      }
    );
    request.on("error", reject);
    request.write(serializedBody);
    request.end();
  });
}

async function getVertexAccessToken() {
  if (!serviceAccount?.client_email || !serviceAccount?.private_key || !serviceAccount?.token_uri) {
    throw new Error("Service account JSON is missing required fields.");
  }
  const now = Math.floor(Date.now() / 1000);
  if (accessTokenCache && accessTokenCache.expiresAt - 60 > now) {
    return accessTokenCache.token;
  }

  const assertion = signJWT(
    {
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/cloud-platform",
      aud: serviceAccount.token_uri,
      iat: now,
      exp: now + 3600,
    },
    serviceAccount.private_key
  );
  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion,
  }).toString();

  const tokenURL = new URL(serviceAccount.token_uri);
  const response = await postJSON({
    hostname: tokenURL.hostname,
    path: `${tokenURL.pathname}${tokenURL.search}`,
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!response.access_token) {
    throw new Error("Google token endpoint returned no access token.");
  }
  accessTokenCache = {
    token: response.access_token,
    expiresAt: now + Number(response.expires_in || 3600),
  };
  return accessTokenCache.token;
}

function coachPrompt(syncId, contextJSON) {
  return `
You are an AI health and lifestyle coach inside a native iOS smartwatch companion app.

The app connects to a Veepoo/ES02 smartwatch, syncs stored health data over Bluetooth, saves local JSON snapshots, and shows a dashboard with AI-generated coaching summaries. Every time the user syncs their watch, you must re-analyze the newest data and compare it against saved history, recent trends, timestamps, and the user's normal baseline when available.

Your job is to explain the user's watch data in a clear, supportive, personalized, and non-diagnostic way.

You are not a doctor. Do not diagnose medical conditions, make medical claims, or tell the user they have a disease. If data looks unusual, concerning, or repeatedly outside the user's normal range, explain the pattern gently and suggest monitoring it or speaking with a healthcare professional.

DATA YOU MAY RECEIVE:
- Sleep duration
- Sleep start and wake time
- Accurate sleep data
- Sleep score
- Deep sleep, light sleep, awake time, and wake events
- Heart rate half-hour samples
- Resting heart rate
- Average heart rate
- Heart rate during sleep
- HRV, if available
- Blood oxygen / SpO2
- Blood pressure
- Blood glucose
- Steps
- Distance
- Calories
- Activity history
- Temperature, if supported
- ECG record counts
- Battery state
- Sync metadata
- Diagnostics, partial syncs, skipped paths, or timeout notes
- Historical saved snapshots from previous syncs

IMPORTANT APP CONTEXT:
The app may provide timestamp correlation context. Use this carefully.

For example, if sleep was recorded from 12:30 AM to 7:10 AM, only treat heart-rate samples inside that time range as sleep heart-rate data. Do not say heart rate was elevated during sleep unless the heart-rate timestamp actually overlaps with the recorded sleep window.

If timestamps do not overlap or the data is missing, say that the correlation is uncertain.

CORE TASK:
Every time a new sync happens, produce a fresh AI coach analysis that:
1. Explains the newest synced metrics.
2. Scores each major health category.
3. Gives 1-2 personalized reasoning sentences below each score.
4. Finds correlations between data points using timestamps and time windows.
5. Suggests realistic actions based on the actual data.
6. Mentions uncertainty when data is missing, partial, stale, or not clearly correlated.
7. Avoids generic advice unless it directly connects to the user's synced data.

SCORING CATEGORIES:
Use a 0-100 score for each category:
- Overall Wellness Score
- Sleep Score
- Activity Score
- Recovery Score
- Heart Health Score
- Stress / Readiness Score

For each score, include:
- score: 0-100
- status: Excellent, Good, Fair, or Needs Attention
- reasoning: 1-2 sentences
- suggested_action: 1 practical recommendation

SCORING GUIDELINES:
Use the user's data and history when available.

Sleep Score:
Consider sleep duration, bedtime/wake consistency, interruptions, awake time, deep/light sleep, and heart-rate samples that occurred during the sleep window.

Activity Score:
Consider steps, distance, calories, active minutes, workouts, and how today compares to the user's goal and recent average.

Recovery Score:
Consider sleep quality, resting heart rate, HRV if available, sleep heart rate, previous activity load, and whether the user appears under-recovered.

Heart Health Score:
Consider resting heart rate, average heart rate, sleep heart rate, heart-rate spikes, and whether those spikes match activity, sleep, or inactivity timestamps.

Stress / Readiness Score:
Consider HRV, resting heart rate, sleep quality, activity level, and stress-like patterns such as elevated heart rate during inactivity or poor recovery after low sleep.

CORRELATION RULES:
Always use timestamps and time ranges when making connections.
- If heart rate was high during the recorded sleep window, check whether sleep duration was short, sleep was interrupted, or wake events happened nearby.
- If resting heart rate is higher than the user's 7-day or 30-day baseline and sleep was short, explain that poor sleep may have affected recovery.
- If steps are low but recovery also looks poor, suggest light movement such as a short walk instead of intense exercise.
- If steps are low and recovery looks good, suggest increasing movement with a walk, workout, or step goal.
- If heart rate spikes happened outside sleep and near activity timestamps, treat them as likely activity-related.
- If heart rate spikes happened during inactivity, mention that the app saw an unexplained rise but avoid medical conclusions.
- If blood oxygen appears low or unusual, do not diagnose. Mention that the reading may be affected by sensor fit or movement and recommend monitoring trends.
- If blood pressure or glucose values are present, explain them cautiously and non-diagnostically.
- If data is incomplete because of a partial sync, timeout, or skipped path, say that the analysis is based only on available synced data.

BASELINE RULES:
If 7-day or 30-day baselines are available, compare today against them.
If baselines are not available, say: "Once more syncs are saved, this analysis will become more personalized because I will be able to compare today against your normal patterns."

OUTPUT FORMAT:
Return structured JSON only. Do not wrap it in markdown. Use this exact structure:

{
  "overall_summary": {
    "score": 0,
    "status": "Excellent | Good | Fair | Needs Attention",
    "summary": "A 2-3 sentence plain-English summary of the user's day, connecting multiple data points.",
    "priority_next_action": "The single most useful action the user should take next."
  },
  "metric_scores": [
    {
      "name": "Sleep Score",
      "score": 0,
      "status": "Excellent | Good | Fair | Needs Attention",
      "reasoning": "1-2 sentences explaining the score using sleep data and sleep-window correlations.",
      "suggested_action": "One practical action."
    },
    {
      "name": "Activity Score",
      "score": 0,
      "status": "Excellent | Good | Fair | Needs Attention",
      "reasoning": "1-2 sentences explaining steps, distance, calories, workouts, and comparison to goals or baseline.",
      "suggested_action": "One practical action."
    },
    {
      "name": "Recovery Score",
      "score": 0,
      "status": "Excellent | Good | Fair | Needs Attention",
      "reasoning": "1-2 sentences connecting sleep, resting heart rate, HRV, activity load, and recovery.",
      "suggested_action": "One practical action."
    },
    {
      "name": "Heart Health Score",
      "score": 0,
      "status": "Excellent | Good | Fair | Needs Attention",
      "reasoning": "1-2 sentences explaining resting heart rate, average heart rate, sleep heart rate, and timestamped spikes.",
      "suggested_action": "One practical action."
    },
    {
      "name": "Stress / Readiness Score",
      "score": 0,
      "status": "Excellent | Good | Fair | Needs Attention",
      "reasoning": "1-2 sentences connecting stress-like patterns, HRV, sleep, heart rate, and activity.",
      "suggested_action": "One practical action."
    }
  ],
  "correlations_found": [
    {
      "title": "Short title of the correlation",
      "data_points": ["Example: sleep duration", "Example: sleep heart rate"],
      "time_window": "The relevant time range, or 'unknown' if not available",
      "explanation": "Explain the relationship clearly and cautiously.",
      "confidence": "High | Medium | Low"
    }
  ],
  "insight_cards": [
    {
      "title": "Short insight title",
      "message": "A useful, personalized insight based on the synced data.",
      "type": "positive | neutral | caution | action"
    }
  ],
  "warnings": [
    {
      "title": "Short warning title",
      "message": "Only include if data is unusual, missing, partial, or potentially concerning. Keep it non-diagnostic.",
      "severity": "low | medium | high"
    }
  ],
  "coach_message": "A friendly 2-3 sentence message that sounds like a real coach talking to the user.",
  "source": "ai"
}

STYLE RULES:
- Be clear, friendly, and encouraging.
- Do not shame the user.
- Do not sound robotic.
- Use simple language.
- Keep each explanation short but meaningful.
- Focus on what the user can do today.
- Prefer small realistic suggestions over intense changes.
- Mention trends, not just single-day values.
- Do not overreact to one bad day.
- Do not invent missing data.
- Do not claim correlations unless timestamps support them.
- If timestamp overlap is unclear, say the relationship is uncertain.
- If the sync was partial, mention that the analysis may be limited.

FINAL IMPORTANT RULE:
The analysis should feel personalized to this user's actual synced watch data. Do not give generic wellness advice unless it is directly connected to a metric, timestamp, trend, or correlation from the sync.

Watch data context:
${contextJSON}
`;
}

function parseGeminiText(response) {
  const text = response.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new Error("Gemini returned no text.");
  }
  return JSON.parse(text);
}

function callGeminiAPIKey(prompt) {
  return new Promise((resolve, reject) => {
    if (!apiKey) {
      reject(new Error("GEMINI_API_KEY is not set."));
      return;
    }

    const body = JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: "application/json" },
    });
    const path = `/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`;
    const request = https.request(
      {
        hostname: "generativelanguage.googleapis.com",
        path,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(body),
        },
      },
      (response) => {
        let data = "";
        response.setEncoding("utf8");
        response.on("data", (chunk) => {
          data += chunk;
        });
        response.on("end", () => {
          if (response.statusCode < 200 || response.statusCode >= 300) {
            reject(new Error(`Gemini HTTP ${response.statusCode}: ${data}`));
            return;
          }
          try {
            const parsed = JSON.parse(data);
            resolve(parseGeminiText(parsed));
          } catch (error) {
            reject(error);
          }
        });
      }
    );
    request.on("error", reject);
    request.write(body);
    request.end();
  });
}

async function callVertexAI(prompt) {
  const project = process.env.VERTEXAI_PROJECT || serviceAccount?.project_id;
  if (!project) {
    throw new Error("VERTEXAI_PROJECT is not set and service account JSON has no project_id.");
  }
  const accessToken = await getVertexAccessToken();
  const hostname = `${vertexLocation}-aiplatform.googleapis.com`;
  const vertexPath = `/v1/projects/${encodeURIComponent(project)}/locations/${encodeURIComponent(vertexLocation)}/publishers/google/models/${encodeURIComponent(model)}:generateContent`;
  const response = await postJSON({
    hostname,
    path: vertexPath,
    headers: { Authorization: `Bearer ${accessToken}` },
    body: {
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: "application/json" },
    },
  });
  return parseGeminiText(response);
}

async function callGemini(prompt) {
  if (apiKey) {
    return callGeminiAPIKey(prompt);
  }
  return callVertexAI(prompt);
}

const server = http.createServer(async (request, response) => {
  if (request.method === "OPTIONS") {
    sendJSON(response, 204, {});
    return;
  }

  if (request.method === "GET" && request.url === "/health") {
    sendJSON(response, 200, {
      ok: true,
      model,
      hasGeminiApiKey: Boolean(apiKey),
      hasServiceAccount: Boolean(serviceAccount),
      vertexProject: process.env.VERTEXAI_PROJECT || serviceAccount?.project_id || null,
      vertexLocation,
      tokenRequired: Boolean(token),
    });
    return;
  }

  if (request.method !== "POST" || request.url !== "/analyze") {
    sendJSON(response, 404, { error: "Use POST /analyze." });
    return;
  }

  if (!isAuthorized(request)) {
    sendJSON(response, 401, { error: "Unauthorized." });
    return;
  }

  try {
    const body = await readBody(request);
    const input = JSON.parse(body || "{}");
    const syncId = String(input.syncId || "");
    const contextJSON = typeof input.contextJSON === "string"
      ? input.contextJSON
      : JSON.stringify(input.contextJSON || {});

    if (!syncId || !contextJSON) {
      sendJSON(response, 400, { error: "syncId and contextJSON are required." });
      return;
    }

    const analysis = await callGemini(coachPrompt(syncId, contextJSON));
    sendJSON(response, 200, { ...analysis, syncId, source: analysis.source || "ai" });
  } catch (error) {
    sendJSON(response, 500, { error: error.message || String(error) });
  }
});

server.listen(port, host, () => {
  console.log(`Coach AI proxy listening on http://${host}:${port}`);
  if (apiKey) {
    console.log(`Gemini API key mode. Model: ${model}`);
  } else if (serviceAccount) {
    console.log(`Vertex AI service-account mode. Project: ${process.env.VERTEXAI_PROJECT || serviceAccount.project_id}, location: ${vertexLocation}, model: ${model}`);
  } else {
    console.log("No GEMINI_API_KEY or service account JSON is configured.");
  }
});
