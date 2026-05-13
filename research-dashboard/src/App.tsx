import { useMemo, useState } from "react";

import {
  FilterKey,
  Participant,
  TrendPoint,
  cohortStats,
  participants,
} from "./mockData";

const filters: Array<{ key: FilterKey; label: string }> = [
  { key: "all", label: "All" },
  { key: "sync-risk", label: "Sync Risk" },
  { key: "recovery", label: "Recovery" },
  { key: "flagged", label: "Flagged" },
];

export function App() {
  const [selectedId, setSelectedId] = useState(participants[4].id);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<FilterKey>("all");
  const [note, setNote] = useState(participants[4].note);

  const filteredParticipants = useMemo(() => {
    return participants.filter((participant) => {
      const matchesSearch = participant.id.toLowerCase().includes(search.toLowerCase());
      const matchesFilter =
        filter === "all" ||
        (filter === "sync-risk" && participant.syncStatus !== "synced") ||
        (filter === "recovery" && participant.recovery > 0 && participant.recovery < 60) ||
        (filter === "flagged" && participant.flags.length > 0);

      return matchesSearch && matchesFilter;
    });
  }, [filter, search]);

  const selected =
    participants.find((participant) => participant.id === selectedId) ?? participants[0];
  const stats = cohortStats(participants);

  function selectParticipant(participant: Participant) {
    setSelectedId(participant.id);
    setNote(participant.note);
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div>
          <h1>AI Health Coach</h1>
          <p>Research Portal</p>
        </div>
        <nav className="side-nav">
          <a className="active" href="#overview">Overview</a>
          <a href="#participants">Participants</a>
          <a href="#notes">Research Notes</a>
          <a href="#settings">Study Settings</a>
        </nav>
        <div className="researcher">
          <span>RL</span>
          <p>Research Lead</p>
        </div>
      </aside>

      <div className="main-shell">
        <header className="topbar">
          <div>
            <h2>AI Health Coach Study</h2>
            <p>Oct 1 - Oct 7 • mock cohort view</p>
          </div>
          <div className="topbar-actions">
            <span className="sync-pill">9/12 synced</span>
            <button>Refresh</button>
            <button className="outline">Export Data</button>
          </div>
        </header>

        <main className="dashboard">
          <section className="overview-grid">
            <OverviewCard label="Participants Enrolled" value={stats.enrolled} />
            <OverviewCard label="Synced 24h" value={stats.synced} tone="good" />
            <OverviewCard label="Missing Sync" value={stats.missing} tone="risk" />
            <OverviewCard label="Active Flags" value={stats.activeFlags} tone="warn" />
            <OverviewCard label="Avg Recovery" value={`${stats.averageRecovery}/100`} />
            <OverviewCard label="Avg Sleep" value={`${stats.averageSleep}/100`} />
          </section>

          <section className="split-grid">
            <aside className="participant-panel" id="participants">
              <div className="participant-tools">
                <input
                  value={search}
                  onChange={(event) => setSearch(event.target.value)}
                  placeholder="Search ID..."
                />
                <div className="filter-row">
                  {filters.map((item) => (
                    <button
                      key={item.key}
                      className={filter === item.key ? "active" : ""}
                      onClick={() => setFilter(item.key)}
                    >
                      {item.label}
                    </button>
                  ))}
                </div>
              </div>
              <div className="participant-list">
                {filteredParticipants.map((participant) => (
                  <button
                    key={participant.id}
                    className={`participant-row ${
                      selected.id === participant.id ? "selected" : ""
                    }`}
                    onClick={() => selectParticipant(participant)}
                  >
                    <div>
                      <strong>{participant.id}</strong>
                      <span>
                        Rec: {participant.recovery || "-"} | Sleep:{" "}
                        {participant.sleepHours ? `${participant.sleepHours}h` : "-"}
                      </span>
                    </div>
                    <div className="participant-meta">
                      <i className={`status-dot ${participant.syncStatus}`} />
                      <small>{participant.lastSync}</small>
                    </div>
                  </button>
                ))}
              </div>
            </aside>

            <section className="detail-column">
              <ParticipantDetail participant={selected} />
              <TrendSection trend={selected.trend} />
              <section className="notes-card" id="notes">
                <div className="notes-header">
                  <h3>Research Notes</h3>
                  <button>Save Note</button>
                </div>
                <textarea
                  value={note}
                  onChange={(event) => setNote(event.target.value)}
                  placeholder={`Observations for ${selected.id}...`}
                />
                <div className="tag-row">
                  <span>Follow up +</span>
                  <span>Sync issue +</span>
                  <span>Interesting pattern +</span>
                  <span>Exclude day +</span>
                </div>
              </section>
            </section>
          </section>
        </main>
      </div>
    </div>
  );
}

function OverviewCard({
  label,
  value,
  tone,
}: {
  label: string;
  value: string | number;
  tone?: "good" | "warn" | "risk";
}) {
  return (
    <article className={`overview-card ${tone ?? ""}`}>
      <span>{label}</span>
      <strong>{value}</strong>
    </article>
  );
}

function ParticipantDetail({ participant }: { participant: Participant }) {
  return (
    <section className="detail-card">
      <div className="detail-header">
        <div>
          <h3>Participant {participant.id}</h3>
          <p>
            Device ID: {participant.deviceId} • Last Sync: {participant.lastSync}
          </p>
        </div>
        <div className="completeness">
          <span>Data Completeness</span>
          <div>
            {participant.completeness.map((complete, index) => (
              <i key={`${participant.id}-${index}`} className={complete ? "complete" : ""} />
            ))}
          </div>
        </div>
      </div>

      <div className="summary-box">
        <span>Today's Summary</span>
        <p>{participant.summary}</p>
      </div>

      <div className="metric-grid">
        <Metric label="Recovery" value={`${participant.recovery || "-"}%`} />
        <Metric label="Sleep" value={participant.sleepHours ? `${participant.sleepHours}h` : "-"} />
        <Metric label="HRV" value={participant.hrv ? `${participant.hrv} ms` : "-"} />
        <Metric label="Stress" value={participant.stress} tone={participant.stress === "High" ? "risk" : "good"} />
        <Metric label="Steps" value={participant.steps ? participant.steps.toLocaleString() : "-"} />
        <Metric label="SpO2" value={participant.spo2 ? `${participant.spo2}%` : "-"} />
        <Metric label="Temp Delta" value={`${participant.tempDelta > 0 ? "+" : ""}${participant.tempDelta} C`} />
        <Metric label="Blood Pressure" value={participant.bloodPressure ?? "-"} />
      </div>

      <div className="subgrid">
        <div className="proxy-box">
          <h4>Metabolic Proxies</h4>
          <p>Proxy indicators only. Not measured medical values.</p>
          <div className="proxy-row">
            <span>Glucose Proxy</span>
            <strong>{participant.glucoseProxy}</strong>
          </div>
          <div className="proxy-row">
            <span>Nitric Oxide Proxy</span>
            <strong>{participant.nitricOxideProxy}</strong>
          </div>
        </div>

        <div className="flags-box">
          <h4>AI Flags & Recommendation</h4>
          {participant.flags.length ? (
            <div className="flag-list">
              {participant.flags.map((flag) => (
                <span key={flag}>{flag}</span>
              ))}
            </div>
          ) : (
            <p className="quiet">No active flags.</p>
          )}
          <blockquote>{participant.recommendation}</blockquote>
        </div>
      </div>
    </section>
  );
}

function Metric({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone?: "good" | "risk";
}) {
  return (
    <div className="metric">
      <span>{label}</span>
      <strong className={tone ?? ""}>{value}</strong>
    </div>
  );
}

function TrendSection({ trend }: { trend: TrendPoint[] }) {
  return (
    <section className="trend-card">
      <div>
        <h3>Seven-Day Pattern</h3>
        <p>Simple trend view for recovery, sleep, HRV, stress, and steps.</p>
      </div>
      <div className="small-multiples">
        <Sparkline title="Recovery" values={trend.map((point) => point.recovery)} suffix="/100" />
        <Sparkline title="Sleep" values={trend.map((point) => point.sleep)} suffix="/100" />
        <Sparkline title="HRV" values={trend.map((point) => point.hrv)} suffix=" ms" />
        <Sparkline title="Stress" values={trend.map((point) => point.stress)} suffix="/100" inverse />
        <Sparkline title="Steps" values={trend.map((point) => Math.round(point.steps / 100))} suffix="00" />
      </div>
    </section>
  );
}

function Sparkline({
  title,
  values,
  suffix,
  inverse,
}: {
  title: string;
  values: number[];
  suffix: string;
  inverse?: boolean;
}) {
  const max = Math.max(...values, 100);
  const min = Math.min(...values, 0);
  const range = Math.max(1, max - min);
  const points = values
    .map((value, index) => {
      const x = (index / (values.length - 1)) * 100;
      const y = 46 - ((value - min) / range) * 38;
      return `${x},${y}`;
    })
    .join(" ");
  const latest = values[values.length - 1];
  const tone = inverse ? latest < 55 : latest >= 60;

  return (
    <article className="spark-card">
      <div>
        <span>{title}</span>
        <strong className={tone ? "good" : "risk"}>
          {latest}
          {suffix}
        </strong>
      </div>
      <svg viewBox="0 0 100 52" role="img" aria-label={`${title} trend`}>
        <polyline points={points} fill="none" stroke="currentColor" strokeWidth="3" />
      </svg>
    </article>
  );
}
