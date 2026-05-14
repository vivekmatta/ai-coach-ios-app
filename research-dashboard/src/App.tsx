import { useMemo, useState } from "react";

import {
  FilterKey,
  Participant,
  TrendPoint,
  cohortStats,
  participants,
} from "./mockData";

type DashboardView = "overview" | "participants" | "notes" | "settings";

const filters: Array<{ key: FilterKey; label: string }> = [
  { key: "all", label: "All" },
  { key: "sync-risk", label: "Sync Risk" },
  { key: "recovery", label: "Recovery" },
  { key: "flagged", label: "Flagged" },
];

const views: Array<{ key: DashboardView; label: string }> = [
  { key: "overview", label: "Overview" },
  { key: "participants", label: "Participants" },
  { key: "notes", label: "Research Notes" },
  { key: "settings", label: "Study Settings" },
];

export function App() {
  const [view, setView] = useState<DashboardView>("overview");
  const [selectedId, setSelectedId] = useState(participants[4].id);
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<FilterKey>("all");
  const [notes, setNotes] = useState(() =>
    Object.fromEntries(participants.map((participant) => [participant.id, participant.note]))
  );

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
  const selectedNote = notes[selected.id] ?? "";

  function selectParticipant(participant: Participant) {
    setSelectedId(participant.id);
  }

  function updateSelectedNote(nextNote: string) {
    setNotes((current) => ({ ...current, [selected.id]: nextNote }));
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div>
          <h1>AI Health Coach</h1>
          <p>Research Portal</p>
        </div>
        <nav className="side-nav">
          {views.map((item) => (
            <button
              key={item.key}
              className={view === item.key ? "active" : ""}
              onClick={() => setView(item.key)}
            >
              {item.label}
            </button>
          ))}
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
          {view === "overview" ? (
            <OverviewView
              stats={stats}
              selected={selected}
              selectedNote={selectedNote}
              filteredParticipants={filteredParticipants}
              search={search}
              filter={filter}
              onSearch={setSearch}
              onFilter={setFilter}
              onSelectParticipant={selectParticipant}
              onUpdateNote={updateSelectedNote}
            />
          ) : null}

          {view === "participants" ? (
            <ParticipantsView
              selected={selected}
              filteredParticipants={filteredParticipants}
              search={search}
              filter={filter}
              onSearch={setSearch}
              onFilter={setFilter}
              onSelectParticipant={selectParticipant}
            />
          ) : null}

          {view === "notes" ? (
            <NotesView
              selected={selected}
              notes={notes}
              onSelectParticipant={selectParticipant}
              onUpdateNote={updateSelectedNote}
            />
          ) : null}

          {view === "settings" ? <SettingsView /> : null}
        </main>
      </div>
    </div>
  );
}

function OverviewView({
  stats,
  selected,
  selectedNote,
  filteredParticipants,
  search,
  filter,
  onSearch,
  onFilter,
  onSelectParticipant,
  onUpdateNote,
}: {
  stats: ReturnType<typeof cohortStats>;
  selected: Participant;
  selectedNote: string;
  filteredParticipants: Participant[];
  search: string;
  filter: FilterKey;
  onSearch: (value: string) => void;
  onFilter: (value: FilterKey) => void;
  onSelectParticipant: (participant: Participant) => void;
  onUpdateNote: (value: string) => void;
}) {
  return (
    <>
      <OverviewCards stats={stats} />
      <section className="split-grid">
        <ParticipantPanel
          selected={selected}
          participants={filteredParticipants}
          search={search}
          filter={filter}
          onSearch={onSearch}
          onFilter={onFilter}
          onSelectParticipant={onSelectParticipant}
        />
        <section className="detail-column">
          <ParticipantDetail participant={selected} />
          <TrendSection trend={selected.trend} />
          <NotesEditor note={selectedNote} participant={selected} onUpdateNote={onUpdateNote} />
        </section>
      </section>
    </>
  );
}

function ParticipantsView({
  selected,
  filteredParticipants,
  search,
  filter,
  onSearch,
  onFilter,
  onSelectParticipant,
}: {
  selected: Participant;
  filteredParticipants: Participant[];
  search: string;
  filter: FilterKey;
  onSearch: (value: string) => void;
  onFilter: (value: FilterKey) => void;
  onSelectParticipant: (participant: Participant) => void;
}) {
  return (
    <section className="split-grid participants-view">
      <ParticipantPanel
        selected={selected}
        participants={filteredParticipants}
        search={search}
        filter={filter}
        onSearch={onSearch}
        onFilter={onFilter}
        onSelectParticipant={onSelectParticipant}
      />
      <section className="detail-column">
        <ParticipantDetail participant={selected} />
        <TrendSection trend={selected.trend} />
      </section>
    </section>
  );
}

function NotesView({
  selected,
  notes,
  onSelectParticipant,
  onUpdateNote,
}: {
  selected: Participant;
  notes: Record<string, string>;
  onSelectParticipant: (participant: Participant) => void;
  onUpdateNote: (value: string) => void;
}) {
  const notedParticipants = participants.filter(
    (participant) => notes[participant.id]?.trim() || participant.flags.length
  );

  return (
    <section className="notes-layout">
      <aside className="notes-index">
        <h3>Participants to Review</h3>
        <div className="notes-list">
          {notedParticipants.map((participant) => (
            <button
              key={participant.id}
              className={participant.id === selected.id ? "selected" : ""}
              onClick={() => onSelectParticipant(participant)}
            >
              <strong>{participant.id}</strong>
              <span>{participant.flags[0] ?? "Research note"}</span>
            </button>
          ))}
        </div>
      </aside>
      <section className="detail-column">
        <NotesEditor
          note={notes[selected.id] ?? ""}
          participant={selected}
          onUpdateNote={onUpdateNote}
        />
        <ParticipantDetail participant={selected} />
      </section>
    </section>
  );
}

function SettingsView() {
  return (
    <section className="settings-grid">
      <SettingsCard
        title="Study Window"
        rows={[
          ["Active dates", "Oct 1 - Oct 7"],
          ["Target cohort", "12 participants"],
          ["Minimum completeness", "5 of 7 days"],
        ]}
      />
      <SettingsCard
        title="Sync Rules"
        rows={[
          ["Recent sync", "Within 24 hours"],
          ["Stale sync", "24-72 hours"],
          ["Missing sync", "No sync in 72 hours"],
        ]}
      />
      <SettingsCard
        title="Flag Thresholds"
        rows={[
          ["Recovery review", "Below 60"],
          ["High stress", "65+"],
          ["Low sleep", "Under 6 hours"],
        ]}
      />
      <SettingsCard
        title="Signal Policy"
        rows={[
          ["Glucose", "Proxy only"],
          ["Nitric oxide", "Proxy only"],
          ["Clinical diagnosis", "Disabled"],
        ]}
      />
    </section>
  );
}

function OverviewCards({ stats }: { stats: ReturnType<typeof cohortStats> }) {
  return (
    <section className="overview-grid">
      <OverviewCard label="Participants Enrolled" value={stats.enrolled} />
      <OverviewCard label="Synced 24h" value={stats.synced} tone="good" />
      <OverviewCard label="Missing Sync" value={stats.missing} tone="risk" />
      <OverviewCard label="Active Flags" value={stats.activeFlags} tone="warn" />
      <OverviewCard label="Avg Recovery" value={`${stats.averageRecovery}/100`} />
      <OverviewCard label="Avg Sleep" value={`${stats.averageSleep}/100`} />
    </section>
  );
}

function SettingsCard({
  title,
  rows,
}: {
  title: string;
  rows: Array<[string, string]>;
}) {
  return (
    <article className="settings-card">
      <h3>{title}</h3>
      <div className="settings-rows">
        {rows.map(([label, value]) => (
          <div key={label}>
            <span>{label}</span>
            <strong>{value}</strong>
          </div>
        ))}
      </div>
    </article>
  );
}

function ParticipantPanel({
  selected,
  participants,
  search,
  filter,
  onSearch,
  onFilter,
  onSelectParticipant,
}: {
  selected: Participant;
  participants: Participant[];
  search: string;
  filter: FilterKey;
  onSearch: (value: string) => void;
  onFilter: (value: FilterKey) => void;
  onSelectParticipant: (participant: Participant) => void;
}) {
  return (
    <aside className="participant-panel">
      <div className="participant-tools">
        <input
          value={search}
          onChange={(event) => onSearch(event.target.value)}
          placeholder="Search ID..."
        />
        <div className="filter-row">
          {filters.map((item) => (
            <button
              key={item.key}
              className={filter === item.key ? "active" : ""}
              onClick={() => onFilter(item.key)}
            >
              {item.label}
            </button>
          ))}
        </div>
      </div>
      <div className="participant-list">
        {participants.map((participant) => (
          <button
            key={participant.id}
            className={`participant-row ${selected.id === participant.id ? "selected" : ""}`}
            onClick={() => onSelectParticipant(participant)}
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
  );
}

function NotesEditor({
  note,
  participant,
  onUpdateNote,
}: {
  note: string;
  participant: Participant;
  onUpdateNote: (value: string) => void;
}) {
  return (
    <section className="notes-card">
      <div className="notes-header">
        <div>
          <h3>Research Notes</h3>
          <p>Participant {participant.id}</p>
        </div>
        <button>Save Note</button>
      </div>
      <textarea
        value={note}
        onChange={(event) => onUpdateNote(event.target.value)}
        placeholder={`Observations for ${participant.id}...`}
      />
      <div className="tag-row">
        <span>Follow up +</span>
        <span>Sync issue +</span>
        <span>Interesting pattern +</span>
        <span>Exclude day +</span>
      </div>
    </section>
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
