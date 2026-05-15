import React, { useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

import { AppTextInput, Card, PrimaryButton } from "./components";
import { defaultProfile, onboardingQuestions } from "./data";
import {
  buildLocalStructuredPlan,
  generateStructuredPlan,
  sendCoachMessage,
} from "./services/coachApi";
import {
  fetchHealthTimeline,
  fetchLatestHealthData,
  importMockHealthFixture,
} from "./services/healthApi";
import {
  loadCoachTone,
  loadDiaryEntries,
  loadOnboardingComplete,
  loadPersonalityStrength,
  loadProfile,
  saveCoachTone,
  saveDiaryEntries,
  saveOnboardingComplete,
  savePersonalityStrength,
  saveProfile,
} from "./storage";
import { palette, radius, spacing } from "./theme";
import {
  CoachCorrelation,
  CoachMessage,
  CoachPlanResponse,
  CoachScore,
  CoachTask,
  CoachToneMode,
  CoachTrendInsight,
  DiaryEntry,
  HealthTimelineResponse,
  LatestHealthResponse,
  TabKey,
  UserProfile,
} from "./types";

const fields: Array<keyof UserProfile> = [
  "name",
  "goals",
  "exerciseDays",
  "exerciseType",
  "sleepTime",
  "caffeine",
  "workStress",
];

const tabLabels: Record<TabKey, string> = {
  today: "Today",
  insights: "Insights",
  workouts: "Workouts",
  profile: "Profile",
};

const tabGlyphs: Record<TabKey, string> = {
  today: "T",
  insights: "I",
  workouts: "W",
  profile: "P",
};

const toneLabels: Array<{ value: CoachToneMode; label: string; short: string }> = [
  { value: "gentle", label: "Gentle", short: "G" },
  { value: "direct", label: "Direct", short: "D" },
  { value: "hype", label: "Hype", short: "H" },
  { value: "nice", label: "Nice", short: "N" },
  { value: "unhinged", label: "Unhinged", short: "U" },
];

const diaryTags = ["Ran", "Lifted", "Ate late", "Caffeine", "Stress"];

const workoutLibrary = [
  {
    title: "Morning awakening",
    meta: "15 min - gentle stretch",
    icon: "sun",
  },
  {
    title: "Core control",
    meta: "12 min - bodyweight",
    icon: "core",
  },
  {
    title: "Evening wind down",
    meta: "10 min - breathwork",
    icon: "air",
  },
];

function formatShortDate(date: string) {
  return new Date(`${date}T00:00:00`).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
  });
}

function formatSleep(minutes: number) {
  const hours = Math.floor(minutes / 60);
  const remainder = minutes % 60;
  return `${hours}h ${remainder}m`;
}

function average(values: number[]) {
  if (!values.length) {
    return 0;
  }
  return Math.round(values.reduce((sum, value) => sum + value, 0) / values.length);
}

function firstNameFrom(profile: UserProfile) {
  return profile.name.trim().split(" ")[0] || "there";
}

function toneColor(score: number) {
  if (score >= 75) {
    return palette.sage;
  }
  if (score >= 55) {
    return palette.sand;
  }
  return palette.coral;
}

function taskIcon(category: CoachTask["category"]) {
  switch (category) {
    case "hydration":
      return "H";
    case "breath":
      return "B";
    case "sleep":
      return "S";
    case "nutrition":
      return "N";
    case "recovery":
      return "R";
    default:
      return "M";
  }
}

export function MobileApp() {
  const [loading, setLoading] = useState(true);
  const [healthLoading, setHealthLoading] = useState(true);
  const [scenarioLoading, setScenarioLoading] = useState(false);
  const [healthError, setHealthError] = useState<string | null>(null);
  const [onboardingDone, setOnboardingDone] = useState(false);
  const [profile, setProfile] = useState<UserProfile>(defaultProfile);
  const [tab, setTab] = useState<TabKey>("today");
  const [questionIndex, setQuestionIndex] = useState(0);
  const [draft, setDraft] = useState("");
  const [messages, setMessages] = useState<CoachMessage[]>([]);
  const [chatInput, setChatInput] = useState("");
  const [chatLoading, setChatLoading] = useState(false);
  const [chatOpen, setChatOpen] = useState(false);
  const [latestHealth, setLatestHealth] = useState<LatestHealthResponse | null>(null);
  const [timeline, setTimeline] = useState<HealthTimelineResponse | null>(null);
  const [coachPlan, setCoachPlan] = useState<CoachPlanResponse | null>(null);
  const [coachTone, setCoachTone] = useState<CoachToneMode>("gentle");
  const [personalityStrength, setPersonalityStrength] = useState(3);
  const [diaryEntries, setDiaryEntries] = useState<DiaryEntry[]>([]);
  const [diaryDraft, setDiaryDraft] = useState("");
  const [selectedDiaryTags, setSelectedDiaryTags] = useState<string[]>([]);
  const [checkedTasks, setCheckedTasks] = useState<Record<string, boolean>>({});
  const [voiceNoteState, setVoiceNoteState] = useState<"idle" | "captured">("idle");

  const firstName = useMemo(() => firstNameFrom(profile), [profile]);

  async function refreshStructuredPlan(
    health: LatestHealthResponse | null,
    nextProfile = profile,
    tone = coachTone,
    strength = personalityStrength,
    entries = diaryEntries
  ) {
    const plan = await generateStructuredPlan(health, nextProfile, tone, strength, entries);
    setCoachPlan(plan);
  }

  async function loadHealthData(
    nextProfile = profile,
    tone = coachTone,
    strength = personalityStrength,
    entries = diaryEntries
  ) {
    setHealthLoading(true);
    setHealthError(null);

    try {
      const [latest, nextTimeline] = await Promise.all([
        fetchLatestHealthData(),
        fetchHealthTimeline(),
      ]);
      setLatestHealth(latest);
      setTimeline(nextTimeline);
      setMessages((current) =>
        current.length
          ? current
          : [
              {
                id: "welcome",
                role: "assistant",
                text: `${latest.headline} ${latest.summary}`,
              },
            ]
      );
      await refreshStructuredPlan(latest, nextProfile, tone, strength, entries);
    } catch (error) {
      setHealthError(
        error instanceof Error
          ? error.message
          : "Could not load health data. Start the local server and retry."
      );
      setCoachPlan(buildLocalStructuredPlan(null, nextProfile, tone, strength, entries));
    } finally {
      setHealthLoading(false);
    }
  }

  useEffect(() => {
    async function bootstrap() {
      const [storedProfile, done, storedTone, storedStrength, storedDiary] = await Promise.all([
        loadProfile(),
        loadOnboardingComplete(),
        loadCoachTone(),
        loadPersonalityStrength(),
        loadDiaryEntries(),
      ]);

      setProfile(storedProfile);
      setOnboardingDone(done);
      setCoachTone(storedTone);
      setPersonalityStrength(storedStrength);
      setDiaryEntries(storedDiary);
      setLoading(false);
      await loadHealthData(storedProfile, storedTone, storedStrength, storedDiary);
    }

    void bootstrap();
  }, []);

  useEffect(() => {
    if (!onboardingDone) {
      setDraft(profile[fields[questionIndex]] ?? "");
    }
  }, [onboardingDone, profile, questionIndex]);

  async function advanceOnboarding() {
    const key = fields[questionIndex];
    const nextProfile = { ...profile, [key]: draft.trim() };
    setProfile(nextProfile);
    await saveProfile(nextProfile);

    if (questionIndex === fields.length - 1) {
      await saveOnboardingComplete(true);
      setOnboardingDone(true);
      setQuestionIndex(0);
      setDraft("");
      await refreshStructuredPlan(latestHealth, nextProfile);
      return;
    }

    setQuestionIndex((value) => value + 1);
    setDraft(nextProfile[fields[questionIndex + 1]]);
  }

  async function handleSendMessage(prefill?: string) {
    const raw = (prefill ?? chatInput).trim();
    if (!raw || chatLoading) {
      return;
    }

    setChatOpen(true);
    setChatInput("");
    setChatLoading(true);
    setMessages((current) => [
      ...current,
      {
        id: `user-${Date.now()}`,
        role: "user",
        text: raw,
      },
    ]);

    const replyText = await sendCoachMessage(raw, profile);

    setMessages((current) => [
      ...current,
      {
        id: `assistant-${Date.now()}`,
        role: "assistant",
        text: replyText,
      },
    ]);
    setChatLoading(false);
  }

  async function handleScenarioChange(fixtureId: string) {
    setScenarioLoading(true);
    setHealthError(null);

    try {
      const latest = await importMockHealthFixture(fixtureId);
      const nextTimeline = await fetchHealthTimeline();
      setLatestHealth(latest);
      setTimeline(nextTimeline);
      setMessages((current) => [
        ...current,
        {
          id: `assistant-fixture-${Date.now()}`,
          role: "assistant",
          text: `Loaded ${latest.scenarioLabel}. ${latest.summary}`,
        },
      ]);
      await refreshStructuredPlan(latest);
    } catch (error) {
      setHealthError(error instanceof Error ? error.message : "Could not switch scenarios.");
    } finally {
      setScenarioLoading(false);
    }
  }

  async function handleToneChange(tone: CoachToneMode) {
    setCoachTone(tone);
    await saveCoachTone(tone);
    await refreshStructuredPlan(latestHealth, profile, tone, personalityStrength, diaryEntries);
  }

  async function handleStrengthChange(strength: number) {
    setPersonalityStrength(strength);
    await savePersonalityStrength(strength);
    await refreshStructuredPlan(latestHealth, profile, coachTone, strength, diaryEntries);
  }

  async function addDiaryEntry(textOverride?: string, tagsOverride?: string[]) {
    const text = (textOverride ?? diaryDraft).trim();
    const tags = tagsOverride ?? selectedDiaryTags;
    if (!text && !tags.length) {
      return;
    }

    const nextEntries = [
      {
        id: `diary-${Date.now()}`,
        text: text || tags.join(", "),
        tags,
        createdAt: new Date().toISOString(),
      },
      ...diaryEntries,
    ].slice(0, 20);
    setDiaryEntries(nextEntries);
    setDiaryDraft("");
    setSelectedDiaryTags([]);
    setVoiceNoteState("idle");
    await saveDiaryEntries(nextEntries);
    await refreshStructuredPlan(latestHealth, profile, coachTone, personalityStrength, nextEntries);
  }

  function toggleDiaryTag(tag: string) {
    setSelectedDiaryTags((current) =>
      current.includes(tag) ? current.filter((item) => item !== tag) : [...current, tag]
    );
  }

  function toggleTask(taskId: string) {
    setCheckedTasks((current) => ({ ...current, [taskId]: !current[taskId] }));
  }

  function captureVoiceNote() {
    setVoiceNoteState("captured");
    setDiaryDraft((current) => current || "Voice note captured for coach context.");
  }

  const plan = coachPlan ?? buildLocalStructuredPlan(latestHealth, profile, coachTone, personalityStrength, diaryEntries);

  if (loading) {
    return (
      <View style={styles.loadingWrap}>
        <ActivityIndicator color={palette.sage} />
        <Text style={styles.loadingText}>Loading AI Coach</Text>
      </View>
    );
  }

  if (!onboardingDone) {
    return (
      <ScrollView
        style={styles.container}
        contentContainerStyle={styles.onboardingContent}
        keyboardShouldPersistTaps="handled"
      >
        <Card style={styles.onboardingHero}>
          <Text style={styles.pill}>AI Coach Study</Text>
          <Text style={styles.onboardingTitle}>A coach that turns signals into a plan.</Text>
          <Text style={styles.onboardingBody}>
            This prototype combines recovery, sleep, stress, movement, and your goals into a
            simple daily health plan.
          </Text>
        </Card>

        <Card>
          <Text style={styles.questionCounter}>
            Question {questionIndex + 1} of {onboardingQuestions.length}
          </Text>
          <Text style={styles.questionText}>{onboardingQuestions[questionIndex]}</Text>
          <AppTextInput
            value={draft}
            onChangeText={setDraft}
            placeholder="Type your answer"
            multiline={questionIndex === 1}
          />
          <View style={styles.primaryAction}>
            <PrimaryButton
              label={questionIndex === onboardingQuestions.length - 1 ? "Finish setup" : "Continue"}
              onPress={() => {
                void advanceOnboarding();
              }}
              disabled={!draft.trim()}
            />
          </View>
        </Card>
      </ScrollView>
    );
  }

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === "ios" ? "padding" : undefined}
    >
      {chatOpen ? (
        <CoachChatScreen
          messages={messages}
          input={chatInput}
          setInput={setChatInput}
          loading={chatLoading}
          onClose={() => setChatOpen(false)}
          onSend={() => {
            void handleSendMessage();
          }}
        />
      ) : (
        <>
          <AppHeader
            tab={tab}
            firstName={firstName}
            subtitle={tab === "today" ? "Coach is active" : "Coach is reviewing"}
            onChat={() => setChatOpen(true)}
          />

          {tab === "today" ? (
            <TodayScreen
              plan={plan}
              health={latestHealth}
              healthLoading={healthLoading}
              healthError={healthError}
              scenarioLoading={scenarioLoading}
              coachTone={coachTone}
              personalityStrength={personalityStrength}
              checkedTasks={checkedTasks}
              selectedDiaryTags={selectedDiaryTags}
              diaryDraft={diaryDraft}
              voiceNoteState={voiceNoteState}
              onDiaryDraftChange={setDiaryDraft}
              onToggleDiaryTag={toggleDiaryTag}
              onToggleTask={toggleTask}
              onCaptureVoiceNote={captureVoiceNote}
              onAddDiary={() => {
                void addDiaryEntry();
              }}
              onToneChange={(tone) => {
                void handleToneChange(tone);
              }}
              onStrengthChange={(strength) => {
                void handleStrengthChange(strength);
              }}
              onRetry={() => {
                void loadHealthData(profile, coachTone, personalityStrength, diaryEntries);
              }}
              onLoadScenario={(fixtureId) => {
                void handleScenarioChange(fixtureId);
              }}
            />
          ) : null}
          {tab === "insights" ? (
            <InsightsScreen plan={plan} health={latestHealth} timeline={timeline} />
          ) : null}
          {tab === "workouts" ? (
            <WorkoutsScreen
              plan={plan}
              coachTone={coachTone}
              personalityStrength={personalityStrength}
              onToneChange={(tone) => void handleToneChange(tone)}
              onStrengthChange={(strength) => void handleStrengthChange(strength)}
            />
          ) : null}
          {tab === "profile" ? (
            <ProfileScreen
              profile={profile}
              plan={plan}
              coachTone={coachTone}
              personalityStrength={personalityStrength}
              latestHealth={latestHealth}
              onToneChange={(tone) => {
                void handleToneChange(tone);
              }}
              onStrengthChange={(strength) => {
                void handleStrengthChange(strength);
              }}
            />
          ) : null}

          <BottomTabs activeTab={tab} onChange={setTab} />
        </>
      )}
    </KeyboardAvoidingView>
  );
}

function AppHeader({
  tab,
  firstName,
  subtitle,
  onChat,
}: {
  tab: TabKey;
  firstName: string;
  subtitle: string;
  onChat: () => void;
}) {
  return (
    <View style={styles.header}>
      <View style={styles.headerLeft}>
        <View style={styles.avatar}>
          <Text style={styles.avatarText}>{firstName.slice(0, 1).toUpperCase()}</Text>
        </View>
        <View>
          <Text style={styles.headerTitle}>{tab === "today" ? `Good morning, ${firstName}` : tabLabels[tab]}</Text>
          <View style={styles.activeRow}>
            <View style={styles.statusDot} />
            <Text style={styles.headerSubtitle}>{subtitle}</Text>
          </View>
        </View>
      </View>
      <Pressable style={({ pressed }) => [styles.iconButton, pressed && styles.pressed]} onPress={onChat}>
        <Text style={styles.iconButtonText}>chat</Text>
      </Pressable>
    </View>
  );
}

function EmptyState({
  title,
  body,
  loading,
  onRetry,
}: {
  title: string;
  body: string;
  loading?: boolean;
  onRetry: () => void;
}) {
  return (
    <ScrollView style={styles.content} contentContainerStyle={styles.screenContent}>
      <Card style={styles.centerCard}>
        {loading ? <ActivityIndicator color={palette.sage} /> : null}
        <Text style={styles.cardTitle}>{title}</Text>
        <Text style={styles.cardBody}>{body}</Text>
        <PrimaryButton label="Retry" onPress={onRetry} />
      </Card>
    </ScrollView>
  );
}

function TodayScreen({
  plan,
  health,
  healthLoading,
  healthError,
  scenarioLoading,
  coachTone,
  personalityStrength,
  checkedTasks,
  selectedDiaryTags,
  diaryDraft,
  voiceNoteState,
  onDiaryDraftChange,
  onToggleDiaryTag,
  onToggleTask,
  onCaptureVoiceNote,
  onAddDiary,
  onToneChange,
  onStrengthChange,
  onRetry,
  onLoadScenario,
}: {
  plan: CoachPlanResponse;
  health: LatestHealthResponse | null;
  healthLoading: boolean;
  healthError: string | null;
  scenarioLoading: boolean;
  coachTone: CoachToneMode;
  personalityStrength: number;
  checkedTasks: Record<string, boolean>;
  selectedDiaryTags: string[];
  diaryDraft: string;
  voiceNoteState: "idle" | "captured";
  onDiaryDraftChange: (value: string) => void;
  onToggleDiaryTag: (tag: string) => void;
  onToggleTask: (taskId: string) => void;
  onCaptureVoiceNote: () => void;
  onAddDiary: () => void;
  onToneChange: (tone: CoachToneMode) => void;
  onStrengthChange: (strength: number) => void;
  onRetry: () => void;
  onLoadScenario: (fixtureId: string) => void;
}) {
  if (healthLoading && !health) {
    return (
      <EmptyState
        title="Loading the latest sync"
        body="Fetching the current mock bracelet payload."
        loading
        onRetry={onRetry}
      />
    );
  }

  if (!health) {
    return (
      <EmptyState
        title="Health data is unavailable"
        body={healthError || "Start the local server, then retry loading the mock sync data."}
        onRetry={onRetry}
      />
    );
  }

  return (
    <ScrollView style={styles.content} contentContainerStyle={styles.screenContent}>
      <View style={styles.heroSection}>
        <View style={styles.scoreRow}>
          <Text style={styles.statusPill}>{plan.status}</Text>
          <Text style={styles.overallScore}>{plan.overallScore}</Text>
        </View>
        <Text style={styles.heroTitle}>{plan.headline}</Text>
        <Text style={styles.heroBody}>{plan.summary}</Text>
        <View style={styles.activeRow}>
          <View style={[styles.statusDot, { backgroundColor: health.syncStatus.stale ? palette.coral : palette.sage }]} />
          <Text style={styles.syncText}>
            {health.syncStatus.label} - {formatShortDate(health.latestDay.date)}
          </Text>
        </View>
      </View>

      <View style={styles.insightGrid}>
        {plan.cards.map((card) => (
          <InsightBentoCard key={card.id} score={card} />
        ))}
      </View>

      <SectionHeading title="Today's moves" />
      <Card style={styles.actionList}>
        {plan.tasks.slice(0, 5).map((task) => (
          <ActionRow
            key={task.id}
            task={task}
            checked={Boolean(checkedTasks[task.id])}
            onToggle={() => onToggleTask(task.id)}
          />
        ))}
      </Card>

      <SectionHeading title="Coach nudges" />
      <Card style={styles.nudgeCard}>
        <Text style={styles.cardBody}>
          Your coach is active but subtle today. It will nudge hydration, breathing, movement, and
          wind-down only when the plan needs help.
        </Text>
        {plan.alerts.slice(0, 3).map((alert) => (
          <View key={alert.id} style={styles.nudgeRow}>
            <View style={styles.statusDot} />
            <View style={{ flex: 1 }}>
              <Text style={styles.actionTitle}>{alert.title}</Text>
              <Text style={styles.actionText}>{alert.detail}</Text>
            </View>
          </View>
        ))}
      </Card>

      <SectionHeading title="Workout today" />
      <WorkoutHero plan={plan} />

      <Card>
        <Text style={styles.cardTitle}>Why this plan?</Text>
        <Text style={styles.cardBody}>Raw numbers are here when you want them, but the coach uses them to decide what to do next.</Text>
        <View style={styles.rawGrid}>
          <MiniStat label="RHR" value={`${health.latestDay.restingHeartRate} bpm`} />
          <MiniStat label="HRV" value={`${health.latestDay.hrv} ms`} />
          <MiniStat label="Sleep" value={formatSleep(health.latestDay.sleepDurationMinutes)} />
          <MiniStat label="Steps" value={health.latestDay.steps.toLocaleString()} />
          <MiniStat label="Stress" value={health.latestDay.stressLabel} />
        </View>
      </Card>

      <Card style={styles.diaryCard}>
        <Text style={styles.cardTitle}>What changed today?</Text>
        <View style={styles.diaryInputRow}>
          <TextInput
            value={diaryDraft}
            onChangeText={onDiaryDraftChange}
            placeholder="Add a note..."
            placeholderTextColor={palette.textFaint}
            style={styles.diaryInput}
            returnKeyType="done"
            onSubmitEditing={onAddDiary}
          />
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Add voice note placeholder"
            style={({ pressed }) => [styles.micButton, voiceNoteState === "captured" && styles.micButtonActive, pressed && styles.pressed]}
            onPress={onCaptureVoiceNote}
          >
            <Text style={[styles.micButtonText, voiceNoteState === "captured" && styles.micButtonTextActive]}>
              {voiceNoteState === "captured" ? "ok" : "mic"}
            </Text>
          </Pressable>
        </View>
        <View style={styles.chipWrap}>
          {diaryTags.map((tag) => {
            const active = selectedDiaryTags.includes(tag);
            return (
              <Pressable
                key={tag}
                style={({ pressed }) => [
                  styles.smallChip,
                  active && styles.smallChipActive,
                  pressed && styles.pressed,
                ]}
                onPress={() => onToggleDiaryTag(tag)}
              >
                <Text style={[styles.smallChipText, active && styles.smallChipTextActive]}>{tag}</Text>
              </Pressable>
            );
          })}
          <Pressable
            style={({ pressed }) => [
              styles.saveContextButton,
              !diaryDraft.trim() && !selectedDiaryTags.length && styles.disabledButton,
              pressed && styles.pressed,
            ]}
            disabled={!diaryDraft.trim() && !selectedDiaryTags.length}
            onPress={onAddDiary}
          >
            <Text style={styles.saveContextText}>Save context</Text>
          </Pressable>
        </View>
      </Card>

      <ToneSelector
        value={coachTone}
        strength={personalityStrength}
        compact
        onChange={onToneChange}
        onStrengthChange={onStrengthChange}
      />

      <Card>
        <Text style={styles.cardTitle}>Mock sync inputs</Text>
        <Text style={styles.cardBody}>Use these scenarios until the watch SDK is wired in.</Text>
        <View style={styles.scenarioWrap}>
          {health.availableFixtures.map((fixture) => {
            const active = fixture.id === health.scenarioId;
            return (
              <Pressable
                key={fixture.id}
                onPress={() => onLoadScenario(fixture.id)}
                style={({ pressed }) => [
                  styles.scenarioChip,
                  active && styles.scenarioChipActive,
                  pressed && styles.pressed,
                ]}
              >
                <Text style={[styles.scenarioTitle, active && styles.scenarioTitleActive]}>
                  {fixture.label}
                </Text>
                <Text style={styles.scenarioBody}>{fixture.summary}</Text>
              </Pressable>
            );
          })}
        </View>
        {scenarioLoading ? <Text style={styles.footnote}>Switching scenarios...</Text> : null}
      </Card>
    </ScrollView>
  );
}

function InsightBentoCard({ score }: { score: CoachScore }) {
  return (
    <Card style={styles.insightBento}>
      <View style={[styles.metricIcon, { backgroundColor: `${toneColor(score.score)}22` }]}>
        <Text style={[styles.metricIconText, { color: toneColor(score.score) }]}>
          {score.label.slice(0, 2).toLowerCase()}
        </Text>
      </View>
      <Text style={styles.insightTitle}>{score.label}</Text>
      <Text style={styles.cardBody}>{score.explanation}</Text>
    </Card>
  );
}

function ActionRow({
  task,
  checked,
  onToggle,
}: {
  task: CoachTask;
  checked: boolean;
  onToggle: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="checkbox"
      accessibilityState={{ checked }}
      onPress={onToggle}
      style={({ pressed }) => [styles.actionRow, checked && styles.actionRowChecked, pressed && styles.pressed]}
    >
      <View style={[styles.checkbox, checked && styles.checkboxChecked]}>
        <Text style={[styles.checkboxText, checked && styles.checkboxTextChecked]}>
          {checked ? "✓" : taskIcon(task.category)}
        </Text>
      </View>
      <View style={styles.actionCopy}>
        <Text style={[styles.actionTitle, checked && styles.checkedText]}>{task.title}</Text>
        <Text style={styles.actionText} numberOfLines={2}>{task.detail}</Text>
      </View>
    </Pressable>
  );
}

function WorkoutHero({ plan }: { plan: CoachPlanResponse }) {
  const workout = plan.workoutOfTheDay;
  return (
    <Card style={styles.workoutCard}>
      <View style={styles.workoutVisual}>
        <View style={styles.playButton}>
          <Text style={styles.playButtonText}>play</Text>
        </View>
        <Text style={styles.workoutVisualText}>cached demo loop</Text>
      </View>
      <View style={styles.workoutCopy}>
        <View style={styles.rowBetween}>
          <View style={{ flex: 1 }}>
            <Text style={styles.cardTitle}>{workout.title}</Text>
            <Text style={styles.footnote}>{workout.duration} - {workout.label}</Text>
          </View>
          <Text style={styles.statusPill}>{workout.label}</Text>
        </View>
        <Text style={styles.cardBody}>{workout.why}</Text>
        <View style={styles.cueBox}>
          <Text style={styles.label}>Coaching cues</Text>
          {workout.cues.slice(0, 3).map((cue) => (
            <Text key={cue} style={styles.cueText}>{cue}</Text>
          ))}
        </View>
      </View>
    </Card>
  );
}

function InsightsScreen({
  plan,
  health,
  timeline,
}: {
  plan: CoachPlanResponse;
  health: LatestHealthResponse | null;
  timeline: HealthTimelineResponse | null;
}) {
  const avgRecovery = average(timeline?.points.map((point) => point.recoveryScore) ?? []);
  return (
    <ScrollView style={styles.content} contentContainerStyle={styles.screenContent}>
      <Card style={styles.weeklyFocus}>
        <Text style={styles.cardTitle}>Weekly focus</Text>
        <Text style={styles.weeklyText}>
          {timeline?.trendSummary ?? "The coach is watching the relationship between recovery, sleep, movement, and stress before recommending harder work."}
        </Text>
        {health ? <Text style={styles.footnote}>Active scenario: {health.scenarioLabel}</Text> : null}
      </Card>

      <SectionHeading title="Key trends" />
      {plan.trendInsights.map((trend) => (
        <TrendCard key={trend.id} trend={trend} />
      ))}

      <Card>
        <Text style={styles.cardTitle}>Pattern snapshot</Text>
        <View style={styles.rawGrid}>
          <MiniStat label="Avg recovery" value={`${avgRecovery || plan.overallScore}/100`} />
          <MiniStat label="Coach score" value={`${plan.overallScore}/100`} />
          <MiniStat label="Status" value={plan.status} />
        </View>
      </Card>

      <SectionHeading title="Observed correlations" />
      {plan.correlations.map((correlation) => (
        <CorrelationCard key={correlation.id} correlation={correlation} />
      ))}
    </ScrollView>
  );
}

function TrendCard({ trend }: { trend: CoachTrendInsight }) {
  const max = Math.max(...trend.values, 100);
  return (
    <Card style={styles.trendCard}>
      <View style={styles.rowBetween}>
        <View style={styles.trendTitleRow}>
          <View style={styles.metricIcon}>
            <Text style={styles.metricIconText}>{trend.title.slice(0, 2).toLowerCase()}</Text>
          </View>
          <Text style={styles.insightTitle}>{trend.title}</Text>
        </View>
        <Text style={styles.statusPill}>{trend.status}</Text>
      </View>
      <View style={styles.trendBars}>
        {trend.values.map((value, index) => (
          <View key={`${trend.id}-${index}`} style={styles.trendTrack}>
            <View style={[styles.trendFill, { height: Math.max(8, (value / max) * 72) }]} />
          </View>
        ))}
      </View>
      <View style={styles.coachTake}>
        <Text style={styles.label}>Coach's take</Text>
        <Text style={styles.cardBody}>{trend.explanation}</Text>
      </View>
    </Card>
  );
}

function CorrelationCard({ correlation }: { correlation: CoachCorrelation }) {
  return (
    <Card style={styles.correlationCard}>
      <View style={styles.metricIcon}>
        <Text style={styles.metricIconText}>{correlation.title.slice(0, 2).toLowerCase()}</Text>
      </View>
      <View style={{ flex: 1 }}>
        <Text style={styles.insightTitle}>{correlation.title}</Text>
        <Text style={styles.cardBody}>{correlation.explanation}</Text>
      </View>
    </Card>
  );
}

function WorkoutsScreen({
  plan,
  coachTone,
  personalityStrength,
  onToneChange,
  onStrengthChange,
}: {
  plan: CoachPlanResponse;
  coachTone: CoachToneMode;
  personalityStrength: number;
  onToneChange: (tone: CoachToneMode) => void;
  onStrengthChange: (strength: number) => void;
}) {
  return (
    <ScrollView style={styles.content} contentContainerStyle={styles.screenContent}>
      <ToneSelector
        value={coachTone}
        strength={personalityStrength}
        onChange={onToneChange}
        onStrengthChange={onStrengthChange}
      />
      <SectionHeading title="Recommended for you" />
      <WorkoutHero plan={plan} />

      <Card style={styles.coachTake}>
        <Text style={styles.label}>AI media prompt</Text>
        <Text style={styles.cardBody}>{plan.workoutOfTheDay.mediaPrompt}</Text>
      </Card>

      <SectionHeading title="Library" />
      {workoutLibrary.map((item) => (
        <Card key={item.title} style={styles.libraryRow}>
          <View style={styles.libraryThumb}>
            <Text style={styles.libraryIcon}>{item.icon}</Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={styles.insightTitle}>{item.title}</Text>
            <Text style={styles.footnote}>{item.meta}</Text>
          </View>
          <View style={styles.smallPlay}>
            <Text style={styles.smallPlayText}>go</Text>
          </View>
        </Card>
      ))}
    </ScrollView>
  );
}

function ProfileScreen({
  profile,
  plan,
  coachTone,
  personalityStrength,
  latestHealth,
  onToneChange,
  onStrengthChange,
}: {
  profile: UserProfile;
  plan: CoachPlanResponse;
  coachTone: CoachToneMode;
  personalityStrength: number;
  latestHealth: LatestHealthResponse | null;
  onToneChange: (tone: CoachToneMode) => void;
  onStrengthChange: (strength: number) => void;
}) {
  return (
    <ScrollView style={styles.content} contentContainerStyle={styles.screenContent}>
      <View style={styles.profileHeader}>
        <View style={styles.profileAvatar}>
          <Text style={styles.profileAvatarText}>{firstNameFrom(profile).slice(0, 1).toUpperCase()}</Text>
        </View>
        <Text style={styles.profileName}>{profile.name || "Your profile"}</Text>
        <Text style={styles.statusPill}>{plan.status}</Text>
      </View>

      <Card>
        <Text style={styles.cardTitle}>Coach style</Text>
        <Text style={styles.cardBody}>Adjust how your AI coach talks while keeping the same safety rules.</Text>
        <ToneSelector
          value={coachTone}
          strength={personalityStrength}
          compact
          onChange={onToneChange}
          onStrengthChange={onStrengthChange}
        />
        <Text style={styles.personalityPreview}>{personalityPreview(coachTone, personalityStrength)}</Text>
        <View style={styles.settingRow}>
          <View>
            <Text style={styles.actionTitle}>Notifications</Text>
            <Text style={styles.footnote}>Daily summary and subtle nudges</Text>
          </View>
          <View style={styles.toggleOn}>
            <View style={styles.toggleKnob} />
          </View>
        </View>
      </Card>

      <Card>
        <Text style={styles.cardTitle}>Connected devices</Text>
        <DeviceRow title="Apple Health" detail="Height and weight planned for native sync" active />
        <DeviceRow title="Screenless wearable" detail={latestHealth ? `Mock sync: ${latestHealth.scenarioLabel}` : "Mock data active"} active />
        <DeviceRow title="Add device" detail="Watch SDK integration comes next" />
      </Card>

      <Card>
        <Text style={styles.cardTitle}>{profile.name || "Your profile"}</Text>
        <Text style={styles.cardBody}>
          Goal: {profile.goals || "Improve overall wellness"}{"\n"}
          Preferred movement: {profile.exerciseType || "Not set"}{"\n"}
          Sleep target: {profile.sleepTime || "Not set"}{"\n"}
          Stress context: {profile.workStress || "Not set"}
        </Text>
      </Card>

      <Card style={styles.linkList}>
        {["Personal information", "Privacy & security", "Support & FAQ", "Log out"].map((label) => (
          <View key={label} style={styles.linkRow}>
            <Text style={[styles.actionTitle, label === "Log out" && { color: palette.error }]}>{label}</Text>
            <Text style={styles.footnote}>open</Text>
          </View>
        ))}
      </Card>
    </ScrollView>
  );
}

function DeviceRow({ title, detail, active }: { title: string; detail: string; active?: boolean }) {
  return (
    <View style={styles.deviceRow}>
      <View style={styles.metricIcon}>
        <Text style={styles.metricIconText}>{title.slice(0, 2).toLowerCase()}</Text>
      </View>
      <View style={{ flex: 1 }}>
        <Text style={styles.actionTitle}>{title}</Text>
        <Text style={styles.footnote}>{detail}</Text>
      </View>
      <Text style={[styles.statusPill, !active && styles.neutralPill]}>{active ? "Synced" : "Add"}</Text>
    </View>
  );
}

function ToneSelector({
  value,
  strength,
  compact,
  onChange,
  onStrengthChange,
}: {
  value: CoachToneMode;
  strength: number;
  compact?: boolean;
  onChange: (tone: CoachToneMode) => void;
  onStrengthChange: (strength: number) => void;
}) {
  return (
    <View style={[styles.toneWrap, compact && styles.toneWrapCompact]}>
      {!compact ? <Text style={styles.label}>Coach vibe</Text> : null}
      <View style={styles.toneSegment}>
        {toneLabels.map((tone) => {
          const active = tone.value === value;
          return (
            <Pressable
              key={tone.value}
              onPress={() => onChange(tone.value)}
              style={({ pressed }) => [
                styles.toneButton,
                active && styles.toneButtonActive,
                pressed && styles.pressed,
              ]}
            >
              <Text style={[styles.toneText, active && styles.toneTextActive]}>
                {compact ? tone.short : tone.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
      <View style={styles.strengthRow}>
        <Text style={styles.label}>Strength</Text>
        <View style={styles.strengthDots}>
          {[1, 2, 3, 4, 5].map((level) => (
            <Pressable
              key={level}
              accessibilityRole="button"
              accessibilityLabel={`Set personality strength ${level}`}
              onPress={() => onStrengthChange(level)}
              style={({ pressed }) => [
                styles.strengthDot,
                level <= strength && styles.strengthDotActive,
                pressed && styles.pressed,
              ]}
            >
              <Text style={[styles.strengthDotText, level <= strength && styles.strengthDotTextActive]}>
                {level}
              </Text>
            </Pressable>
          ))}
        </View>
      </View>
    </View>
  );
}

function personalityPreview(tone: CoachToneMode, strength: number) {
  if (tone === "unhinged" && strength >= 5) {
    return "Example: We are not raw-dogging this day on low recovery. Drink the damn water, move easy, and let sleep do its job.";
  }
  if (tone === "unhinged") {
    return "Example: Tiny chaos, useful plan. Your nervous system wants a reset, not a heroic workout arc.";
  }
  if (tone === "direct") {
    return strength >= 4
      ? "Example: Keep it easy today. Hydrate early, skip intensity, protect bedtime."
      : "Example: The priority is recovery. Use easy movement and an earlier wind-down.";
  }
  if (tone === "hype") {
    return "Example: Today's mission is simple: stack easy wins and build momentum without draining the tank.";
  }
  if (tone === "nice") {
    return "Example: You are not off track. A small reset today is enough to make tomorrow easier.";
  }
  return "Example: Let's keep this simple and kind to your system. Small actions count today.";
}

function MiniStat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.miniStat}>
      <Text style={styles.miniStatLabel}>{label}</Text>
      <Text style={styles.miniStatValue}>{value}</Text>
    </View>
  );
}

function SectionHeading({ title }: { title: string }) {
  return <Text style={styles.sectionTitle}>{title}</Text>;
}

function CoachChatScreen({
  messages,
  input,
  setInput,
  loading,
  onClose,
  onSend,
}: {
  messages: CoachMessage[];
  input: string;
  setInput: (value: string) => void;
  loading: boolean;
  onClose: () => void;
  onSend: () => void;
}) {
  return (
    <View style={styles.coachScreen}>
      <View style={styles.header}>
        <View style={styles.headerLeft}>
          <View style={styles.avatar}>
            <Text style={styles.avatarText}>AI</Text>
          </View>
          <View>
            <Text style={styles.headerTitle}>Coach chat</Text>
            <Text style={styles.headerSubtitle}>Short answers, practical next steps</Text>
          </View>
        </View>
        <Pressable style={({ pressed }) => [styles.iconButton, pressed && styles.pressed]} onPress={onClose}>
          <Text style={styles.iconButtonText}>done</Text>
        </Pressable>
      </View>
      <ScrollView style={styles.content} contentContainerStyle={styles.chatContent}>
        {messages.map((message) => (
          <View
            key={message.id}
            style={[
              styles.messageRow,
              message.role === "user" ? styles.messageRowUser : styles.messageRowCoach,
            ]}
          >
            <View
              style={[
                styles.messageBubble,
                message.role === "user" ? styles.userBubble : styles.coachBubble,
              ]}
            >
              <Text style={message.role === "user" ? styles.userBubbleText : styles.coachBubbleText}>
                {message.text}
              </Text>
            </View>
          </View>
        ))}
        {loading ? <Text style={styles.footnote}>Coach is thinking...</Text> : null}
      </ScrollView>
      <View style={styles.chatComposerWrap}>
        <View style={styles.chatInputRow}>
          <TextInput
            value={input}
            onChangeText={setInput}
            placeholder="Ask your coach..."
            placeholderTextColor={palette.textFaint}
            style={styles.chatInput}
            returnKeyType="send"
            onSubmitEditing={onSend}
          />
          <Pressable
            disabled={!input.trim() || loading}
            style={({ pressed }) => [
              styles.sendButton,
              (!input.trim() || loading) && styles.disabledButton,
              pressed && input.trim() && !loading && styles.pressed,
            ]}
            onPress={onSend}
          >
            <Text style={styles.sendButtonText}>Send</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

function BottomTabs({
  activeTab,
  onChange,
}: {
  activeTab: TabKey;
  onChange: (tab: TabKey) => void;
}) {
  return (
    <View style={styles.tabBar}>
      {(Object.keys(tabLabels) as TabKey[]).map((key) => {
        const active = key === activeTab;
        return (
          <Pressable
            key={key}
            onPress={() => onChange(key)}
            style={({ pressed }) => [
              styles.tabItem,
              active && styles.tabItemActive,
              pressed && styles.pressed,
            ]}
          >
            <Text style={[styles.tabGlyph, active && styles.tabGlyphActive]}>{tabGlyphs[key]}</Text>
            <Text style={[styles.tabText, active && styles.tabTextActive]}>{tabLabels[key]}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: palette.canvas,
  },
  content: {
    flex: 1,
    backgroundColor: palette.canvas,
  },
  screenContent: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: 132,
    gap: spacing.lg,
  },
  loadingWrap: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.canvas,
    gap: spacing.sm,
  },
  loadingText: {
    color: palette.textMuted,
    fontSize: 14,
  },
  onboardingContent: {
    padding: spacing.lg,
    gap: spacing.lg,
  },
  onboardingHero: {
    gap: spacing.sm,
  },
  pill: {
    alignSelf: "flex-start",
    backgroundColor: palette.sage,
    borderRadius: radius.pill,
    color: palette.surface,
    fontSize: 12,
    fontWeight: "700",
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  onboardingTitle: {
    color: palette.text,
    fontSize: 31,
    fontWeight: "700",
    lineHeight: 38,
  },
  onboardingBody: {
    color: palette.textMuted,
    fontSize: 16,
    lineHeight: 24,
  },
  questionCounter: {
    color: palette.textFaint,
    fontSize: 13,
    marginBottom: spacing.sm,
  },
  questionText: {
    color: palette.text,
    fontSize: 24,
    fontWeight: "700",
    lineHeight: 31,
    marginBottom: spacing.md,
  },
  primaryAction: {
    marginTop: spacing.md,
  },
  header: {
    minHeight: 72,
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    paddingHorizontal: spacing.lg,
    paddingVertical: spacing.md,
    backgroundColor: palette.canvas,
    borderBottomColor: palette.line,
    borderBottomWidth: 1,
  },
  headerLeft: {
    alignItems: "center",
    flexDirection: "row",
    flex: 1,
    gap: spacing.md,
    minWidth: 0,
  },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: radius.pill,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.sageSoft,
  },
  avatarText: {
    color: palette.sage,
    fontSize: 15,
    fontWeight: "800",
  },
  headerTitle: {
    color: palette.sage,
    fontSize: 18,
    fontWeight: "700",
    flexShrink: 1,
  },
  headerSubtitle: {
    color: palette.textFaint,
    fontSize: 11,
    marginTop: 2,
  },
  activeRow: {
    alignItems: "center",
    flexDirection: "row",
    gap: 8,
    marginTop: 4,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: radius.pill,
    backgroundColor: palette.sage,
  },
  iconButton: {
    minWidth: 44,
    height: 40,
    borderRadius: radius.pill,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1,
    borderColor: palette.line,
    backgroundColor: palette.surface,
    paddingHorizontal: 10,
  },
  iconButtonText: {
    color: palette.sage,
    fontSize: 11,
    fontWeight: "800",
  },
  pressed: {
    opacity: 0.82,
  },
  centerCard: {
    gap: spacing.md,
    alignItems: "flex-start",
  },
  heroSection: {
    gap: spacing.md,
    paddingTop: spacing.sm,
  },
  scoreRow: {
    alignItems: "center",
    flexDirection: "row",
    gap: spacing.md,
  },
  statusPill: {
    alignSelf: "flex-start",
    backgroundColor: palette.sageSoft,
    borderRadius: radius.pill,
    color: palette.sage,
    fontSize: 12,
    fontWeight: "900",
    overflow: "hidden",
    paddingHorizontal: 12,
    paddingVertical: 7,
    textTransform: "uppercase",
  },
  neutralPill: {
    backgroundColor: palette.surfaceMuted,
    color: palette.textMuted,
  },
  overallScore: {
    color: palette.sage,
    fontSize: 40,
    fontWeight: "300",
    lineHeight: 48,
  },
  heroTitle: {
    color: palette.text,
    fontSize: 28,
    fontWeight: "500",
    lineHeight: 34,
  },
  heroBody: {
    color: palette.textMuted,
    fontSize: 16,
    lineHeight: 24,
  },
  syncText: {
    color: palette.textMuted,
    fontSize: 13,
    fontWeight: "600",
  },
  insightGrid: {
    gap: spacing.sm,
  },
  insightBento: {
    gap: spacing.sm,
  },
  metricIcon: {
    width: 34,
    height: 34,
    borderRadius: radius.pill,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.sageSoft,
  },
  metricIconText: {
    color: palette.sage,
    fontSize: 11,
    fontWeight: "900",
  },
  insightTitle: {
    color: palette.text,
    fontSize: 16,
    fontWeight: "800",
    lineHeight: 22,
  },
  sectionTitle: {
    color: palette.text,
    fontSize: 22,
    fontWeight: "700",
    lineHeight: 28,
  },
  actionList: {
    paddingVertical: spacing.xs,
  },
  actionRow: {
    alignItems: "flex-start",
    flexDirection: "row",
    gap: spacing.md,
    paddingHorizontal: spacing.xs,
    paddingVertical: spacing.sm,
    borderBottomWidth: 1,
    borderBottomColor: palette.line,
    borderRadius: radius.md,
  },
  actionRowChecked: {
    backgroundColor: palette.surfaceMuted,
  },
  checkbox: {
    width: 28,
    height: 28,
    borderRadius: radius.sm,
    borderWidth: 1.5,
    borderColor: palette.outline,
    alignItems: "center",
    justifyContent: "center",
    marginTop: 2,
  },
  checkboxText: {
    color: palette.textMuted,
    fontSize: 10,
    fontWeight: "900",
  },
  checkboxChecked: {
    backgroundColor: palette.sage,
    borderColor: palette.sage,
  },
  checkboxTextChecked: {
    color: palette.surface,
  },
  checkedText: {
    color: palette.textFaint,
    textDecorationLine: "line-through",
  },
  actionCopy: {
    flex: 1,
    gap: 3,
    minWidth: 0,
  },
  actionTitle: {
    color: palette.text,
    fontSize: 15,
    fontWeight: "700",
  },
  actionText: {
    color: palette.textMuted,
    fontSize: 13,
    lineHeight: 18,
  },
  nudgeCard: {
    gap: spacing.md,
  },
  nudgeRow: {
    alignItems: "flex-start",
    borderTopColor: palette.line,
    borderTopWidth: 1,
    flexDirection: "row",
    gap: spacing.md,
    paddingTop: spacing.md,
  },
  workoutCard: {
    gap: 0,
    overflow: "hidden",
    padding: 0,
  },
  workoutVisual: {
    height: 188,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.surfaceHigh,
  },
  workoutVisualText: {
    color: palette.textMuted,
    fontSize: 12,
    fontWeight: "800",
    marginTop: spacing.sm,
    textTransform: "uppercase",
  },
  playButton: {
    width: 58,
    height: 58,
    borderRadius: radius.pill,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.surface,
  },
  playButtonText: {
    color: palette.sage,
    fontSize: 12,
    fontWeight: "900",
  },
  workoutCopy: {
    gap: spacing.md,
    padding: spacing.lg,
  },
  cueBox: {
    gap: spacing.sm,
    backgroundColor: palette.surfaceMuted,
    borderColor: palette.line,
    borderRadius: radius.lg,
    borderWidth: 1,
    padding: spacing.md,
  },
  cueText: {
    color: palette.textMuted,
    fontSize: 14,
    lineHeight: 20,
  },
  label: {
    color: palette.textFaint,
    fontSize: 12,
    fontWeight: "900",
    letterSpacing: 0.6,
    textTransform: "uppercase",
  },
  rawGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.sm,
    marginTop: spacing.md,
  },
  miniStat: {
    flexBasis: "48%",
    flexGrow: 1,
    minWidth: 128,
    backgroundColor: palette.surfaceMuted,
    borderRadius: radius.md,
    padding: spacing.md,
  },
  miniStatLabel: {
    color: palette.textMuted,
    fontSize: 11,
    fontWeight: "800",
    letterSpacing: 0.5,
    textTransform: "uppercase",
  },
  miniStatValue: {
    color: palette.text,
    fontSize: 16,
    fontWeight: "800",
    marginTop: 5,
  },
  diaryCard: {
    gap: spacing.md,
  },
  diaryInputRow: {
    alignItems: "center",
    borderBottomColor: palette.line,
    borderBottomWidth: 1,
    flexDirection: "row",
    gap: spacing.sm,
  },
  diaryInput: {
    flex: 1,
    color: palette.text,
    fontSize: 16,
    minHeight: 44,
    paddingVertical: spacing.sm,
  },
  chipWrap: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.sm,
  },
  smallChip: {
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: palette.line,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  smallChipActive: {
    backgroundColor: palette.sageSoft,
    borderColor: palette.sage,
  },
  smallChipText: {
    color: palette.textMuted,
    fontSize: 12,
    fontWeight: "800",
  },
  smallChipTextActive: {
    color: palette.sage,
  },
  micButton: {
    alignItems: "center",
    justifyContent: "center",
    width: 42,
    height: 42,
    borderRadius: radius.pill,
    backgroundColor: palette.surfaceMuted,
    borderWidth: 1,
    borderColor: palette.line,
  },
  micButtonActive: {
    backgroundColor: palette.sageSoft,
    borderColor: palette.sage,
  },
  micButtonText: {
    color: palette.textMuted,
    fontSize: 11,
    fontWeight: "900",
  },
  micButtonTextActive: {
    color: palette.sage,
  },
  saveContextButton: {
    borderRadius: radius.pill,
    backgroundColor: palette.sage,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  saveContextText: {
    color: palette.surface,
    fontSize: 12,
    fontWeight: "900",
  },
  toneWrap: {
    gap: spacing.sm,
  },
  toneWrapCompact: {
    marginTop: spacing.md,
  },
  toneSegment: {
    flexDirection: "row",
    gap: 4,
    backgroundColor: palette.surfaceMuted,
    borderRadius: radius.lg,
    padding: 4,
  },
  toneButton: {
    flex: 1,
    alignItems: "center",
    borderRadius: radius.md,
    minHeight: 38,
    justifyContent: "center",
    paddingHorizontal: 5,
    paddingVertical: 9,
  },
  toneButtonActive: {
    backgroundColor: palette.surface,
  },
  toneText: {
    color: palette.textMuted,
    fontSize: 11,
    fontWeight: "800",
    textAlign: "center",
  },
  toneTextActive: {
    color: palette.sage,
  },
  strengthRow: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    gap: spacing.md,
  },
  strengthDots: {
    flexDirection: "row",
    gap: spacing.xs,
  },
  strengthDot: {
    width: 30,
    height: 30,
    borderRadius: radius.pill,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.surfaceMuted,
    borderColor: palette.line,
    borderWidth: 1,
  },
  strengthDotActive: {
    backgroundColor: palette.sage,
    borderColor: palette.sage,
  },
  strengthDotText: {
    color: palette.textMuted,
    fontSize: 11,
    fontWeight: "900",
  },
  strengthDotTextActive: {
    color: palette.surface,
  },
  scenarioWrap: {
    gap: spacing.sm,
    marginTop: spacing.md,
  },
  scenarioChip: {
    backgroundColor: palette.surfaceMuted,
    borderColor: palette.line,
    borderRadius: radius.md,
    borderWidth: 1,
    gap: 5,
    padding: spacing.md,
  },
  scenarioChipActive: {
    backgroundColor: palette.sageSoft,
    borderColor: palette.sage,
  },
  scenarioTitle: {
    color: palette.text,
    fontSize: 15,
    fontWeight: "800",
  },
  scenarioTitleActive: {
    color: palette.sage,
  },
  scenarioBody: {
    color: palette.textMuted,
    fontSize: 13,
    lineHeight: 18,
  },
  footnote: {
    color: palette.textFaint,
    fontSize: 13,
    lineHeight: 18,
    marginTop: spacing.sm,
  },
  weeklyFocus: {
    backgroundColor: palette.surfaceMuted,
    gap: spacing.md,
  },
  weeklyText: {
    color: palette.text,
    fontSize: 16,
    lineHeight: 24,
  },
  trendCard: {
    gap: spacing.md,
  },
  trendTitleRow: {
    alignItems: "center",
    flexDirection: "row",
    gap: spacing.sm,
    flex: 1,
    minWidth: 0,
  },
  trendBars: {
    height: 92,
    flexDirection: "row",
    alignItems: "flex-end",
    gap: 8,
  },
  trendTrack: {
    flex: 1,
    height: 82,
    borderRadius: radius.pill,
    backgroundColor: palette.surfaceRaised,
    justifyContent: "flex-end",
    overflow: "hidden",
  },
  trendFill: {
    width: "100%",
    borderRadius: radius.pill,
    backgroundColor: palette.sage,
  },
  coachTake: {
    gap: spacing.sm,
    backgroundColor: palette.surfaceMuted,
  },
  correlationCard: {
    flexDirection: "row",
    gap: spacing.md,
  },
  libraryRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.md,
  },
  libraryThumb: {
    width: 58,
    height: 58,
    borderRadius: radius.lg,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.surfaceMuted,
  },
  libraryIcon: {
    color: palette.sage,
    fontSize: 13,
    fontWeight: "900",
  },
  smallPlay: {
    width: 34,
    height: 34,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: palette.line,
    alignItems: "center",
    justifyContent: "center",
  },
  smallPlayText: {
    color: palette.sage,
    fontSize: 11,
    fontWeight: "900",
  },
  profileHeader: {
    alignItems: "center",
    gap: spacing.sm,
    paddingVertical: spacing.md,
  },
  profileAvatar: {
    width: 96,
    height: 96,
    borderRadius: radius.pill,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.sageSoft,
  },
  profileAvatarText: {
    color: palette.sage,
    fontSize: 34,
    fontWeight: "900",
  },
  profileName: {
    color: palette.text,
    fontSize: 24,
    fontWeight: "800",
    textAlign: "center",
  },
  personalityPreview: {
    backgroundColor: palette.surfaceMuted,
    borderColor: palette.line,
    borderRadius: radius.lg,
    borderWidth: 1,
    color: palette.textMuted,
    fontSize: 14,
    lineHeight: 20,
    marginTop: spacing.md,
    padding: spacing.md,
  },
  settingRow: {
    alignItems: "center",
    borderTopColor: palette.line,
    borderTopWidth: 1,
    flexDirection: "row",
    justifyContent: "space-between",
    marginTop: spacing.md,
    paddingTop: spacing.md,
  },
  toggleOn: {
    width: 48,
    height: 26,
    borderRadius: radius.pill,
    backgroundColor: palette.sage,
    justifyContent: "center",
    alignItems: "flex-end",
    paddingHorizontal: 4,
  },
  toggleKnob: {
    width: 18,
    height: 18,
    borderRadius: radius.pill,
    backgroundColor: palette.surface,
  },
  deviceRow: {
    alignItems: "center",
    borderTopColor: palette.line,
    borderTopWidth: 1,
    flexDirection: "row",
    gap: spacing.md,
    paddingVertical: spacing.md,
    minWidth: 0,
  },
  linkList: {
    paddingVertical: 0,
  },
  linkRow: {
    alignItems: "center",
    borderBottomColor: palette.line,
    borderBottomWidth: 1,
    flexDirection: "row",
    justifyContent: "space-between",
    paddingVertical: spacing.md,
  },
  rowBetween: {
    alignItems: "flex-start",
    flexDirection: "row",
    justifyContent: "space-between",
    gap: spacing.md,
    minWidth: 0,
  },
  cardTitle: {
    color: palette.text,
    fontSize: 18,
    fontWeight: "700",
    lineHeight: 24,
  },
  cardBody: {
    color: palette.textMuted,
    fontSize: 15,
    lineHeight: 22,
  },
  coachScreen: {
    flex: 1,
    backgroundColor: palette.canvas,
  },
  chatContent: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: 132,
    gap: spacing.lg,
  },
  messageRow: {
    flexDirection: "row",
    gap: spacing.sm,
    maxWidth: "90%",
  },
  messageRowCoach: {
    alignSelf: "flex-start",
  },
  messageRowUser: {
    alignSelf: "flex-end",
  },
  messageBubble: {
    borderRadius: 18,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  coachBubble: {
    backgroundColor: palette.surface,
    borderBottomLeftRadius: 4,
    borderColor: palette.line,
    borderWidth: 1,
  },
  userBubble: {
    backgroundColor: palette.sage,
    borderBottomRightRadius: 4,
  },
  coachBubbleText: {
    color: palette.text,
    fontSize: 15,
    lineHeight: 22,
  },
  userBubbleText: {
    color: palette.surface,
    fontSize: 15,
    lineHeight: 22,
  },
  chatComposerWrap: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: spacing.lg,
    backgroundColor: palette.canvas,
  },
  chatInputRow: {
    alignItems: "center",
    backgroundColor: palette.surface,
    borderColor: palette.line,
    borderRadius: radius.pill,
    borderWidth: 1,
    flexDirection: "row",
    gap: spacing.sm,
    padding: 8,
  },
  chatInput: {
    flex: 1,
    color: palette.text,
    fontSize: 15,
    paddingHorizontal: 10,
    paddingVertical: 10,
  },
  sendButton: {
    backgroundColor: palette.sage,
    borderRadius: radius.pill,
    paddingHorizontal: 16,
    paddingVertical: 11,
  },
  disabledButton: {
    opacity: 0.45,
  },
  sendButtonText: {
    color: palette.surface,
    fontSize: 13,
    fontWeight: "900",
  },
  tabBar: {
    position: "absolute",
    bottom: 0,
    left: 0,
    right: 0,
    flexDirection: "row",
    justifyContent: "space-around",
    alignItems: "center",
    paddingTop: 10,
    paddingBottom: 24,
    paddingHorizontal: spacing.xs,
    backgroundColor: palette.surface,
    borderTopLeftRadius: radius.lg,
    borderTopRightRadius: radius.lg,
    borderTopColor: palette.line,
    borderTopWidth: 1,
    shadowColor: palette.shadow,
    shadowOpacity: 1,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: -6 },
    elevation: 8,
  },
  tabItem: {
    alignItems: "center",
    borderRadius: radius.pill,
    flex: 1,
    minWidth: 0,
    marginHorizontal: 2,
    paddingHorizontal: 6,
    paddingVertical: 7,
  },
  tabItemActive: {
    backgroundColor: palette.sageSoft,
  },
  tabGlyph: {
    color: palette.textMuted,
    fontSize: 10,
    fontWeight: "900",
    marginBottom: 2,
    textTransform: "uppercase",
  },
  tabGlyphActive: {
    color: palette.sage,
  },
  tabText: {
    color: palette.textMuted,
    fontSize: 10,
    fontWeight: "800",
    textAlign: "center",
  },
  tabTextActive: {
    color: palette.sage,
  },
});
