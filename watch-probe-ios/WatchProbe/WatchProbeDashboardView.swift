import SwiftUI

struct MetricDetailRow: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String

    init(_ label: String, _ value: String, id: String? = nil) {
        self.id = id ?? "\(label)-\(value)"
        self.label = label
        self.value = value
    }
}

struct MetricHistorySection: Identifiable, Equatable {
    let id: String
    let title: String
    let rows: [MetricDetailRow]

    init(_ title: String, rows: [MetricDetailRow]) {
        self.id = title
        self.title = title
        self.rows = rows
    }
}

struct MetricDetailData: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let colorName: String
    let value: String
    let detail: String
    let rows: [MetricDetailRow]
    let history: [MetricHistorySection]
    let aiExplanation: MetricAIExplanation?

    var color: Color {
        switch colorName {
        case "red": return .wpRed
        case "blue": return .wpBlue
        case "green": return .wpGreen
        case "orange": return .wpOrange
        case "secondary": return .wpSecondary
        default: return .wpPrimary
        }
    }
}

struct WatchDeviceCandidate: Identifiable, Equatable {
    let id: String
    let name: String
    let address: String
    let rssi: Int
}

final class WatchProbeViewModel: ObservableObject {
    @Published var deviceName = "ES02"
    @Published var deviceAddress = "--"
    @Published var connectionState = "Ready"
    @Published var battery = "--"
    @Published var lastSync = "not yet"
    @Published var nextSync = "not scheduled"
    @Published var localStorage = "No local data yet"
    @Published var autoSyncEnabled = true
    @Published var canSync = false
    @Published var canExport = false
    @Published var canDisconnect = false
    @Published var isConnected = false
    @Published var isSyncing = false
    @Published var heartRate = "--"
    @Published var oxygen = "--"
    @Published var ecg = "--"
    @Published var hrv = "--"
    @Published var bloodPressure = "--"
    @Published var bloodGlucose = "--"
    @Published var sleepDuration = "--"
    @Published var sleepScore = "--"
    @Published var sleepScoreDetail = "No sleep score yet"
    @Published var steps = "--"
    @Published var distance = "--"
    @Published var calories = "--"
    @Published var temperature = "--"
    @Published var updatedAt = "--"
    @Published var metricDetails: [String: MetricDetailData] = [:]
    @Published var coachAnalysis: AICoachAnalysis = .empty
    @Published var aiStatus = "Sync your watch to generate coach insights."
    @Published var isAIAnalyzing = false
    @Published var discoveredWatches: [WatchDeviceCandidate] = []
    @Published var onboardingCompleted = UserDefaults.standard.bool(forKey: "WatchProbe.onboardingCompleted")
    @Published var notificationPermissionStatus = "Not requested"
    @Published var localAIProxyURL = UserDefaults.standard.string(forKey: "WatchProbe.localAIProxyURL") ?? "" {
        didSet {
            UserDefaults.standard.set(localAIProxyURL, forKey: "WatchProbe.localAIProxyURL")
        }
    }
    @Published var debugLog = ""
    @Published var showDebugLog = false

    var connectAction: (() -> Void)?
    var disconnectAction: (() -> Void)?
    var syncAction: (() -> Void)?
    var exportAction: (() -> Void)?
    var autoSyncAction: ((Bool) -> Void)?
    var heartRateAction: (() -> Void)?
    var oxygenAction: (() -> Void)?
    var stepAction: (() -> Void)?
    var temperatureAction: (() -> Void)?
    var completeOnboardingAction: (() -> Void)?
    var notificationPermissionAction: (() -> Void)?
    var calendarContextChangedAction: (() -> Void)?
    var watchSelectAction: ((WatchDeviceCandidate) -> Void)?

    var wellnessScore: Int {
        var score = 55
        if isConnected { score += 10 }
        if battery != "--" { score += 5 }
        if heartRate != "--" { score += 8 }
        if oxygen != "--" { score += 8 }
        if sleepScore != "--" { score += 8 }
        if hrv != "--" { score += 4 }
        if steps != "--" { score += 6 }
        if temperature != "--" { score += 4 }
        return min(score, 96)
    }

    func appendLog(_ message: String) {
        let next = debugLog.isEmpty ? message : "\(message)\n\(debugLog)"
        debugLog = next
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(80)
            .joined(separator: "\n")
        connectionState = message
    }

    func completeOnboarding() {
        onboardingCompleted = true
        UserDefaults.standard.set(true, forKey: "WatchProbe.onboardingCompleted")
        completeOnboardingAction?()
    }

    func showOnboarding() {
        onboardingCompleted = false
        UserDefaults.standard.set(false, forKey: "WatchProbe.onboardingCompleted")
    }
}

struct WatchProbeDashboardView: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        if !model.onboardingCompleted {
            OnboardingRootView(model: model)
        } else {
            TabView {
                DashboardView(model: model)
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("Dashboard")
                    }

                ProfileDashboardView(model: model)
                    .tabItem {
                        Image(systemName: "person.crop.circle")
                        Text("Profile")
                    }
            }
            .accentColor(.wpPrimary)
        }
    }
}

private struct OnboardingRootView: View {
    @ObservedObject var model: WatchProbeViewModel
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                OnboardingPage(
                    icon: "applewatch",
                    title: "AI Coach",
                    bodyText: "Sync your ES02 watch and turn the latest health data into a simple recovery and activity readout."
                )
                .tag(0)

                OnboardingPage(
                    icon: "lock.shield",
                    title: "Your Data",
                    bodyText: "Raw sync files stay local, and the coach uses compact summaries for explanations and next steps."
                )
                .tag(1)

                OnboardingPermissionsPage(model: model)
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))

            HStack(spacing: 12) {
                if page > 0 {
                    Button(action: { page -= 1 }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 46, height: 46)
                    }
                    .foregroundColor(.wpPrimary)
                    .background(Color.wpSurface)
                    .cornerRadius(23)
                    .shadow(color: Color.wpShadowDark, radius: 8, x: 5, y: 5)
                    .shadow(color: Color.white.opacity(0.95), radius: 8, x: -5, y: -5)
                }

                Button(action: {
                    if page < 2 {
                        page += 1
                    } else {
                        model.completeOnboarding()
                    }
                }) {
                    Text(page < 2 ? "Continue" : "Open App")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundColor(.white)
                        .background(Color.wpPrimary)
                        .cornerRadius(24)
                        .shadow(color: Color.wpPrimary.opacity(0.26), radius: 12, x: 0, y: 8)
                }
            }
            .padding(20)
        }
        .background(Color.wpBackground.edgesIgnoringSafeArea(.all))
    }
}

private struct OnboardingPage: View {
    let icon: String
    let title: String
    let bodyText: String

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            OnboardingHeroIcon(systemName: icon, color: .wpPrimary)
                .padding(.bottom, 24)
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.wpText)
            Text(bodyText)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.wpTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 28)
            Spacer()
        }
    }
}

private struct OnboardingHeroIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.wpSurface)
                .frame(width: 188, height: 188)
                .shadow(color: Color.wpShadowDark, radius: 20, x: 10, y: 10)
                .shadow(color: Color.white.opacity(0.95), radius: 20, x: -10, y: -10)
            Circle()
                .fill(Color.wpSurfaceLow)
                .frame(width: 136, height: 136)
                .shadow(color: Color.wpShadowDark, radius: 10, x: 5, y: 5)
                .shadow(color: Color.white.opacity(0.95), radius: 10, x: -5, y: -5)
            Image(systemName: systemName)
                .font(.system(size: 64, weight: .regular))
                .foregroundColor(color)
        }
    }
}

private struct OnboardingPermissionsPage: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 8) {
                    Capsule()
                        .fill(Color.wpSurfaceLow)
                        .frame(width: 30, height: 8)
                        .neoInset(radius: 4)
                    Capsule()
                        .fill(Color.wpSurfaceLow)
                        .frame(width: 30, height: 8)
                        .neoInset(radius: 4)
                    Capsule()
                        .fill(Color.wpPrimary)
                        .frame(width: 30, height: 8)
                        .shadow(color: Color.wpPrimary.opacity(0.25), radius: 8, x: 0, y: 3)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                Text("Final Steps")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.wpText)
                    .frame(maxWidth: .infinity)
                PermissionCard(
                    icon: "bell.badge.fill",
                    title: "Morning sync reminder",
                    detail: model.notificationPermissionStatus,
                    actionTitle: "Allow Reminder",
                    action: model.notificationPermissionAction
                )
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        CircleIcon(systemName: "applewatch", color: .wpPrimary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.isConnected ? "Watch connected" : "Saved watch")
                                .wpHeadline()
                            Text(model.isConnected ? "\(model.deviceName) is ready" : "Look for \(model.deviceName) nearby")
                                .wpCaption()
                        }
                        Spacer()
                    }
                    HStack {
                        Text("MAC ADDRESS")
                            .wpLabel()
                        Spacer(minLength: 12)
                        Text(model.deviceAddress == "--" ? "Waiting for watch" : model.deviceAddress)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.wpText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .padding(12)
                    .background(Color.wpSurfaceLow)
                    .cornerRadius(14)
                    .neoInset(radius: 14)
                    if !model.discoveredWatches.isEmpty {
                        ForEach(model.discoveredWatches) { watch in
                            Button(action: { model.watchSelectAction?(watch) }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(watch.name)
                                            .wpHeadline()
                                        Text(watch.address)
                                            .font(.system(size: 13, weight: .regular, design: .monospaced))
                                            .foregroundColor(.wpTextSecondary)
                                    }
                                    Spacer()
                                    Text("\(watch.rssi)")
                                        .wpCaption()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider()
                        }
                    }
                    ActionButton(
                        title: model.isConnected ? "Connected" : "Find Watch",
                        color: .wpPrimary,
                        filled: true,
                        disabled: model.isConnected,
                        action: model.connectAction
                    )
                }
                .card()
            }
            .padding(20)
        }
    }
}

private struct PermissionCard: View {
    let icon: String
    let title: String
    let detail: String
    let actionTitle: String
    let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                CircleIcon(systemName: icon, color: .wpOrange)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .wpHeadline()
                    Text(detail)
                        .wpCaption()
                }
            }
            HStack {
                Spacer()
                Button(action: { action?() }) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.wpPrimary)
                        .cornerRadius(18)
                        .shadow(color: Color.wpPrimary.opacity(0.25), radius: 9, x: 0, y: 4)
                }
            }
        }
        .card()
    }
}

private struct DashboardView: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    WatchStatusCard(model: model)
                    VStack(spacing: 16) {
                        if model.isAIAnalyzing {
                            AILoadingCard(status: model.aiStatus)
                        }
                        CoachSummaryCard(model: model)
                        SuggestedActionsList(model: model)
                        WellnessScoreCard(score: model.coachAnalysis.overallScore ?? model.wellnessScore)
                    }
                    MetricsGrid(model: model)
                }
                .padding(20)
            }
            .background(Color.wpBackground.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("AI Coach", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct InsightsView: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    InsightGroupsView(model: model)
                }
                .padding(16)
            }
            .background(Color.wpBackground.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Insights", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct ProfileDashboardView: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ProfileHeader()
                    ConnectedDeviceSection(model: model)
                    SettingsSection(model: model)
                    DataSection(model: model)
                    DebugSection(model: model)
                }
                .padding(20)
            }
            .background(Color.wpBackground.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("AI Coach", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct AILoadingCard: View {
    let status: String
    @State private var phase = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.wpPrimary.opacity(0.18), lineWidth: 8)
                    .frame(width: 54, height: 54)
                Circle()
                    .trim(from: 0, to: 0.72)
                    .stroke(Color.wpPrimary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(phase ? 360 : 0))
                    .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: phase)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.wpPrimary)
                    .scaleEffect(phase ? 1.08 : 0.92)
                    .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: phase)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("AI coach is updating")
                    .wpHeadline()
                Text(status.isEmpty ? "Reading your latest watch and calendar context." : status)
                    .wpCaption()
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .card()
        .onAppear { phase = true }
    }
}

private struct CoachSummaryCard: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("COACH")
                    .wpLabel()
                    .foregroundColor(.wpPrimary)
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                    Text(model.aiStatus)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.wpSecondary)
            }
            Text(model.coachAnalysis.overallSummary)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.wpText)
                .fixedSize(horizontal: false, vertical: true)

            if let actionRoute {
                NavigationLink(destination: MetricActionView(detail: actionRoute.detail, action: actionRoute.action.title, actionModel: actionRoute.action)) {
                    SuggestedActionDashboardButton(action: actionRoute.action.title)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                SuggestedActionDashboardButton(action: model.coachAnalysis.priority)
            }

            if !model.coachAnalysis.coachMessage.isEmpty {
                Text(model.coachAnalysis.coachMessage)
                    .wpCaption()
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card()
    }

    private var actionRoute: (detail: MetricDetailData, action: CoachSuggestedAction)? {
        let preferredOrder = ["activity", "sleep", "heartRate", "hrv", "oxygen", "temperature"]
        for id in preferredOrder {
            guard let detail = model.metricDetails[id],
                  let action = detail.suggestedActionText else { continue }
            return (detail, typedAction(for: detail, actionText: action))
        }

        if model.steps != "--" {
            let detail = model.metricDetails["activity"] ?? MetricDetailData(
                id: "activity",
                title: "Activity",
                icon: "figure.walk",
                colorName: "orange",
                value: model.steps,
                detail: "\(model.distance) km / \(model.calories) kcal",
                rows: [
                    MetricDetailRow("Steps today", model.steps),
                    MetricDetailRow("Distance", "\(model.distance) km"),
                    MetricDetailRow("Calories", "\(model.calories) kcal")
                ],
                history: [],
                aiExplanation: MetricAIExplanation.fallback(metricId: "activity", value: model.steps, title: "Activity")
            )
            let text = detail.suggestedActionText ?? "Increase active movement by 15 minutes this afternoon."
            return (detail, typedAction(for: detail, actionText: text))
        }

        return nil
    }

    private func typedAction(for detail: MetricDetailData, actionText: String) -> CoachSuggestedAction {
        model.coachAnalysis.suggestedActions.first {
            $0.metricIds.contains(detail.id) || $0.title == actionText
        } ?? CoachSuggestedAction.legacy(actionText, metricId: detail.id, rationale: detail.actionReasonText)
    }
}

private struct SuggestedActionDashboardButton: View {
    let action: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CircleIcon(systemName: "target", color: .wpPrimary)
                .scaleEffect(0.82)
            VStack(alignment: .leading, spacing: 6) {
                Text("Suggested action")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.wpPrimary)
                Text(action)
                    .wpCaption()
                    .foregroundColor(.wpText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.wpTextSecondary)
        }
        .padding(14)
        .background(Color.wpSurfaceLow)
        .cornerRadius(16)
        .neoInset(radius: 16)
    }
}

private struct SuggestedActionsList: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        if !model.coachAnalysis.suggestedActions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("SUGGESTED ACTIONS")
                    .wpLabel()
                ForEach(model.coachAnalysis.suggestedActions.prefix(5)) { action in
                    NavigationLink(destination: MetricActionView(detail: detail(for: action), action: action.title, actionModel: action)) {
                        HStack(alignment: .top, spacing: 12) {
                            CircleIcon(systemName: icon(for: action), color: color(for: action))
                                .scaleEffect(0.82)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(action.title)
                                    .wpHeadline()
                                    .lineLimit(2)
                                Text(action.rationale.isEmpty ? action.category.capitalized : action.rationale)
                                    .wpCaption()
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.wpTextSecondary)
                                .padding(.top, 5)
                        }
                        .padding(14)
                        .background(Color.wpSurfaceLow)
                        .cornerRadius(16)
                        .neoInset(radius: 16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .card()
        }
    }

    private func detail(for action: CoachSuggestedAction) -> MetricDetailData {
        for metricId in action.metricIds {
            if let detail = model.metricDetails[metricId] {
                return detail
            }
        }
        return model.metricDetails["activity"] ?? MetricDetailData(
            id: action.category,
            title: action.category.capitalized,
            icon: icon(for: action),
            colorName: "primary",
            value: "\(action.durationMinutes) min",
            detail: action.rationale,
            rows: [
                MetricDetailRow("Action", action.title),
                MetricDetailRow("Intensity", action.intensity.capitalized),
                MetricDetailRow("Duration", "\(action.durationMinutes) minutes")
            ],
            history: [],
            aiExplanation: nil
        )
    }

    private func icon(for action: CoachSuggestedAction) -> String {
        switch action.category {
        case "hydration": return "drop.fill"
        case "sleep": return "bed.double.fill"
        case "stress": return "wind"
        case "activity": return action.intensity.lowercased() == "high" ? "flame.fill" : "figure.walk"
        default: return "target"
        }
    }

    private func color(for action: CoachSuggestedAction) -> Color {
        switch action.category {
        case "hydration": return .wpBlue
        case "sleep": return .wpSecondary
        case "stress": return .wpPrimary
        case "activity": return .wpOrange
        default: return .wpPrimary
        }
    }
}

private struct InsightGroupsView: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        VStack(spacing: 12) {
            CoachInsightCards(model: model)
            SectionPanel(title: "RECOVERY") {
                VStack(spacing: 12) {
                    DetailMetricCard(id: "sleep", title: "Sleep", icon: "bed.double.fill", color: .wpSecondary, value: model.sleepScore, detail: "\(model.sleepDuration) slept / \(model.sleepScoreDetail)", detailData: model.metricDetails["sleep"])
                    HStack(spacing: 12) {
                        DetailMetricCard(id: "hrv", title: "HRV", icon: "waveform.path", color: .wpPrimary, value: model.hrv, detail: "Heart rate variability", detailData: model.metricDetails["hrv"])
                        DetailMetricCard(id: "temperature", title: "Temperature", icon: "thermometer", color: .wpRed, value: model.temperature, detail: "Body / skin", detailData: model.metricDetails["temperature"])
                    }
                }
            }

            SectionPanel(title: "CARDIO") {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        DetailMetricCard(id: "heartRate", title: "Heart Rate", icon: "heart.fill", color: .wpRed, value: model.heartRate, detail: "Latest saved or live", detailData: model.metricDetails["heartRate"])
                        DetailMetricCard(id: "oxygen", title: "Blood Oxygen", icon: "drop.fill", color: .wpBlue, value: model.oxygen, detail: "SpO2", detailData: model.metricDetails["oxygen"])
                    }
                    HStack(spacing: 12) {
                        DetailMetricCard(id: "bloodPressure", title: "Blood Pressure", icon: "gauge.with.dots.needle.33percent", color: .wpRed, value: model.bloodPressure, detail: "Systolic / diastolic", detailData: model.metricDetails["bloodPressure"])
                        DetailMetricCard(id: "ecg", title: "ECG", icon: "waveform.path.ecg", color: .wpPrimary, value: model.ecg, detail: "Offline ECG", detailData: model.metricDetails["ecg"])
                    }
                }
            }

            SectionPanel(title: "ACTIVITY & DATA") {
                VStack(spacing: 12) {
                    DetailMetricCard(id: "activity", title: "Activity", icon: "figure.walk", color: .wpOrange, value: model.steps, detail: "\(model.distance) km / \(model.calories) kcal", detailData: model.metricDetails["activity"])
                    HStack(spacing: 12) {
                        DetailMetricCard(id: "bloodGlucose", title: "Glucose", icon: "testtube.2", color: .wpGreen, value: model.bloodGlucose, detail: "Latest stored value", detailData: model.metricDetails["bloodGlucose"])
                        DetailMetricCard(id: "battery", title: "Battery", icon: "battery.100", color: .wpGreen, value: model.battery, detail: "Watch", detailData: model.metricDetails["battery"])
                    }
                }
            }
        }
    }
}

private struct CoachInsightCards: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        Group {
            if !model.coachAnalysis.insightCards.isEmpty {
                SectionPanel(title: "COACH INSIGHTS") {
                    VStack(spacing: 10) {
                        ForEach(model.coachAnalysis.insightCards.sorted { $0.priority < $1.priority }) { insight in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(insight.title)
                                    .wpHeadline()
                                Text(insight.body)
                                    .wpCaption()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                        }
                    }
                }
            }
        }
    }
}

private struct DashboardMetricExplanation: View {
    let detail: MetricDetailData

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            CircleIcon(systemName: detail.icon, color: detail.color)
            VStack(alignment: .leading, spacing: 5) {
                Text(detail.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.wpText)
                Text(detail.aiExplanation?.shortExplanation ?? detail.detail)
                    .wpCaption()
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                if let reference = VitalReference.reference(for: detail.id) {
                    Text("Reference: \(reference.shortRange)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.wpTextSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 5) {
                Text(detail.value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(detail.color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.wpTextSecondary)
            }
        }
    }
}

private struct DashboardMetricList: View {
    @ObservedObject var model: WatchProbeViewModel

    private let metricOrder = [
        "sleep",
        "heartRate",
        "oxygen",
        "hrv",
        "bloodPressure",
        "activity",
        "temperature",
        "bloodGlucose",
        "ecg",
        "battery",
        "updated"
    ]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(metricOrder, id: \.self) { id in
                if let detail = model.metricDetails[id] {
                    VStack(spacing: 8) {
                        NavigationLink(destination: MetricDetailView(detail: detail)) {
                            DashboardMetricExplanation(detail: detail)
                                .card()
                        }
                        .buttonStyle(PlainButtonStyle())

                        if let action = detail.suggestedActionText {
                            NavigationLink(destination: MetricActionView(detail: detail, action: action, actionModel: typedAction(for: detail, actionText: action))) {
                                SuggestedActionSummaryCard(detail: detail, action: action)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            if model.metricDetails.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No synced metrics yet")
                        .wpHeadline()
                    Text("Connect the watch and run a sync to populate metric explanations.")
                        .wpCaption()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
        }
    }

    private func typedAction(for detail: MetricDetailData, actionText: String) -> CoachSuggestedAction {
        model.coachAnalysis.suggestedActions.first {
            $0.metricIds.contains(detail.id) || $0.title == actionText
        } ?? CoachSuggestedAction.legacy(actionText, metricId: detail.id, rationale: detail.actionReasonText)
    }
}

private struct SuggestedActionSummaryCard: View {
    let detail: MetricDetailData
    let action: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CircleIcon(systemName: "target", color: detail.color)
                .scaleEffect(0.82)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SUGGESTED ACTION")
                        .wpLabel()
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.wpTextSecondary)
                }
                Text(action)
                    .wpCaption()
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.wpSurface)
        .cornerRadius(22)
        .shadow(color: Color.wpShadowDark, radius: 12, x: 7, y: 7)
        .shadow(color: Color.white.opacity(0.95), radius: 10, x: -7, y: -7)
    }
}

private struct DashboardMetricsSection: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        SectionPanel(title: "LATEST METRICS") {
            DashboardMetricList(model: model)
        }
    }
}

private struct MetricsGrid: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        VStack(spacing: 12) {
            DashboardMetricsSection(model: model)
        }
    }
}

private struct MetricActionView: View {
    let detail: MetricDetailData
    let action: String
    let actionModel: CoachSuggestedAction?
    @Environment(\.presentationMode) private var presentationMode
    @State private var accepted = false
    @State private var proposedSlots: [CoachSuggestedTimeSlot] = []
    @State private var slotStatus = "Finding times from your calendar..."
    @State private var reminderStatus = ""
    @State private var scheduledEvents: [CoachScheduledCalendarEvent] = []
    @State private var showCalendarConfirmation = false
    @State private var confirmationTitle = ""
    @State private var confirmationMessage = ""

    private var effectiveAction: CoachSuggestedAction {
        actionModel ?? CoachSuggestedAction.legacy(action, metricId: detail.id, rationale: detail.actionReasonText)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 16) {
                    CircleIcon(systemName: "target", color: detail.color)
                        .scaleEffect(1.2)
                    Text("Suggested Action")
                        .wpLabel()
                    Text(action)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.wpPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(detail.color.opacity(0.8))
                            .frame(width: 8, height: 8)
                        Text("Related Metric: \(detail.title)")
                            .wpLabel()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.wpSurfaceLow)
                    .cornerRadius(18)
                }
                .frame(maxWidth: .infinity)
                .card()

                SectionPanel(title: "WHY THIS ACTION") {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.wpPrimary)
                            .padding(.top, 2)
                        Text(detail.actionReasonText)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.wpText)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.wpSurface)
                    .cornerRadius(24)
                    .shadow(color: Color.wpShadowDark, radius: 18, x: 10, y: 10)
                    .shadow(color: Color.white.opacity(0.95), radius: 14, x: -10, y: -10)

                    if !historyEvidence.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RECENT SAVED DATA")
                                .wpLabel()
                            Text(historyEvidence)
                                .wpCaption()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .card()
                    }
                }

                SectionPanel(title: "LATEST DATA") {
                    if detail.rows.count >= 2 {
                        HStack(spacing: 16) {
                            ForEach(Array(detail.rows.prefix(2))) { row in
                                ActionDataMiniCard(row: row, color: detail.color)
                            }
                        }
                    } else {
                        MetricRowsCard(rows: detail.rows)
                    }
                }

                if let reference = VitalReference.reference(for: detail.id) {
                    SectionPanel(title: "REFERENCE RANGE") {
                        ReferenceRangeCard(reference: reference, color: detail.color)
                    }
                }

                if effectiveAction.calendarSuitable {
                    SectionPanel(title: "SUGGESTED TIMES") {
                        VStack(alignment: .leading, spacing: 12) {
                            if !scheduledEvents.isEmpty {
                                ForEach(scheduledEvents) { event in
                                    ScheduledEventRow(event: event, color: detail.color) {
                                        deleteCalendarEvent(event)
                                    }
                                }
                            }
                            if proposedSlots.isEmpty {
                                Text(slotStatus)
                                    .wpCaption()
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                ForEach(proposedSlots) { slot in
                                    Button(action: { addToCalendar(slot) }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "calendar.badge.plus")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(detail.color)
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(slot.timeLabel)
                                                    .wpHeadline()
                                                Text(slot.durationLabel)
                                                    .wpCaption()
                                                Text(slot.reason)
                                                    .wpCaption()
                                                    .lineLimit(4)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            Spacer()
                                        }
                                        .padding(14)
                                        .background(Color.wpSurface)
                                        .cornerRadius(16)
                                        .shadow(color: Color.wpShadowDark, radius: 10, x: 6, y: 6)
                                        .shadow(color: Color.white.opacity(0.95), radius: 8, x: -6, y: -6)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                if !slotStatus.isEmpty {
                                    Text(slotStatus)
                                        .wpCaption()
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .onAppear {
                            refreshScheduledEvents()
                            loadSuggestedTimes()
                        }
                    }
                }

                if !effectiveAction.alternatives.isEmpty || effectiveAction.futureGifPrompt != nil {
                    SectionPanel(title: "MORE OPTIONS") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(effectiveAction.alternatives, id: \.self) { alternative in
                                Label(alternative, systemImage: "arrow.triangle.branch")
                                    .wpCaption()
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let prompt = effectiveAction.futureGifPrompt, !prompt.isEmpty {
                                Label("Workout demo prompt ready for future GIF generation.", systemImage: "figure.strengthtraining.traditional")
                                    .wpCaption()
                                Text(prompt)
                                    .font(.system(size: 12))
                                    .foregroundColor(.wpTextSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .card()
                    }
                }

                VStack(spacing: 12) {
                    Button(action: { accepted = true }) {
                        HStack(spacing: 8) {
                            Text(accepted ? "Recommendation Accepted" : "Accept Recommendation")
                            Image(systemName: accepted ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(Color.wpPrimaryContainer)
                        .cornerRadius(14)
                        .shadow(color: Color.wpPrimary.opacity(0.30), radius: 10, x: 4, y: 6)
                        .shadow(color: Color.white.opacity(0.70), radius: 8, x: -4, y: -4)
                    }

                    if effectiveAction.reminderSuitable {
                        Button(action: scheduleReminder) {
                            HStack(spacing: 8) {
                                Text(reminderStatus.isEmpty ? "Schedule Reminders" : reminderStatus)
                                Image(systemName: "bell.badge")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.wpPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.wpSurface)
                            .cornerRadius(14)
                            .shadow(color: Color.wpShadowDark, radius: 10, x: 4, y: 6)
                            .shadow(color: Color.white.opacity(0.70), radius: 8, x: -4, y: -4)
                        }
                    }

                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Text("Dismiss")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.wpTextSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                    }
                }
                .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Color.wpBackground.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("AI Coach", displayMode: .inline)
        .alert(isPresented: $showCalendarConfirmation) {
            Alert(
                title: Text(confirmationTitle),
                message: Text(confirmationMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func loadSuggestedTimes() {
        guard proposedSlots.isEmpty else { return }
        CoachCalendarService.shared.suggestedSlotsWithDiagnostics(for: effectiveAction) { slots, diagnostic in
            proposedSlots = slots
            slotStatus = slots.isEmpty ? "\(diagnostic) Connect or select calendars in Profile to get specific times." : diagnostic
        }
    }

    private func addToCalendar(_ slot: CoachSuggestedTimeSlot) {
        CoachCalendarService.shared.add(action: effectiveAction, at: slot) { success, message, _ in
            accepted = success
            slotStatus = message
            refreshScheduledEvents()
            confirmationTitle = success ? "Added to Calendar" : "Calendar Update Failed"
            confirmationMessage = success ? "\(effectiveAction.title)\n\(slot.timeLabel)" : message
            showCalendarConfirmation = true
        }
    }

    private func deleteCalendarEvent(_ event: CoachScheduledCalendarEvent) {
        CoachCalendarService.shared.delete(event: event) { success, message in
            refreshScheduledEvents()
            slotStatus = message
            confirmationTitle = success ? "Calendar Event Deleted" : "Delete Failed"
            confirmationMessage = message
            showCalendarConfirmation = true
        }
    }

    private func refreshScheduledEvents() {
        scheduledEvents = CoachCalendarService.shared.scheduledEvents(for: effectiveAction.id)
    }

    private func scheduleReminder() {
        CoachReminderScheduler.shared.scheduleActionReminders(for: effectiveAction) { success, message in
            reminderStatus = success ? message : message
        }
    }

    private var historyEvidence: String {
        let sections = detail.history.prefix(3)
        guard !sections.isEmpty else { return "" }
        return sections.map { section in
            let values = section.rows.prefix(3).map { "\($0.label): \($0.value)" }.joined(separator: ", ")
            return "\(section.title) - \(values)"
        }
        .joined(separator: "\n")
    }
}

private struct ScheduledEventRow: View {
    let event: CoachScheduledCalendarEvent
    let color: Color
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 4) {
                Text("Scheduled")
                    .wpHeadline()
                Text(timeLabel)
                    .wpCaption()
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(action: deleteAction) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.wpRed)
                    .frame(width: 38, height: 38)
            }
            .background(Color.wpSurfaceLow)
            .cornerRadius(19)
        }
        .padding(14)
        .background(Color.wpSurface)
        .cornerRadius(16)
        .shadow(color: Color.wpShadowDark, radius: 10, x: 6, y: 6)
        .shadow(color: Color.white.opacity(0.95), radius: 8, x: -6, y: -6)
    }

    private var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d h:mm a"
        return "\(formatter.string(from: event.start)) - \(event.provider == .google ? "Google" : "iOS Calendar")"
    }
}

private struct ActionDataMiniCard: View {
    let row: MetricDetailRow
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.wpTextSecondary)
                Spacer()
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
            }
            Text(row.value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.wpText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(row.label.uppercased())
                .wpLabel()
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.wpSurface)
        .cornerRadius(22)
        .shadow(color: Color.wpShadowDark, radius: 14, x: 8, y: 8)
        .shadow(color: Color.white.opacity(0.95), radius: 12, x: -8, y: -8)
    }
}

private struct ReferenceRangeCard: View {
    let reference: VitalReference
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(reference.shortRange)
                    .wpLabel()
                Spacer()
            }
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.wpSurfaceLow)
                    .frame(height: 14)
                    .neoInset(radius: 7)
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.wpGreen.opacity(0.20))
                        .frame(width: proxy.size.width * 0.58, height: 14)
                        .offset(x: proxy.size.width * 0.21)
                    Circle()
                        .fill(color)
                        .frame(width: 18, height: 18)
                        .shadow(color: color.opacity(0.35), radius: 5, x: 0, y: 2)
                        .offset(x: proxy.size.width * 0.36, y: -2)
                }
                .frame(height: 14)
            }
            HStack(spacing: 4) {
                Text("Reference")
                    .wpCaption()
                Text(reference.source)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.wpGreen)
            }
            Text(reference.detail)
                .wpCaption()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(Color.wpSurface)
        .cornerRadius(24)
        .shadow(color: Color.wpShadowDark, radius: 18, x: 10, y: 10)
        .shadow(color: Color.white.opacity(0.95), radius: 14, x: -10, y: -10)
    }
}

private struct DetailMetricCard: View {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let value: String
    let detail: String
    let detailData: MetricDetailData?

    var body: some View {
        NavigationLink(destination: MetricDetailView(detail: resolvedDetail)) {
            MetricCardContent(detail: resolvedDetail)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var resolvedDetail: MetricDetailData {
        detailData ?? MetricDetailData(
            id: id,
            title: title,
            icon: icon,
            colorName: "primary",
            value: value,
            detail: detail,
            rows: [MetricDetailRow("Status", "No saved detail yet")],
            history: [],
            aiExplanation: MetricAIExplanation.fallback(metricId: id, value: value, title: title)
        )
    }
}

private struct MetricCardContent: View {
    let detail: MetricDetailData

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            CircleIcon(systemName: detail.icon, color: detail.color)
            VStack(alignment: .leading, spacing: 5) {
                Text(detail.title)
                    .wpHeadline()
                Text(detail.aiExplanation?.shortExplanation ?? detail.detail)
                    .wpCaption()
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 5) {
                Text(detail.value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(detail.color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.65)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.wpTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct WatchStatusCard: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        HStack(spacing: 14) {
            CircleIcon(systemName: "applewatch", color: .wpPrimary)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.deviceName)
                    .wpHeadline()
                Text("Last synced: \(model.lastSync)")
                    .wpCaption()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                StatusPill(text: model.isConnected ? "Connected" : "Searching", color: model.isConnected ? .wpGreen : .wpOrange)
                Text(model.autoSyncEnabled ? "Auto-sync: On" : "Auto-sync: Off")
                    .wpLabel()
            }
        }
        .card()
    }
}

private struct WellnessScoreCard: View {
    let score: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 10) {
                Text("WELLNESS SCORE")
                    .wpLabel()
                    .foregroundColor(Color.white.opacity(0.78))
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(score)")
                        .font(.system(size: 44, weight: .bold))
                    Text("/100")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.72))
                }
                Text("Based on the latest watch sync and live readings")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.78))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "heart.fill")
                .font(.system(size: 84, weight: .regular))
                .foregroundColor(Color.white.opacity(0.12))
                .offset(x: 12, y: -14)
        }
        .padding(22)
        .background(Color.wpPrimaryContainer)
        .cornerRadius(24)
        .shadow(color: Color.wpPrimary.opacity(0.28), radius: 14, x: 6, y: 8)
        .shadow(color: Color.white.opacity(0.62), radius: 10, x: -5, y: -5)
    }
}

private struct MetricDetailView: View {
    let detail: MetricDetailData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(spacing: 16) {
                    CircleIcon(systemName: detail.icon, color: detail.color)
                        .scaleEffect(1.25)
                    Text(detail.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.wpTextSecondary)
                    Text(detail.value)
                        .font(.system(size: 52, weight: .bold))
                        .foregroundColor(.wpText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                    Text(detail.detail)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.wpTextSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(Color.wpSurfaceHigh)
                        .cornerRadius(16)
                }
                .frame(maxWidth: .infinity)
                .card()

                SectionPanel(title: "LATEST DATA") {
                    MetricRowsCard(rows: detail.rows)
                }

                SectionPanel(title: "WHAT IT MEANS") {
                    MetricCoachExplanationCard(detail: detail)
                }

                if let reference = VitalReference.reference(for: detail.id) {
                    SectionPanel(title: "REFERENCE RANGE") {
                        ReferenceRangeCard(reference: reference, color: detail.color)
                    }
                }

                if !detail.history.isEmpty {
                    SectionPanel(title: "PREVIOUS DATA") {
                        MetricHistorySummaryCard(detail: detail)
                    }

                    SectionPanel(title: "HISTORY BROWSER") {
                        MetricHistoryBrowser(sections: detail.history)
                    }
                }
            }
            .padding(20)
        }
        .background(Color.wpBackground.edgesIgnoringSafeArea(.all))
        .navigationBarTitle("AI Coach", displayMode: .inline)
    }
}

private struct MetricCoachExplanationCard: View {
    let detail: MetricDetailData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                StatusPill(text: "Confidence: \(detail.aiExplanation?.confidence ?? "low")", color: .wpGreen)
                StatusPill(text: "Data: \(detail.aiExplanation?.dataQuality ?? "missing")", color: .wpBlue)
            }

            Text(detail.aiExplanation?.shortExplanation ?? detail.detail)
                .wpHeadline()
                .fixedSize(horizontal: false, vertical: true)

            Text(longExplanation)
                .wpCaption()
                .fixedSize(horizontal: false, vertical: true)

            if !historyEvidence.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Previous data backing this up")
                        .wpLabel()
                    Text(historyEvidence)
                        .wpCaption()
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .card()
    }

    private var longExplanation: String {
        let details = detail.aiExplanation?.details ?? "More synced history will make this explanation more useful."
        let cleaned = details.removingSuggestedActionLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return "More synced history will make this explanation more useful."
        }
        return cleaned
    }

    private var historyEvidence: String {
        let sections = detail.history.prefix(3)
        guard !sections.isEmpty else { return "" }
        return sections.map { section in
            let values = section.rows.prefix(3).map { "\($0.label): \($0.value)" }.joined(separator: ", ")
            return "\(section.title) - \(values)"
        }
        .joined(separator: "\n")
    }
}

private struct MetricHistorySummaryCard: View {
    let detail: MetricDetailData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                HistoryStat(title: "Days / groups", value: "\(detail.history.count)")
                HistoryStat(title: "Saved rows", value: "\(detail.history.reduce(0) { $0 + $1.rows.count })")
            }

            if let latest = detail.history.first {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Latest saved group")
                        .wpLabel()
                    Text(latest.title)
                        .wpHeadline()
                    MetricRowsCard(rows: Array(latest.rows.prefix(5)))
                }
            }
        }
        .card()
    }
}

private struct HistoryStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .wpLabel()
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.wpText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.wpSurface)
        .cornerRadius(10)
    }
}

private struct MetricHistoryBrowser: View {
    let sections: [MetricHistorySection]
    @State private var expandedSectionIds: Set<String> = []

    var body: some View {
        VStack(spacing: 10) {
            ForEach(sections) { section in
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedSectionIds.contains(section.id) },
                        set: { isExpanded in
                            if isExpanded {
                                expandedSectionIds.insert(section.id)
                            } else {
                                expandedSectionIds.remove(section.id)
                            }
                        }
                    )
                ) {
                    MetricRowsCard(rows: section.rows)
                        .padding(.top, 8)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(section.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.wpText)
                            Text("\(section.rows.count) saved value(s)")
                                .wpCaption()
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .accentColor(.wpPrimary)
                .padding(12)
                .background(Color.wpSurface)
                .cornerRadius(10)
            }
        }
    }
}

private extension MetricDetailData {
    var suggestedActionText: String? {
        let direct = aiExplanation?.suggestedAction?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct, !direct.isEmpty {
            return direct
        }

        let parsed = aiExplanation?.details.parsedSuggestedAction?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parsed, !parsed.isEmpty {
            return parsed
        }
        if id == "activity", value != "--" {
            return "Increase active movement by 15 minutes this afternoon."
        }
        return nil
    }

    var actionReasonText: String {
        if id == "activity", aiExplanation?.suggestedAction == nil, aiExplanation?.details.parsedSuggestedAction == nil {
            return "Your latest activity data is available from the watch. A short extra walk is a low-risk way to raise movement without turning it into a hard workout. Compare this with sleep and recovery before pushing intensity."
        }

        let summary = aiExplanation?.shortExplanation ?? detail
        let details = aiExplanation?.details.removingSuggestedActionLine.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if details.isEmpty || details == summary {
            return summary
        }
        return "\(summary)\n\n\(details)"
    }
}

private extension String {
    var parsedSuggestedAction: String? {
        let markers = ["Suggested action:", "suggested_action:"]
        for marker in markers {
            guard let range = range(of: marker, options: [.caseInsensitive]) else { continue }
            return String(self[range.upperBound...])
                .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                .first
                .map(String.init)
        }
        return nil
    }

    var removingSuggestedActionLine: String {
        split(separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                !line.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .hasPrefix("suggested action:")
            }
            .joined(separator: "\n")
    }
}

private struct MetricRowsCard: View {
    let rows: [MetricDetailRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: 12) {
                    Text(row.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.wpTextSecondary)
                    Spacer(minLength: 12)
                    Text(row.value)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.wpText)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, 10)
                if row.id != rows.last?.id {
                    Divider()
                }
            }
        }
        .card()
    }
}

private struct ProfileHeader: View {
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.wpSecondary.opacity(0.22), Color.wpPrimary.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "person.fill")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(.wpPrimary)
            }
            .frame(width: 96, height: 96)
            .background(Color.wpSurface)
            .clipShape(Circle())
            .shadow(color: Color.wpShadowDark, radius: 16, x: 8, y: 8)
            .shadow(color: Color.white.opacity(0.95), radius: 12, x: -8, y: -8)

            VStack(alignment: .center, spacing: 4) {
                Text("Vivek")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.wpText)
                Text("Profile & Settings")
                    .wpCaption()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }
}

private struct ConnectedDeviceSection: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        SectionPanel(title: "CONNECTED DEVICE") {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    CircleIcon(systemName: "applewatch", color: .wpPrimary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.deviceName)
                            .wpHeadline()
                        Text("Synced: \(model.lastSync)")
                            .wpCaption()
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "battery.100")
                            .font(.system(size: 13, weight: .semibold))
                        Text(model.battery)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.wpGreen)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.wpSurfaceLow)
                    .cornerRadius(16)
                    .neoInset(radius: 16)
                }
                Divider()
                HStack {
                    Text("MAC ADDRESS")
                        .wpLabel()
                    Spacer(minLength: 12)
                    Text(model.deviceAddress)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .foregroundColor(.wpText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                }
                .padding(12)
                .background(Color.wpSurfaceLow)
                .cornerRadius(14)
                .neoInset(radius: 14)

                HStack(spacing: 10) {
                    ActionButton(title: model.isSyncing ? "Syncing" : "Sync Now", color: .wpPrimary, filled: true, disabled: !model.canSync || model.isSyncing, action: model.syncAction)
                    ActionButton(title: "Connect", color: .wpPrimary, filled: false, disabled: model.isConnected, action: model.connectAction)
                }
                ActionButton(title: "Disconnect Watch", color: .wpRed, filled: false, disabled: !model.canDisconnect, action: model.disconnectAction)
            }
            .card()
        }
    }
}

private struct SettingsSection: View {
    @ObservedObject var model: WatchProbeViewModel
    @ObservedObject private var calendarService = CoachCalendarService.shared
    @State private var calendarMessage = ""

    var body: some View {
        SectionPanel(title: "APP SETTINGS") {
            VStack(spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto-sync when app opens")
                            .wpHeadline()
                        Text("Runs a quick sync after the saved watch connects.")
                            .wpCaption()
                    }
                    Spacer()
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { model.autoSyncEnabled },
                            set: { model.autoSyncAction?($0) }
                        )
                    )
                    .labelsHidden()
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        CircleIcon(systemName: "sparkles", color: .wpPrimary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Show onboarding")
                                .wpHeadline()
                            Text("Replay the first-run setup without deleting app data.")
                                .wpCaption()
                        }
                    }
                    ActionButton(title: "Show Onboarding", color: .wpPrimary, filled: false, disabled: false) {
                        model.showOnboarding()
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        CircleIcon(systemName: "calendar", color: .wpPrimary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Calendar-aware coaching")
                                .wpHeadline()
                            Text(calendarMessage.isEmpty ? calendarService.status : calendarMessage)
                                .wpCaption()
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Picker(
                        "Privacy",
                        selection: Binding(
                            get: { calendarService.privacyMode },
                            set: { calendarService.privacyMode = $0 }
                        )
                    ) {
                        ForEach(CoachCalendarPrivacyMode.allCases, id: \.self) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    HStack(spacing: 10) {
                        ActionButton(title: "iOS Calendar", color: .wpPrimary, filled: false, disabled: false) {
                            calendarService.requestEventKitAccess { _, message in
                                calendarMessage = message
                                model.calendarContextChangedAction?()
                            }
                        }
                        ActionButton(title: "Google", color: .wpPrimary, filled: true, disabled: false) {
                            calendarService.connectGoogleCalendar { _, message in
                                calendarMessage = message
                                model.calendarContextChangedAction?()
                            }
                        }
                    }

                    if !calendarService.calendars.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SELECTED CALENDARS")
                                .wpLabel()
                            ForEach(calendarService.calendars) { calendar in
                                CalendarSelectionRow(calendar: calendar, service: calendarService)
                            }
                        }
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Local AI proxy")
                        .wpHeadline()
                    Text("For testing without Firebase, run the Mac proxy and enter its URL.")
                        .wpCaption()
                    TextField("http://your-mac-ip:8790", text: $model.localAIProxyURL)
                        .font(.system(size: 14, weight: .regular, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                        .padding(13)
                        .background(Color.wpSurfaceLow)
                        .cornerRadius(14)
                        .neoInset(radius: 14)
                }
                .card()
            }
        }
    }
}

private struct CalendarSelectionRow: View {
    let calendar: CoachCalendarInfo
    @ObservedObject var service: CoachCalendarService

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button(action: { service.toggleCalendar(calendar) }) {
                    Image(systemName: service.selectedCalendarStorageIds.contains(calendar.storageId) ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.wpPrimary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.wpText)
                    Text(calendar.provider == .google ? "Google Calendar" : "iOS Calendar")
                        .wpCaption()
                }
                Spacer()
                if calendar.canWrite {
                    Button(action: { service.chooseWriteCalendar(calendar) }) {
                        Image(systemName: service.writeCalendarStorageId == calendar.storageId ? "square.and.pencil.circle.fill" : "square.and.pencil")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundColor(.wpOrange)
                    }
                }
            }
            Divider()
        }
    }
}

private struct DataSection: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        SectionPanel(title: "DATA MANAGEMENT") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Local data storage")
                            .wpHeadline()
                        Text(model.localStorage)
                            .wpCaption()
                    }
                    Spacer()
                }
                Divider()
                ActionButton(title: "Export Latest JSON", color: .wpPrimary, filled: false, disabled: !model.canExport, action: model.exportAction)
            }
            .card()
        }
    }
}

private struct DebugSection: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        SectionPanel(title: "DEBUG") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Show Debug Log")
                        .wpHeadline()
                    Spacer()
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { model.showDebugLog },
                            set: { model.showDebugLog = $0 }
                        )
                    )
                    .labelsHidden()
                }
                if model.showDebugLog {
                    Text(model.debugLog.isEmpty ? "No debug messages yet." : model.debugLog)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(.wpTextSecondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.wpSurfaceLow)
                        .cornerRadius(14)
                        .neoInset(radius: 14)
                }
            }
            .card()
        }
    }
}

private struct SectionPanel<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .wpLabel()
                .padding(.leading, 4)
            content
        }
    }
}

private struct ActionButton: View {
    let title: String
    let color: Color
    let filled: Bool
    let disabled: Bool
    let action: (() -> Void)?

    var body: some View {
        Button(action: { action?() }) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(filled ? .white : color)
                .background(filled ? color : Color.wpSurface)
                .cornerRadius(22)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(filled ? Color.clear : Color.white.opacity(0.72), lineWidth: 1)
                )
                .shadow(color: filled ? color.opacity(0.25) : Color.wpShadowDark, radius: filled ? 12 : 8, x: filled ? 0 : 5, y: filled ? 6 : 5)
                .shadow(color: filled ? Color.clear : Color.white.opacity(0.9), radius: 8, x: -5, y: -5)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }
}

private struct CircleIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.wpSurface)
                .shadow(color: Color.wpShadowDark, radius: 8, x: 5, y: 5)
                .shadow(color: Color.white.opacity(0.95), radius: 8, x: -5, y: -5)
            Circle()
                .fill(Color.wpSurfaceLow)
                .frame(width: 30, height: 30)
                .shadow(color: Color.wpShadowDark, radius: 4, x: 2, y: 2)
                .shadow(color: Color.white.opacity(0.9), radius: 4, x: -2, y: -2)
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
        }
        .frame(width: 46, height: 46)
    }
}

private struct StatusPill: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.wpSurfaceLow)
        .cornerRadius(16)
        .neoInset(radius: 16)
    }
}

private extension View {
    func card() -> some View {
        self
            .padding(16)
            .background(Color.wpSurface)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.62), lineWidth: 1)
            )
            .shadow(color: Color.wpShadowDark, radius: 18, x: 10, y: 10)
            .shadow(color: Color.white.opacity(0.95), radius: 14, x: -10, y: -10)
    }

    func neoInset(radius: CGFloat) -> some View {
        self
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.white.opacity(0.45), lineWidth: 1)
                    .shadow(color: Color.wpShadowDark, radius: 5, x: 3, y: 3)
                    .clipShape(RoundedRectangle(cornerRadius: radius))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.white.opacity(0.88), lineWidth: 1)
                    .shadow(color: Color.white.opacity(0.95), radius: 5, x: -3, y: -3)
                    .clipShape(RoundedRectangle(cornerRadius: radius))
            )
    }

    func wpHeadline() -> some View {
        self
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.wpText)
    }

    func wpCaption() -> some View {
        self
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(.wpTextSecondary)
    }

    func wpLabel() -> some View {
        self
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.wpTextSecondary)
    }
}

private extension Color {
    static let wpPrimary = Color(red: 0.0, green: 0.345, blue: 0.737)
    static let wpPrimaryContainer = Color(red: 0.0, green: 0.439, blue: 0.922)
    static let wpSecondary = Color(red: 0.0, green: 0.4, blue: 0.529)
    static let wpBackground = Color(red: 0.941, green: 0.957, blue: 0.973)
    static let wpSurface = Color.white
    static let wpSurfaceLow = Color(red: 0.941, green: 0.957, blue: 0.973)
    static let wpSurfaceHigh = Color(red: 0.882, green: 0.898, blue: 0.922)
    static let wpText = Color(red: 0.102, green: 0.110, blue: 0.122)
    static let wpTextSecondary = Color(red: 0.255, green: 0.278, blue: 0.333)
    static let wpOutline = Color(red: 0.757, green: 0.776, blue: 0.843)
    static let wpRed = Color(red: 0.73, green: 0.10, blue: 0.10)
    static let wpBlue = Color(red: 0.196, green: 0.678, blue: 0.902)
    static let wpGreen = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let wpOrange = Color(red: 1.0, green: 0.584, blue: 0.0)
    static let wpShadowDark = Color(red: 0.82, green: 0.85, blue: 0.90)
}
