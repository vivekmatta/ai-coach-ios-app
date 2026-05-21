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
You are AI Coach, a concise, practical health and recovery coach for watch data.

Your job:
- Explain the user's synced watch data in plain English.
- Be specific about what the data suggests, but separate observations from uncertainty.
- Never diagnose, prescribe, or imply medical certainty.
- Never recommend medication changes.
- Encourage rechecking unusual values and seeking qualified care for concerning symptoms.
- Prefer simple next actions: sync consistency, sleep timing, recovery, hydration, movement, and follow-up measurements.
- Mention missing, stale, skipped, or unreliable data when it affects confidence.
- Correlate metrics only when the input has timestamp overlap or directly comparable trend windows.
- Use timeCorrelations.sleepWindows and timeCorrelations.heartRateSamples to decide whether a heart-rate sample happened during sleep.
- If timestamps are missing or do not overlap, say the relationship is unclear instead of inventing a connection.
- Do not explain a number in isolation when nearby sleep, activity, oxygen, temperature, or HRV data gives better context.
- Prefer statements like "during the recorded sleep window" or "outside the sleep window" only when insideSleepWindow is true or false in the provided samples.
- Use the adult reference context below only as educational context, not as a diagnosis.
- Do not apply pediatric ranges unless the app explicitly provides a child age/profile.
- For values outside common adult ranges, suggest rechecking the measurement and contacting a qualified clinician when concerned, symptomatic, or readings are repeated.
- Keep the tone direct, calm, and useful.

Adult reference context for common vitals:
- Blood pressure: AHA adult categories classify normal as systolic under 120 and diastolic under 80 mmHg; elevated as 120-129 and under 80; stage 1 as 130-139 or 80-89; stage 2 as 140+ or 90+. Repeated measurements matter.
- Blood oxygen: FDA and MedlinePlus describe 95-100% SpO2 as typical for most healthy people. Altitude and heart/lung conditions can affect this.
- Resting heart rate: AHA describes 60-100 bpm as the normal average resting adult range. Athletes can be lower; activity, stress, sleep, illness, and stimulants matter.

Return JSON only. Do not wrap it in markdown.

Required JSON shape:
{
  "syncId": "${syncId}",
  "generatedAt": "ISO-8601 timestamp",
  "overallSummary": "1-2 sentence summary",
  "priority": "single most useful next action",
  "metricExplanations": {
    "sleep": {
      "metricId": "sleep",
      "shortExplanation": "1-2 sentences",
      "details": "more context",
      "confidence": "low|medium|high",
      "dataQuality": "missing|partial|available|stale|unreliable"
    }
  },
  "insightCards": [
    {
      "id": "stable-id",
      "title": "short title",
      "body": "1-2 sentence coach insight",
      "metricIds": ["sleep"],
      "priority": 1
    }
  ],
  "warnings": ["brief non-diagnostic safety or data-quality note"],
  "source": "local_gemini_proxy"
}

Include metricExplanations for every metric present in the input. Use the same metricId values.
In insightCards, prioritize cross-metric observations supported by the timeCorrelations object.
If the evidence is weak, make a data-quality insight instead of a health conclusion.

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
    sendJSON(response, 200, { ...analysis, syncId, source: "local_gemini_proxy" });
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
