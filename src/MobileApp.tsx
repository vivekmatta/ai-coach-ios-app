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
  type DimensionValue,
} from "react-native";

import { AppTextInput, Card, PrimaryButton } from "./components";
import { defaultProfile, onboardingQuestions } from "./data";
import { sendCoachMessage } from "./services/coachApi";
import {
  fetchHealthTimeline,
  fetchLatestHealthData,
  importMockHealthFixture,
} from "./services/healthApi";
import {
  loadOnboardingComplete,
  loadProfile,
  saveOnboardingComplete,
  saveProfile,
} from "./storage";
import { palette, radius, spacing } from "./theme";
import {
  CoachMessage,
  HealthInsight,
  HealthMetricCard,
  HealthTimelinePoint,
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
  progress: "Progress",
  coach: "Coach",
  you: "Profile",
};

const tabGlyphs: Record<TabKey, string> = {
  today: "T",
  progress: "P",
  coach: "C",
  you: "Y",
};

const defaultQuickPrompts = [
  "What should I do today?",
  "Why is my recovery low?",
  "How can I sleep better tonight?",
];

function toneColor(tone: string) {
  switch (tone) {
    case "good":
      return palette.sage;
    case "caution":
      return palette.sand;
    case "alert":
      return palette.coral;
    default:
      return palette.blue;
  }
}

function toneSoftColor(tone: string) {
  switch (tone) {
    case "good":
      return palette.sageSoft;
    case "caution":
      return palette.sandSoft;
    case "alert":
      return palette.coralSoft;
    default:
      return palette.blueSoft;
  }
}

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
  const [latestHealth, setLatestHealth] = useState<LatestHealthResponse | null>(null);
  const [timeline, setTimeline] = useState<HealthTimelineResponse | null>(null);

  async function loadHealthData() {
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
    } catch (error) {
      setHealthError(
        error instanceof Error
          ? error.message
          : "Could not load health data. Start the local server and retry."
      );
    } finally {
      setHealthLoading(false);
    }
  }

  useEffect(() => {
    async function bootstrap() {
      const [storedProfile, done] = await Promise.all([
        loadProfile(),
        loadOnboardingComplete(),
      ]);

      setProfile(storedProfile);
      setOnboardingDone(done);
      setLoading(false);
      await loadHealthData();
    }

    void bootstrap();
  }, []);

  useEffect(() => {
    if (!onboardingDone) {
      setDraft(profile[fields[questionIndex]] ?? "");
    }
  }, [onboardingDone, profile, questionIndex]);

  const firstName = useMemo(() => firstNameFrom(profile), [profile]);

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

    setTab("coach");
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
    } catch (error) {
      setHealthError(error instanceof Error ? error.message : "Could not switch scenarios.");
    } finally {
      setScenarioLoading(false);
    }
  }

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
          <Text style={styles.onboardingTitle}>A calmer, clearer health coach.</Text>
          <Text style={styles.onboardingBody}>
            This prototype turns wearable sync data into simple daily guidance for student
            participants.
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
      <AppHeader tab={tab} firstName={firstName} />

      {tab === "today" ? (
        <TodayScreen
          health={latestHealth}
          healthLoading={healthLoading}
          healthError={healthError}
          scenarioLoading={scenarioLoading}
          onRetry={() => {
            void loadHealthData();
          }}
          onLoadScenario={(fixtureId) => {
            void handleScenarioChange(fixtureId);
          }}
          onAskCoach={(prompt) => {
            void handleSendMessage(prompt);
          }}
        />
      ) : null}
      {tab === "progress" ? (
        <ProgressScreen
          health={latestHealth}
          timeline={timeline}
          healthLoading={healthLoading}
          healthError={healthError}
          onRetry={() => {
            void loadHealthData();
          }}
        />
      ) : null}
      {tab === "coach" ? (
        <CoachScreen
          messages={messages}
          input={chatInput}
          setInput={setChatInput}
          loading={chatLoading}
          onSend={() => {
            void handleSendMessage();
          }}
          onPrompt={(prompt) => {
            void handleSendMessage(prompt);
          }}
        />
      ) : null}
      {tab === "you" ? <ProfileScreen profile={profile} latestHealth={latestHealth} /> : null}

      <BottomTabs activeTab={tab} onChange={setTab} />
    </KeyboardAvoidingView>
  );
}

function AppHeader({ tab, firstName }: { tab: TabKey; firstName: string }) {
  return (
    <View style={styles.header}>
      <View style={styles.avatar}>
        <Text style={styles.avatarText}>{firstName.slice(0, 1).toUpperCase()}</Text>
      </View>
      <View style={styles.headerCenter}>
        <Text style={styles.headerTitle}>{tabLabels[tab]}</Text>
        <Text style={styles.headerSubtitle}>AI Health Coach</Text>
      </View>
      <Pressable style={({ pressed }) => [styles.iconButton, pressed && styles.pressed]}>
        <Text style={styles.iconButtonText}>Set</Text>
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
  health,
  healthLoading,
  healthError,
  scenarioLoading,
  onRetry,
  onLoadScenario,
  onAskCoach,
}: {
  health: LatestHealthResponse | null;
  healthLoading: boolean;
  healthError: string | null;
  scenarioLoading: boolean;
  onRetry: () => void;
  onLoadScenario: (fixtureId: string) => void;
  onAskCoach: (prompt: string) => void;
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

  const primaryMetrics = health.metricCards.filter((metric) =>
    ["recovery", "sleep", "stress", "hrv"].includes(metric.id)
  );

  return (
    <ScrollView style={styles.content} contentContainerStyle={styles.screenContent}>
      <Card style={styles.heroCard}>
        <View style={styles.ambientBlob} />
        <Text style={styles.heroTitle}>{health.headline}</Text>
        <View style={styles.syncRow}>
          <View style={[styles.statusDot, { backgroundColor: health.syncStatus.stale ? palette.coral : palette.sage }]} />
          <Text style={styles.syncText}>
            {health.syncStatus.label} • {formatShortDate(health.latestDay.date)}
          </Text>
        </View>
        <Text style={styles.heroBody}>{health.summary}</Text>
        <View style={styles.tagRow}>
          <Text style={styles.softTag}>{health.latestDay.recoveryScore < 55 ? "Rest Day" : "Steady Build"}</Text>
          <Text style={styles.softTag}>{health.scenarioLabel}</Text>
        </View>
      </Card>

      <View style={styles.bentoGrid}>
        {primaryMetrics.map((metric, index) => (
          <MetricBentoCard key={metric.id} metric={metric} large={index === 0} />
        ))}
      </View>

      <SectionHeading title="Today's action plan" />
      <Card style={styles.actionList}>
        {health.actionPlan.slice(0, 4).map((item) => (
          <ActionRow key={item.title} title={item.title} text={item.text} />
        ))}
      </Card>

      <SectionHeading title="What matters most" />
      {health.insights.slice(0, 3).map((insight) => (
        <InsightCard key={insight.title} insight={insight} />
      ))}

      <Card style={styles.proxyCard}>
        <Text style={styles.cardTitle}>Proxy indicators</Text>
        <Text style={styles.cardBody}>
          Glucose and nitric oxide are behavior proxies only, not measured medical values.
        </Text>
        <View style={styles.proxyGrid}>
          <MiniStat label="Glucose proxy" value={health.latestDay.glucoseProxy} />
          <MiniStat label="Nitric oxide proxy" value={health.latestDay.nitricOxideProxy} />
        </View>
      </Card>

      <Card>
        <Text style={styles.cardTitle}>Mock sync inputs</Text>
        <Text style={styles.cardBody}>Use these fixtures until the watch SDK is wired in.</Text>
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

      <Pressable
        style={({ pressed }) => [styles.askCoachButton, pressed && styles.pressed]}
        onPress={() => onAskCoach("Give me a plan for today based on the latest synced wearable data.")}
      >
        <Text style={styles.askCoachText}>Ask Coach</Text>
      </Pressable>
    </ScrollView>
  );
}

function ProgressScreen({
  health,
  timeline,
  healthLoading,
  healthError,
  onRetry,
}: {
  health: LatestHealthResponse | null;
  timeline: HealthTimelineResponse | null;
  healthLoading: boolean;
  healthError: string | null;
  onRetry: () => void;
}) {
  if (healthLoading && !timeline) {
    return (
      <EmptyState
        title="Loading progress"
        body="Fetching the seven-day trend view."
        loading
        onRetry={onRetry}
      />
    );
  }

  if (!health || !timeline) {
    return (
      <EmptyState
        title="Progress data is unavailable"
        body={healthError || "Load a mock sync scenario to populate the trend view."}
        onRetry={onRetry}
      />
    );
  }

  const hrvMetric = health.metricCards.find((metric) => metric.id === "hrv");
  const stressMetric = health.metricCards.find((metric) => metric.id === "stress");
  const avgRecovery = average(timeline.points.map((point) => point.recoveryScore));
  const avgSleep = average(timeline.points.map((point) => point.sleepScore));

  return (
    <ScrollView style={styles.content} contentContainerStyle={styles.screenContent}>
      <Card style={styles.coachingInsight}>
        <View style={styles.insightIcon}>
          <Text style={styles.insightIconText}>AI</Text>
        </View>
        <Text style={styles.summaryTitle}>
          {avgRecovery >= 60 ? "Looking steadier" : "Recovery needs attention"}
        </Text>
        <Text style={styles.cardBody}>{timeline.trendSummary}</Text>
      </Card>

      <View style={styles.twoColumn}>
        <StatCard
          label="HRV"
          value={hrvMetric?.value ?? `${health.latestDay.hrv} ms`}
          context={`vs ${health.latestDay.hrvBaseline} ms baseline`}
          tone="caution"
        />
        <StatCard
          label="Resting HR"
          value={`${health.latestDay.restingHeartRate} bpm`}
          context="Latest synced day"
          tone="good"
        />
      </View>

      <Card style={styles.stepsCard}>
        <View>
          <Text style={styles.metricLabel}>Daily Steps</Text>
          <Text style={styles.stepsValue}>
            {health.latestDay.steps.toLocaleString()}
            <Text style={styles.stepsGoal}> / {health.latestDay.stepGoal.toLocaleString()}</Text>
          </Text>
        </View>
        <RingProgress percent={health.latestDay.steps / health.latestDay.stepGoal} />
      </Card>

      <Card>
        <View style={styles.rowBetween}>
          <Text style={styles.cardTitle}>Recovery</Text>
          <Text style={styles.rangePill}>7 Days</Text>
        </View>
        <TrendBars points={timeline.points} valueKey="recoveryScore" color={palette.sage} />
      </Card>

      <Card>
        <Text style={styles.cardTitle}>Pattern snapshot</Text>
        <View style={styles.proxyGrid}>
          <MiniStat label="Avg recovery" value={`${avgRecovery}/100`} />
          <MiniStat label="Avg sleep" value={`${avgSleep}/100`} />
          <MiniStat label="Stress" value={stressMetric?.value ?? health.latestDay.stressLabel} />
        </View>
      </Card>

      {timeline.points.map((point) => (
        <TimelinePointCard key={point.date} point={point} />
      ))}
    </ScrollView>
  );
}

function CoachScreen({
  messages,
  input,
  setInput,
  loading,
  onSend,
  onPrompt,
}: {
  messages: CoachMessage[];
  input: string;
  setInput: (value: string) => void;
  loading: boolean;
  onSend: () => void;
  onPrompt: (prompt: string) => void;
}) {
  return (
    <View style={styles.coachScreen}>
      <ScrollView style={styles.content} contentContainerStyle={styles.chatContent}>
        <Text style={styles.chatTimestamp}>Today, 8:30 AM</Text>
        {messages.map((message) => (
          <View
            key={message.id}
            style={[
              styles.messageRow,
              message.role === "user" ? styles.messageRowUser : styles.messageRowCoach,
            ]}
          >
            {message.role === "assistant" ? (
              <View style={styles.coachAvatar}>
                <Text style={styles.coachAvatarText}>AI</Text>
              </View>
            ) : null}
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
        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.promptScroller}
        >
          {defaultQuickPrompts.map((prompt) => (
            <Pressable
              key={prompt}
              style={({ pressed }) => [styles.promptChip, pressed && styles.pressed]}
              onPress={() => onPrompt(prompt)}
            >
              <Text style={styles.promptChipText}>{prompt}</Text>
            </Pressable>
          ))}
        </ScrollView>
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

function ProfileScreen({
  profile,
  latestHealth,
}: {
  profile: UserProfile;
  latestHealth: LatestHealthResponse | null;
}) {
  const directSignals = ["Sleep", "HRV", "Heart Rate", "Steps", "SpO2", "Temperature"];

  return (
    <ScrollView style={styles.content} contentContainerStyle={styles.screenContent}>
      <Card style={styles.heroCard}>
        <Text style={styles.cardTitle}>Study Details</Text>
        <Text style={styles.cardBody}>
          You are enrolled in the AI Health Coach research prototype. Your bracelet syncs to
          the phone app and helps us study student stress, recovery, and daily coaching patterns.
        </Text>
        <Text style={styles.idBadge}>Participant ID #12345</Text>
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

      <SectionHeading title="Direct Signals" />
      <Text style={styles.sectionBody}>Measurements collected directly from the wearable device.</Text>
      <View style={styles.signalGrid}>
        {directSignals.map((signal) => (
          <View key={signal} style={styles.signalCard}>
            <View style={styles.signalIcon}>
              <Text style={styles.signalIconText}>{signal.slice(0, 2).toUpperCase()}</Text>
            </View>
            <Text style={styles.signalTitle}>{signal}</Text>
            <Text style={styles.signalStatus}>Active</Text>
          </View>
        ))}
      </View>

      <SectionHeading title="Proxy Indicators" />
      <Card style={styles.noticeCard}>
        <Text style={styles.cardBody}>
          Proxy indicators are estimated from direct signals. These are proxy indicators only,
          not medical values, and should not be used for diagnosis.
        </Text>
      </Card>

      <View style={styles.twoColumn}>
        <ProxyDetailCard
          title="Glucose proxy"
          value={latestHealth?.latestDay.glucoseProxy ?? "Caution"}
          body="Estimated from sleep, activity, and routine timing patterns."
          color={palette.coral}
        />
        <ProxyDetailCard
          title="Nitric oxide proxy"
          value={latestHealth?.latestDay.nitricOxideProxy ?? "Could improve"}
          body="Estimated cardiovascular support signal derived from movement and recovery context."
          color={palette.blue}
        />
      </View>

      <Card>
        <Text style={styles.cardTitle}>Current ingestion model</Text>
        <Text style={styles.cardBody}>
          Bracelet data is stored on-device, synced over Bluetooth to the phone, normalized by
          the app/backend, and then used by coaching plus the research dashboard.
        </Text>
        {latestHealth ? (
          <Text style={styles.footnote}>Active scenario: {latestHealth.scenarioLabel}</Text>
        ) : null}
      </Card>
    </ScrollView>
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

function SectionHeading({ title }: { title: string }) {
  return <Text style={styles.sectionTitle}>{title}</Text>;
}

function MetricBentoCard({ metric, large }: { metric: HealthMetricCard; large?: boolean }) {
  const progressWidth: DimensionValue =
    metric.id === "recovery" ? (metric.value.replace("/100", "%") as DimensionValue) : "58%";

  return (
    <Card style={[styles.bentoCard, large && styles.bentoCardLarge]}>
      <View style={styles.rowBetween}>
        <Text style={[styles.metricInitial, { color: toneColor(metric.tone) }]}>
          {metric.label.slice(0, 1)}
        </Text>
        <Text style={[styles.bentoValue, { color: toneColor(metric.tone) }]}>{metric.value}</Text>
      </View>
      <View>
        <Text style={styles.metricLabel}>{metric.label}</Text>
        <Text style={styles.cardBody}>{metric.context}</Text>
      </View>
      <View style={styles.progressTrack}>
        <View
          style={[
            styles.progressFill,
            {
              backgroundColor: toneColor(metric.tone),
              width: progressWidth,
            },
          ]}
        />
      </View>
    </Card>
  );
}

function ActionRow({ title, text }: { title: string; text: string }) {
  return (
    <View style={styles.actionRow}>
      <View style={styles.checkbox} />
      <View style={styles.actionCopy}>
        <Text style={styles.actionTitle}>{title}</Text>
        <Text style={styles.actionText}>{text}</Text>
      </View>
    </View>
  );
}

function InsightCard({ insight }: { insight: HealthInsight }) {
  return (
    <Card style={[styles.insightCard, { borderColor: toneSoftColor(insight.tone) }]}>
      <View style={[styles.accentDot, { backgroundColor: toneColor(insight.tone) }]} />
      <Text style={styles.cardTitle}>{insight.title}</Text>
      <Text style={styles.cardBody}>{insight.text}</Text>
    </Card>
  );
}

function StatCard({
  label,
  value,
  context,
  tone,
}: {
  label: string;
  value: string;
  context: string;
  tone: "good" | "caution" | "alert" | "neutral";
}) {
  return (
    <Card style={styles.statCard}>
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={[styles.footnote, { color: toneColor(tone) }]}>{context}</Text>
    </Card>
  );
}

function RingProgress({ percent }: { percent: number }) {
  const clamped = Math.max(0, Math.min(1, percent));
  return (
    <View style={styles.ring}>
      <Text style={styles.ringText}>{Math.round(clamped * 100)}%</Text>
    </View>
  );
}

function TrendBars({
  points,
  valueKey,
  color,
}: {
  points: HealthTimelinePoint[];
  valueKey: "recoveryScore" | "sleepScore" | "stressScore";
  color: string;
}) {
  const max = Math.max(...points.map((point) => point[valueKey]), 100);

  return (
    <View style={styles.trendBars}>
      {points.map((point) => {
        const height = Math.max(8, (point[valueKey] / max) * 86);
        return (
          <View key={point.date} style={styles.trendDay}>
            <View style={styles.trendTrack}>
              <View style={[styles.trendFill, { height, backgroundColor: color }]} />
            </View>
            <Text style={styles.trendLabel}>
              {new Date(`${point.date}T00:00:00`).toLocaleDateString("en-US", {
                weekday: "narrow",
              })}
            </Text>
          </View>
        );
      })}
    </View>
  );
}

function TimelinePointCard({ point }: { point: HealthTimelinePoint }) {
  return (
    <Card style={styles.timelineCard}>
      <View style={styles.rowBetween}>
        <View>
          <Text style={styles.cardTitle}>{formatShortDate(point.date)}</Text>
          <Text style={styles.footnote}>Mock bracelet sync day</Text>
        </View>
        <Text style={styles.hrvLabel}>HRV {point.hrv}</Text>
      </View>
      <View style={styles.proxyGrid}>
        <MiniStat label="Recovery" value={`${point.recoveryScore}/100`} />
        <MiniStat label="Sleep" value={`${point.sleepScore}/100`} />
        <MiniStat label="Stress" value={`${point.stressScore}/100`} />
      </View>
      <Text style={styles.footnote}>{point.steps.toLocaleString()} steps</Text>
    </Card>
  );
}

function MiniStat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.miniStat}>
      <Text style={styles.miniStatLabel}>{label}</Text>
      <Text style={styles.miniStatValue}>{value}</Text>
    </View>
  );
}

function ProxyDetailCard({
  title,
  value,
  body,
  color,
}: {
  title: string;
  value: string;
  body: string;
  color: string;
}) {
  return (
    <Card style={[styles.proxyDetail, { borderLeftColor: color }]}>
      <View style={styles.rowBetween}>
        <Text style={styles.cardTitle}>{title}</Text>
        <Text style={[styles.proxyBadge, { color }]}>{value}</Text>
      </View>
      <Text style={styles.cardBody}>{body}</Text>
      <View style={styles.progressTrack}>
        <View style={[styles.progressFill, { width: "58%", backgroundColor: color }]} />
      </View>
    </Card>
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
    height: 64,
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    paddingHorizontal: spacing.lg,
    backgroundColor: palette.canvas,
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
  headerCenter: {
    alignItems: "center",
  },
  headerTitle: {
    color: palette.sage,
    fontSize: 20,
    fontWeight: "700",
  },
  headerSubtitle: {
    color: palette.textFaint,
    fontSize: 11,
    marginTop: 2,
  },
  iconButton: {
    width: 40,
    height: 40,
    borderRadius: radius.pill,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 1,
    borderColor: palette.line,
    backgroundColor: palette.surface,
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
  heroCard: {
    gap: spacing.md,
    overflow: "hidden",
  },
  ambientBlob: {
    position: "absolute",
    right: -54,
    top: -54,
    width: 190,
    height: 190,
    borderRadius: 95,
    backgroundColor: palette.coralSoft,
    opacity: 0.45,
  },
  heroTitle: {
    color: palette.text,
    fontSize: 32,
    fontWeight: "700",
    letterSpacing: -0.6,
    lineHeight: 38,
  },
  heroBody: {
    color: palette.textMuted,
    fontSize: 16,
    lineHeight: 24,
  },
  syncRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  statusDot: {
    width: 8,
    height: 8,
    borderRadius: radius.pill,
  },
  syncText: {
    color: palette.textMuted,
    fontSize: 13,
    fontWeight: "600",
  },
  tagRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.sm,
  },
  softTag: {
    backgroundColor: palette.surfaceMuted,
    borderRadius: radius.pill,
    color: palette.textMuted,
    fontSize: 13,
    fontWeight: "700",
    overflow: "hidden",
    paddingHorizontal: 12,
    paddingVertical: 7,
  },
  bentoGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.md,
  },
  bentoCard: {
    width: "47.8%",
    minHeight: 162,
    justifyContent: "space-between",
  },
  bentoCardLarge: {
    width: "100%",
    minHeight: 176,
  },
  rowBetween: {
    alignItems: "flex-start",
    flexDirection: "row",
    justifyContent: "space-between",
    gap: spacing.md,
  },
  metricInitial: {
    fontSize: 24,
    fontWeight: "800",
  },
  bentoValue: {
    fontSize: 24,
    fontWeight: "800",
  },
  metricLabel: {
    color: palette.textMuted,
    fontSize: 13,
    fontWeight: "800",
    letterSpacing: 0.4,
    textTransform: "uppercase",
  },
  progressTrack: {
    height: 8,
    borderRadius: radius.pill,
    backgroundColor: palette.surfaceRaised,
    overflow: "hidden",
  },
  progressFill: {
    height: "100%",
    borderRadius: radius.pill,
  },
  sectionTitle: {
    color: palette.text,
    fontSize: 22,
    fontWeight: "700",
    lineHeight: 28,
  },
  sectionBody: {
    color: palette.textMuted,
    fontSize: 15,
    lineHeight: 22,
    marginTop: -12,
  },
  actionList: {
    paddingVertical: spacing.sm,
  },
  actionRow: {
    flexDirection: "row",
    gap: spacing.md,
    paddingVertical: spacing.md,
    borderBottomWidth: 1,
    borderBottomColor: palette.line,
  },
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: radius.pill,
    borderWidth: 1.5,
    borderColor: palette.outline,
    marginTop: 2,
  },
  actionCopy: {
    flex: 1,
    gap: 4,
  },
  actionTitle: {
    color: palette.text,
    fontSize: 16,
    fontWeight: "700",
  },
  actionText: {
    color: palette.textMuted,
    fontSize: 14,
    lineHeight: 20,
  },
  insightCard: {
    borderWidth: 1.5,
    gap: spacing.sm,
  },
  accentDot: {
    width: 10,
    height: 10,
    borderRadius: radius.pill,
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
  proxyCard: {
    gap: spacing.md,
  },
  proxyGrid: {
    flexDirection: "row",
    gap: spacing.sm,
    marginTop: spacing.sm,
  },
  miniStat: {
    flex: 1,
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
  askCoachButton: {
    alignItems: "center",
    alignSelf: "flex-end",
    backgroundColor: palette.sage,
    borderRadius: radius.pill,
    paddingHorizontal: 22,
    paddingVertical: 15,
  },
  askCoachText: {
    color: palette.surface,
    fontSize: 14,
    fontWeight: "800",
  },
  coachingInsight: {
    alignItems: "center",
    backgroundColor: palette.sageSoft,
    gap: spacing.sm,
  },
  insightIcon: {
    width: 48,
    height: 48,
    borderRadius: radius.pill,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.surface,
  },
  insightIconText: {
    color: palette.sage,
    fontSize: 13,
    fontWeight: "900",
  },
  summaryTitle: {
    color: palette.text,
    fontSize: 21,
    fontWeight: "800",
  },
  twoColumn: {
    flexDirection: "row",
    gap: spacing.md,
  },
  statCard: {
    flex: 1,
    gap: spacing.sm,
  },
  statValue: {
    color: palette.text,
    fontSize: 31,
    fontWeight: "800",
    letterSpacing: -0.6,
  },
  stepsCard: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
  },
  stepsValue: {
    color: palette.text,
    fontSize: 26,
    fontWeight: "800",
  },
  stepsGoal: {
    color: palette.textFaint,
    fontSize: 16,
    fontWeight: "600",
  },
  ring: {
    width: 72,
    height: 72,
    borderRadius: 36,
    alignItems: "center",
    justifyContent: "center",
    borderWidth: 7,
    borderColor: palette.blue,
    backgroundColor: palette.blueSoft,
  },
  ringText: {
    color: palette.blue,
    fontSize: 13,
    fontWeight: "900",
  },
  rangePill: {
    backgroundColor: palette.surfaceMuted,
    borderRadius: radius.pill,
    color: palette.textMuted,
    fontSize: 12,
    fontWeight: "800",
    overflow: "hidden",
    paddingHorizontal: 11,
    paddingVertical: 7,
  },
  trendBars: {
    height: 132,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-end",
    marginTop: spacing.lg,
  },
  trendDay: {
    alignItems: "center",
    flex: 1,
    gap: spacing.sm,
  },
  trendTrack: {
    width: 9,
    height: 92,
    borderRadius: radius.pill,
    backgroundColor: palette.surfaceRaised,
    justifyContent: "flex-end",
    overflow: "hidden",
  },
  trendFill: {
    width: "100%",
    borderRadius: radius.pill,
  },
  trendLabel: {
    color: palette.textFaint,
    fontSize: 12,
    fontWeight: "800",
  },
  timelineCard: {
    gap: spacing.sm,
  },
  hrvLabel: {
    color: palette.sage,
    fontSize: 13,
    fontWeight: "800",
  },
  coachScreen: {
    flex: 1,
    backgroundColor: palette.canvas,
  },
  chatContent: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: 232,
    gap: spacing.lg,
  },
  chatTimestamp: {
    color: palette.textFaint,
    fontSize: 12,
    fontWeight: "800",
    textAlign: "center",
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
  coachAvatar: {
    width: 32,
    height: 32,
    borderRadius: radius.pill,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.sageSoft,
    marginTop: 4,
  },
  coachAvatarText: {
    color: palette.sage,
    fontSize: 11,
    fontWeight: "900",
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
    position: "absolute",
    left: 0,
    right: 0,
    bottom: 86,
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.xl,
    paddingBottom: spacing.md,
    backgroundColor: palette.canvas,
    gap: spacing.sm,
  },
  promptScroller: {
    gap: spacing.sm,
    paddingRight: spacing.lg,
  },
  promptChip: {
    backgroundColor: palette.surfaceMuted,
    borderColor: palette.line,
    borderRadius: radius.pill,
    borderWidth: 1,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  promptChipText: {
    color: palette.textMuted,
    fontSize: 13,
    fontWeight: "700",
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
  idBadge: {
    alignSelf: "flex-start",
    backgroundColor: palette.surfaceMuted,
    borderRadius: radius.pill,
    color: palette.textMuted,
    fontSize: 13,
    fontWeight: "800",
    marginTop: spacing.md,
    overflow: "hidden",
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  signalGrid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.md,
  },
  signalCard: {
    width: "47.8%",
    alignItems: "center",
    backgroundColor: palette.surface,
    borderColor: palette.line,
    borderRadius: radius.lg,
    borderWidth: 1,
    gap: spacing.sm,
    padding: spacing.md,
  },
  signalIcon: {
    width: 48,
    height: 48,
    borderRadius: radius.pill,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: palette.blueSoft,
  },
  signalIconText: {
    color: palette.blue,
    fontSize: 12,
    fontWeight: "900",
  },
  signalTitle: {
    color: palette.text,
    fontSize: 15,
    fontWeight: "800",
    textAlign: "center",
  },
  signalStatus: {
    color: palette.sage,
    fontSize: 12,
    fontWeight: "800",
  },
  noticeCard: {
    backgroundColor: palette.surfaceMuted,
  },
  proxyDetail: {
    flex: 1,
    borderLeftWidth: 4,
    gap: spacing.md,
  },
  proxyBadge: {
    fontSize: 12,
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
    paddingHorizontal: spacing.md,
    backgroundColor: palette.surfaceMuted,
    borderTopLeftRadius: radius.lg,
    borderTopRightRadius: radius.lg,
    shadowColor: palette.shadow,
    shadowOpacity: 1,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: -6 },
    elevation: 8,
  },
  tabItem: {
    alignItems: "center",
    borderRadius: radius.pill,
    minWidth: 70,
    paddingHorizontal: 12,
    paddingVertical: 7,
  },
  tabItemActive: {
    backgroundColor: palette.sageSoft,
  },
  tabGlyph: {
    color: palette.textMuted,
    fontSize: 14,
    fontWeight: "900",
    marginBottom: 2,
  },
  tabGlyphActive: {
    color: palette.sage,
  },
  tabText: {
    color: palette.textMuted,
    fontSize: 11,
    fontWeight: "800",
  },
  tabTextActive: {
    color: palette.sage,
  },
});
