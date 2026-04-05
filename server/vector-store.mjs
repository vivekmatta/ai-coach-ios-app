import { access, mkdir, readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { embedTexts, getVertexConfig, normalizeVector } from "./vertex-client.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "..");
const defaultDbPath = path.join(repoRoot, "data", "vector-db", "coach-data-vectors.json");

let cachedDb;

export async function vectorDbExists(dbPath = defaultDbPath) {
  try {
    await access(dbPath);
    return true;
  } catch {
    return false;
  }
}

export async function loadVectorDb(dbPath = defaultDbPath) {
  if (!cachedDb || cachedDb.__path !== dbPath) {
    const raw = await readFile(dbPath, "utf8");
    cachedDb = {
      __path: dbPath,
      ...JSON.parse(raw),
    };
  }

  return cachedDb;
}

export async function saveVectorDb(db, dbPath = defaultDbPath) {
  await mkdir(path.dirname(dbPath), { recursive: true });
  await writeFile(dbPath, JSON.stringify(db, null, 2));
  cachedDb = {
    __path: dbPath,
    ...db,
  };
}

export async function retrieveRelevantChunks(query, { dbPath = defaultDbPath, topK = 5 } = {}) {
  if (!(await vectorDbExists(dbPath))) {
    return [];
  }

  const db = await loadVectorDb(dbPath);
  const [embedding] = await embedTexts([query], {
    taskType: "RETRIEVAL_QUERY",
    outputDimensionality: db.dimensions,
  });
  const queryVector = normalizeVector(embedding.values);

  const scored = db.chunks.map((chunk) => ({
    ...chunk,
    score: dot(queryVector, chunk.embedding),
  }));

  return scored
    .sort((a, b) => b.score - a.score)
    .slice(0, topK);
}

export function formatRetrievedContext(chunks) {
  if (!chunks.length) {
    return "";
  }

  return chunks
    .map((chunk, index) => {
      return JSON.stringify({
        rank: index + 1,
        source: chunk.source,
        excerpt: chunk.text,
      });
    })
    .join("\n");
}

export async function buildVectorDb({ sourcePath, chunks, dbPath = defaultDbPath, dimensions = 3072 }) {
  const embeddings = await embedTexts(
    chunks.map((chunk) => chunk.text),
    {
      taskType: "RETRIEVAL_DOCUMENT",
      outputDimensionality: dimensions,
    }
  );

  const { embeddingModel } = await getVertexConfig();

  const db = {
    createdAt: new Date().toISOString(),
    sourcePath,
    embeddingModel,
    dimensions,
    chunkCount: chunks.length,
    chunks: chunks.map((chunk, index) => ({
      ...chunk,
      embedding: normalizeVector(embeddings[index].values),
      tokenCount: embeddings[index].statistics?.token_count ?? null,
    })),
  };

  await saveVectorDb(db, dbPath);
  return db;
}

function dot(a, b) {
  let sum = 0;
  for (let i = 0; i < a.length; i += 1) {
    sum += a[i] * b[i];
  }
  return sum;
}
