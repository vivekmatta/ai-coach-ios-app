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
  PrimaryButton,
  Screen,
  SectionTitle,
  SecondaryButton,
  AppTextInput,
  Pill,
} from "./components";
import {
  dailyPlan,
  defaultProfile,
  healthLog,
  metrics,
  onboardingQuestions,
  planPrompts,
  researchSignals,
  sensors,
  topInsights,
  workouts,
} from "./data";
import { sendCoachMessage, generatePlan } from "./services/coachApi";
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
  activity: "Activity",
  plan: "Plan",
  coach: "Coach",
  signals: "Signals",
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
  const [planInput, setPlanInput] = useState(planPrompts[0]);
  const [generatedPlan, setGeneratedPlan] = useState("");
  const [planLoading, setPlanLoading] = useState(false);
  const [keyboardVisible, setKeyboardVisible] = useState(false);

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
    setTab("coach");
  }

  async function handleGeneratePlan(prompt?: string) {
    const raw = (prompt ?? planInput).trim();
    if (!raw || planLoading) {
      return;
    }

    setPlanInput(raw);
    setPlanLoading(true);
    const text = await generatePlan(raw, profile, dailyPlan);
    setGeneratedPlan(text);
    setPlanLoading(false);
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
            Less tracking noise. More clarity about what to do next.
          </Text>
        </View>
        <Pressable onPress={() => setTab("signals")} style={styles.headerBadge}>
          <Text style={styles.headerBadgeText}>Research Mode</Text>
        </Pressable>
      </View>

      {tab === "today" ? (
        <TodayScreen onAskCoach={handleSendMessage} onOpenSignals={() => setTab("signals")} />
      ) : null}
      {tab === "activity" ? <ActivityScreen /> : null}
      {tab === "plan" ? (
        <PlanScreen
          planInput={planInput}
          setPlanInput={setPlanInput}
          generatedPlan={generatedPlan}
          loading={planLoading}
          onGenerate={handleGeneratePlan}
          onRefine={(text) => {
            void handleSendMessage(`Please refine this weekly plan: ${text.slice(0, 220)}`);
          }}
        />
      ) : null}
      {tab === "coach" ? (
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
      ) : null}
      {tab === "signals" ? <SignalsScreen /> : null}

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
    </KeyboardAvoidingView>
  );
}

function TodayScreen({
  onAskCoach,
  onOpenSignals,
}: {
  onAskCoach: (prompt?: string) => Promise<void>;
  onOpenSignals: () => void;
}) {
  return (
    <Screen>
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
          <View style={styles.heroButton}>
            <SecondaryButton label="View signal model" onPress={onOpenSignals} />
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
        eyebrow="Signals"
        title="Insight-first metrics"
        subtitle="Values are still there, but they serve the decision."
      />

      {metrics.map((metric) => (
        <Card key={metric.id}>
          <View style={styles.metricTopRow}>
            <View>
              <Text style={styles.cardTitle}>{metric.name}</Text>
              <Text style={styles.metricValue}>
                {metric.value}
                {metric.unit ? <Text style={styles.metricUnit}> {metric.unit}</Text> : null}
              </Text>
              <Text style={styles.metricBaseline}>{metric.baseline}</Text>
            </View>
            <View style={[styles.statusBadge, { backgroundColor: metric.accent }]}>
              <Text style={styles.statusBadgeText}>{metric.status}</Text>
            </View>
          </View>
          <Text style={styles.cardBody}>{metric.shortInsight}</Text>
          <Text style={styles.metricDescription}>{metric.description}</Text>
          <View style={styles.actionWrap}>
            {metric.actions.map((action) => (
              <View key={action.text} style={styles.actionPill}>
                <Text style={styles.actionPillText}>{action.text}</Text>
              </View>
            ))}
          </View>
        </Card>
      ))}
    </Screen>
  );
}

function ActivityScreen() {
  return (
    <Screen>
      <SectionTitle
        eyebrow="Activity"
        title="The recent load tells the story."
        subtitle="Context matters more than single-day numbers."
      />

      <Card>
        <Text style={styles.summaryHeadline}>This cycle has been heavy enough to justify a downshift.</Text>
        <Text style={styles.cardBody}>
          The workload rose, sleep slipped, and the recovery trend never fully stabilized. The log makes the case for coaching the next week more conservatively.
        </Text>
      </Card>

      {workouts.map((workout) => (
        <Card key={workout.id}>
          <View style={styles.workoutHeader}>
            <View>
              <Text style={styles.cardTitle}>{workout.typeLabel}</Text>
              <Text style={styles.workoutMeta}>{workout.date}</Text>
            </View>
            <Text style={styles.workoutEffort}>{workout.effort}</Text>
          </View>
          <Text style={styles.workoutStats}>
            {workout.duration} • {workout.distance} • Avg HR {workout.avgHR}
          </Text>
          <Text style={styles.cardBody}>{workout.notes}</Text>
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
          <Text style={styles.logMetrics}>
            HRV {entry.hrv} • Sleep {entry.sleep} • Recovery {entry.recovery}
          </Text>
          <Text style={styles.logMetrics}>
            RHR {entry.rhr} • Steps {entry.steps} • Stress {entry.stress}
          </Text>
          <Text style={styles.cardBody}>{entry.notes}</Text>
        </Card>
      ))}
    </Screen>
  );
}

function PlanScreen({
  planInput,
  setPlanInput,
  generatedPlan,
  loading,
  onGenerate,
  onRefine,
}: {
  planInput: string;
  setPlanInput: (value: string) => void;
  generatedPlan: string;
  loading: boolean;
  onGenerate: (prompt?: string) => Promise<void>;
  onRefine: (text: string) => void;
}) {
  return (
    <Screen>
      <SectionTitle
        eyebrow="Weekly coaching"
        title="Generate a plan that fits the signals."
        subtitle="The coach should turn goals and biometrics into a week you can actually follow."
      />

      <Card>
        <Text style={styles.cardTitle}>Quick starts</Text>
        <View style={styles.quickPromptWrap}>
          {planPrompts.map((prompt) => (
            <Pressable
              key={prompt}
              onPress={() => setPlanInput(prompt)}
              style={styles.quickPrompt}
            >
              <Text style={styles.quickPromptText}>{prompt}</Text>
            </Pressable>
          ))}
        </View>
      </Card>

      <Card>
        <Text style={styles.cardTitle}>Plan request</Text>
        <AppTextInput
          value={planInput}
          onChangeText={setPlanInput}
          placeholder="Describe the weekly plan you want"
          multiline
        />
        <View style={styles.questionActions}>
          <PrimaryButton
            label={loading ? "Generating..." : "Generate weekly plan"}
            onPress={() => {
              void onGenerate();
            }}
            disabled={!planInput.trim() || loading}
          />
        </View>
      </Card>

      {generatedPlan ? (
        <Card>
          <Text style={styles.cardTitle}>Generated plan</Text>
          <Text style={styles.generatedPlanText}>{generatedPlan}</Text>
          <View style={styles.heroButtons}>
            <View style={styles.heroButton}>
              <SecondaryButton
                label="Refine in coach"
                onPress={() => onRefine(generatedPlan)}
              />
            </View>
          </View>
        </Card>
      ) : null}
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
        subtitle="The coach should sound like a guide, not a dashboard."
      />

      <Card>
        <View style={styles.quickPromptWrap}>
          {[
            "Give me a plan for today",
            "Why is my HRV low?",
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

function SignalsScreen() {
  return (
    <Screen>
      <SectionTitle
        eyebrow="Research"
        title="What the band is trying to understand"
        subtitle="This screen translates the research document into a clean product layer."
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
          <Text style={styles.signalSensors}>{signal.sensors.join(" • ")}</Text>
        </Card>
      ))}

      <SectionTitle
        eyebrow="Sensors"
        title="Current stack candidates"
        subtitle="Hardware and sensing choices pulled directly from the research notes."
      />

      {sensors.map((sensor) => (
        <Card key={sensor.name}>
          <Text style={styles.cardTitle}>{sensor.name}</Text>
          <Text style={styles.sensorPurpose}>{sensor.purpose}</Text>
          <Text style={styles.cardBody}>{sensor.notes}</Text>
        </Card>
      ))}
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
  signalSensors: {
    marginTop: 12,
    color: palette.text,
    fontSize: 13,
    fontWeight: "600",
  },
  sensorPurpose: {
    marginTop: 8,
    color: palette.text,
    fontSize: 14,
    fontWeight: "600",
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
