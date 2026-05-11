import { HealthTimelineResponse, LatestHealthResponse } from "../types";
import { inferDevApiBase } from "./apiBase";

async function requestJson<T>(path: string, init?: RequestInit): Promise<T> {
  const apiBase = inferDevApiBase();
  if (!apiBase) {
    throw new Error("Could not infer the local API base URL.");
  }

  const response = await fetch(`${apiBase}${path}`, init);
  const payload = (await response.json()) as T & { error?: string };

  if (!response.ok) {
    throw new Error(payload.error || `Request failed for ${path}`);
  }

  return payload;
}

export function fetchLatestHealthData(): Promise<LatestHealthResponse> {
  return requestJson<LatestHealthResponse>("/health-data/latest");
}

export function fetchHealthTimeline(): Promise<HealthTimelineResponse> {
  return requestJson<HealthTimelineResponse>("/health-data/timeline");
}

export function importMockHealthFixture(fixtureId: string): Promise<LatestHealthResponse> {
  return requestJson<LatestHealthResponse>("/health-data/import-mock", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ fixtureId }),
  });
}
