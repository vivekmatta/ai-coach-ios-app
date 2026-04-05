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
  Card,
  Screen,
  SectionTitle,
  SecondaryButton,
  AppTextInput,
  Pill,
  PrimaryButton,
} from "./components";
import {
  dailyPlan,
  defaultProfile,
  healthLog,
  metrics,
  onboardingQuestions,
  researchSignals,
  sensors,
  topInsights,
  workouts,
} from "./data";
import { sendCoachMessage } from "./services/coachApi";
import { loadOnboardingComplete, loadProfile, saveOnboardingComplete, saveProfile } from "./storage";
import { palette, radius, spacing } from "./theme";
import { CoachMessage, TabKey, UserProfile } from "./types";

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

export function MobileApp() {
  const [loading, setLoading] = useState(true);
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

  useEffect(() => {
    async function bootstrap() {
      const [storedProfile, done] = await Promise.all([
        loadProfile(),
        loadOnboardingComplete(),
      ]);

      setProfile(storedProfile);
      setOnboardingDone(done);
      setMessages([
        {
          id: "welcome",
          role: "assistant",
          text: "I’ve already looked at today’s signals. Recovery is low, stress is high, and the smartest move is to simplify the day.",
        },
      ]);
      setLoading(false);
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
            Your coach turns today’s signals into a simpler plan.
          </Text>
        </View>
        <Pressable onPress={() => setTab("you")} style={styles.headerBadge}>
          <Text style={styles.headerBadgeText}>About You</Text>
        </Pressable>
      </View>

      {tab === "today" ? (
        <TodayScreen
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
          onAskCoach={async (prompt) => {
            setCoachOpen(true);
            if (prompt) {
              void handleSendMessage(prompt);
            }
          }}
        />
      ) : null}
      {tab === "you" ? <YouScreen profile={profile} /> : null}

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
          style={({ pressed }) => [styles.floatingCoachButton, pressed && styles.floatingCoachPressed]}
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
                  <Text style={styles.modalSubtitle}>Ask about today, recovery, sleep, or what to do next.</Text>
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
  onAskCoach,
}: {
  onAskCoach: (prompt?: string) => Promise<void>;
}) {
  return (
    <Screen bottomPadding={150}>
      <Card style={styles.morningHero}>
        <Text style={styles.heroEyebrow}>Today’s read</Text>
        <Text style={styles.heroTitle}>Your body is asking for a lighter day.</Text>
        <Text style={styles.heroBody}>
          Recovery is low, sleep debt is visible, and stress is elevated. The best move is to protect the next 24 hours instead of trying to force performance.
        </Text>
        <View style={styles.heroButtons}>
          <View style={styles.heroButton}>
            <PrimaryButton
              label="Ask coach for today’s plan"
              onPress={() => {
                void onAskCoach("Give me a plan for today based on my current signals.");
              }}
            />
          </View>
        </View>
      </Card>

      <SectionTitle
        eyebrow="Key insights"
        title="What matters most today"
        subtitle="Short explanations, then clear action."
      />

      {topInsights.map((insight) => (
        <Card key={insight.title}>
          <View style={styles.inlineTitleRow}>
            <View style={[styles.accentDot, { backgroundColor: insight.accent }]} />
            <Text style={styles.cardTitle}>{insight.title}</Text>
          </View>
          <Text style={styles.cardBody}>{insight.text}</Text>
        </Card>
      ))}

      <Card>
        <Text style={styles.planTitle}>Today’s plan</Text>
        <View style={styles.planItem}>
          <Text style={styles.planLabel}>Bedtime</Text>
          <Text style={styles.planValue}>{dailyPlan.bedtime}</Text>
        </View>
        <View style={styles.planItem}>
          <Text style={styles.planLabel}>Workout</Text>
          <Text style={styles.planValue}>{dailyPlan.workout}</Text>
        </View>
        <View style={styles.planItem}>
          <Text style={styles.planLabel}>Hydration</Text>
          <Text style={styles.planValue}>{dailyPlan.hydration}</Text>
        </View>
        <View style={styles.planItem}>
          <Text style={styles.planLabel}>Nutrition</Text>
          <Text style={styles.planValue}>{dailyPlan.nutrition}</Text>
        </View>
      </Card>

      <SectionTitle
        eyebrow="What to watch"
        title="A few focused coaching cues"
        subtitle="Less data, more meaning."
      />

      {metrics.map((metric) => (
        <Card key={metric.id}>
          <View style={styles.metricNarrativeHeader}>
            <View style={[styles.metricAccentBar, { backgroundColor: metric.accent }]} />
            <View style={styles.metricNarrativeTextWrap}>
              <Text style={styles.cardTitle}>{metric.name}</Text>
              <Text style={styles.cardBody}>{metric.shortInsight}</Text>
            </View>
          </View>
          <View style={styles.metricMetaRow}>
            <View style={[styles.softStatusBadge, { backgroundColor: metric.accent }]} />
            <Text style={styles.metricStatusLabel}>{metric.status}</Text>
            <Text style={styles.metricMetaDivider}>•</Text>
            <Text style={styles.metricMetaLabel}>Tap Coach if you want the why</Text>
          </View>
        </Card>
      ))}
    </Screen>
  );
}

function ProgressScreen({
  onAskCoach,
}: {
  onAskCoach: (prompt?: string) => Promise<void>;
}) {
  return (
    <Screen bottomPadding={150}>
      <SectionTitle
        eyebrow="Progress"
        title="The trend matters more than the metric."
        subtitle="Use history to understand the pattern, not to obsess over numbers."
      />

      <Card>
        <Text style={styles.summaryHeadline}>This week points to a recovery dip, not a motivation problem.</Text>
        <Text style={styles.cardBody}>
          The workload rose, sleep slipped, and the rebound stayed fragile. The right response is gentler structure, not more pressure.
        </Text>
        <View style={styles.heroButtons}>
          <View style={styles.heroButton}>
            <SecondaryButton
              label="Ask coach what changed"
              onPress={() => {
                void onAskCoach("What changed this week and what should I do next?");
              }}
            />
          </View>
        </View>
      </Card>

      <SectionTitle
        eyebrow="Recent sessions"
        title="Training in plain language"
        subtitle="A quick read on what each session meant."
      />

      {workouts.map((workout) => (
        <Card key={workout.id}>
          <View style={styles.workoutHeader}>
            <View>
              <Text style={styles.cardTitle}>{workout.typeLabel}</Text>
              <Text style={styles.workoutMeta}>{workout.date}</Text>
            </View>
            <Text style={styles.workoutEffort}>{workout.type.toUpperCase()}</Text>
          </View>
          <Text style={styles.cardBody}>{workout.notes}</Text>
          <Text style={styles.progressFootnote}>{workout.effort} • {workout.duration}</Text>
        </Card>
      ))}

      <SectionTitle
        eyebrow="Health log"
        title="Pattern over perfection"
        subtitle="Use trends to explain behavior, not to shame it."
      />

      {healthLog.map((entry) => (
        <Card key={entry.date}>
          <Text style={styles.cardTitle}>{entry.date}</Text>
          <Text style={styles.cardBody}>{entry.notes}</Text>
          <Text style={styles.progressFootnote}>Stress {entry.stress} • Sleep {entry.sleep}</Text>
        </Card>
      ))}
    </Screen>
  );
}

function YouScreen({
  profile,
}: {
  profile: UserProfile;
}) {
  return (
    <Screen bottomPadding={140}>
      <SectionTitle
        eyebrow="You"
        title="How the app understands your day"
        subtitle="Profile, preferences, and a simple explanation of the data model."
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

      <SectionTitle
        eyebrow="Trust"
        title="Direct, proxy, and context signals"
        subtitle="Most of the app is translating signals into simpler language, not exposing raw measurements."
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
        subtitle="Chat is the only live AI surface for now."
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
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  modalCloseText: {
    color: palette.text,
    fontSize: 13,
    fontWeight: "700",
  },
  heroCard: {
    backgroundColor: palette.surfaceMuted,
  },
  morningHero: {
    backgroundColor: "#FBF8F4",
  },
  heroEyebrow: {
    fontSize: 12,
    fontWeight: "700",
    letterSpacing: 1,
    color: palette.sage,
    textTransform: "uppercase",
    marginBottom: 10,
  },
  heroTitle: {
    fontSize: 30,
    lineHeight: 36,
    fontWeight: "700",
    color: palette.text,
  },
  heroBody: {
    marginTop: 12,
    fontSize: 16,
    lineHeight: 24,
    color: palette.textMuted,
  },
  heroButtons: {
    marginTop: 18,
    gap: 10,
  },
  heroButton: {
    width: "100%",
  },
  inlineTitleRow: {
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
  },
  accentDot: {
    width: 10,
    height: 10,
    borderRadius: 999,
  },
  cardTitle: {
    fontSize: 18,
    fontWeight: "700",
    color: palette.text,
  },
  cardBody: {
    marginTop: 10,
    fontSize: 15,
    lineHeight: 22,
    color: palette.textMuted,
  },
  planTitle: {
    fontSize: 20,
    fontWeight: "700",
    color: palette.text,
    marginBottom: 4,
  },
  planItem: {
    paddingVertical: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: palette.line,
  },
  planLabel: {
    color: palette.text,
    fontSize: 13,
    fontWeight: "700",
    marginBottom: 4,
  },
  planValue: {
    color: palette.textMuted,
    fontSize: 15,
    lineHeight: 22,
  },
  metricTopRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    gap: spacing.sm,
  },
  metricNarrativeHeader: {
    flexDirection: "row",
    gap: 12,
    alignItems: "flex-start",
  },
  metricAccentBar: {
    width: 6,
    minHeight: 58,
    borderRadius: radius.pill,
  },
  metricNarrativeTextWrap: {
    flex: 1,
  },
  metricMetaRow: {
    marginTop: 14,
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
  },
  softStatusBadge: {
    width: 10,
    height: 10,
    borderRadius: 999,
  },
  metricStatusLabel: {
    color: palette.text,
    fontSize: 12,
    fontWeight: "700",
  },
  metricMetaDivider: {
    color: palette.textMuted,
    fontSize: 12,
  },
  metricMetaLabel: {
    color: palette.textMuted,
    fontSize: 12,
  },
  metricValue: {
    marginTop: 8,
    color: palette.text,
    fontSize: 24,
    fontWeight: "700",
  },
  metricUnit: {
    fontSize: 16,
    fontWeight: "600",
    color: palette.textMuted,
  },
  metricBaseline: {
    marginTop: 6,
    color: palette.textMuted,
    fontSize: 13,
  },
  metricDescription: {
    marginTop: 8,
    fontSize: 14,
    lineHeight: 21,
    color: palette.textMuted,
  },
  statusBadge: {
    borderRadius: radius.pill,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  statusBadgeText: {
    color: palette.surface,
    fontSize: 12,
    fontWeight: "700",
  },
  actionWrap: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 8,
    marginTop: 14,
  },
  actionPill: {
    backgroundColor: palette.surfaceMuted,
    borderRadius: radius.pill,
    paddingHorizontal: 10,
    paddingVertical: 8,
  },
  actionPillText: {
    color: palette.text,
    fontSize: 12,
    fontWeight: "600",
  },
  summaryHeadline: {
    fontSize: 22,
    lineHeight: 30,
    color: palette.text,
    fontWeight: "700",
  },
  workoutHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    gap: spacing.sm,
  },
  workoutMeta: {
    marginTop: 4,
    color: palette.textMuted,
    fontSize: 13,
  },
  workoutEffort: {
    color: palette.coral,
    fontSize: 13,
    fontWeight: "700",
  },
  workoutStats: {
    marginTop: 10,
    color: palette.text,
    fontSize: 14,
    fontWeight: "600",
  },
  progressFootnote: {
    marginTop: 12,
    color: palette.textMuted,
    fontSize: 12,
    fontWeight: "600",
  },
  logMetrics: {
    marginTop: 8,
    color: palette.text,
    fontSize: 13,
  },
  quickPromptWrap: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10,
    marginTop: 12,
  },
  quickPrompt: {
    backgroundColor: palette.surfaceMuted,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: palette.line,
    paddingHorizontal: 12,
    paddingVertical: 10,
  },
  quickPromptText: {
    color: palette.text,
    fontSize: 13,
    lineHeight: 18,
    fontWeight: "600",
  },
  generatedPlanText: {
    marginTop: 12,
    color: palette.textMuted,
    fontSize: 15,
    lineHeight: 23,
  },
  assistantBubble: {
    backgroundColor: palette.surface,
  },
  userBubble: {
    backgroundColor: "#F4EFE8",
  },
  messageRole: {
    color: palette.text,
    fontSize: 12,
    fontWeight: "700",
    textTransform: "uppercase",
    letterSpacing: 1,
  },
  directnessBadge: {
    backgroundColor: palette.sageSoft,
    borderRadius: radius.pill,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  directnessText: {
    color: palette.sage,
    fontSize: 12,
    fontWeight: "700",
  },
  sensorRow: {
    paddingTop: 12,
    borderTopWidth: StyleSheet.hairlineWidth,
    borderTopColor: palette.line,
    marginTop: 12,
  },
  sensorName: {
    color: palette.text,
    fontSize: 14,
    fontWeight: "700",
  },
  sensorBody: {
    marginTop: 4,
    color: palette.textMuted,
    fontSize: 14,
    lineHeight: 20,
  },
  questionCounter: {
    color: palette.textMuted,
    fontSize: 13,
    marginBottom: 8,
  },
  questionText: {
    color: palette.text,
    fontSize: 22,
    lineHeight: 30,
    fontWeight: "700",
    marginBottom: 16,
  },
  questionActions: {
    marginTop: 14,
  },
});
