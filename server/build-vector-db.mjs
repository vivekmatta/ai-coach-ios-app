import { readdir, readFile, stat } from "node:fs/promises";
import path from "node:path";

import { PDFParse } from "pdf-parse";

import { buildVectorDb } from "./vector-store.mjs";

const sourcePathArg = process.argv[2];

if (!sourcePathArg) {
  console.error("Usage: node server/build-vector-db.mjs '/absolute/path/to/file-or-directory'");
  process.exit(1);
}

const sourcePath = path.resolve(sourcePathArg);
const sourceStat = await stat(sourcePath);
const files = sourceStat.isDirectory() ? await collectFiles(sourcePath) : [sourcePath];
const chunks = [];

for (const file of files) {
  const text = await parseFile(file);
  if (!text) {
    continue;
  }

  const fileChunks = chunkText(text).map((chunkText, index) => ({
    id: `${path.basename(file)}-chunk-${index + 1}`,
    source: path.basename(file),
    filePath: file,
    text: chunkText,
  }));

  chunks.push(...fileChunks);
}

if (!chunks.length) {
  throw new Error("No text chunks were produced from the provided source path.");
}

const db = await buildVectorDb({
  sourcePath,
  chunks,
});

console.log(
  JSON.stringify(
    {
      ok: true,
      sourcePath,
      files: files.length,
      chunks: db.chunkCount,
      dimensions: db.dimensions,
    },
    null,
    2
  )
);

async function collectFiles(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  const files = [];

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await collectFiles(fullPath)));
      continue;
    }
    if (/\.(txt|pdf)$/i.test(entry.name)) {
      files.push(fullPath);
    }
  }

  return files.sort();
}

async function parseFile(file) {
  if (file.endsWith(".txt")) {
    const text = await readFile(file, "utf8");
    return normalizeText(text);
  }

  if (file.endsWith(".pdf")) {
    const dataBuffer = await readFile(file);
    const parser = new PDFParse({ data: dataBuffer });
    const parsed = await parser.getText();
    await parser.destroy();
    return normalizeText(parsed.text);
  }

  return "";
}

function normalizeText(text) {
  return text
    .replace(/\r/g, "\n")
    .replace(/\t+/g, " ")
    .replace(/[ ]{2,}/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function chunkText(text) {
  const chunkSize = 1000;
  const chunkOverlap = 200;
  const separators = ["\n\n", "\n", " ", ""];
  const rawChunks = splitRecursively(text, separators, chunkSize)
    .map((chunk) => chunk.trim())
    .filter(Boolean);

  const merged = [];
  let buffer = "";

  for (const piece of rawChunks) {
    const candidate = buffer ? `${buffer} ${piece}`.trim() : piece;
    if (candidate.length <= chunkSize) {
      buffer = candidate;
      continue;
    }
    if (buffer) {
      merged.push(buffer);
    }
    const overlap = buffer.slice(Math.max(0, buffer.length - chunkOverlap)).trim();
    buffer = overlap ? `${overlap} ${piece}`.trim() : piece;
  }

  if (buffer) {
    merged.push(buffer);
  }

  return merged;
}

function splitRecursively(text, separators, chunkSize) {
  if (text.length <= chunkSize || separators.length === 0) {
    return [text];
  }

  const [separator, ...rest] = separators;
  if (!separator) {
    const chunks = [];
    for (let start = 0; start < text.length; start += chunkSize) {
      chunks.push(text.slice(start, start + chunkSize));
    }
    return chunks;
  }

  const parts = text.split(separator);
  if (parts.length === 1) {
    return splitRecursively(text, rest, chunkSize);
  }

  const pieces = [];
  let current = "";

  for (const part of parts) {
    const next = current ? `${current}${separator}${part}` : part;
    if (next.length <= chunkSize) {
      current = next;
      continue;
    }
    if (current) {
      pieces.push(current);
    }
    if (part.length > chunkSize) {
      pieces.push(...splitRecursively(part, rest, chunkSize));
      current = "";
    } else {
      current = part;
    }
  }

  if (current) {
    pieces.push(current);
  }

  return pieces;
}
