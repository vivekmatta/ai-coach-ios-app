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
}

struct WatchProbeDashboardView: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        TabView {
            InsightsView(model: model)
                .tabItem {
                    Image(systemName: "chart.bar.xaxis")
                    Text("Insights")
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

private struct InsightsView: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    WatchStatusCard(model: model)
                    WellnessScoreCard(score: model.wellnessScore)
                    MetricsGrid(model: model)
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
                VStack(alignment: .leading, spacing: 16) {
                    ProfileHeader()
                    ConnectedDeviceSection(model: model)
                    SettingsSection(model: model)
                    DataSection(model: model)
                    DebugSection(model: model)
                }
                .padding(16)
            }
            .background(Color.wpBackground.edgesIgnoringSafeArea(.all))
            .navigationBarTitle("Profile", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

private struct WatchStatusCard: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        HStack(spacing: 12) {
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
                Text(model.autoSyncEnabled ? "Auto-sync on" : "Auto-sync off")
                    .wpCaption()
            }
        }
        .card()
    }
}

private struct WellnessScoreCard: View {
    let score: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
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
        .padding(20)
        .background(Color.wpPrimary)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

private struct MetricsGrid: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        VStack(spacing: 12) {
            DetailMetricCard(
                id: "sleep",
                title: "Sleep",
                icon: "bed.double.fill",
                color: .wpSecondary,
                value: model.sleepScore,
                detail: "\(model.sleepDuration) slept / \(model.sleepScoreDetail)",
                detailData: model.metricDetails["sleep"]
            )
            HStack(spacing: 12) {
                DetailMetricCard(id: "heartRate", title: "Heart Rate", icon: "heart.fill", color: .wpRed, value: model.heartRate, detail: "Latest saved or live", detailData: model.metricDetails["heartRate"])
                DetailMetricCard(id: "oxygen", title: "Blood Oxygen", icon: "drop.fill", color: .wpBlue, value: model.oxygen, detail: "SpO2", detailData: model.metricDetails["oxygen"])
            }
            HStack(spacing: 12) {
                DetailMetricCard(id: "hrv", title: "HRV", icon: "waveform.path", color: .wpPrimary, value: model.hrv, detail: "Heart rate variability", detailData: model.metricDetails["hrv"])
                DetailMetricCard(id: "bloodPressure", title: "Blood Pressure", icon: "gauge.with.dots.needle.33percent", color: .wpRed, value: model.bloodPressure, detail: "Systolic / diastolic", detailData: model.metricDetails["bloodPressure"])
            }
            DetailMetricCard(
                id: "activity",
                title: "Activity",
                icon: "figure.walk",
                color: .wpOrange,
                value: model.steps,
                detail: "\(model.distance) km / \(model.calories) kcal",
                detailData: model.metricDetails["activity"]
            )
            HStack(spacing: 12) {
                DetailMetricCard(id: "temperature", title: "Temperature", icon: "thermometer", color: .wpRed, value: model.temperature, detail: "Body / skin", detailData: model.metricDetails["temperature"])
                DetailMetricCard(id: "bloodGlucose", title: "Glucose", icon: "testtube.2", color: .wpGreen, value: model.bloodGlucose, detail: "Latest stored value", detailData: model.metricDetails["bloodGlucose"])
            }
            HStack(spacing: 12) {
                DetailMetricCard(id: "ecg", title: "ECG", icon: "waveform.path.ecg", color: .wpPrimary, value: model.ecg, detail: "Offline ECG", detailData: model.metricDetails["ecg"])
                DetailMetricCard(id: "battery", title: "Battery", icon: "battery.100", color: .wpGreen, value: model.battery, detail: "Watch", detailData: model.metricDetails["battery"])
            }
            DetailMetricCard(id: "updated", title: "Updated", icon: "clock", color: .wpSecondary, value: model.updatedAt, detail: model.connectionState, detailData: model.metricDetails["updated"])
        }
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
            MetricCardContent(title: title, icon: icon, color: color, value: value, detail: detail)
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
            history: []
        )
    }
}

private struct MetricCardContent: View {
    let title: String
    let icon: String
    let color: Color
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title.uppercased())
                    .wpLabel()
                    .foregroundColor(.wpTextSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.wpTextSecondary)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.wpText)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
            Text(detail)
                .wpCaption()
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct MetricDetailView: View {
    let detail: MetricDetailData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    CircleIcon(systemName: detail.icon, color: detail.color)
                    Text(detail.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.wpText)
                    Text(detail.value)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(detail.color)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                    Text(detail.detail)
                        .wpCaption()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                SectionPanel(title: "LATEST DATA") {
                    MetricRowsCard(rows: detail.rows)
                }

                if !detail.history.isEmpty {
                    SectionPanel(title: "HISTORY") {
                        VStack(spacing: 12) {
                            ForEach(detail.history) { section in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(section.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.wpText)
                                    MetricRowsCard(rows: section.rows)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color.wpBackground.edgesIgnoringSafeArea(.all))
        .navigationBarTitle(Text(detail.title), displayMode: .inline)
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
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.wpSurfaceHigh)
                Image(systemName: "person.fill")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundColor(.wpTextSecondary)
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text("Vivek")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.wpText)
                Text("Profile & Settings")
                    .wpCaption()
            }
        }
    }
}

private struct ConnectedDeviceSection: View {
    @ObservedObject var model: WatchProbeViewModel

    var body: some View {
        SectionPanel(title: "CONNECTED DEVICE") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(model.deviceName)
                        .wpHeadline()
                    Spacer()
                    Image(systemName: "applewatch")
                        .foregroundColor(.wpTextSecondary)
                }
                Divider()
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MAC ADDRESS")
                            .wpLabel()
                        Text(model.deviceAddress)
                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                            .foregroundColor(.wpText)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BATTERY")
                            .wpLabel()
                        Text(model.battery)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.wpText)
                    }
                }
                Text("Synced: \(model.lastSync)")
                    .wpCaption()
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

    var body: some View {
        SectionPanel(title: "APP SETTINGS") {
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
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.wpSurfaceHigh)
                        .cornerRadius(8)
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
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .wpLabel()
            content
        }
        .padding(12)
        .background(Color.wpSurfaceHigh)
        .cornerRadius(14)
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
                .padding(.vertical, 11)
                .foregroundColor(filled ? .white : color)
                .background(filled ? color : Color.wpSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(filled ? Color.clear : color.opacity(0.65), lineWidth: 1)
                )
                .cornerRadius(10)
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
                .fill(Color.wpSurfaceHigh)
            Image(systemName: systemName)
                .foregroundColor(color)
        }
        .frame(width: 40, height: 40)
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
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.wpTextSecondary)
        }
    }
}

private extension View {
    func card() -> some View {
        self
            .padding(12)
            .background(Color.wpSurfaceLow)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.wpOutline.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
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
    static let wpPrimary = Color(red: 0.0, green: 0.35, blue: 0.74)
    static let wpSecondary = Color(red: 0.30, green: 0.29, blue: 0.79)
    static let wpBackground = Color(red: 0.976, green: 0.976, blue: 0.996)
    static let wpSurface = Color.white
    static let wpSurfaceLow = Color(red: 0.953, green: 0.953, blue: 0.973)
    static let wpSurfaceHigh = Color(red: 0.91, green: 0.91, blue: 0.93)
    static let wpText = Color(red: 0.102, green: 0.110, blue: 0.122)
    static let wpTextSecondary = Color(red: 0.255, green: 0.278, blue: 0.333)
    static let wpOutline = Color(red: 0.757, green: 0.776, blue: 0.843)
    static let wpRed = Color(red: 0.73, green: 0.10, blue: 0.10)
    static let wpBlue = Color(red: 0.196, green: 0.678, blue: 0.902)
    static let wpGreen = Color(red: 0.204, green: 0.780, blue: 0.349)
    static let wpOrange = Color(red: 1.0, green: 0.584, blue: 0.0)
}
