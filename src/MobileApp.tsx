import React, { useEffect, useMemo, useState } from "react";
import {
  ActivityIndicator,
  Keyboard,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  StyleSheet,
  Text,
  View,
} from "react-native";

import {
  AppTextInput,
  Card,
  Pill,
  PrimaryButton,
  Screen,
  SecondaryButton,
  SectionTitle,
} from "./components";
import { defaultProfile, onboardingQuestions, researchSignals, sensors } from "./data";
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
  HealthMetricCard,
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
  you: "You",
};

function toneColor(tone: string) {
  switch (tone) {
    case "good":
      return palette.mint;
    case "caution":
      return palette.sand;
    case "alert":
      return palette.coral;
    default:
      return palette.blue;
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
  const [keyboardVisible, setKeyboardVisible] = useState(false);
  const [coachOpen, setCoachOpen] = useState(false);
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
    const showEvent = Platform.OS === "ios" ? "keyboardWillShow" : "keyboardDidShow";
    const hideEvent = Platform.OS === "ios" ? "keyboardWillHide" : "keyboardDidHide";

    const showSubscription = Keyboard.addListener(showEvent, () => {
      setKeyboardVisible(true);
    });
    const hideSubscription = Keyboard.addListener(hideEvent, () => {
      setKeyboardVisible(false);
    });

    return () => {
      showSubscription.remove();
      hideSubscription.remove();
    };
  }, []);

  const firstName = useMemo(() => {
    const value = profile.name.trim().split(" ")[0];
    return value || "there";
  }, [profile.name]);

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

  useEffect(() => {
    if (!onboardingDone) {
      setDraft(profile[fields[questionIndex]] ?? "");
    }
  }, [onboardingDone, profile, questionIndex]);

  async function handleSendMessage(prefill?: string) {
    const raw = (prefill ?? chatInput).trim();
    if (!raw || chatLoading) {
      return;
    }

    const userMessage: CoachMessage = {
      id: `user-${Date.now()}`,
      role: "user",
      text: raw,
    };

    setMessages((current) => [...current, userMessage]);
    setChatInput("");
    setChatLoading(true);

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
    setCoachOpen(true);
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
          text: `Loaded the ${latest.scenarioLabel} scenario. ${latest.summary}`,
        },
      ]);
    } catch (error) {
      setHealthError(
        error instanceof Error
          ? error.message
          : "Could not switch scenarios."
      );
    } finally {
      setScenarioLoading(false);
    }
  }

  if (loading) {
    return (
      <View style={styles.loadingWrap}>
        <ActivityIndicator color={palette.text} />
        <Text style={styles.loadingText}>Loading AI Coach</Text>
      </View>
    );
  }

  if (!onboardingDone) {
    return (
      <Screen>
        <Card style={styles.heroCard}>
          <Pill label="AI Coach" accent={palette.text} />
          <SectionTitle
            eyebrow="Onboarding"
            title="A calmer, clearer health coach."
            subtitle="This prototype turns wearable and context data into simple daily guidance instead of a wall of numbers."
          />
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
          <View style={styles.questionActions}>
            <PrimaryButton
              label={questionIndex === onboardingQuestions.length - 1 ? "Finish setup" : "Continue"}
              onPress={() => {
                void advanceOnboarding();
              }}
              disabled={!draft.trim()}
            />
          </View>
        </Card>
      </Screen>
    );
  }

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === "ios" ? "padding" : "height"}
      keyboardVerticalOffset={Platform.OS === "ios" ? 12 : 0}
    >
      <View style={styles.header}>
        <View>
          <Text style={styles.headerGreeting}>Good morning, {firstName}</Text>
          <Text style={styles.headerSubtext}>
            {latestHealth?.scenarioLabel
              ? `${latestHealth.scenarioLabel} is loaded into the dashboard.`
              : "Your coach turns synced signals into a simpler plan."}
          </Text>
        </View>
        <Pressable onPress={() => setTab("you")} style={styles.headerBadge}>
          <Text style={styles.headerBadgeText}>About You</Text>
        </Pressable>
      </View>

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
          onAskCoach={async (prompt) => {
            setCoachOpen(true);
            if (prompt) {
              void handleSendMessage(prompt);
            }
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
          onAskCoach={async (prompt) => {
            setCoachOpen(true);
            if (prompt) {
              void handleSendMessage(prompt);
            }
          }}
        />
      ) : null}
      {tab === "you" ? <YouScreen profile={profile} latestHealth={latestHealth} /> : null}

      {!keyboardVisible ? (
        <View style={styles.tabBar}>
          {(Object.keys(tabLabels) as TabKey[]).map((key) => (
            <Pressable
              key={key}
              onPress={() => setTab(key)}
              style={[styles.tabItem, tab === key && styles.tabItemActive]}
            >
              <Text style={[styles.tabLabel, tab === key && styles.tabLabelActive]}>
                {tabLabels[key]}
              </Text>
            </Pressable>
          ))}
        </View>
      ) : null}

      {!coachOpen && !keyboardVisible && (tab === "today" || tab === "progress") ? (
        <Pressable
          onPress={() => setCoachOpen(true)}
          style={({ pressed }) => [
            styles.floatingCoachButton,
            pressed && styles.floatingCoachPressed,
          ]}
        >
          <Text style={styles.floatingCoachIcon}>AI</Text>
          <Text style={styles.floatingCoachText}>Coach</Text>
        </Pressable>
      ) : null}

      {coachOpen ? (
        <View pointerEvents="box-none" style={styles.coachSheetOverlay}>
          <KeyboardAvoidingView
            style={styles.coachSheetWrap}
            behavior={Platform.OS === "ios" ? "padding" : "height"}
            keyboardVerticalOffset={Platform.OS === "ios" ? 12 : 0}
          >
            <View style={styles.coachSheet}>
              <View style={styles.sheetHandle} />
              <View style={styles.modalHeader}>
                <View>
                  <Text style={styles.modalTitle}>Coach</Text>
                  <Text style={styles.modalSubtitle}>
                    Ask about today, recovery, sleep, or what to do next.
                  </Text>
                </View>
                <Pressable onPress={() => setCoachOpen(false)} style={styles.modalClose}>
                  <Text style={styles.modalCloseText}>Close</Text>
                </Pressable>
              </View>
              <CoachScreen
                messages={messages}
                input={chatInput}
                setInput={setChatInput}
                loading={chatLoading}
                keyboardVisible={keyboardVisible}
                onSend={() => {
                  void handleSendMessage();
                }}
              />
            </View>
          </KeyboardAvoidingView>
        </View>
      ) : null}
    </KeyboardAvoidingView>
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
  onAskCoach: (prompt?: string) => Promise<void>;
}) {
  if (healthLoading && !health) {
    return (
      <Screen bottomPadding={140}>
        <Card>
          <ActivityIndicator color={palette.text} />
          <Text style={styles.loadingCardText}>Loading the latest mock sync data.</Text>
        </Card>
      </Screen>
    );
  }

  if (!health) {
    return (
      <Screen bottomPadding={140}>
        <Card>
          <Text style={styles.cardTitle}>Health data is unavailable</Text>
          <Text style={styles.cardBody}>
            {healthError || "Start the local server, then retry loading the mock sync data."}
          </Text>
          <View style={styles.questionActions}>
            <PrimaryButton label="Retry" onPress={onRetry} />
          </View>
        </Card>
      </Screen>
    );
  }

  return (
    <Screen bottomPadding={150}>
      <Card style={styles.morningHero}>
        <Pill label={health.syncStatus.label} accent={health.syncStatus.stale ? palette.coral : palette.mint} />
        <Text style={styles.heroEyebrow}>Today’s read</Text>
        <Text style={styles.heroTitle}>{health.headline}</Text>
        <Text style={styles.heroBody}>{health.summary}</Text>
        <Text style={styles.syncFootnote}>
          Last sync {formatShortDate(health.latestDay.date)} • Scenario {health.scenarioLabel}
        </Text>
        <View style={styles.heroButtons}>
          <View style={styles.heroButton}>
            <PrimaryButton
              label="Ask coach for today’s plan"
              onPress={() => {
                void onAskCoach("Give me a plan for today based on the latest synced wearable data.");
              }}
            />
          </View>
        </View>
      </Card>

      <SectionTitle
        eyebrow="Scenario switcher"
        title="Mock sync inputs"
        subtitle="Use these fixtures until the watch arrives and the SDK is wired in."
      />

      <Card>
        <View style={styles.scenarioWrap}>
          {health.availableFixtures.map((fixture) => {
            const active = fixture.id === health.scenarioId;
            return (
              <Pressable
                key={fixture.id}
                onPress={() => onLoadScenario(fixture.id)}
                style={[
                  styles.scenarioChip,
                  active && styles.scenarioChipActive,
                ]}
              >
                <Text style={[styles.scenarioChipTitle, active && styles.scenarioChipTitleActive]}>
                  {fixture.label}
                </Text>
                <Text style={styles.scenarioChipBody}>{fixture.summary}</Text>
              </Pressable>
            );
          })}
        </View>
        {scenarioLoading ? <Text style={styles.progressFootnote}>Switching scenarios...</Text> : null}
      </Card>

      <SectionTitle
        eyebrow="Key insights"
        title="What matters most today"
        subtitle="Short explanations, then clear action."
      />

      {health.insights.map((insight) => (
        <Card key={insight.title}>
          <View style={styles.inlineTitleRow}>
            <View
              style={[
                styles.accentDot,
                { backgroundColor: toneColor(insight.tone) },
              ]}
            />
            <Text style={styles.cardTitle}>{insight.title}</Text>
          </View>
          <Text style={styles.cardBody}>{insight.text}</Text>
        </Card>
      ))}

      <Card>
        <Text style={styles.planTitle}>Today’s plan</Text>
        {health.actionPlan.map((item) => (
          <View key={item.title} style={styles.planItem}>
            <Text style={styles.planLabel}>{item.title}</Text>
            <Text style={styles.planValue}>{item.text}</Text>
          </View>
        ))}
      </Card>

      {health.riskFlags.length ? (
        <>
          <SectionTitle
            eyebrow="Watch list"
            title="Risk flags"
            subtitle="These are warnings, not diagnoses."
          />
          {health.riskFlags.map((flag) => (
            <Card key={flag.title}>
              <Text style={styles.cardTitle}>{flag.title}</Text>
              <Text style={styles.cardBody}>{flag.text}</Text>
            </Card>
          ))}
        </>
      ) : null}

      <SectionTitle
        eyebrow="Daily metrics"
        title="A small number of signals"
        subtitle="Enough context to be useful without turning into a dashboard maze."
      />

      <View style={styles.metricGrid}>
        {health.metricCards.map((metric) => (
          <MetricCard key={metric.id} metric={metric} />
        ))}
      </View>
    </Screen>
  );
}

function ProgressScreen({
  health,
  timeline,
  healthLoading,
  healthError,
  onRetry,
  onAskCoach,
}: {
  health: LatestHealthResponse | null;
  timeline: HealthTimelineResponse | null;
  healthLoading: boolean;
  healthError: string | null;
  onRetry: () => void;
  onAskCoach: (prompt?: string) => Promise<void>;
}) {
  if (healthLoading && !timeline) {
    return (
      <Screen bottomPadding={140}>
        <Card>
          <ActivityIndicator color={palette.text} />
          <Text style={styles.loadingCardText}>Loading the recent trend view.</Text>
        </Card>
      </Screen>
    );
  }

  if (!timeline || !health) {
    return (
      <Screen bottomPadding={140}>
        <Card>
          <Text style={styles.cardTitle}>Progress data is unavailable</Text>
          <Text style={styles.cardBody}>
            {healthError || "Load a mock sync scenario to populate the progress view."}
          </Text>
          <View style={styles.questionActions}>
            <PrimaryButton label="Retry" onPress={onRetry} />
          </View>
        </Card>
      </Screen>
    );
  }

  return (
    <Screen bottomPadding={150}>
      <SectionTitle
        eyebrow="Progress"
        title="The trend matters more than the metric."
        subtitle="Use the last 7 days to understand the pattern, not to obsess over a single reading."
      />

      <Card>
        <Text style={styles.summaryHeadline}>{timeline.trendSummary}</Text>
        <Text style={styles.cardBody}>{health.scenarioSummary}</Text>
        <View style={styles.heroButtons}>
          <View style={styles.heroButton}>
            <SecondaryButton
              label="Ask coach what changed"
              onPress={() => {
                void onAskCoach("What changed across the last week and what should I do next?");
              }}
            />
          </View>
        </View>
      </Card>

      <SectionTitle
        eyebrow="Seven-day timeline"
        title="Recent health pattern"
        subtitle="Recovery, sleep, HRV, movement, and stress side by side."
      />

      {timeline.points.map((point) => (
        <Card key={point.date}>
          <View style={styles.workoutHeader}>
            <View>
              <Text style={styles.cardTitle}>{formatShortDate(point.date)}</Text>
              <Text style={styles.workoutMeta}>Mock bracelet sync day</Text>
            </View>
            <Text style={styles.workoutEffort}>HRV {point.hrv}</Text>
          </View>
          <View style={styles.timelineRow}>
            <MiniStat label="Recovery" value={`${point.recoveryScore}/100`} />
            <MiniStat label="Sleep" value={`${point.sleepScore}/100`} />
            <MiniStat label="Stress" value={`${point.stressScore}/100`} />
          </View>
          <Text style={styles.progressFootnote}>
            {point.steps.toLocaleString()} steps
          </Text>
        </Card>
      ))}

      <SectionTitle
        eyebrow="Current snapshot"
        title="Where the latest day landed"
        subtitle="A compact summary of the most recent sync."
      />

      <Card>
        <Text style={styles.cardBody}>
          Sleep {formatSleep(health.latestDay.sleepDurationMinutes)} • Recovery{" "}
          {health.latestDay.recoveryScore}/100 • Stress {health.latestDay.stressLabel} •
          Glucose proxy {health.latestDay.glucoseProxy}
        </Text>
      </Card>
    </Screen>
  );
}

function YouScreen({
  profile,
  latestHealth,
}: {
  profile: UserProfile;
  latestHealth: LatestHealthResponse | null;
}) {
  return (
    <Screen bottomPadding={140}>
      <SectionTitle
        eyebrow="You"
        title="How the app understands your day"
        subtitle="Profile, trust model, and the current mock-to-real device pipeline."
      />

      <Card>
        <Text style={styles.cardTitle}>{profile.name || "Your profile"}</Text>
        <Text style={styles.cardBody}>
          Goal: {profile.goals || "Improve overall wellness"}{"\n"}
          Preferred movement: {profile.exerciseType || "Not set"}{"\n"}
          Sleep target: {profile.sleepTime || "Not set"}{"\n"}
          Stress context: {profile.workStress || "Not set"}
        </Text>
      </Card>

      <Card>
        <Text style={styles.cardTitle}>Current ingestion model</Text>
        <Text style={styles.cardBody}>
          The manufacturer stores about 7 days on-device, then syncs data over Bluetooth to the phone app. Right now this repo uses mock post-sync payloads that match that architecture so the dashboard and coaching logic can be built before the watch arrives.
        </Text>
        {latestHealth ? (
          <Text style={styles.progressFootnote}>
            Active scenario: {latestHealth.scenarioLabel}
          </Text>
        ) : null}
      </Card>

      <SectionTitle
        eyebrow="Trust"
        title="Direct, proxy, and context signals"
        subtitle="Most of the app translates signals into plain language instead of exposing raw measurements."
      />

      {researchSignals.map((signal) => (
        <Card key={signal.title}>
          <View style={styles.metricTopRow}>
            <View>
              <Text style={styles.cardTitle}>{signal.title}</Text>
              <Text style={styles.metricBaseline}>{signal.directness} signal</Text>
            </View>
            <View style={styles.directnessBadge}>
              <Text style={styles.directnessText}>{signal.directness}</Text>
            </View>
          </View>
          <Text style={styles.cardBody}>{signal.summary}</Text>
        </Card>
      ))}

      <Card>
        <Text style={styles.cardTitle}>Current sensor model</Text>
        {sensors.map((sensor) => (
          <View key={sensor.name} style={styles.sensorRow}>
            <Text style={styles.sensorName}>{sensor.name}</Text>
            <Text style={styles.sensorBody}>{sensor.purpose}</Text>
          </View>
        ))}
      </Card>
    </Screen>
  );
}

function CoachScreen({
  messages,
  input,
  setInput,
  loading,
  keyboardVisible,
  onSend,
}: {
  messages: CoachMessage[];
  input: string;
  setInput: (value: string) => void;
  loading: boolean;
  keyboardVisible: boolean;
  onSend: () => void;
}) {
  return (
    <Screen bottomPadding={keyboardVisible ? 32 : 140}>
      <SectionTitle
        eyebrow="Coach"
        title="Short answers. Clear actions."
        subtitle="Chat is still the only open-ended AI surface."
      />

      <Card>
        <View style={styles.quickPromptWrap}>
          {[
            "Give me a plan for today",
            "What matters most right now?",
            "How is sleep affecting me?",
          ].map((prompt) => (
            <Pressable key={prompt} onPress={() => setInput(prompt)} style={styles.quickPrompt}>
              <Text style={styles.quickPromptText}>{prompt}</Text>
            </Pressable>
          ))}
        </View>
      </Card>

      {messages.map((message) => (
        <Card
          key={message.id}
          style={message.role === "assistant" ? styles.assistantBubble : styles.userBubble}
        >
          <Text style={styles.messageRole}>
            {message.role === "assistant" ? "Coach" : "You"}
          </Text>
          <Text style={styles.cardBody}>{message.text}</Text>
        </Card>
      ))}

      <Card>
        <AppTextInput
          value={input}
          onChangeText={setInput}
          placeholder="Ask your coach anything"
          multiline
        />
        <View style={styles.questionActions}>
          <PrimaryButton
            label={loading ? "Thinking..." : "Send"}
            onPress={onSend}
            disabled={!input.trim() || loading}
          />
        </View>
      </Card>
    </Screen>
  );
}

function MetricCard({ metric }: { metric: HealthMetricCard }) {
  return (
    <Card style={styles.metricCard}>
      <View
        style={[
          styles.metricAccentBar,
          { backgroundColor: toneColor(metric.tone) },
        ]}
      />
      <Text style={styles.metricCardLabel}>{metric.label}</Text>
      <Text style={styles.metricCardValue}>{metric.value}</Text>
      <Text style={styles.metricCardContext}>{metric.context}</Text>
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

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: palette.canvas,
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
  loadingCardText: {
    marginTop: spacing.sm,
    color: palette.textMuted,
    fontSize: 14,
  },
  header: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: spacing.sm,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    gap: spacing.md,
  },
  headerGreeting: {
    fontSize: 24,
    fontWeight: "700",
    color: palette.text,
  },
  headerSubtext: {
    marginTop: 4,
    maxWidth: 260,
    fontSize: 14,
    lineHeight: 20,
    color: palette.textMuted,
  },
  headerBadge: {
    backgroundColor: palette.surface,
    borderWidth: 1,
    borderColor: palette.line,
    borderRadius: radius.pill,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  headerBadgeText: {
    color: palette.text,
    fontSize: 12,
    fontWeight: "700",
  },
  heroCard: {
    gap: spacing.md,
  },
  questionCounter: {
    color: palette.textMuted,
    fontSize: 13,
    marginBottom: spacing.sm,
  },
  questionText: {
    color: palette.text,
    fontSize: 24,
    lineHeight: 30,
    fontWeight: "700",
    marginBottom: spacing.md,
  },
  questionActions: {
    marginTop: spacing.md,
  },
  tabBar: {
    position: "absolute",
    left: spacing.lg,
    right: spacing.lg,
    bottom: spacing.md,
    backgroundColor: palette.surface,
    borderRadius: radius.xl,
    borderWidth: 1,
    borderColor: palette.line,
    flexDirection: "row",
    padding: 8,
    gap: 6,
  },
  tabItem: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: radius.md,
    alignItems: "center",
  },
  tabItemActive: {
    backgroundColor: palette.surfaceMuted,
  },
  tabLabel: {
    color: palette.textMuted,
    fontSize: 12,
    fontWeight: "600",
  },
  tabLabelActive: {
    color: palette.text,
  },
  floatingCoachButton: {
    position: "absolute",
    right: spacing.lg,
    bottom: 98,
    backgroundColor: palette.text,
    borderRadius: radius.pill,
    paddingHorizontal: 16,
    paddingVertical: 14,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    shadowColor: palette.shadow,
    shadowOpacity: 1,
    shadowRadius: 18,
    shadowOffset: { width: 0, height: 8 },
    elevation: 5,
  },
  floatingCoachPressed: {
    opacity: 0.94,
  },
  floatingCoachIcon: {
    color: palette.surface,
    fontSize: 12,
    fontWeight: "800",
  },
  floatingCoachText: {
    color: palette.surface,
    fontSize: 14,
    fontWeight: "700",
  },
  coachSheetOverlay: {
    ...StyleSheet.absoluteFillObject,
    justifyContent: "flex-end",
    paddingHorizontal: spacing.lg,
    paddingTop: 88,
    paddingBottom: 94,
    backgroundColor: "rgba(30, 42, 38, 0.10)",
  },
  coachSheetWrap: {
    flex: 1,
    justifyContent: "flex-end",
  },
  coachSheet: {
    flex: 1,
    maxHeight: "100%",
    backgroundColor: palette.canvas,
    borderRadius: radius.xl,
    borderWidth: 1,
    borderColor: palette.line,
    overflow: "hidden",
    shadowColor: palette.shadow,
    shadowOpacity: 1,
    shadowRadius: 20,
    shadowOffset: { width: 0, height: 10 },
    elevation: 8,
  },
  sheetHandle: {
    alignSelf: "center",
    width: 44,
    height: 5,
    borderRadius: radius.pill,
    backgroundColor: palette.line,
    marginTop: 10,
  },
  modalHeader: {
    paddingHorizontal: spacing.lg,
    paddingTop: spacing.md,
    paddingBottom: spacing.md,
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    gap: spacing.md,
  },
  modalTitle: {
    color: palette.text,
    fontSize: 26,
    fontWeight: "700",
  },
  modalSubtitle: {
    marginTop: 4,
    color: palette.textMuted,
    fontSize: 14,
    lineHeight: 20,
    maxWidth: 260,
  },
  modalClose: {
    backgroundColor: palette.surface,
    borderWidth: 1,
    borderColor: palette.line,
    borderRadius: radius.pill,
    paddingHorizontal: 12,
    paddingVertical: 9,
  },
  modalCloseText: {
    color: palette.text,
    fontSize: 12,
    fontWeight: "700",
  },
  morningHero: {
    gap: spacing.sm,
  },
  heroEyebrow: {
    color: palette.sage,
    textTransform: "uppercase",
    letterSpacing: 1,
    fontSize: 12,
    fontWeight: "700",
  },
  heroTitle: {
    color: palette.text,
    fontSize: 30,
    lineHeight: 36,
    fontWeight: "700",
  },
  heroBody: {
    color: palette.textMuted,
    fontSize: 16,
    lineHeight: 24,
  },
  syncFootnote: {
    color: palette.textMuted,
    fontSize: 13,
  },
  heroButtons: {
    marginTop: spacing.sm,
  },
  heroButton: {
    width: "100%",
  },
  scenarioWrap: {
    gap: spacing.sm,
  },
  scenarioChip: {
    borderWidth: 1,
    borderColor: palette.line,
    borderRadius: radius.md,
    padding: spacing.md,
    backgroundColor: palette.surfaceMuted,
    gap: 6,
  },
  scenarioChipActive: {
    backgroundColor: palette.sageSoft,
    borderColor: palette.sage,
  },
  scenarioChipTitle: {
    color: palette.text,
    fontSize: 15,
    fontWeight: "700",
  },
  scenarioChipTitleActive: {
    color: palette.text,
  },
  scenarioChipBody: {
    color: palette.textMuted,
    fontSize: 13,
    lineHeight: 18,
  },
  inlineTitleRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: spacing.sm,
    marginBottom: spacing.sm,
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
  },
  cardBody: {
    color: palette.textMuted,
    fontSize: 15,
    lineHeight: 22,
  },
  planTitle: {
    color: palette.text,
    fontSize: 22,
    fontWeight: "700",
    marginBottom: spacing.sm,
  },
  planItem: {
    paddingVertical: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: palette.line,
  },
  planLabel: {
    color: palette.text,
    fontSize: 14,
    fontWeight: "700",
    marginBottom: 4,
  },
  planValue: {
    color: palette.textMuted,
    fontSize: 15,
    lineHeight: 22,
  },
  metricGrid: {
    gap: spacing.md,
  },
  metricCard: {
    gap: spacing.sm,
  },
  metricAccentBar: {
    width: 40,
    height: 4,
    borderRadius: radius.pill,
  },
  metricCardLabel: {
    color: palette.textMuted,
    fontSize: 13,
    fontWeight: "700",
    textTransform: "uppercase",
    letterSpacing: 0.6,
  },
  metricCardValue: {
    color: palette.text,
    fontSize: 28,
    lineHeight: 32,
    fontWeight: "700",
  },
  metricCardContext: {
    color: palette.textMuted,
    fontSize: 14,
  },
  summaryHeadline: {
    color: palette.text,
    fontSize: 24,
    lineHeight: 30,
    fontWeight: "700",
    marginBottom: spacing.sm,
  },
  workoutHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    gap: spacing.md,
    marginBottom: spacing.sm,
  },
  workoutMeta: {
    color: palette.textMuted,
    fontSize: 13,
    marginTop: 4,
  },
  workoutEffort: {
    color: palette.sage,
    fontSize: 13,
    fontWeight: "700",
  },
  timelineRow: {
    flexDirection: "row",
    gap: spacing.sm,
    marginTop: spacing.sm,
  },
  miniStat: {
    flex: 1,
    backgroundColor: palette.surfaceMuted,
    borderRadius: radius.md,
    padding: spacing.sm,
  },
  miniStatLabel: {
    color: palette.textMuted,
    fontSize: 12,
    fontWeight: "700",
    marginBottom: 4,
  },
  miniStatValue: {
    color: palette.text,
    fontSize: 16,
    fontWeight: "700",
  },
  progressFootnote: {
    color: palette.textMuted,
    fontSize: 13,
    marginTop: spacing.sm,
  },
  metricTopRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    gap: spacing.md,
    marginBottom: spacing.sm,
  },
  metricBaseline: {
    color: palette.textMuted,
    fontSize: 13,
    marginTop: 4,
  },
  directnessBadge: {
    backgroundColor: palette.surfaceMuted,
    borderRadius: radius.pill,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  directnessText: {
    color: palette.text,
    fontSize: 11,
    fontWeight: "700",
  },
  sensorRow: {
    paddingVertical: spacing.sm,
    borderTopWidth: 1,
    borderTopColor: palette.line,
  },
  sensorName: {
    color: palette.text,
    fontSize: 15,
    fontWeight: "700",
    marginBottom: 4,
  },
  sensorBody: {
    color: palette.textMuted,
    fontSize: 14,
    lineHeight: 20,
  },
  quickPromptWrap: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: spacing.sm,
  },
  quickPrompt: {
    backgroundColor: palette.surfaceMuted,
    borderRadius: radius.pill,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  quickPromptText: {
    color: palette.text,
    fontSize: 13,
    fontWeight: "600",
  },
  assistantBubble: {
    backgroundColor: palette.surface,
  },
  userBubble: {
    backgroundColor: palette.sageSoft,
  },
  messageRole: {
    color: palette.textMuted,
    fontSize: 12,
    fontWeight: "700",
    marginBottom: spacing.sm,
    textTransform: "uppercase",
    letterSpacing: 0.8,
  },
});
