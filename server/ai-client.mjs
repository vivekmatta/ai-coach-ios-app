import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const envPath = path.join(repoRoot, ".env");

loadDotEnv();

const geminiApiKey =
  process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || process.env.AI_API_KEY;
const geminiModel = process.env.GEMINI_MODEL || process.env.AI_CHAT_MODEL || "gemini-2.5-flash";

function loadDotEnv() {
  if (!existsSync(envPath)) {
    return;
  }

  const raw = readFileSync(envPath, "utf8");

  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) {
      continue;
    }

    const separatorIndex = trimmed.indexOf("=");
    if (separatorIndex === -1) {
      continue;
    }

    const key = trimmed.slice(0, separatorIndex).trim();
    const value = trimmed.slice(separatorIndex + 1).trim().replace(/^["']|["']$/g, "");

    if (key && process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

export function getAiChatConfig() {
  if (!geminiApiKey) {
    throw new Error("Set GEMINI_API_KEY in .env or your shell to enable AI chat.");
  }

  return {
    provider: "gemini-api-key",
    model: geminiModel,
  };
}

export async function callAiChatGenerate({ systemInstruction, userText }) {
  const { model } = getAiChatConfig();
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`;

  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-goog-api-key": geminiApiKey,
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
        maxOutputTokens: 768,
      },
    }),
  });

  const payload = await response.json();

  if (!response.ok) {
    const message = payload?.error?.message || `Gemini API request failed with status ${response.status}`;
    throw new Error(message);
  }

  const text = payload?.candidates?.[0]?.content?.parts
    ?.map((part) => part.text)
    .filter(Boolean)
    .join("\n")
    .trim();

  if (!text) {
    throw new Error("Gemini API returned an empty response.");
  }

  return text;
}
