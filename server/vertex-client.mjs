import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { GoogleAuth } from "google-auth-library";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const defaultCredentialsPath = path.join(repoRoot, "secrets", "google-service-account.json");

const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || defaultCredentialsPath;
const location = process.env.VERTEX_AI_LOCATION || "us-central1";
const chatModel = process.env.VERTEX_AI_MODEL || "gemini-2.5-flash";
const embeddingModel = process.env.VERTEX_AI_EMBEDDING_MODEL || "gemini-embedding-001";

let serviceAccount;
let authClientPromise;

async function loadServiceAccount() {
  if (!serviceAccount) {
    const raw = await readFile(credentialsPath, "utf8");
    serviceAccount = JSON.parse(raw);
  }

  return serviceAccount;
}

async function getAuthClient() {
  if (!authClientPromise) {
    authClientPromise = (async () => {
      const credentials = await loadServiceAccount();
      const auth = new GoogleAuth({
        credentials,
        scopes: ["https://www.googleapis.com/auth/cloud-platform"],
      });
      return auth.getClient();
    })();
  }

  return authClientPromise;
}

async function getAccessToken() {
  const authClient = await getAuthClient();
  const tokenResponse = await authClient.getAccessToken();
  const token = typeof tokenResponse === "string" ? tokenResponse : tokenResponse?.token;

  if (!token) {
    throw new Error("Could not obtain a Google access token.");
  }

  return token;
}

export async function getVertexConfig() {
  const credentials = await loadServiceAccount();
  return {
    projectId: credentials.project_id,
    location,
    chatModel,
    embeddingModel,
    credentialsPath,
  };
}

export async function callVertexGenerate({ systemInstruction, userText }) {
  const { projectId } = await getVertexConfig();
  const accessToken = await getAccessToken();
  const endpoint = `https://${location}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${location}/publishers/google/models/${chatModel}:generateContent`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      systemInstruction: {
        parts: [{ text: systemInstruction }],
      },
      contents: [
        {
          role: "user",
          parts: [{ text: userText }],
        },
      ],
      generationConfig: {
        temperature: 0.7,
        maxOutputTokens: 1024,
      },
    }),
  });

  const payload = await response.json();

  if (!response.ok) {
    const message = payload?.error?.message || `Vertex AI request failed with status ${response.status}`;
    throw new Error(message);
  }

  const text = payload?.candidates?.[0]?.content?.parts
    ?.map((part) => part.text)
    .filter(Boolean)
    .join("\n")
    .trim();

  if (!text) {
    throw new Error("Vertex AI returned an empty response.");
  }

  return text;
}

export async function embedTexts(texts, { taskType, outputDimensionality = 3072 } = {}) {
  const { projectId } = await getVertexConfig();
  const accessToken = await getAccessToken();
  const endpoint = `https://${location}-aiplatform.googleapis.com/v1/projects/${projectId}/locations/${location}/publishers/google/models/${embeddingModel}:predict`;
  const results = [];

  for (const text of texts) {
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        instances: [
          {
            content: text,
            ...(taskType ? { task_type: taskType } : {}),
          },
        ],
        parameters: {
          outputDimensionality,
        },
      }),
    });

    const payload = await response.json();

    if (!response.ok) {
      const message = payload?.error?.message || `Vertex embedding request failed with status ${response.status}`;
      throw new Error(message);
    }

    const prediction = payload?.predictions?.[0]?.embeddings;
    const values = prediction?.values;

    if (!Array.isArray(values) || values.length === 0) {
      throw new Error("Vertex AI returned an empty embedding.");
    }

    results.push({
      values,
      statistics: prediction?.statistics || {},
    });
  }

  return results;
}

export function normalizeVector(values) {
  const magnitude = Math.sqrt(values.reduce((sum, value) => sum + value * value, 0));
  if (!magnitude) {
    return values;
  }
  return values.map((value) => value / magnitude);
}
