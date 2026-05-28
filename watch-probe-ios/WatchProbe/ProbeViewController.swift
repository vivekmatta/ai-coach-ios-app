import UIKit
import SwiftUI
import UserNotifications
import CryptoKit

final class ProbeViewController: UIViewController {
    private enum ActiveFunction: String {
        case heartRate = "Heart Rate"
        case bloodOxygen = "Blood Oxygen"
        case oxygenAndHeart = "Oxygen + Heart"
        case ecg = "ECG"
        case temperature = "Temperature"
        case healthGlance = "Health Glance"
        case microTest = "Micro Test"
    }

    private enum MainTab: Int {
        case insights = 0
        case profile = 1
    }

    private let manager = VPBleCentralManage.sharedBleManager()
    private let viewModel = WatchProbeViewModel()
    private var dashboardController: UIHostingController<WatchProbeDashboardView>?
    private var devices: [VPPeripheralModel] = []
    private var isScanning = false
    private var isConnecting = false
    private var isVerified = false
    private var isReadingBattery = false
    private var isDebugLogVisible = false
    private var isAutoCollectionEnabled = true
    private var isManuallyDisconnected = false
    private var isCollectionSyncing = false
    private var stepTimer: Timer?
    private var collectionTimer: Timer?
    private var connectionTimeoutWorkItem: DispatchWorkItem?
    private var connectionVerificationRetryCount = 0
    private var nextCollectionDate: Date?
    private var activeFunction: ActiveFunction?
    private var shouldAutoConnectToPreferredDevice = false
    private var currentTab: MainTab = .insights
    private var latestSafeSyncDays: [[String: Any]] = []
    private var latestSafeSyncMetadata: [String: Any] = [:]

    private let preferredDeviceAddressKey = "WatchProbe.preferredDeviceAddress"
    private let preferredDeviceNameKey = "WatchProbe.preferredDeviceName"
    private let syncReadTimeout: TimeInterval = 15
    private let syncSleepReadTimeout: TimeInterval = 60
    private let syncBaseDailyTimeout: TimeInterval = 120
    private let syncLongReadTimeout: TimeInterval = 30
    private let syncTotalTimeout: TimeInterval = 180
    private let connectionVerificationTimeout: TimeInterval = 25
    private let maxConnectionVerificationRetries = 1
    private let syncMaxPackageCount = 96
    private let syncRRProbeMaxBlocks = 20

    private let statusLabel = UILabel()
    private let debugLogButton = UIButton(type: .system)
    private let scanButton = UIButton(type: .system)
    private let disconnectButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let deviceListLabel = UILabel()
    private let tabControl = UISegmentedControl(items: ["Insights", "Profile"])
    private let resultsPanel = UIStackView()
    private let watchStatusNameLabel = UILabel()
    private let watchStatusSyncLabel = UILabel()
    private let watchStatusAutoLabel = UILabel()
    private let profileNameLabel = UILabel()
    private let profileAddressLabel = UILabel()
    private let profileBatteryLabel = UILabel()
    private let deviceTileValueLabel = UILabel()
    private let batteryTileValueLabel = UILabel()
    private let heartTileValueLabel = UILabel()
    private let oxygenTileValueLabel = UILabel()
    private let ecgTileValueLabel = UILabel()
    private let updatedTileValueLabel = UILabel()
    private let stepsTileValueLabel = UILabel()
    private let temperatureTileValueLabel = UILabel()
    private let heartSparklineView = SparklineView()
    private let oxygenSparklineView = SparklineView()
    private let ecgProgressView = UIProgressView(progressViewStyle: .default)
    private let collectionPanel = UIStackView()
    private let collectionStatusLabel = UILabel()
    private let lastSyncLabel = UILabel()
    private let nextSyncLabel = UILabel()
    private let localStorageLabel = UILabel()
    private let autoCollectionButton = UIButton(type: .system)
    private let syncNowButton = UIButton(type: .system)
    private let exportLatestSyncButton = UIButton(type: .system)
    private let profileDisconnectButton = UIButton(type: .system)
    private let functionPanel = UIStackView()
    private let readCapabilitiesButton = UIButton(type: .system)
    private let readBatteryButton = UIButton(type: .system)
    private let heartRateButton = UIButton(type: .system)
    private let bloodOxygenButton = UIButton(type: .system)
    private let oxygenAndHeartButton = UIButton(type: .system)
    private let ecgButton = UIButton(type: .system)
    private let stepPollingButton = UIButton(type: .system)
    private let temperatureButton = UIButton(type: .system)
    private let healthGlanceButton = UIButton(type: .system)
    private let microTestButton = UIButton(type: .system)
    private let stopActiveTestButton = UIButton(type: .system)
    private lazy var functionButtons: [UIButton] = [
        readCapabilitiesButton,
        readBatteryButton,
        heartRateButton,
        bloodOxygenButton,
        oxygenAndHeartButton,
        ecgButton,
        stepPollingButton,
        temperatureButton,
        healthGlanceButton,
        microTestButton,
        stopActiveTestButton
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Watch Probe"
        view.backgroundColor = .systemBackground
        configureUI()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        appendStatus("Ready. Start scan when the watch is nearby.")
        updateNotificationPermissionStatus()
        loadLatestSavedSnapshotIntoDashboard(logFailures: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.startPreferredWatchScan(reason: "app_launch")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopActiveFunction(log: false)
        stopStepPolling(log: false)
        stopCollectionTimer()
        cancelConnectionTimeout()
        manager?.veepooSDKStopScanDevice()
    }

    private func configureUI() {
        statusLabel.numberOfLines = 0
        tableView.dataSource = self
        tableView.delegate = self

        configureDashboardActions()

        let dashboard = WatchProbeDashboardView(model: viewModel)
        let hostingController = UIHostingController(rootView: dashboard)
        hostingController.view.backgroundColor = .clear
        dashboardController = hostingController

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)

        resetResultTiles()
        updateCollectionLabels()
        updateFunctionButtons()
    }

    private func configureDashboardActions() {
        viewModel.connectAction = { [weak self] in
            self?.isManuallyDisconnected = false
            self?.startPreferredWatchScan(reason: "manual_connect")
        }
        viewModel.disconnectAction = { [weak self] in
            self?.disconnect()
        }
        viewModel.syncAction = { [weak self] in
            self?.runCollectionSync(reason: "manual")
        }
        viewModel.exportAction = { [weak self] in
            self?.exportLatestSync()
        }
        viewModel.autoSyncAction = { [weak self] enabled in
            self?.setAutoCollectionEnabled(enabled)
        }
        viewModel.heartRateAction = { [weak self] in
            self?.toggleHeartRate()
        }
        viewModel.oxygenAction = { [weak self] in
            self?.toggleBloodOxygen()
        }
        viewModel.stepAction = { [weak self] in
            self?.toggleStepPolling()
        }
        viewModel.temperatureAction = { [weak self] in
            self?.toggleTemperature()
        }
        viewModel.notificationPermissionAction = { [weak self] in
            CoachReminderScheduler.shared.requestAuthorizationAndSchedule { granted in
                self?.viewModel.notificationPermissionStatus = granted ? "Daily reminder set for 8:00 AM" : "Notifications not allowed"
                self?.appendStatus(granted ? "Morning sync reminder scheduled." : "Notification permission was not granted.")
            }
        }
        viewModel.calendarContextChangedAction = { [weak self] in
            self?.rerunCoachAnalysisForLatestSync(reason: "calendar_context_changed")
        }
        CoachCalendarService.shared.calendarContextChanged = { [weak self] in
            self?.rerunCoachAnalysisForLatestSync(reason: "calendar_context_changed")
        }
        viewModel.completeOnboardingAction = { [weak self] in
            CoachReminderScheduler.shared.scheduleMorningSyncReminder()
            guard let self, !self.isVerified else { return }
            self.startPreferredWatchScan(reason: "onboarding_complete")
        }
        viewModel.watchSelectAction = { [weak self] candidate in
            guard let self else { return }
            if let model = self.devices.first(where: { ($0.deviceAddress ?? $0.deviceName ?? "") == candidate.id }) {
                self.connect(to: model)
            }
        }
    }

    private func updateNotificationPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self?.viewModel.notificationPermissionStatus = "Daily reminder set for 8:00 AM"
                    CoachReminderScheduler.shared.scheduleMorningSyncReminder()
                case .denied:
                    self?.viewModel.notificationPermissionStatus = "Notifications not allowed"
                case .notDetermined:
                    self?.viewModel.notificationPermissionStatus = "Not requested"
                @unknown default:
                    self?.viewModel.notificationPermissionStatus = "Unknown"
                }
            }
        }
    }

    private func configureCollectionPanel() {
        collectionPanel.axis = .vertical
        collectionPanel.spacing = 12

        [collectionStatusLabel, lastSyncLabel, nextSyncLabel, localStorageLabel].forEach { label in
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
        }

        syncNowButton.setTitle("Sync Now", for: .normal)
        syncNowButton.addTarget(self, action: #selector(syncNowTapped), for: .touchUpInside)

        exportLatestSyncButton.setTitle("Export Latest JSON", for: .normal)
        exportLatestSyncButton.addTarget(self, action: #selector(exportLatestSync), for: .touchUpInside)

        profileDisconnectButton.setTitle("Disconnect Watch", for: .normal)
        profileDisconnectButton.addTarget(self, action: #selector(disconnect), for: .touchUpInside)

        autoCollectionButton.addTarget(self, action: #selector(toggleAutoCollection), for: .touchUpInside)

        [syncNowButton, autoCollectionButton, exportLatestSyncButton, profileDisconnectButton].forEach(styleButton)

        let profileHeader = UIStackView(arrangedSubviews: [
            makeAvatarView(),
            makeProfileHeaderText()
        ])
        profileHeader.axis = .horizontal
        profileHeader.alignment = .center
        profileHeader.spacing = 16

        let deviceCard = makeProfileDeviceCard()
        let syncCard = makeProfileSettingsCard(
            title: "Auto-sync when app opens",
            detail: "The app syncs automatically unless the watch is manually disconnected.",
            trailing: autoCollectionButton
        )
        let storageCard = makeProfileDataCard()

        collectionPanel.addArrangedSubview(profileHeader)
        collectionPanel.addArrangedSubview(deviceCard)
        collectionPanel.addArrangedSubview(makeButtonRow([syncNowButton, exportLatestSyncButton]))
        collectionPanel.addArrangedSubview(profileDisconnectButton)
        collectionPanel.addArrangedSubview(syncCard)
        collectionPanel.addArrangedSubview(storageCard)
    }

    private func makeAvatarView() -> UIView {
        let label = UILabel()
        label.text = "V"
        label.font = .systemFont(ofSize: 26, weight: .bold)
        label.textColor = .secondaryLabel
        label.textAlignment = .center

        let container = UIView()
        container.backgroundColor = .systemGray5
        container.layer.cornerRadius = 32
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 64),
            container.heightAnchor.constraint(equalToConstant: 64),
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }

    private func makeProfileHeaderText() -> UIView {
        let name = UILabel()
        name.text = "Vivek"
        name.font = .preferredFont(forTextStyle: .title2)
        name.textColor = .label

        let subtitle = UILabel()
        subtitle.text = "Profile & Settings"
        subtitle.font = .preferredFont(forTextStyle: .subheadline)
        subtitle.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [name, subtitle])
        stack.axis = .vertical
        stack.spacing = 3
        return stack
    }

    private func makeProfileDeviceCard() -> UIView {
        profileNameLabel.font = .preferredFont(forTextStyle: .headline)
        profileNameLabel.textColor = .label
        profileNameLabel.text = "ES02"

        profileAddressLabel.font = .preferredFont(forTextStyle: .subheadline)
        profileAddressLabel.textColor = .secondaryLabel
        profileAddressLabel.numberOfLines = 0
        profileAddressLabel.text = "Address: --"

        profileBatteryLabel.font = .preferredFont(forTextStyle: .subheadline)
        profileBatteryLabel.textColor = .secondaryLabel
        profileBatteryLabel.text = "Battery: --"

        let status = UILabel()
        status.text = "Connected"
        status.font = .preferredFont(forTextStyle: .caption1)
        status.textColor = .systemGreen

        let header = UIStackView(arrangedSubviews: [profileNameLabel, status])
        header.axis = .horizontal
        header.alignment = .center
        header.distribution = .equalSpacing

        let content = UIStackView(arrangedSubviews: [header, profileAddressLabel, profileBatteryLabel, collectionStatusLabel, lastSyncLabel, nextSyncLabel])
        content.axis = .vertical
        content.spacing = 8
        return makeCard(content)
    }

    private func makeProfileSettingsCard(title: String, detail: String, trailing: UIView) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = .preferredFont(forTextStyle: .caption1)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let row = UIStackView(arrangedSubviews: [textStack, trailing])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        return makeCard(row)
    }

    private func makeProfileDataCard() -> UIView {
        let title = UILabel()
        title.text = "Local data storage"
        title.font = .preferredFont(forTextStyle: .body)
        title.textColor = .label

        localStorageLabel.font = .preferredFont(forTextStyle: .caption1)
        localStorageLabel.textColor = .secondaryLabel
        localStorageLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [title, localStorageLabel])
        stack.axis = .vertical
        stack.spacing = 6
        return makeCard(stack)
    }

    private func configureResultsPanel() {
        resultsPanel.axis = .vertical
        resultsPanel.spacing = 12

        heartSparklineView.lineColor = .systemRed
        oxygenSparklineView.lineColor = .systemBlue
        ecgProgressView.progress = 0

        let titleLabel = UILabel()
        titleLabel.text = "Insights"
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        titleLabel.textColor = .label

        resultsPanel.addArrangedSubview(titleLabel)
        resultsPanel.addArrangedSubview(makeWatchStatusCard())
        resultsPanel.addArrangedSubview(makeWellnessScoreCard())
        resultsPanel.addArrangedSubview(makeTileRow([
            makeMetricCard(title: "Sleep Score", systemImage: "moon.fill", tintColor: .systemIndigo, value: "Waiting for sleep data", detail: "Sync cache snapshot"),
            makeResultTile(title: "Heart Rate", valueLabel: heartTileValueLabel, systemImage: "heart.fill", tintColor: .systemRed)
        ]))
        resultsPanel.addArrangedSubview(makeTileRow([
            makeResultTile(title: "Blood Oxygen", valueLabel: oxygenTileValueLabel, systemImage: "drop.fill", tintColor: .systemBlue),
            makeResultTile(title: "Activity", valueLabel: stepsTileValueLabel, systemImage: "figure.run", tintColor: .systemOrange)
        ]))
        resultsPanel.addArrangedSubview(makeTileRow([
            makeResultTile(title: "ECG", valueLabel: ecgTileValueLabel, systemImage: "waveform.path.ecg", tintColor: .systemTeal),
            makeResultTile(title: "Temperature", valueLabel: temperatureTileValueLabel, systemImage: "thermometer", tintColor: .systemRed)
        ]))
        resultsPanel.addArrangedSubview(makeTileRow([
            makeResultTile(title: "Battery", valueLabel: batteryTileValueLabel, systemImage: "battery.100", tintColor: .systemGreen),
            makeResultTile(title: "Updated", valueLabel: updatedTileValueLabel, systemImage: "checkmark.circle.fill", tintColor: .systemGreen)
        ]))
        resultsPanel.addArrangedSubview(makeTrendPanel())
    }

    private func makeWatchStatusCard() -> UIView {
        watchStatusNameLabel.text = "ES02"
        watchStatusNameLabel.font = .preferredFont(forTextStyle: .headline)
        watchStatusNameLabel.textColor = .label

        watchStatusSyncLabel.text = "Last synced: not yet"
        watchStatusSyncLabel.font = .preferredFont(forTextStyle: .caption1)
        watchStatusSyncLabel.textColor = .secondaryLabel

        watchStatusAutoLabel.text = "Auto-sync on"
        watchStatusAutoLabel.font = .preferredFont(forTextStyle: .caption1)
        watchStatusAutoLabel.textColor = .secondaryLabel

        let icon = makeSymbolView(systemName: "applewatch", tintColor: .systemBlue)
        let textStack = UIStackView(arrangedSubviews: [watchStatusNameLabel, watchStatusSyncLabel])
        textStack.axis = .vertical
        textStack.spacing = 3

        let left = UIStackView(arrangedSubviews: [icon, textStack])
        left.axis = .horizontal
        left.alignment = .center
        left.spacing = 12

        let dot = UIView()
        dot.backgroundColor = .systemGreen
        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8)
        ])

        let status = UIStackView(arrangedSubviews: [dot, watchStatusAutoLabel])
        status.axis = .horizontal
        status.alignment = .center
        status.spacing = 6

        let row = UIStackView(arrangedSubviews: [left, status])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        return makeCard(row)
    }

    private func makeWellnessScoreCard() -> UIView {
        let caption = UILabel()
        caption.text = "WELLNESS SCORE"
        caption.font = .preferredFont(forTextStyle: .caption1)
        caption.textColor = .white.withAlphaComponent(0.85)

        let score = UILabel()
        score.text = "82/100"
        score.font = .systemFont(ofSize: 34, weight: .bold)
        score.textColor = .white

        let detail = UILabel()
        detail.text = "Based on sleep, heart rate, oxygen, temperature, and activity"
        detail.font = .preferredFont(forTextStyle: .caption1)
        detail.textColor = .white.withAlphaComponent(0.85)
        detail.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [caption, score, detail])
        stack.axis = .vertical
        stack.spacing = 6
        stack.layoutMargins = UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.backgroundColor = .systemBlue
        stack.layer.cornerRadius = 14
        stack.clipsToBounds = true
        return stack
    }

    private func makeTrendPanel() -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = "Trends"
        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.textColor = .secondaryLabel

        let heartTitle = UILabel()
        heartTitle.text = "Heart Rate"
        heartTitle.font = .preferredFont(forTextStyle: .caption2)
        heartTitle.textColor = .secondaryLabel

        let oxygenTitle = UILabel()
        oxygenTitle.text = "Blood Oxygen"
        oxygenTitle.font = .preferredFont(forTextStyle: .caption2)
        oxygenTitle.textColor = .secondaryLabel

        let ecgTitle = UILabel()
        ecgTitle.text = "ECG Progress"
        ecgTitle.font = .preferredFont(forTextStyle: .caption2)
        ecgTitle.textColor = .secondaryLabel

        [heartSparklineView, oxygenSparklineView].forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false
            view.heightAnchor.constraint(equalToConstant: 46).isActive = true
        }

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            heartTitle,
            heartSparklineView,
            oxygenTitle,
            oxygenSparklineView,
            ecgTitle,
            ecgProgressView
        ])
        stack.axis = .vertical
        stack.spacing = 6
        stack.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 12, right: 12)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.backgroundColor = .secondarySystemBackground
        stack.layer.cornerRadius = 8
        stack.clipsToBounds = true
        return stack
    }

    private func makeTileRow(_ tiles: [UIView]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: tiles)
        row.axis = .horizontal
        row.spacing = 10
        row.distribution = .fillEqually
        return row
    }

    private func makeMetricCard(
        title: String,
        systemImage: String,
        tintColor: UIColor,
        value: String,
        detail: String
    ) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.textColor = .secondaryLabel

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .preferredFont(forTextStyle: .headline)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 0

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = .preferredFont(forTextStyle: .caption1)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0

        let header = UIStackView(arrangedSubviews: [makeSymbolView(systemName: systemImage, tintColor: tintColor), titleLabel])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 7

        let stack = UIStackView(arrangedSubviews: [header, valueLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 7
        return makeCard(stack)
    }

    private func makeResultTile(
        title: String,
        valueLabel: UILabel,
        systemImage: String,
        tintColor: UIColor
    ) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.textColor = .secondaryLabel

        valueLabel.text = "--"
        valueLabel.font = .preferredFont(forTextStyle: .title3)
        valueLabel.textColor = .label
        valueLabel.numberOfLines = 2
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75

        let header = UIStackView(arrangedSubviews: [makeSymbolView(systemName: systemImage, tintColor: tintColor), titleLabel])
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 7

        let stack = UIStackView(arrangedSubviews: [header, valueLabel])
        stack.axis = .vertical
        stack.spacing = 7
        return makeCard(stack)
    }

    private func makeSymbolView(systemName: String, tintColor: UIColor) -> UIView {
        let imageView = UIImageView(image: UIImage(systemName: systemName))
        imageView.tintColor = tintColor
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let container = UIView()
        container.backgroundColor = tintColor.withAlphaComponent(0.12)
        container.layer.cornerRadius = 15
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(imageView)
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 30),
            container.heightAnchor.constraint(equalToConstant: 30),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 17),
            imageView.heightAnchor.constraint(equalToConstant: 17)
        ])
        return container
    }

    private func makeCard(_ content: UIView) -> UIView {
        let stack = UIStackView(arrangedSubviews: [content])
        stack.axis = .vertical
        stack.spacing = 0
        stack.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.backgroundColor = .secondarySystemBackground
        stack.layer.cornerRadius = 12
        stack.layer.borderWidth = 1
        stack.layer.borderColor = UIColor.separator.withAlphaComponent(0.25).cgColor
        stack.clipsToBounds = true
        return stack
    }

    private func configureFunctionPanel() {
        functionPanel.axis = .vertical
        functionPanel.spacing = 10

        let titleLabel = UILabel()
        titleLabel.text = "Functions"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label

        readCapabilitiesButton.setTitle("Read Capabilities", for: .normal)
        readCapabilitiesButton.addTarget(self, action: #selector(readCapabilities), for: .touchUpInside)

        readBatteryButton.setTitle("Read Battery", for: .normal)
        readBatteryButton.addTarget(self, action: #selector(readBatteryTapped), for: .touchUpInside)

        heartRateButton.setTitle("Start Heart Rate", for: .normal)
        heartRateButton.addTarget(self, action: #selector(toggleHeartRate), for: .touchUpInside)

        bloodOxygenButton.setTitle("Start Blood Oxygen", for: .normal)
        bloodOxygenButton.addTarget(self, action: #selector(toggleBloodOxygen), for: .touchUpInside)

        oxygenAndHeartButton.setTitle("Start O2 + Heart", for: .normal)
        oxygenAndHeartButton.addTarget(self, action: #selector(toggleOxygenAndHeart), for: .touchUpInside)

        ecgButton.setTitle("Start ECG", for: .normal)
        ecgButton.addTarget(self, action: #selector(toggleECG), for: .touchUpInside)

        stepPollingButton.setTitle("Start Step Polling", for: .normal)
        stepPollingButton.addTarget(self, action: #selector(toggleStepPolling), for: .touchUpInside)

        temperatureButton.setTitle("Start Temperature", for: .normal)
        temperatureButton.addTarget(self, action: #selector(toggleTemperature), for: .touchUpInside)

        healthGlanceButton.setTitle("Health Glance", for: .normal)
        healthGlanceButton.addTarget(self, action: #selector(toggleHealthGlance), for: .touchUpInside)

        microTestButton.setTitle("Micro Test", for: .normal)
        microTestButton.addTarget(self, action: #selector(toggleMicroTest), for: .touchUpInside)

        stopActiveTestButton.setTitle("Stop Active Test", for: .normal)
        stopActiveTestButton.addTarget(self, action: #selector(stopActiveTapped), for: .touchUpInside)

        functionButtons.forEach(styleButton)

        functionPanel.addArrangedSubview(titleLabel)
        functionPanel.addArrangedSubview(makeButtonRow([readCapabilitiesButton, readBatteryButton]))
        functionPanel.addArrangedSubview(makeButtonRow([heartRateButton, bloodOxygenButton]))
        functionPanel.addArrangedSubview(makeButtonRow([oxygenAndHeartButton, ecgButton]))
        functionPanel.addArrangedSubview(makeButtonRow([stepPollingButton, temperatureButton]))
        functionPanel.addArrangedSubview(makeButtonRow([healthGlanceButton, microTestButton]))
        functionPanel.addArrangedSubview(stopActiveTestButton)
    }

    private func makeButtonRow(_ buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.spacing = 10
        row.distribution = .fillEqually
        return row
    }

    private func styleButton(_ button: UIButton) {
        button.titleLabel?.font = .preferredFont(forTextStyle: .callout)
        button.backgroundColor = .secondarySystemBackground
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
    }

    @objc private func startScan() {
        beginScan(autoConnectPreferred: false, reason: "manual")
    }

    @objc private func tabChanged() {
        currentTab = MainTab(rawValue: tabControl.selectedSegmentIndex) ?? .insights
        applyCurrentTabVisibility()
    }

    private func startPreferredWatchScan(reason: String) {
        guard isAutoCollectionEnabled, !isManuallyDisconnected, !isVerified, !isConnecting else { return }
        beginScan(autoConnectPreferred: true, reason: reason)
    }

    private func beginScan(autoConnectPreferred: Bool, reason: String) {
        guard !isVerified else { return }
        guard !isConnecting else {
            appendStatus("Already connecting. Disconnect before scanning again.")
            return
        }
        if isScanning {
            shouldAutoConnectToPreferredDevice = shouldAutoConnectToPreferredDevice || autoConnectPreferred
            appendStatus(autoConnectPreferred ? "Already scanning for saved watch..." : "Already scanning...")
            return
        }

        isManuallyDisconnected = false
        if reason != "verification_retry" {
            connectionVerificationRetryCount = 0
        }
        isScanning = true
        shouldAutoConnectToPreferredDevice = autoConnectPreferred
        stopStepPolling(log: false)
        stopCollectionTimer()
        cancelConnectionTimeout()
        manager?.veepooSDKStopScanDevice()
        devices.removeAll()
        viewModel.discoveredWatches = []
        isVerified = false
        isReadingBattery = false
        activeFunction = nil
        setResultsPanelVisible(false)
        setFunctionButtonsVisible(false)
        setCollectionPanelVisible(false)
        resetResultTiles()
        updateCollectionLabels()
        updateFunctionButtons()
        tableView.reloadData()
        viewModel.isConnected = false
        viewModel.canDisconnect = false
        deviceListLabel.isHidden = false
        tableView.isHidden = false
        tabControl.isHidden = true
        appendStatus(autoConnectPreferred ? "Scanning for saved watch..." : "Scanning...")

        manager?.automaticConnection = false
        manager?.veepooSDKDisconnectDevice()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            self?.startSDKScanIfNeeded()
        }
    }

    private func startSDKScanIfNeeded() {
        guard isScanning, !isConnecting, !isVerified else { return }
        manager?.manufacturerIDFilter = false
        manager?.automaticConnection = false
        manager?.deviceShowConfirm = !hasPreferredDevice()
        manager?.peripheralManage = VPPeripheralManage.shareVPPeripheralManager()
        manager?.veepooSDKStartScanDeviceAndReceiveScanningDevice { [weak self] model in
            guard let self, let model else { return }
            DispatchQueue.main.async {
                guard self.isScanning, !self.isConnecting, !self.isVerified else { return }
                self.addOrUpdate(model)
            }
        }
    }

    private func hasPreferredDevice() -> Bool {
        let defaults = UserDefaults.standard
        let savedAddress = defaults.string(forKey: preferredDeviceAddressKey) ?? ""
        let savedName = defaults.string(forKey: preferredDeviceNameKey) ?? ""
        return !savedAddress.isEmpty || !savedName.isEmpty
    }

    @objc private func disconnect() {
        isManuallyDisconnected = true
        shouldAutoConnectToPreferredDevice = false
        stopActiveFunction(log: false)
        stopStepPolling(log: false)
        stopCollectionTimer()
        manager?.veepooSDKStopScanDevice()
        manager?.veepooSDKDisconnectDevice()
        viewModel.discoveredWatches = []
        cancelConnectionTimeout()
        isScanning = false
        isConnecting = false
        isVerified = false
        isReadingBattery = false
        tableView.allowsSelection = true
        scanButton.isEnabled = true
        deviceListLabel.isHidden = false
        tableView.isHidden = false
        tabControl.isHidden = true
        setResultsPanelVisible(false)
        setFunctionButtonsVisible(false)
        setCollectionPanelVisible(false)
        resetResultTiles()
        updateCollectionLabels()
        updateFunctionButtons()
        viewModel.connectionState = "Disconnected"
        appendStatus("Disconnected and stopped scanning.")
    }

    private func addOrUpdate(_ model: VPPeripheralModel) {
        if let index = devices.firstIndex(where: { $0.deviceAddress == model.deviceAddress }) {
            devices[index] = model
        } else {
            devices.append(model)
        }

        devices.sort {
            let lhs = $0.rssi?.intValue ?? Int.min
            let rhs = $1.rssi?.intValue ?? Int.min
            return lhs > rhs
        }
        let candidates = devices.map {
            WatchDeviceCandidate(
                id: $0.deviceAddress ?? $0.deviceName ?? UUID().uuidString,
                name: displayName(for: $0),
                address: $0.deviceAddress ?? "--",
                rssi: $0.rssi?.intValue ?? 0
            )
        }

        DispatchQueue.main.async {
            self.viewModel.discoveredWatches = candidates
            self.tableView.reloadData()
            self.appendStatus("Found \(self.devices.count) device(s). Tap the watch to connect.")
            if self.shouldAutoConnectToPreferredDevice,
               self.matchesPreferredDevice(model) || self.canAutoConnectFirstDiscoveredDevice(model) {
                self.shouldAutoConnectToPreferredDevice = false
                self.appendStatus("Found watch. Connecting automatically.")
                self.connect(to: model)
            }
        }
    }

    private func connect(to model: VPPeripheralModel) {
        guard !isConnecting && !isVerified else {
            appendStatus("Connection already in progress or verified. Disconnect before retrying.")
            return
        }

        isScanning = false
        isConnecting = true
        tableView.allowsSelection = false
        scanButton.isEnabled = false
        manager?.automaticConnection = false
        manager?.veepooSDKStopScanDevice()
        appendStatus("Connecting to \(displayName(for: model))...")
        scheduleConnectionTimeout()

        manager?.veepooSDKConnectDevice(model) { [weak self] state in
            DispatchQueue.main.async {
                self?.handleConnectState(state)
            }
        }
    }

    private func scheduleConnectionTimeout() {
        cancelConnectionTimeout()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.isConnecting, !self.isVerified else { return }
            self.manager?.veepooSDKStopScanDevice()
            self.manager?.veepooSDKDisconnectDevice()
            self.isScanning = false
            self.isConnecting = false
            self.shouldAutoConnectToPreferredDevice = false
            self.viewModel.isConnected = false
            self.viewModel.canDisconnect = false
            self.viewModel.connectionState = "Connection timed out"
            self.tableView.allowsSelection = true
            self.scanButton.isEnabled = true
            if self.connectionVerificationRetryCount < self.maxConnectionVerificationRetries,
               self.isAutoCollectionEnabled,
               !self.isManuallyDisconnected {
                self.connectionVerificationRetryCount += 1
                self.appendStatus("Password verification timed out. Retrying connection...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.startPreferredWatchScan(reason: "verification_retry")
                }
            } else {
                self.appendStatus("Password verification timed out. Tap Connect to retry.")
            }
        }
        connectionTimeoutWorkItem = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + connectionVerificationTimeout, execute: timeout)
    }

    private func cancelConnectionTimeout() {
        connectionTimeoutWorkItem?.cancel()
        connectionTimeoutWorkItem = nil
    }

    private func persistPreferredDevice(_ model: VPPeripheralModel) {
        let defaults = UserDefaults.standard
        if let address = model.deviceAddress, !address.isEmpty {
            defaults.set(address, forKey: preferredDeviceAddressKey)
        }
        if let name = model.deviceName, !name.isEmpty {
            defaults.set(name, forKey: preferredDeviceNameKey)
        }
    }

    private func matchesPreferredDevice(_ model: VPPeripheralModel) -> Bool {
        let defaults = UserDefaults.standard
        if let savedAddress = defaults.string(forKey: preferredDeviceAddressKey),
           !savedAddress.isEmpty,
           model.deviceAddress == savedAddress {
            return true
        }

        if let savedName = defaults.string(forKey: preferredDeviceNameKey),
           !savedName.isEmpty,
           model.deviceName == savedName {
            return true
        }

        return false
    }

    private func canAutoConnectFirstDiscoveredDevice(_ model: VPPeripheralModel) -> Bool {
        let defaults = UserDefaults.standard
        let hasPreferredDevice = defaults.string(forKey: preferredDeviceAddressKey) != nil
            || defaults.string(forKey: preferredDeviceNameKey) != nil
        let deviceName = model.deviceName ?? ""
        return !hasPreferredDevice && devices.count == 1 && deviceName == "ES02"
    }

    private func handleConnectState(_ state: DeviceConnectState) {
        appendStatus("BLE connection state: \(connectionStateDescription(state))")
        switch state {
        case .BlePoweredOff:
            cancelConnectionTimeout()
            isScanning = false
            isConnecting = false
            viewModel.isConnected = false
            viewModel.canDisconnect = false
            appendStatus("Bluetooth is powered off.")
        case .BleConnecting:
            viewModel.connectionState = "Connecting..."
            appendStatus("Connecting...")
        case .BleConnectSuccess:
            viewModel.connectionState = "Connected. Verifying..."
            appendStatus("Connected. Waiting for SDK password verification...")
        case .BleConnectFailed:
            cancelConnectionTimeout()
            isScanning = false
            isConnecting = false
            viewModel.isConnected = false
            viewModel.canDisconnect = false
            tableView.allowsSelection = true
            scanButton.isEnabled = true
            appendStatus("Connection failed.")
        case .BleVerifyPasswordSuccess:
            cancelConnectionTimeout()
            isScanning = false
            isConnecting = false
            isVerified = true
            connectionVerificationRetryCount = 0
            shouldAutoConnectToPreferredDevice = false
            viewModel.isConnected = true
            viewModel.canDisconnect = true
            tableView.allowsSelection = false
            deviceListLabel.isHidden = true
            tableView.isHidden = true
            if let model = manager?.peripheralManage.peripheralModel {
                persistPreferredDevice(model)
            }
            updateDeviceTile()
            currentTab = .insights
            tabControl.selectedSegmentIndex = MainTab.insights.rawValue
            tabControl.isHidden = false
            applyCurrentTabVisibility()
            markUpdated()
            updateFunctionButtons()
            appendStatus("Password verified. Reading battery...")
            readBattery()
            startCollectionTimer(runImmediately: true, reason: "connect")
        case .BleVerifyPasswordFailure:
            cancelConnectionTimeout()
            isScanning = false
            isConnecting = false
            viewModel.isConnected = false
            viewModel.canDisconnect = false
            tableView.allowsSelection = true
            scanButton.isEnabled = true
            appendStatus("Password verification failed.")
        case .BleConnectTimeout:
            cancelConnectionTimeout()
            isScanning = false
            isConnecting = false
            viewModel.isConnected = false
            viewModel.canDisconnect = false
            tableView.allowsSelection = true
            scanButton.isEnabled = true
            appendStatus("Connection timed out.")
        case .BleConfirmTimeout:
            cancelConnectionTimeout()
            isScanning = false
            isConnecting = false
            viewModel.isConnected = false
            viewModel.canDisconnect = false
            tableView.allowsSelection = true
            scanButton.isEnabled = true
            appendStatus("Device confirmation timed out. Disconnect before retrying.")
        @unknown default:
            appendStatus("Unknown connection state: \(state.rawValue)")
        }
    }

    private func connectionStateDescription(_ state: DeviceConnectState) -> String {
        switch state {
        case .BlePoweredOff:
            return "powered off"
        case .BleConnecting:
            return "connecting"
        case .BleConnectSuccess:
            return "connected, verifying password"
        case .BleConnectFailed:
            return "connect failed"
        case .BleVerifyPasswordSuccess:
            return "password verified"
        case .BleVerifyPasswordFailure:
            return "password failed"
        case .BleConnectTimeout:
            return "connect timeout"
        case .BleConfirmTimeout:
            return "confirm timeout"
        @unknown default:
            return "unknown \(state.rawValue)"
        }
    }

    private func readBattery() {
        guard !isReadingBattery else { return }
        guard isVerified else {
            appendStatus("Connect to a watch before reading battery.")
            return
        }
        isReadingBattery = true

        manager?.peripheralManage.veepooSDKReadDeviceBatteryAndChargeInfo { [weak self] isPercent, chargeState, isLowBattery, battery in
            DispatchQueue.main.async {
                let unit = isPercent ? "%" : " bars"
                let low = isLowBattery ? " low-battery" : ""
                self?.batteryTileValueLabel.text = "\(battery)\(unit)\ncharge \(chargeState.rawValue)"
                self?.profileBatteryLabel.text = "Battery: \(battery)\(unit)"
                self?.viewModel.battery = "\(battery)\(unit)"
                self?.markUpdated()
                self?.appendStatus("Battery: \(battery)\(unit), chargeState=\(chargeState.rawValue)\(low)")
                self?.isReadingBattery = false
            }
        }
    }

    @objc private func readBatteryTapped() {
        readBattery()
    }

    @objc private func toggleDebugLog() {
        isDebugLogVisible.toggle()
        debugLogButton.setTitle(isDebugLogVisible ? "Hide Debug Log" : "Show Debug Log", for: .normal)
        applyCurrentTabVisibility()
    }

    @objc private func syncNowTapped() {
        runCollectionSync(reason: "manual")
    }

    @objc private func exportLatestSync() {
        guard let latestFileURL = WatchResearchStore.shared.latestSyncFileURL() else {
            appendStatus("No local research JSON file to export yet.")
            return
        }

        let activityController = UIActivityViewController(
            activityItems: [latestFileURL],
            applicationActivities: nil
        )
        activityController.popoverPresentationController?.sourceView = view
        present(activityController, animated: true)
    }

    @objc private func toggleAutoCollection() {
        setAutoCollectionEnabled(!isAutoCollectionEnabled)
    }

    private func setAutoCollectionEnabled(_ enabled: Bool) {
        guard isAutoCollectionEnabled != enabled else {
            updateCollectionLabels()
            return
        }

        isAutoCollectionEnabled = enabled
        if isAutoCollectionEnabled, isVerified, !isManuallyDisconnected {
            startCollectionTimer(runImmediately: false, reason: "auto_enabled")
        } else {
            stopCollectionTimer()
        }
        updateCollectionLabels()
        appendStatus("10-minute auto collection \(isAutoCollectionEnabled ? "enabled" : "disabled").")
    }

    @objc private func appWillEnterForeground() {
        loadLatestSavedSnapshotIntoDashboard(logFailures: false)
        guard isAutoCollectionEnabled, !isManuallyDisconnected else { return }
        if isVerified {
            startCollectionTimer(runImmediately: true, reason: "app_open")
        } else {
            startPreferredWatchScan(reason: "app_open")
        }
    }

    private func startCollectionTimer(runImmediately: Bool, reason: String) {
        guard isAutoCollectionEnabled, !isManuallyDisconnected else {
            updateCollectionLabels()
            return
        }

        stopCollectionTimer()
        nextCollectionDate = Date().addingTimeInterval(600)
        collectionTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            self?.nextCollectionDate = Date().addingTimeInterval(600)
            self?.runCollectionSync(reason: "scheduled_10_min")
            self?.updateCollectionLabels()
        }
        updateCollectionLabels()

        if runImmediately {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.runCollectionSync(reason: reason)
            }
        }
    }

    private func stopCollectionTimer() {
        collectionTimer?.invalidate()
        collectionTimer = nil
        nextCollectionDate = nil
        updateCollectionLabels()
    }

    private func runCollectionSync(reason: String) {
        guard isVerified, manager?.peripheralManage.peripheralModel != nil else {
            appendStatus("Collection sync skipped: watch is not connected.")
            return
        }

        guard isAutoCollectionEnabled, !isManuallyDisconnected else {
            appendStatus("Collection sync skipped: auto-sync is disabled.")
            return
        }

        if let activeFunction {
            saveSkippedSync(reason: reason, activeTest: activeFunction.rawValue)
            return
        }

        if isCollectionSyncing {
            appendStatus("Collection sync already running.")
            return
        }

        if isReadingBattery {
            appendStatus("Collection sync delayed because battery read is active.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                self?.runCollectionSync(reason: reason)
            }
            return
        }

        stopStepPolling(log: false)
        isCollectionSyncing = true
        viewModel.isSyncing = true
        viewModel.isAIAnalyzing = true
        viewModel.aiStatus = "Syncing watch data"
        collectionStatusLabel.text = "Saving local research snapshot..."
        syncNowButton.isEnabled = false
        appendStatus("Starting research sync: \(reason)")

        syncDailyDataSequence { [weak self] success in
            guard let self else { return }
            self.extractAndStoreResearchSnapshot(reason: reason, dailySyncSucceeded: success) { fileURL in
                self.isCollectionSyncing = false
                self.viewModel.isSyncing = false
                if fileURL == nil {
                    self.viewModel.isAIAnalyzing = false
                }
                self.syncNowButton.isEnabled = true
                self.markUpdated()
                self.updateCollectionLabels()

                if let fileURL {
                    self.appendStatus("Research sync saved: \(fileURL.path)")
                } else {
                    self.appendStatus("Research sync finished, but local save failed.")
                }
            }
        }
    }

    private func syncDailyDataSequence(completion: @escaping (Bool) -> Void) {
        collectionStatusLabel.text = "Reading watch database..."
        latestSafeSyncDays = []
        latestSafeSyncMetadata = [
            "mode": "sdk_database_first_then_safe_direct_reads",
            "baseDailyReadAttempted": true,
            "baseDailyReadReason": "Vendor demo reads sleep through SDK database sync; direct reads are fallback only.",
            "baseDailyReadSucceeded": false,
            "hrvDirectReadSkipped": true,
            "hrvDirectReadSkippedReason": "The SDK marks direct HRV day reads unavailable and the bulk HRV parser has crashed on this watch.",
            "startedAt": ISO8601DateFormatter().string(from: Date()),
            "timedOutReads": [],
            "failedReads": [],
            "readDurations": []
        ]
        appendStatus("Running SDK base daily sync first so sleep can populate the SDK database.")
        readBaseDailyDataWithTimeout { [weak self] baseSucceeded in
            guard let self else { return }
            self.latestSafeSyncMetadata["baseDailyReadSucceeded"] = baseSucceeded
            if baseSucceeded {
                self.latestSafeSyncMetadata["completedAt"] = ISO8601DateFormatter().string(from: Date())
                self.latestSafeSyncMetadata["partial"] = false
                self.latestSafeSyncMetadata["finishReason"] = "sdk_base_daily_completed"
                self.latestSafeSyncMetadata["safeDirectReadsSkipped"] = true
                self.latestSafeSyncMetadata["safeDirectReadsSkippedReason"] = "SDK base daily sync completed; database snapshot already contains sleep, steps, and daily metrics."
                self.collectionStatusLabel.text = "Watch database sync complete"
                completion(true)
                return
            }

            self.appendStatus("SDK base daily sync did not complete; falling back to safe direct reads.")
            self.performSafeDirectWatchSync(completion: completion)
        }
    }

    private func performSafeDirectWatchSync(completion: @escaping (Bool) -> Void) {
        let dayNumbers = [1, 0, 2]
        var dayPayloads: [[String: Any]] = []
        var didFinish = false

        func finish(success: Bool, reason: String) {
            guard !didFinish else { return }
            didFinish = true
            latestSafeSyncDays = dayPayloads
            latestSafeSyncMetadata["completedAt"] = ISO8601DateFormatter().string(from: Date())
            latestSafeSyncMetadata["partial"] = !success
            latestSafeSyncMetadata["finishReason"] = reason
            collectionStatusLabel.text = success ? "Watch storage read complete" : "Saving partial watch sync"
            completion(success)
        }

        let totalTimeout = DispatchWorkItem { [weak self] in
            guard let self, !didFinish else { return }
            self.recordTimedOutRead(name: "whole safe direct sync", timeout: self.syncTotalTimeout, duration: self.syncTotalTimeout)
            finish(success: false, reason: "whole_sync_timeout")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + syncTotalTimeout, execute: totalTimeout)

        func finishAndCancel(success: Bool, reason: String) {
            totalTimeout.cancel()
            finish(success: success, reason: reason)
        }

        func readDay(at index: Int) {
            guard !didFinish else { return }
            guard index < dayNumbers.count else {
                readDirectSportsRecords(shouldContinue: { !didFinish }) { [weak self] sportsPayload in
                    guard let self, !didFinish else { return }
                    self.latestSafeSyncMetadata["sportsRecords"] = sportsPayload
                    if self.payloadHasTimeout(sportsPayload) || self.payloadHasFailure(sportsPayload) {
                        finishAndCancel(success: false, reason: "sports_records_incomplete")
                        return
                    }

                    self.readDirectManualMeasurements(shouldContinue: { !didFinish }) { manualPayload in
                        guard !didFinish else { return }
                        self.latestSafeSyncMetadata["manualMeasurements"] = manualPayload
                        if self.payloadHasTimeout(manualPayload) || self.payloadHasFailure(manualPayload) {
                            finishAndCancel(success: false, reason: "manual_measurements_incomplete")
                            return
                        }

                        self.readRRIntervalProbeIfNeeded(dayNumber: 1, shouldContinue: { !didFinish }) { rrPayload in
                            guard !didFinish else { return }
                            self.latestSafeSyncMetadata["rrIntervalProbe"] = rrPayload
                            let rrTimedOut = self.payloadHasTimeout(rrPayload)
                            let rrFailed = self.payloadHasFailure(rrPayload)
                            finishAndCancel(
                                success: !rrTimedOut && !rrFailed,
                                reason: rrTimedOut ? "rr_interval_probe_timeout" : (rrFailed ? "rr_interval_probe_failed" : "completed")
                            )
                        }
                    }
                }
                return
            }

            let dayNumber = dayNumbers[index]
            collectionStatusLabel.text = "Reading watch day \(dayNumber)..."
            readSafeDirectDay(dayNumber: dayNumber, shouldContinue: { !didFinish }) { [weak self] dayPayload in
                guard let self, !didFinish else { return }
                dayPayloads.append(dayPayload)
                if self.payloadHasTimeout(dayPayload) || self.payloadHasFailure(dayPayload) {
                    finishAndCancel(success: false, reason: "day_\(dayNumber)_incomplete")
                    return
                }
                readDay(at: index + 1)
            }
        }

        readDay(at: 0)
    }

    private func readSafeDirectDay(
        dayNumber: Int,
        shouldContinue: @escaping () -> Bool = { true },
        completion: @escaping ([String: Any]) -> Void
    ) {
        var dayPayload: [String: Any] = [
            "date": WatchResearchStore.dayString(daysAgo: dayNumber),
            "daysAgo": dayNumber,
            "source": "watch_direct_read"
        ]

        let readMetricsAfterSleep = { [weak self] in
            guard let self else { return }
            guard shouldContinue() else { return }
            self.readDirectSteps(dayNumber: dayNumber, shouldContinue: shouldContinue) { stepPayload in
                guard shouldContinue() else { return }
                dayPayload["steps"] = stepPayload
                if self.payloadHasTimeout(stepPayload) || self.payloadHasFailure(stepPayload) {
                    completion(dayPayload)
                    return
                }

                self.readDirectBasicData(dayNumber: dayNumber, shouldContinue: shouldContinue) { basicPayload in
                    guard shouldContinue() else { return }
                    dayPayload["basicData"] = basicPayload
                    if self.payloadHasTimeout(basicPayload) || self.payloadHasFailure(basicPayload) {
                        completion(dayPayload)
                        return
                    }

                    self.readDirectTemperatureIfNeeded(dayNumber: dayNumber, shouldContinue: shouldContinue) { temperaturePayload in
                        guard shouldContinue() else { return }
                        dayPayload["temperature"] = temperaturePayload
                        completion(dayPayload)
                    }
                }
            }
        }

        guard dayNumber > 0 else {
            dayPayload["sleep"] = [
                "skipped": true,
                "reason": "SDK sleep day 0 is not valid; sleep should be read from day 1 or later."
            ]
            readMetricsAfterSleep()
            return
        }

        if latestSafeSyncMetadata["baseDailyReadSucceeded"] as? Bool == true {
            dayPayload["sleep"] = [
                "skipped": true,
                "reason": "SDK base daily sync completed first; sleep will be read from the SDK database snapshot for this date."
            ]
            readMetricsAfterSleep()
            return
        }

        collectionStatusLabel.text = "Reading sleep day \(dayNumber)..."
        readDirectSleepIfNeeded(dayNumber: dayNumber, shouldContinue: shouldContinue) { [weak self] sleepPayload in
            guard let self else { return }
            guard shouldContinue() else { return }
            dayPayload["sleep"] = sleepPayload
            if self.payloadHasTimeout(sleepPayload) || self.payloadHasFailure(sleepPayload) {
                completion(dayPayload)
                return
            }
            readMetricsAfterSleep()
        }
    }

    private func timedReadFinisher(
        name: String,
        timeout: TimeInterval,
        onFinish: (() -> Void)? = nil,
        completion: @escaping ([String: Any]) -> Void
    ) -> ([String: Any]) -> Void {
        let startedAt = Date()
        var didFinish = false
        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self, !didFinish else { return }
            didFinish = true
            onFinish?()
            self.recordTimedOutRead(name: name, timeout: timeout, duration: Date().timeIntervalSince(startedAt))
            completion([
                "timedOut": true,
                "readName": name,
                "timeoutSeconds": timeout,
                "durationSeconds": Date().timeIntervalSince(startedAt)
            ])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

        return { [weak self] payload in
            DispatchQueue.main.async {
                guard !didFinish else {
                    self?.appendStatus("Ignoring late callback for \(name).")
                    return
                }
                didFinish = true
                onFinish?()
                timeoutWork.cancel()
                var completedPayload = payload
                let duration = Date().timeIntervalSince(startedAt)
                completedPayload["durationSeconds"] = duration
                self?.recordReadDuration(name: name, duration: duration)
                completion(completedPayload)
            }
        }
    }

    private func failurePayload(name: String, reason: String) -> [String: Any] {
        recordFailedRead(name: name, reason: reason)
        return [
            "failed": true,
            "readName": name,
            "reason": reason
        ]
    }

    private func recordReadDuration(name: String, duration: TimeInterval) {
        appendSyncMetadataArray(
            key: "readDurations",
            value: [
                "name": name,
                "durationSeconds": duration
            ]
        )
    }

    private func recordTimedOutRead(name: String, timeout: TimeInterval, duration: TimeInterval) {
        appendStatus("\(name) timed out after \(Int(timeout))s; saving partial sync.")
        appendSyncMetadataArray(
            key: "timedOutReads",
            value: [
                "name": name,
                "timeoutSeconds": timeout,
                "durationSeconds": duration
            ]
        )
    }

    private func recordFailedRead(name: String, reason: String) {
        appendStatus("\(name) failed: \(reason)")
        appendSyncMetadataArray(
            key: "failedReads",
            value: [
                "name": name,
                "reason": reason
            ]
        )
    }

    private func appendSyncMetadataArray(key: String, value: [String: Any]) {
        var values = latestSafeSyncMetadata[key] as? [[String: Any]] ?? []
        values.append(value)
        latestSafeSyncMetadata[key] = values
    }

    private func payloadHasTimeout(_ value: Any) -> Bool {
        if let dictionary = value as? [String: Any] {
            if dictionary["timedOut"] as? Bool == true { return true }
            return dictionary.values.contains { payloadHasTimeout($0) }
        }

        if let array = value as? [Any] {
            return array.contains { payloadHasTimeout($0) }
        }

        return false
    }

    private func payloadHasFailure(_ value: Any) -> Bool {
        if let dictionary = value as? [String: Any] {
            if dictionary["failed"] as? Bool == true { return true }
            return dictionary.values.contains { payloadHasFailure($0) }
        }

        if let array = value as? [Any] {
            return array.contains { payloadHasFailure($0) }
        }

        return false
    }

    private func readDirectSteps(
        dayNumber: Int,
        shouldContinue: @escaping () -> Bool = { true },
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard shouldContinue() else { return }
        guard let peripheralManage = manager?.peripheralManage else {
            completion(failurePayload(name: "steps day \(dayNumber)", reason: "peripheral manager unavailable"))
            return
        }

        collectionStatusLabel.text = "Reading steps day \(dayNumber)..."
        let finish = timedReadFinisher(name: "steps day \(dayNumber)", timeout: syncReadTimeout, completion: completion)
        peripheralManage.veepooSDK_readStepData(withDayNumber: dayNumber) { [weak self] stepDict in
            DispatchQueue.main.async {
                guard shouldContinue() else { return }
                let payload = stepDict as? [String: Any] ?? [:]
                if dayNumber == 0 {
                    self?.applyStepPayloadToDashboard(payload)
                }
                self?.appendStatus("Direct step read day \(dayNumber): \(payload.isEmpty ? "no data" : "ok")")
                finish(payload.isEmpty ? ["empty": true] : payload)
            }
        }
    }

    private func readDirectSleepIfNeeded(
        dayNumber: Int,
        shouldContinue: @escaping () -> Bool = { true },
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard shouldContinue() else { return }
        guard dayNumber > 0 else {
            completion([
                "skipped": true,
                "reason": "SDK sleep day 0 is not valid; sleep should be read from day 1 or later."
            ])
            return
        }

        guard let peripheralManage = manager?.peripheralManage else {
            completion(failurePayload(name: "sleep day \(dayNumber)", reason: "peripheral manager unavailable"))
            return
        }

        let sleepType = manager?.peripheralManage.peripheralModel.sleepType ?? -1
        let finish = timedReadFinisher(name: "sleep day \(dayNumber)", timeout: syncSleepReadTimeout, completion: completion)
        readVeepooDirectSleep(
            dayNumber: dayNumber,
            sleepType: sleepType,
            peripheralManage: peripheralManage,
            shouldContinue: shouldContinue,
            finish: finish
        )
    }

    private func readVeepooDirectSleep(
        dayNumber: Int,
        sleepType: Int,
        peripheralManage: VPPeripheralBaseManage,
        shouldContinue: @escaping () -> Bool,
        finish: @escaping ([String: Any]) -> Void
    ) {
        peripheralManage.veepooSDK_readSleepData(withDayNumber: dayNumber) { [weak self] sleepArray in
            DispatchQueue.main.async {
                guard shouldContinue() else { return }
                let records = sleepArray?.map { $0 } ?? []
                self?.appendStatus("Direct sleep read day \(dayNumber): \(records.count) record(s)")
                let payload = self?.sleepRecordsPayload(records, sleepType: sleepType, source: "watch_direct_read") ?? [
                    "records": [],
                    "count": 0,
                    "sleepType": sleepType
                ]
                finish(payload)
            }
        }
    }

    private func readDirectBasicData(
        dayNumber: Int,
        shouldContinue: @escaping () -> Bool = { true },
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard shouldContinue() else { return }
        guard let peripheralManage = manager?.peripheralManage else {
            completion(failurePayload(name: "basic day \(dayNumber)", reason: "peripheral manager unavailable"))
            return
        }

        var records: [Any] = []
        var lastPackage = 0
        var totalPackages = 0
        var seenPackages = Set<Int>()
        var readStopped = false
        let finish = timedReadFinisher(
            name: "basic day \(dayNumber)",
            timeout: syncLongReadTimeout,
            onFinish: { readStopped = true },
            completion: completion
        )

        func readPackage(_ package: Int) {
            guard !readStopped, shouldContinue() else {
                readStopped = true
                return
            }
            guard package <= syncMaxPackageCount else {
                finish([
                    "records": records,
                    "count": records.count,
                    "totalPackages": totalPackages,
                    "lastPackage": lastPackage,
                    "failed": true,
                    "reason": "Exceeded package safety limit \(syncMaxPackageCount)."
                ])
                return
            }

            peripheralManage.veepooSDK_readBasicData(withDayNumber: dayNumber, maxPackage: package) { [weak self] basicArray, totalPackage, currentPackage in
                DispatchQueue.main.async {
                    guard !readStopped, shouldContinue() else {
                        readStopped = true
                        return
                    }
                    records.append(contentsOf: basicArray ?? [])
                    totalPackages = totalPackage
                    lastPackage = currentPackage
                    self?.collectionStatusLabel.text = "Basic day \(dayNumber): \(currentPackage)/\(totalPackage)"

                    if totalPackage <= 0 || currentPackage >= totalPackage {
                        self?.appendStatus("Direct basic read day \(dayNumber): \(records.count) record(s)")
                        finish([
                            "records": records,
                            "count": records.count,
                            "totalPackages": totalPackages,
                            "lastPackage": lastPackage
                        ])
                    } else if seenPackages.contains(currentPackage) {
                        self?.appendStatus("Direct basic read day \(dayNumber): repeated package \(currentPackage), stopping partial read.")
                        finish([
                            "records": records,
                            "count": records.count,
                            "totalPackages": totalPackages,
                            "lastPackage": lastPackage,
                            "failed": true,
                            "reason": "Repeated package \(currentPackage)."
                        ])
                    } else {
                        seenPackages.insert(currentPackage)
                        if !readStopped, shouldContinue() {
                            readPackage(max(currentPackage + 1, package + 1))
                        }
                    }
                }
            }
        }

        readPackage(1)
    }

    private func readDirectTemperatureIfNeeded(
        dayNumber: Int,
        shouldContinue: @escaping () -> Bool = { true },
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard shouldContinue() else { return }
        let temperatureType = manager?.peripheralManage.peripheralModel.temperatureType ?? 0
        guard temperatureType != 0 else {
            completion(["unsupported": true])
            return
        }

        guard temperatureType != 5 else {
            completion([
                "skipped": true,
                "reason": "SDK says temperatureType 5 is included in basic data, not the temperature direct-read API."
            ])
            return
        }

        guard let peripheralManage = manager?.peripheralManage else {
            completion(failurePayload(name: "temperature day \(dayNumber)", reason: "peripheral manager unavailable"))
            return
        }

        var records: [Any] = []
        var seenPackages = Set<Int>()
        var readStopped = false
        let finish = timedReadFinisher(
            name: "temperature day \(dayNumber)",
            timeout: syncLongReadTimeout,
            onFinish: { readStopped = true },
            completion: completion
        )

        func readPackage(_ package: Int) {
            guard !readStopped, shouldContinue() else {
                readStopped = true
                return
            }
            guard package <= syncMaxPackageCount else {
                finish([
                    "records": records,
                    "count": records.count,
                    "failed": true,
                    "reason": "Exceeded package safety limit \(syncMaxPackageCount)."
                ])
                return
            }

            peripheralManage.veepooSDK_readDeviceAutoTestTemperatureData(withDayNumber: dayNumber, maxPackage: package) { [weak self] tempArray, totalPackage, currentPackage in
                DispatchQueue.main.async {
                    guard !readStopped, shouldContinue() else {
                        readStopped = true
                        return
                    }
                    records.append(contentsOf: tempArray ?? [])

                    if totalPackage <= 0 || currentPackage >= totalPackage {
                        self?.appendStatus("Direct temperature read day \(dayNumber): \(records.count) record(s)")
                        finish([
                            "records": records,
                            "count": records.count,
                            "totalPackages": totalPackage,
                            "lastPackage": currentPackage
                        ])
                    } else if seenPackages.contains(currentPackage) {
                        self?.appendStatus("Direct temperature read day \(dayNumber): repeated package \(currentPackage), stopping partial read.")
                        finish([
                            "records": records,
                            "count": records.count,
                            "totalPackages": totalPackage,
                            "lastPackage": currentPackage,
                            "failed": true,
                            "reason": "Repeated package \(currentPackage)."
                        ])
                    } else {
                        seenPackages.insert(currentPackage)
                        if !readStopped, shouldContinue() {
                            readPackage(max(currentPackage + 1, package + 1))
                        }
                    }
                }
            }
        }

        readPackage(1)
    }

    private func readDirectSportsRecords(
        shouldContinue: @escaping () -> Bool = { true },
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard shouldContinue() else { return }
        guard let peripheralManage = manager?.peripheralManage else {
            completion(failurePayload(name: "sports records", reason: "peripheral manager unavailable"))
            return
        }

        collectionStatusLabel.text = "Reading sports records..."
        var readStopped = false
        let finish = timedReadFinisher(
            name: "sports records",
            timeout: syncLongReadTimeout,
            onFinish: { readStopped = true },
            completion: completion
        )

        peripheralManage.veepooSDK_readDeviceRunningCrcResult { [weak self] crcValues in
            DispatchQueue.main.async {
                guard !readStopped, shouldContinue() else {
                    readStopped = true
                    return
                }
                let crcs = crcValues ?? []
                let indexedCRCs = crcs.enumerated().compactMap { index, value -> (Int, Any)? in
                    if let number = value as? NSNumber, number.intValue != 0 {
                        return (index, value)
                    }
                    return nil
                }

                guard !indexedCRCs.isEmpty else {
                    self?.appendStatus("Direct sports read: no stored sports records.")
                    finish([
                        "crcValues": crcs,
                        "records": [],
                        "count": 0
                    ])
                    return
                }

                var records: [[String: Any]] = []

                func readRecord(at cursor: Int) {
                    guard !readStopped, shouldContinue() else {
                        readStopped = true
                        return
                    }
                    guard cursor < indexedCRCs.count else {
                        self?.appendStatus("Direct sports read: \(records.count) record(s)")
                        finish([
                            "crcValues": crcs,
                            "records": records,
                            "count": records.count
                        ])
                        return
                    }

                    let item = indexedCRCs[cursor]
                    var latestRecord: [String: Any] = [:]
                    self?.manager?.peripheralManage.veepooSDK_readDeviceRunningData(withBlockNumber: item.0) { runningDict, totalPackage, currentPackage in
                        DispatchQueue.main.async {
                            guard !readStopped, shouldContinue() else {
                                readStopped = true
                                return
                            }
                            latestRecord = runningDict as? [String: Any] ?? latestRecord
                            if totalPackage <= 0 || currentPackage >= totalPackage {
                                records.append([
                                    "blockIndex": item.0,
                                    "crc": item.1,
                                    "data": latestRecord,
                                    "totalPackages": totalPackage,
                                    "lastPackage": currentPackage
                                ])
                                if !readStopped, shouldContinue() {
                                    readRecord(at: cursor + 1)
                                }
                            }
                        }
                    }
                }

                readRecord(at: 0)
            }
        }
    }

    private func readDirectManualMeasurements(
        shouldContinue: @escaping () -> Bool = { true },
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard shouldContinue() else { return }
        guard let peripheralManage = manager?.peripheralManage else {
            completion(failurePayload(name: "manual measurements", reason: "peripheral manager unavailable"))
            return
        }

        let supported = peripheralManage.supportManualTestType.rawValue
        guard supported != 0 else {
            completion(["unsupported": true])
            return
        }

        let allTypes = VPManualTestDataType(rawValue: UInt(UInt32.max))
        collectionStatusLabel.text = "Reading manual measurements..."
        let finish = timedReadFinisher(name: "manual measurements", timeout: syncReadTimeout, completion: completion)
        peripheralManage.readManualTestData(withTimestamp: 0, dataType: allTypes) { [weak self] model in
            DispatchQueue.main.async {
                guard shouldContinue() else { return }
                let payload = self?.manualMeasurementsPayload(from: model) ?? ["empty": true]
                self?.appendStatus("Direct manual measurement read complete.")
                finish(payload)
            }
        }
    }

    private func readRRIntervalProbeIfNeeded(
        dayNumber: Int,
        shouldContinue: @escaping () -> Bool = { true },
        completion: @escaping ([String: Any]) -> Void
    ) {
        guard shouldContinue() else { return }
        guard let peripheralManage = manager?.peripheralManage else {
            completion(failurePayload(name: "rr interval day \(dayNumber)", reason: "peripheral manager unavailable"))
            return
        }

        let model = peripheralManage.peripheralModel
        guard model?.hrvType ?? 0 != 0 else {
            completion([
                "unsupported": true,
                "reason": "Device model reports hrvType == 0."
            ])
            return
        }

        collectionStatusLabel.text = "Probing RR interval day \(dayNumber)..."
        var records: [[String: Any]] = []
        var readStopped = false
        let finish = timedReadFinisher(
            name: "rr interval day \(dayNumber)",
            timeout: syncLongReadTimeout,
            onFinish: { readStopped = true },
            completion: completion
        )

        peripheralManage.veepooSDK_readRRIntervalData(withDayNumber: dayNumber, blockNumber: 1) { [weak self] responseObject, progress, error in
            DispatchQueue.main.async {
                guard let self, !readStopped, shouldContinue() else {
                    readStopped = true
                    return
                }

                if let error {
                    finish([
                        "failed": true,
                        "error": error.localizedDescription,
                        "records": records,
                        "count": records.count
                    ])
                    return
                }

                if let rrModel = responseObject as? VPRRIntervalDataModel {
                    records.append(self.rrIntervalPayload(from: rrModel))
                }

                let completed = progress?.completedUnitCount ?? 0
                let total = progress?.totalUnitCount ?? 0
                let progressFinished = total > 0 && completed >= total
                if records.count >= self.syncRRProbeMaxBlocks || progressFinished {
                    let reason = records.count >= self.syncRRProbeMaxBlocks ? "sample_limit_reached" : "complete"
                    self.appendStatus("RR interval probe day \(dayNumber): \(records.count) block(s), \(reason).")
                    finish([
                        "dayNumber": dayNumber,
                        "records": records,
                        "count": records.count,
                        "progressCompleted": completed,
                        "progressTotal": total,
                        "stoppedReason": reason,
                        "note": "Vendor bulk HRV sync remains disabled; this probes raw RR blocks only."
                    ])
                }
            }
        }
    }

    private func rrIntervalPayload(from model: VPRRIntervalDataModel) -> [String: Any] {
        let rrValues = UInt16.littleEndianValues(from: model.dataConvertStream)
        return [
            "blockNumber": model.blockNumber,
            "date": model.date,
            "time": model.time,
            "dataStreamBytes": model.dataStream.count,
            "dataConvertStreamBytes": model.dataConvertStream.count,
            "rrValueCount": rrValues.count,
            "rrValues": rrValues
        ]
    }

    private func manualMeasurementsPayload(from model: VPManualTestDataModel?) -> [String: Any] {
        guard let object = model else { return ["empty": true] }

        let bloodPressure = objectArrayPayload(object, key: "bloodPressureArr")
        let bodyTemperature = objectArrayPayload(object, key: "bodyTempArr")
        let bloodComponents = objectArrayPayload(object, key: "bloodCompArr")
        let heartRate = objectArrayPayload(object, key: "heartRateArr")
        let bloodOxygen = objectArrayPayload(object, key: "bloodOxygenArr")
        let bloodSugar = objectArrayPayload(object, key: "bloodSugarArr")

        return [
            "mac": object.value(forKey: "mac") ?? "",
            "bloodPressure": bloodPressure,
            "bodyTemperature": bodyTemperature,
            "bloodComponents": bloodComponents,
            "heartRate": heartRate,
            "bloodOxygen": bloodOxygen,
            "bloodSugar": bloodSugar,
            "counts": [
                "bloodPressure": bloodPressure.count,
                "bodyTemperature": bodyTemperature.count,
                "bloodComponents": bloodComponents.count,
                "heartRate": heartRate.count,
                "bloodOxygen": bloodOxygen.count,
                "bloodSugar": bloodSugar.count
            ]
        ]
    }

    private func objectArrayPayload(_ object: NSObject, key: String) -> [Any] {
        if let array = object.value(forKey: key) as? [Any] {
            return array
        }

        if let array = object.value(forKey: key) as? NSArray {
            return array.map { $0 }
        }

        return []
    }

    private func isAccurateSleepType(_ sleepType: Int) -> Bool {
        sleepType != 0 && sleepType != 2
    }

    private func sleepRecordsPayload(_ records: [Any], sleepType: Int, source: String) -> [String: Any] {
        [
            "records": records.map { sleepRecordPayload($0) },
            "count": records.count,
            "sleepType": sleepType,
            "sleepKind": isAccurateSleepType(sleepType) ? "accurate" : "normal",
            "source": source,
            "note": isAccurateSleepType(sleepType)
                ? "Device reports accurate sleep; records are serialized from VPAccurateSleepModel."
                : "Device reports normal sleep; records use the SDK sleep dictionary fields."
        ]
    }

    private func sleepRecordPayload(_ record: Any) -> Any {
        if let model = record as? VPAccurateSleepModel {
            return accurateSleepPayload(from: model)
        }

        if let dictionary = record as? [String: Any] {
            return dictionary
        }

        if let dictionary = record as? NSDictionary {
            var payload: [String: Any] = [:]
            dictionary.forEach { key, value in
                payload[String(describing: key)] = value
            }
            return payload
        }

        return ["description": String(describing: record)]
    }

    private func accurateSleepPayload(from model: VPAccurateSleepModel) -> [String: Any] {
        let stringKeys = [
            "sleepType",
            "sleepTime",
            "wakeTime",
            "sleepTag",
            "getUpScore",
            "deepScore",
            "sleepEfficiencyScore",
            "fallAsleepScore",
            "sleepTimeScore",
            "exitSleepMode",
            "sleepQuality",
            "getUpTimes",
            "deepAndLightMode",
            "sleepDuration",
            "deepDuration",
            "lightDuration",
            "getUpDuration",
            "otherDuration",
            "firstDeepDuration",
            "getUpToDeepAve",
            "onePointDuration",
            "accurateType",
            "insomniaTag",
            "insomniaScore",
            "insomniaTimes",
            "sleepLine",
            "insomniaDuration",
            "lastType",
            "nextType",
            "mac"
        ]
        var payload = stringKeys.reduce(into: [String: Any]()) { result, key in
            result[key] = model.value(forKey: key) ?? ""
        }
        payload["insomniaRecord"] = model.insomniaRecord
        payload["sleepLineParsed"] = model.parseSleepLine()
        return payload
    }

    private func applyStepPayloadToDashboard(_ payload: [String: Any]) {
        let steps = stringValue(from: payload["Step"])
        let distance = stringValue(from: payload["Dis"])
        let calories = stringValue(from: payload["Cal"])
        stepsTileValueLabel.text = "\(steps) steps\n\(distance) km / \(calories) kcal"
        viewModel.steps = "\(steps) steps"
        viewModel.distance = distance
        viewModel.calories = calories
        markUpdated()
    }

    private func loadLatestSavedSnapshotIntoDashboard(logFailures: Bool = true) {
        do {
            guard let snapshot = try WatchResearchStore.shared.latestSyncSnapshot() else { return }
            applySnapshotToDashboard(snapshot.payload, fileURL: snapshot.url)
        } catch {
            if logFailures {
                appendStatus("Failed to load latest local JSON: \(error.localizedDescription)")
            }
        }
    }

    private func applyLatestSnapshotToDashboard(from fileURL: URL) {
        do {
            let payload = try WatchResearchStore.shared.loadSyncSnapshot(from: fileURL)
            applySnapshotToDashboard(payload, fileURL: fileURL)
        } catch {
            appendStatus("Saved JSON could not be reloaded for dashboard: \(error.localizedDescription)")
        }
    }

    private func runCoachAnalysisIfNeeded(syncId: String) {
        guard !syncId.isEmpty else { return }
        viewModel.isAIAnalyzing = true
        let calendarAware = CoachCalendarService.shared.hasUsableCalendarContext
        if let cached = HealthDataStore.shared.cachedCoachAnalysis(syncId: syncId),
           cached.isAIBacked,
           !calendarAware {
            viewModel.coachAnalysis = cached
            viewModel.aiStatus = "AI analyzed"
            viewModel.isAIAnalyzing = false
            return
        }

        viewModel.aiStatus = "AI analyzing"
        Task { [weak self] in
            guard let self else { return }
            do {
                let context = await self.coachPromptContextWithCalendar(syncId: syncId)
                let contextHash = self.coachContextHash(context)
                if let cached = HealthDataStore.shared.cachedCoachAnalysis(contextHash: contextHash) {
                    let reused = cached.reusedForSync(
                        syncId: syncId,
                        generatedAt: HealthDataStore.shared.currentTimestamp()
                    )
                    HealthDataStore.shared.saveCoachAnalysis(reused, contextHash: contextHash)
                    await MainActor.run {
                        self.viewModel.coachAnalysis = reused
                        self.loadLatestSavedSnapshotIntoDashboard(logFailures: false)
                        self.viewModel.aiStatus = "AI reused"
                        self.viewModel.isAIAnalyzing = false
                        self.appendStatus("AI coach analysis reused for unchanged context.")
                    }
                    return
                }
                let analysis = try await AICoachService.shared.analyze(syncId: syncId, contextJSON: context)
                HealthDataStore.shared.saveCoachAnalysis(analysis, contextHash: contextHash)
                await MainActor.run {
                    self.viewModel.coachAnalysis = analysis
                    self.loadLatestSavedSnapshotIntoDashboard(logFailures: false)
                    self.viewModel.aiStatus = "AI analyzed"
                    self.viewModel.isAIAnalyzing = false
                    self.appendStatus("AI coach analysis saved for sync \(syncId).")
                }
            } catch {
                let contextHash = HealthDataStore.shared.coachPromptContextHash(syncId: syncId)
                let fallback = HealthDataStore.shared.localFallbackAnalysis(syncId: syncId)
                HealthDataStore.shared.saveCoachAnalysis(fallback, contextHash: contextHash)
                await MainActor.run {
                    self.viewModel.coachAnalysis = fallback
                    self.loadLatestSavedSnapshotIntoDashboard(logFailures: false)
                    self.viewModel.aiStatus = "AI setup needed"
                    self.viewModel.isAIAnalyzing = false
                    self.appendStatus("AI coach fallback saved: \(error.localizedDescription)")
                }
            }
        }
    }

    private func rerunCoachAnalysisForLatestSync(reason: String) {
        do {
            guard let snapshot = try WatchResearchStore.shared.latestSyncSnapshot(),
                  let syncId = snapshot.payload["syncId"] as? String,
                  !syncId.isEmpty else {
                appendStatus("Calendar connected. Sync watch once so AI can use calendar context.")
                return
            }
            viewModel.aiStatus = "AI updating with calendar"
            viewModel.isAIAnalyzing = true
            appendStatus("Refreshing AI coach analysis for \(reason).")
            runCoachAnalysisIfNeeded(syncId: syncId)
        } catch {
            appendStatus("Calendar connected, but latest sync could not be loaded: \(error.localizedDescription)")
        }
    }

    private func coachPromptContextWithCalendar(syncId: String) async -> String {
        let base = HealthDataStore.shared.coachPromptContext(syncId: syncId)
        guard CoachCalendarService.shared.hasUsableCalendarContext,
              let data = base.data(using: .utf8),
              var payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return base
        }
        let availability = await withCheckedContinuation { continuation in
            CoachCalendarService.shared.availabilityContextForAI { summary in
                continuation.resume(returning: summary)
            }
        }
        payload["calendarContext"] = availability
        let enriched = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? data
        return String(data: enriched, encoding: .utf8) ?? base
    }

    private func coachContextHash(_ context: String) -> String {
        let digest = SHA256.hash(data: Data(context.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func applySnapshotToDashboard(_ payload: [String: Any], fileURL: URL?) {
        let latestDays = snapshotDays(from: payload)
        let days = historicalDashboardDays(fallbackDays: latestDays)
        var details: [String: MetricDetailData] = [:]
        let syncId = payload["syncId"] as? String ?? ""

        HealthDataStore.shared.ingestSnapshot(payload: payload, fileURL: fileURL)
        if let cached = HealthDataStore.shared.cachedCoachAnalysis(syncId: syncId) {
            viewModel.coachAnalysis = cached
            viewModel.aiStatus = cached.isAIBacked ? "AI analyzed" : "Local explanation"
        } else if !syncId.isEmpty {
            viewModel.coachAnalysis = HealthDataStore.shared.localFallbackAnalysis(syncId: syncId)
            viewModel.aiStatus = "AI pending"
        }

        if let device = payload["device"] as? [String: Any] {
            viewModel.deviceName = stringValue(from: device["name"])
            viewModel.deviceAddress = stringValue(from: device["id"])
        }

        if let syncedAt = payload["syncedAt"] as? String {
            let display = displayTimestamp(syncedAt)
            viewModel.lastSync = display
            viewModel.updatedAt = display
            lastSyncLabel.text = "Last sync: \(display)"
            watchStatusSyncLabel.text = "Last synced: \(display)"
        }

        if let heart = latestHeartRate(from: days) {
            viewModel.heartRate = "\(heart.value) bpm"
            heartTileValueLabel.text = "\(heart.value) bpm\n\(heart.time)"
            details["heartRate"] = metricDetail(
                id: "heartRate",
                title: "Heart Rate",
                icon: "heart.fill",
                colorName: "red",
                value: viewModel.heartRate,
                detail: "Latest half-hour sample from \(heart.date)",
                rows: [
                    MetricDetailRow("Date", heart.date),
                    MetricDetailRow("Time", heart.time),
                    MetricDetailRow("Latest", "\(heart.value) bpm"),
                    MetricDetailRow("Average", "\(heart.average) bpm"),
                    MetricDetailRow("Samples", "\(heart.count)")
                ],
                history: heartRateHistory(from: days)
            )
        }

        if let oxygen = latestDictionaryValue(from: days, metric: "bloodOxygen", valueKeys: ["OxygenValue", "oxygenValue", "value"], requirePositive: true) {
            viewModel.oxygen = "\(oxygen.value)%"
            oxygenTileValueLabel.text = "\(oxygen.value)%\n\(oxygen.time)"
            details["oxygen"] = metricDetail(
                id: "oxygen",
                title: "Blood Oxygen",
                icon: "drop.fill",
                colorName: "blue",
                value: viewModel.oxygen,
                detail: "Latest SpO2 sample from \(oxygen.date)",
                rows: oxygen.rows(prefix: "SpO2", unit: "%"),
                history: dictionaryMetricHistory(
                    from: days,
                    metric: "bloodOxygen",
                    valueKeys: ["OxygenValue", "oxygenValue", "value"],
                    unit: "%",
                    requirePositive: true
                )
            )
        }

        if let pressure = latestBloodPressure(from: days) {
            viewModel.bloodPressure = "\(pressure.systolic)/\(pressure.diastolic)"
            details["bloodPressure"] = metricDetail(
                id: "bloodPressure",
                title: "Blood Pressure",
                icon: "gauge",
                colorName: "red",
                value: viewModel.bloodPressure,
                detail: "Latest stored blood pressure",
                rows: [
                    MetricDetailRow("Date", pressure.date),
                    MetricDetailRow("Time", pressure.time),
                    MetricDetailRow("Systolic", "\(pressure.systolic) mmHg"),
                    MetricDetailRow("Diastolic", "\(pressure.diastolic) mmHg"),
                    MetricDetailRow("Samples", "\(pressure.count)")
                ],
                history: bloodPressureHistory(from: days)
            )
        }

        applySleepDashboard(from: days, details: &details)
        applyActivityDashboard(from: days, details: &details)
        applyTemperatureDashboard(from: days, details: &details)
        applyGlucoseDashboard(from: days, details: &details)
        applyHRVDashboard(from: days, details: &details)
        applyECGDashboard(from: days, details: &details)

        details["battery"] = metricDetail(
            id: "battery",
            title: "Battery",
            icon: "battery.100",
            colorName: "green",
            value: viewModel.battery,
            detail: "Live battery value after connection",
            rows: [MetricDetailRow("Battery", viewModel.battery), MetricDetailRow("Source", "Watch live read")]
        )

        let latestName = fileURL?.lastPathComponent ?? "Latest local sync"
        details["updated"] = metricDetail(
            id: "updated",
            title: "Updated",
            icon: "clock",
            colorName: "secondary",
            value: viewModel.updatedAt,
            detail: latestName,
            rows: [
                MetricDetailRow("Last sync", viewModel.lastSync),
                MetricDetailRow("Local file", latestName),
                MetricDetailRow("Storage", WatchResearchStore.shared.localStorageDetailSummary())
            ]
        )

        viewModel.metricDetails = details
        viewModel.localStorage = WatchResearchStore.shared.localStorageDetailSummary()
        viewModel.canExport = WatchResearchStore.shared.latestSyncFileURL() != nil
    }

    private func applySleepDashboard(from days: [[String: Any]], details: inout [String: MetricDetailData]) {
        guard let sleep = latestSleepRecord(from: days) else {
            viewModel.sleepDuration = "--"
            viewModel.sleepScore = "--"
            viewModel.sleepScoreDetail = "No sleep record"
            details["sleep"] = metricDetail(
                id: "sleep",
                title: "Sleep",
                icon: "bed.double.fill",
                colorName: "secondary",
                value: "--",
                detail: "No sleep record in the latest local JSON",
                rows: [MetricDetailRow("Status", "No sleep records found")],
                history: []
            )
            return
        }

        let score = sleepScore(for: sleep.record, in: days)
        let durationMinutes = intValue(from: sleep.record["sleepDuration"]) ?? score.durationMinutes
        let deepMinutes = intValue(from: sleep.record["deepDuration"]) ?? 0
        let lightMinutes = intValue(from: sleep.record["lightDuration"]) ?? 0
        let awakeMinutes = intValue(from: sleep.record["getUpDuration"]) ?? 0
        let wakeEvents = intValue(from: sleep.record["getUpTimes"]) ?? 0

        viewModel.sleepDuration = durationText(minutes: durationMinutes)
        viewModel.sleepScore = "\(score.total)/100"
        viewModel.sleepScoreDetail = score.category

        details["sleep"] = metricDetail(
            id: "sleep",
            title: "Sleep",
            icon: "bed.double.fill",
            colorName: "secondary",
            value: viewModel.sleepScore,
            detail: "\(viewModel.sleepDuration) slept, \(score.category)",
            rows: [
                MetricDetailRow("Date", sleep.date),
                MetricDetailRow("Sleep time", stringValue(from: sleep.record["sleepTime"])),
                MetricDetailRow("Wake time", stringValue(from: sleep.record["wakeTime"])),
                MetricDetailRow("Duration", durationText(minutes: durationMinutes)),
                MetricDetailRow("Deep", durationText(minutes: deepMinutes)),
                MetricDetailRow("Light", durationText(minutes: lightMinutes)),
                MetricDetailRow("Awake", durationText(minutes: awakeMinutes)),
                MetricDetailRow("Wake events", "\(wakeEvents)"),
                MetricDetailRow("Duration score", "\(score.durationPoints)/50"),
                MetricDetailRow("Consistency score", "\(score.consistencyPoints)/30"),
                MetricDetailRow("Interruption score", "\(score.interruptionPoints)/20"),
                MetricDetailRow("Score model", "Apple-style estimate from duration, consistency, and interruptions")
            ],
            history: sleepHistory(from: days)
        )
    }

    private func applyActivityDashboard(from days: [[String: Any]], details: inout [String: MetricDetailData]) {
        guard let day = firstDay(in: days, where: { isNonEmptyDictionary($0["steps"]) }),
              let steps = day["steps"] as? [String: Any] else { return }

        let stepCount = stringValue(from: steps["Step"])
        let distance = stringValue(from: steps["Dis"])
        let calories = stringValue(from: steps["Cal"])
        viewModel.steps = "\(stepCount) steps"
        viewModel.distance = distance
        viewModel.calories = calories
        stepsTileValueLabel.text = "\(stepCount) steps\n\(distance) km / \(calories) kcal"
        details["activity"] = metricDetail(
            id: "activity",
            title: "Activity",
            icon: "figure.walk",
            colorName: "orange",
            value: viewModel.steps,
            detail: "\(distance) km / \(calories) kcal on \(day["date"] as? String ?? "--")",
            rows: [
                MetricDetailRow("Date", day["date"] as? String ?? "--"),
                MetricDetailRow("Steps", stepCount),
                MetricDetailRow("Distance", "\(distance) km"),
                MetricDetailRow("Calories", "\(calories) kcal")
            ],
            history: activityHistory(from: days)
        )
    }

    private func applyTemperatureDashboard(from days: [[String: Any]], details: inout [String: MetricDetailData]) {
        guard let temperature = latestDictionaryValue(from: days, metric: "temperature", valueKeys: ["value", "temperature", "bodyTemperature"], requirePositive: false) else { return }
        viewModel.temperature = "\(temperature.value) C"
        temperatureTileValueLabel.text = "\(temperature.value) C\n\(temperature.time)"
        details["temperature"] = metricDetail(
            id: "temperature",
            title: "Temperature",
            icon: "thermometer",
            colorName: "red",
            value: viewModel.temperature,
            detail: "Latest stored temperature sample",
            rows: temperature.rows(prefix: "Temperature", unit: " C"),
            history: dictionaryMetricHistory(
                from: days,
                metric: "temperature",
                valueKeys: ["value", "temperature", "bodyTemperature"],
                unit: " C",
                requirePositive: false
            )
        )
    }

    private func applyGlucoseDashboard(from days: [[String: Any]], details: inout [String: MetricDetailData]) {
        guard let glucose = latestGlucose(from: days) else {
            viewModel.bloodGlucose = "--"
            return
        }
        viewModel.bloodGlucose = glucose.value
        details["bloodGlucose"] = metricDetail(
            id: "bloodGlucose",
            title: "Glucose",
            icon: "testtube.2",
            colorName: "green",
            value: glucose.value,
            detail: "Latest stored glucose sample",
            rows: [
                MetricDetailRow("Date", glucose.date),
                MetricDetailRow("Time", glucose.time),
                MetricDetailRow("Glucose", glucose.value),
                MetricDetailRow("Samples", "\(glucose.count)")
            ],
            history: glucoseHistory(from: days)
        )
    }

    private func applyHRVDashboard(from days: [[String: Any]], details: inout [String: MetricDetailData]) {
        guard let day = firstDay(in: days, where: { $0["hrv"] != nil }) else { return }
        let hrv = day["hrv"]
        if let dictionary = hrv as? [String: Any], dictionary["skipped"] as? Bool == true {
            viewModel.hrv = "Skipped"
            details["hrv"] = metricDetail(
                id: "hrv",
                title: "HRV",
                icon: "waveform.path",
                colorName: "primary",
                value: "Skipped",
                detail: stringValue(from: dictionary["reason"]),
                rows: [
                    MetricDetailRow("Date", day["date"] as? String ?? "--"),
                    MetricDetailRow("Status", "Skipped"),
                    MetricDetailRow("Reason", stringValue(from: dictionary["reason"]))
                ],
                history: hrvHistory(from: days)
            )
        } else {
            viewModel.hrv = "\(recordCount(hrv)) records"
            details["hrv"] = metricDetail(
                id: "hrv",
                title: "HRV",
                icon: "waveform.path",
                colorName: "primary",
                value: viewModel.hrv,
                detail: "Stored HRV data",
                rows: [MetricDetailRow("Date", day["date"] as? String ?? "--"), MetricDetailRow("Records", "\(recordCount(hrv))")],
                history: hrvHistory(from: days)
            )
        }
    }

    private func applyECGDashboard(from days: [[String: Any]], details: inout [String: MetricDetailData]) {
        let count = days.reduce(0) { $0 + recordCount($1["offlineECG"]) }
        viewModel.ecg = count > 0 ? "\(count) record(s)" : "--"
        ecgTileValueLabel.text = viewModel.ecg
        details["ecg"] = metricDetail(
            id: "ecg",
            title: "ECG",
            icon: "waveform.path.ecg",
            colorName: "primary",
            value: viewModel.ecg,
            detail: "Offline ECG records in local JSON",
            rows: [MetricDetailRow("Records", "\(count)"), MetricDetailRow("Source", "offlineECG")],
            history: ecgHistory(from: days)
        )
    }

    private func metricDetail(
        id: String,
        title: String,
        icon: String,
        colorName: String,
        value: String,
        detail: String,
        rows: [MetricDetailRow],
        history: [MetricHistorySection] = [],
        aiExplanation: MetricAIExplanation? = nil
    ) -> MetricDetailData {
        let referenceRows: [MetricDetailRow]
        if let reference = VitalReference.reference(for: id) {
            referenceRows = [
                MetricDetailRow("Reference", reference.shortRange, id: "\(id)-reference"),
                MetricDetailRow("Reference note", reference.detail, id: "\(id)-reference-note")
            ]
        } else {
            referenceRows = []
        }

        return MetricDetailData(
            id: id,
            title: title,
            icon: icon,
            colorName: colorName,
            value: value,
            detail: detail,
            rows: rows + referenceRows,
            history: history,
            aiExplanation: aiExplanation ?? viewModel.coachAnalysis.metricExplanations[id] ?? MetricAIExplanation.fallback(metricId: id, value: value, title: title)
        )
    }

    private func historicalDashboardDays(fallbackDays: [[String: Any]]) -> [[String: Any]] {
        do {
            let snapshots = try WatchResearchStore.shared.allSyncSnapshots()
            var daysByDate: [String: [String: Any]] = [:]
            for snapshot in snapshots {
                for day in snapshotDays(from: snapshot.payload) {
                    guard let date = day["date"] as? String, daysByDate[date] == nil else { continue }
                    daysByDate[date] = day
                }
            }
            let historyDays = Array(daysByDate.values)
                .sorted { ($0["date"] as? String ?? "") > ($1["date"] as? String ?? "") }
            return historyDays.isEmpty ? fallbackDays : historyDays
        } catch {
            return fallbackDays
        }
    }

    private func sleepHistory(from days: [[String: Any]]) -> [MetricHistorySection] {
        days.flatMap { day -> [MetricHistorySection] in
            guard let date = day["date"] as? String else { return [] }
            return sleepRecords(in: day).enumerated().map { index, record in
                let score = sleepScore(for: record, in: days)
                let durationMinutes = intValue(from: record["sleepDuration"]) ?? score.durationMinutes
                let deepMinutes = intValue(from: record["deepDuration"]) ?? 0
                let lightMinutes = intValue(from: record["lightDuration"]) ?? 0
                let awakeMinutes = intValue(from: record["getUpDuration"]) ?? 0
                let wakeEvents = intValue(from: record["getUpTimes"]) ?? 0
                let title = index == 0 ? date : "\(date) sleep \(index + 1)"
                return MetricHistorySection(title, rows: [
                    MetricDetailRow("Score", "\(score.total)/100 \(score.category)", id: "\(title)-score"),
                    MetricDetailRow("Sleep time", stringValue(from: record["sleepTime"]), id: "\(title)-sleep"),
                    MetricDetailRow("Wake time", stringValue(from: record["wakeTime"]), id: "\(title)-wake"),
                    MetricDetailRow("Duration", durationText(minutes: durationMinutes), id: "\(title)-duration"),
                    MetricDetailRow("Deep", durationText(minutes: deepMinutes), id: "\(title)-deep"),
                    MetricDetailRow("Light", durationText(minutes: lightMinutes), id: "\(title)-light"),
                    MetricDetailRow("Awake", durationText(minutes: awakeMinutes), id: "\(title)-awake"),
                    MetricDetailRow("Wake events", "\(wakeEvents)", id: "\(title)-events")
                ])
            }
        }
    }

    private func heartRateHistory(from days: [[String: Any]]) -> [MetricHistorySection] {
        days.compactMap { day in
            guard let date = day["date"] as? String,
                  let samples = day["heartHalfHour"] as? [String: Any] else { return nil }
            let readings = samples.compactMap { key, value -> (time: String, value: Int)? in
                guard let dictionary = value as? [String: Any],
                      let heart = intValue(from: dictionary["heartValue"]),
                      heart > 0 else { return nil }
                return (key, heart)
            }
            .sorted { $0.time < $1.time }
            guard !readings.isEmpty else { return nil }
            let average = Int(round(Double(readings.reduce(0) { $0 + $1.value }) / Double(readings.count)))
            let rows = [
                MetricDetailRow("Average", "\(average) bpm", id: "\(date)-hr-average"),
                MetricDetailRow("Samples", "\(readings.count)", id: "\(date)-hr-count")
            ] + readings.enumerated().map { index, reading in
                MetricDetailRow(reading.time, "\(reading.value) bpm", id: "\(date)-hr-\(index)")
            }
            return MetricHistorySection("\(date) (\(readings.count) samples)", rows: rows)
        }
    }

    private func dictionaryMetricHistory(
        from days: [[String: Any]],
        metric: String,
        valueKeys: [String],
        unit: String,
        requirePositive: Bool
    ) -> [MetricHistorySection] {
        days.compactMap { day in
            guard let date = day["date"] as? String,
                  let records = day[metric] as? [[String: Any]] else { return nil }
            let rows = records.enumerated().compactMap { index, record -> MetricDetailRow? in
                guard let rawValue = valueForFirstKey(in: record, keys: valueKeys) else { return nil }
                if requirePositive, (doubleValue(from: rawValue) ?? 0) <= 0 { return nil }
                let time = displayRecordTime(from: record, fallback: "Reading \(index + 1)")
                return MetricDetailRow(time, "\(stringValue(from: rawValue))\(unit)", id: "\(date)-\(metric)-\(index)")
            }
            guard !rows.isEmpty else { return nil }
            return MetricHistorySection("\(date) (\(rows.count) samples)", rows: rows)
        }
    }

    private func bloodPressureHistory(from days: [[String: Any]]) -> [MetricHistorySection] {
        days.compactMap { day in
            guard let date = day["date"] as? String,
                  let records = day["bloodPressure"] as? [[String: Any]] else { return nil }
            let rows = records.enumerated().compactMap { index, record -> MetricDetailRow? in
                guard let systolic = intValue(from: record["systolic"]),
                      let diastolic = intValue(from: record["diastolic"]),
                      systolic > 0,
                      diastolic > 0 else { return nil }
                let time = displayRecordTime(from: record, fallback: "Reading \(index + 1)")
                return MetricDetailRow(time, "\(systolic)/\(diastolic) mmHg", id: "\(date)-bp-\(index)")
            }
            guard !rows.isEmpty else { return nil }
            return MetricHistorySection("\(date) (\(rows.count) samples)", rows: rows)
        }
    }

    private func glucoseHistory(from days: [[String: Any]]) -> [MetricHistorySection] {
        days.compactMap { day in
            guard let date = day["date"] as? String,
                  let records = day["bloodGlucose"] as? [[String: Any]] else { return nil }
            var rows: [MetricDetailRow] = []
            for (recordIndex, record) in records.enumerated() {
                let time = displayRecordTime(from: record, fallback: "Reading \(recordIndex + 1)")
                if let values = record["bloodGlucoses"] as? [Any], !values.isEmpty {
                    for (valueIndex, value) in values.enumerated() {
                        let display = stringValue(from: value)
                        guard display != "--" else { continue }
                        let label = values.count == 1 ? time : "\(time) #\(valueIndex + 1)"
                        rows.append(MetricDetailRow(label, display, id: "\(date)-glucose-\(recordIndex)-\(valueIndex)"))
                    }
                } else {
                    let display = stringValue(from: record["bloodGlucose"] ?? record["value"])
                    guard display != "--" else { continue }
                    rows.append(MetricDetailRow(time, display, id: "\(date)-glucose-\(recordIndex)"))
                }
            }
            guard !rows.isEmpty else { return nil }
            return MetricHistorySection("\(date) (\(rows.count) samples)", rows: rows)
        }
    }

    private func activityHistory(from days: [[String: Any]]) -> [MetricHistorySection] {
        days.compactMap { day in
            guard let date = day["date"] as? String,
                  let steps = day["steps"] as? [String: Any],
                  !steps.isEmpty else { return nil }
            return MetricHistorySection(date, rows: [
                MetricDetailRow("Steps", "\(stringValue(from: steps["Step"])) steps", id: "\(date)-steps"),
                MetricDetailRow("Distance", "\(stringValue(from: steps["Dis"])) km", id: "\(date)-distance"),
                MetricDetailRow("Calories", "\(stringValue(from: steps["Cal"])) kcal", id: "\(date)-calories")
            ])
        }
    }

    private func hrvHistory(from days: [[String: Any]]) -> [MetricHistorySection] {
        days.compactMap { day in
            guard let date = day["date"] as? String, let hrv = day["hrv"] else { return nil }
            if let dictionary = hrv as? [String: Any], dictionary["skipped"] as? Bool == true {
                return MetricHistorySection(date, rows: [
                    MetricDetailRow("Status", "Skipped", id: "\(date)-hrv-status"),
                    MetricDetailRow("Reason", stringValue(from: dictionary["reason"]), id: "\(date)-hrv-reason")
                ])
            }
            return MetricHistorySection(date, rows: [
                MetricDetailRow("Records", "\(recordCount(hrv))", id: "\(date)-hrv-count")
            ])
        }
    }

    private func ecgHistory(from days: [[String: Any]]) -> [MetricHistorySection] {
        days.compactMap { day in
            guard let date = day["date"] as? String else { return nil }
            let count = recordCount(day["offlineECG"])
            guard count > 0 else { return nil }
            return MetricHistorySection(date, rows: [
                MetricDetailRow("Records", "\(count)", id: "\(date)-ecg-count")
            ])
        }
    }

    private func sleepRecords(in day: [String: Any]) -> [[String: Any]] {
        for key in ["accurateSleep", "sleep"] {
            guard let payload = day[key] as? [String: Any],
                  let records = payload["records"] as? [[String: Any]],
                  !records.isEmpty else { continue }
            return records
        }
        return []
    }

    private func displayRecordTime(from record: [String: Any], fallback: String) -> String {
        let value = stringValue(from: record["Time"] ?? record["time"] ?? record["date"])
        return value == "--" ? fallback : value
    }

    private func readBaseDailyData(completion: @escaping (Bool) -> Void) {
        manager?.peripheralManage.veepooSdkStartReadDeviceAllData { [weak self] state, totalDay, currentReadDayNumber, progress in
            DispatchQueue.main.async {
                self?.collectionStatusLabel.text = "Base sync: \(currentReadDayNumber)/\(totalDay) \(progress)%"
                self?.appendStatus("Base daily sync \(self?.readStateName(state) ?? "state \(state.rawValue)") \(currentReadDayNumber)/\(totalDay) \(progress)%")

                if state == .complete {
                    completion(true)
                } else if state == .invalid {
                    completion(false)
                }
            }
        }
    }

    private func readBaseDailyDataWithTimeout(completion: @escaping (Bool) -> Void) {
        var didFinish = false
        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self, !didFinish else { return }
            didFinish = true
            self.recordTimedOutRead(
                name: "sdk base daily sync",
                timeout: self.syncBaseDailyTimeout,
                duration: self.syncBaseDailyTimeout
            )
            completion(false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + syncBaseDailyTimeout, execute: timeoutWork)
        readBaseDailyData { success in
            guard !didFinish else { return }
            didFinish = true
            timeoutWork.cancel()
            completion(success)
        }
    }

    private func readOxygenDailyDataIfNeeded(completion: @escaping (Bool) -> Void) {
        let model = manager?.peripheralManage.peripheralModel
        guard (model?.oxygenType ?? 0) != 0 || (model?.bloodOxygenType ?? 0) != 0 else {
            completion(false)
            return
        }

        manager?.peripheralManage.veepooSdkStartReadDeviceOxygenData { [weak self] state, totalDay, currentReadDayNumber, progress in
            DispatchQueue.main.async {
                self?.collectionStatusLabel.text = "Oxygen sync: \(currentReadDayNumber)/\(totalDay) \(progress)%"
                self?.appendStatus("Oxygen daily sync \(self?.readStateName(state) ?? "state \(state.rawValue)") \(currentReadDayNumber)/\(totalDay) \(progress)%")

                if state == .complete {
                    completion(true)
                } else if state == .invalid {
                    completion(false)
                }
            }
        }
    }

    private func readHRVDailyDataIfNeeded(completion: @escaping (Bool) -> Void) {
        guard manager?.peripheralManage.peripheralModel.hrvType ?? 0 != 0 else {
            completion(false)
            return
        }

        manager?.peripheralManage.veepooSdkStartReadDeviceHrvData { [weak self] state, totalDay, currentReadDayNumber, progress in
            DispatchQueue.main.async {
                self?.collectionStatusLabel.text = "HRV sync: \(currentReadDayNumber)/\(totalDay) \(progress)%"
                self?.appendStatus("HRV daily sync \(self?.readStateName(state) ?? "state \(state.rawValue)") \(currentReadDayNumber)/\(totalDay) \(progress)%")

                if state == .complete {
                    completion(true)
                } else if state == .invalid {
                    completion(false)
                }
            }
        }
    }

    private func readTemperatureDailyDataIfNeeded(completion: @escaping (Bool) -> Void) {
        let temperatureType = manager?.peripheralManage.peripheralModel.temperatureType ?? 0
        guard temperatureType != 0, temperatureType != 5 else {
            completion(false)
            return
        }

        manager?.peripheralManage.veepooSdkStartReadDeviceTemperatureData { [weak self] state, totalDay, currentReadDayNumber, progress in
            DispatchQueue.main.async {
                self?.collectionStatusLabel.text = "Temperature sync: \(currentReadDayNumber)/\(totalDay) \(progress)%"
                self?.appendStatus("Temperature daily sync \(self?.readStateName(state) ?? "state \(state.rawValue)") \(currentReadDayNumber)/\(totalDay) \(progress)%")

                if state == .complete {
                    completion(true)
                } else if state == .invalid {
                    completion(false)
                }
            }
        }
    }

    private func extractAndStoreResearchSnapshot(
        reason: String,
        dailySyncSucceeded: Bool,
        completion: @escaping (URL?) -> Void
    ) {
        guard let model = manager?.peripheralManage.peripheralModel else {
            completion(nil)
            return
        }

        let deviceId = model.deviceAddress ?? model.deviceName ?? "unknown-device"
        let deviceName = model.deviceName ?? "ES02"
        let tableID = model.deviceAddress ?? ""
        let stature = UInt(model.deviceStature)
        let syncId = UUID().uuidString
        let dispatchGroup = DispatchGroup()
        var days: [[String: Any]] = []
        let directDaysByDate = Dictionary(
            uniqueKeysWithValues: latestSafeSyncDays.compactMap { payload -> (String, [String: Any])? in
                guard let date = payload["date"] as? String else { return nil }
                return (date, payload)
            }
        )

        for daysAgo in 0..<3 {
            let date = WatchResearchStore.dayString(daysAgo: daysAgo)
            var dayPayload = extractSynchronousDayPayload(date: date, tableID: tableID, model: model)
            dayPayload["directWatchReads"] = directDaysByDate[date] ?? [
                "notRead": true,
                "reason": "No direct read payload was produced for this date."
            ]
            dispatchGroup.enter()
            VPDataBaseOperation.veepooSDKGetStepData(
                withDate: date,
                andTableID: tableID,
                changeUserStature: stature
            ) { stepDict in
                dayPayload["steps"] = stepDict ?? [:]
                days.append(dayPayload)
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            let sortedDays = days.sorted {
                ($0["date"] as? String ?? "") > ($1["date"] as? String ?? "")
            }
            var metadata: [String: Any] = [
                "status": dailySyncSucceeded ? "sdk_database_sync_completed" : "local_snapshot_partial",
                "bulkDailyReadDisabledReason": "SDK bulk read is used only after Objective-C categories are linked with -ObjC; direct fallback is used if that sync fails.",
                "autoCollectionEnabled": self.isAutoCollectionEnabled,
                "manualDisconnect": self.isManuallyDisconnected,
                "capabilities": self.capabilityPayload(from: model),
                "storageRoot": WatchResearchStore.shared.rootDirectory.path
            ]
            metadata["directWatchSync"] = self.latestSafeSyncMetadata

            do {
                let fileURL = try WatchResearchStore.shared.saveSyncSnapshot(
                    deviceId: deviceId,
                    deviceName: deviceName,
                    syncId: syncId,
                    reason: reason,
                    days: sortedDays,
                    metadata: metadata
                )
                let syncTime = self.displayTime(Date())
                self.lastSyncLabel.text = "Last sync: \(syncTime)"
                self.watchStatusSyncLabel.text = "Last synced: \(syncTime)"
                self.localStorageLabel.text = "Local data: \(WatchResearchStore.shared.localStorageDetailSummary())"
                self.viewModel.lastSync = syncTime
                self.viewModel.localStorage = WatchResearchStore.shared.localStorageDetailSummary()
                self.applyLatestSnapshotToDashboard(from: fileURL)
                self.runCoachAnalysisIfNeeded(syncId: syncId)
                completion(fileURL)
            } catch {
                self.appendStatus("Local JSON save failed: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    private func extractSynchronousDayPayload(date: String, tableID: String, model: VPPeripheralModel) -> [String: Any] {
        var day: [String: Any] = [
            "date": date,
            "heartRaw": VPDataBaseOperation.veepooSDKGetOriginalData(withDate: date, andTableID: tableID) ?? [:],
            "heartHalfHour": VPDataBaseOperation.veepooSDKGetOriginalChangeHalfHourData(withDate: date, andTableID: tableID) ?? [:],
            "bloodPressure": VPDataBaseOperation.veepooSDKGetBloodData(withDate: date, andTableID: tableID) ?? []
        ]

        if isAccurateSleepType(model.sleepType) {
            let records = VPDataBaseOperation.veepooSDKGetAccurateSleepData(withDate: date, andTableID: tableID)?.map { $0 } ?? []
            let payload = sleepRecordsPayload(records, sleepType: model.sleepType, source: "sdk_database")
            day["sleep"] = payload
            day["accurateSleep"] = payload
        } else {
            let records = VPDataBaseOperation.veepooSDKGetSleepData(withDate: date, andTableID: tableID)?.map { $0 } ?? []
            day["sleep"] = sleepRecordsPayload(records, sleepType: model.sleepType, source: "sdk_database")
        }

        if model.oxygenType != 0 || model.bloodOxygenType != 0 {
            day["bloodOxygen"] = VPDataBaseOperation.veepooSDKGetDeviceOxygenData(withDate: date, andTableID: tableID) ?? []
        } else {
            day["bloodOxygen"] = ["unsupported": true]
        }

        day["hrv"] = [
            "skipped": model.hrvType != 0,
            "unsupported": model.hrvType == 0,
            "reason": "Disabled because this ES02 firmware crashes inside the vendor HRV daily-data parser."
        ]

        if model.temperatureType != 0 {
            day["temperature"] = VPDataBaseOperation.veepooSDKGetDeviceTemperatureData(withDate: date, andTableID: tableID) ?? []
        } else {
            day["temperature"] = ["unsupported": true]
        }

        if model.bloodGlucoseType != 0 {
            day["bloodGlucose"] = VPDataBaseOperation.veepooSDKGetDeviceBloodGlucoseData(withDate: date, andTableID: tableID) ?? []
        } else {
            day["bloodGlucose"] = ["unsupported": true]
        }

        if model.bloodAnalysisType != 0 {
            day["bloodAnalysis"] = VPDataBaseOperation.veepooSDKGetDeviceBloodAnalysisData(withDate: date, andTableID: tableID) ?? []
        } else {
            day["bloodAnalysis"] = ["unsupported": true]
        }

        day["offlineECG"] = VPDataBaseOperation.veepooSDKGetDeviceOffStoreECG(withDate: date, andTableID: tableID) ?? []

        return day
    }

    private func saveSkippedSync(reason: String, activeTest: String) {
        guard let model = manager?.peripheralManage.peripheralModel else { return }
        let deviceId = model.deviceAddress ?? model.deviceName ?? "unknown-device"
        let deviceName = model.deviceName ?? "ES02"

        do {
            let fileURL = try WatchResearchStore.shared.saveSkippedSync(
                deviceId: deviceId,
                deviceName: deviceName,
                reason: reason,
                activeTest: activeTest
            )
            collectionStatusLabel.text = "Skipped sync: \(activeTest) active"
            localStorageLabel.text = "Local data: \(WatchResearchStore.shared.localStorageDetailSummary())"
            appendStatus("Research sync skipped and logged: \(fileURL.lastPathComponent)")
        } catch {
            appendStatus("Failed to log skipped sync: \(error.localizedDescription)")
        }
    }

    @objc private func readCapabilities() {
        guard isVerified, let model = manager?.peripheralManage.peripheralModel else {
            appendStatus("No verified device model yet.")
            return
        }

        let manualTypes = manager?.peripheralManage.supportManualTestType.rawValue ?? 0
        let lines = [
            "Capabilities for \(model.deviceName ?? "device")",
            "address=\(model.deviceAddress ?? "unknown")",
            "heartRateType=\(model.heartRateType)",
            "oxygenType=\(model.oxygenType), bloodOxygenType=\(model.bloodOxygenType)",
            "ecgType=\(model.ecgType), hrvType=\(model.hrvType)",
            "healthGlanceType=\(model.healthGlanceType)",
            "temperatureType=\(model.temperatureType)",
            "sleepType=\(model.sleepType)",
            "runningType=\(model.runningType), runningSaveTimes=\(model.runningSaveTimes)",
            "bloodGlucoseType=\(model.bloodGlucoseType)",
            "bloodAnalysisType=\(model.bloodAnalysisType)",
            "bodyCompositionType=\(model.bodyCompositionType)",
            "manualTestType=0x\(String(manualTypes, radix: 16))",
            "deviceFunctionData=\(hexString(model.deviceFuctionData))",
            "deviceFunctionDataTwo=\(hexString(model.deviceFuctionDataTwo))"
        ]

        updateDeviceTile()
        markUpdated()
        appendStatus(lines.joined(separator: "\n"))
        updateFunctionButtons()
    }

    @objc private func toggleHeartRate() {
        if activeFunction == .heartRate {
            stopActiveFunction()
            return
        }

        startFunction(.heartRate)
        manager?.peripheralManage.veepooSDKTestHeartStart(true) { [weak self] state, value in
            DispatchQueue.main.async {
                if state == .testing {
                    self?.heartTileValueLabel.text = "\(value) bpm"
                    self?.viewModel.heartRate = "\(value) bpm"
                    self?.appendHeartTrend(value)
                    self?.markUpdated()
                } else if state == .start {
                    self?.heartTileValueLabel.text = "starting"
                    self?.viewModel.heartRate = "starting"
                } else {
                    let stateName = self?.heartStateName(state) ?? "state"
                    self?.heartTileValueLabel.text = stateName
                    self?.viewModel.heartRate = stateName
                    self?.markUpdated()
                }
                self?.appendStatus("Heart Rate \(self?.heartStateName(state) ?? "state \(state.rawValue)"), value=\(value)")
                self?.clearActiveIfEnded(state.rawValue, endingValues: [2, 3, 4])
            }
        }
    }

    @objc private func toggleBloodOxygen() {
        if activeFunction == .bloodOxygen {
            stopActiveFunction()
            return
        }

        startFunction(.bloodOxygen)
        manager?.peripheralManage.veepooSDKTestOxygenStart(true) { [weak self] state, value in
            DispatchQueue.main.async {
                if state == .testing {
                    self?.oxygenTileValueLabel.text = "\(value)%"
                    self?.viewModel.oxygen = "\(value)%"
                    self?.appendOxygenTrend(value)
                    self?.markUpdated()
                } else if state == .start {
                    self?.oxygenTileValueLabel.text = "starting"
                    self?.viewModel.oxygen = "starting"
                } else {
                    let stateName = self?.oxygenStateName(state) ?? "state"
                    self?.oxygenTileValueLabel.text = stateName
                    self?.viewModel.oxygen = stateName
                    self?.markUpdated()
                }
                self?.appendStatus("Blood Oxygen \(self?.oxygenStateName(state) ?? "state \(state.rawValue)"), value=\(value)")
                self?.clearActiveIfEnded(state.rawValue, endingValues: [2, 3, 4, 5, 7, 8])
            }
        }
    }

    @objc private func toggleOxygenAndHeart() {
        if activeFunction == .oxygenAndHeart {
            stopActiveFunction()
            return
        }

        startFunction(.oxygenAndHeart)
        manager?.peripheralManage.veepooSDKTestOxygenAndHeartStart(true) { [weak self] state, oxygenValue, heartValue in
            DispatchQueue.main.async {
                if state == .testing {
                    self?.oxygenTileValueLabel.text = "\(oxygenValue)%"
                    self?.heartTileValueLabel.text = "\(heartValue) bpm"
                    self?.viewModel.oxygen = "\(oxygenValue)%"
                    self?.viewModel.heartRate = "\(heartValue) bpm"
                    self?.appendOxygenTrend(oxygenValue)
                    self?.appendHeartTrend(heartValue)
                    self?.markUpdated()
                } else if state == .start {
                    self?.oxygenTileValueLabel.text = "starting"
                    self?.viewModel.oxygen = "starting"
                } else {
                    let stateName = self?.oxygenStateName(state) ?? "state"
                    self?.oxygenTileValueLabel.text = stateName
                    self?.viewModel.oxygen = stateName
                    self?.markUpdated()
                }
                self?.appendStatus("Oxygen + Heart \(self?.oxygenStateName(state) ?? "state \(state.rawValue)"), oxygen=\(oxygenValue), heart=\(heartValue)")
                self?.clearActiveIfEnded(state.rawValue, endingValues: [2, 3, 4, 5, 7, 8])
            }
        }
    }

    @objc private func toggleECG() {
        if activeFunction == .ecg {
            stopActiveFunction()
            return
        }

        guard manager?.peripheralManage.peripheralModel.ecgType ?? 0 != 0 else {
            appendStatus("ECG is not supported by this device model.")
            return
        }

        startFunction(.ecg)
        manager?.peripheralManage.veepooSDKTestECGStart(true) { [weak self] state, progress, model in
            DispatchQueue.main.async {
                let heart = model?.aveHeart ?? model?.muHearts.lastObject.map { "\($0)" } ?? "n/a"
                self?.ecgTileValueLabel.text = "\(self?.ecgStateName(state) ?? "state")\n\(progress)% hr \(heart)"
                self?.viewModel.ecg = "\(progress)% hr \(heart)"
                self?.ecgProgressView.progress = Float(progress) / 100.0
                self?.markUpdated()
                self?.appendStatus("ECG \(self?.ecgStateName(state) ?? "state \(state.rawValue)"), progress=\(progress), heart=\(heart)")
                self?.clearActiveIfEnded(state.rawValue, endingValues: [3, 4, 5, 6, 7])
            }
        }
    }

    @objc private func toggleStepPolling() {
        if stepTimer != nil {
            stopStepPolling()
        } else {
            startStepPolling()
        }
    }

    private func startStepPolling() {
        guard isVerified else {
            appendStatus("Connect to a watch before polling steps.")
            return
        }

        stopActiveFunction(log: false)
        pollSteps()
        stepTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.pollSteps()
        }
        updateFunctionButtons()
        appendStatus("Started step polling.")
    }

    private func stopStepPolling(log: Bool = true) {
        guard stepTimer != nil else { return }
        stepTimer?.invalidate()
        stepTimer = nil
        updateFunctionButtons()

        if log {
            appendStatus("Stopped step polling.")
        }
    }

    private func pollSteps() {
        guard isVerified else { return }

        manager?.peripheralManage.veepooSDK_readStepData(withDayNumber: 0) { [weak self] stepDict in
            DispatchQueue.main.async {
                let steps = self?.stringValue(from: stepDict?["Step"]) ?? "--"
                let distance = self?.stringValue(from: stepDict?["Dis"]) ?? "--"
                let calories = self?.stringValue(from: stepDict?["Cal"]) ?? "--"
                self?.stepsTileValueLabel.text = "\(steps) steps\n\(distance) km / \(calories) kcal"
                self?.viewModel.steps = "\(steps) steps"
                self?.viewModel.distance = distance
                self?.viewModel.calories = calories
                self?.markUpdated()
                self?.appendStatus("Steps: \(steps), distance=\(distance) km, calories=\(calories) kcal")
            }
        }
    }

    @objc private func toggleTemperature() {
        if activeFunction == .temperature {
            stopActiveFunction()
            return
        }

        guard manager?.peripheralManage.peripheralModel.temperatureType ?? 0 != 0 else {
            appendStatus("Temperature is not supported by this device model.")
            return
        }

        startFunction(.temperature)
        manager?.peripheralManage.veepooSDK_temperatureTestStart(true) { [weak self] state, enable, progress, tempValue, originalTempValue in
            DispatchQueue.main.async {
                let body = Double(tempValue) / 10.0
                let skin = Double(originalTempValue) / 10.0
                if state == .open, enable {
                    self?.temperatureTileValueLabel.text = String(format: "%.1f C\nskin %.1f C", body, skin)
                    self?.viewModel.temperature = String(format: "%.1f C / %.1f C", body, skin)
                    self?.markUpdated()
                    if progress >= 100 {
                        self?.activeFunction = nil
                        self?.updateFunctionButtons()
                    }
                } else {
                    self?.temperatureTileValueLabel.text = "\(self?.temperatureStateName(state) ?? "state")\n\(progress)%"
                    self?.viewModel.temperature = "\(self?.temperatureStateName(state) ?? "state") \(progress)%"
                    self?.markUpdated()
                }
                self?.appendStatus("Temperature \(self?.temperatureStateName(state) ?? "state \(state.rawValue)"), enabled=\(enable), progress=\(progress), body=\(body), skin=\(skin)")
                if [0, 2, 9].contains(Int(state.rawValue)) {
                    self?.activeFunction = nil
                    self?.updateFunctionButtons()
                }
            }
        }
    }

    @objc private func toggleHealthGlance() {
        if activeFunction == .healthGlance {
            stopActiveFunction()
            return
        }

        guard manager?.peripheralManage.peripheralModel.healthGlanceType ?? 0 > 1 else {
            appendStatus("Public Health Glance is not supported by this device model.")
            return
        }

        startFunction(.healthGlance)
        manager?.peripheralManage.veepooSDK_healthGlanceTestStart(true, andProgress: { [weak self] progress in
            DispatchQueue.main.async {
                self?.ecgTileValueLabel.text = "health glance\n\(progress)%"
                self?.appendStatus("Health Glance progress=\(progress)%")
            }
        }, andResult: { [weak self] state, model in
            DispatchQueue.main.async {
                let result = model.map {
                    "heart=\($0.heartRate), oxygen=\($0.bloodOxygen), stress=\($0.stress), temp=\($0.bodyTemperature), hrv=\($0.hrv), support=0x\(String($0.functionSupport, radix: 16))"
                } ?? "no model"
                if let model {
                    self?.heartTileValueLabel.text = "\(model.heartRate) bpm"
                    self?.oxygenTileValueLabel.text = "\(model.bloodOxygen)%"
                    self?.ecgTileValueLabel.text = "health glance\nstate \(state.rawValue)"
                    self?.viewModel.heartRate = "\(model.heartRate) bpm"
                    self?.viewModel.oxygen = "\(model.bloodOxygen)%"
                    self?.viewModel.ecg = "health glance"
                    self?.markUpdated()
                }
                self?.appendStatus("Health Glance state=\(state.rawValue), \(result)")
                self?.clearActiveIfEnded(Int(state.rawValue), endingValues: [0, 1, 2, 3, 4, 5, 6, 7])
            }
        })
    }

    @objc private func toggleMicroTest() {
        if activeFunction == .microTest {
            stopActiveFunction()
            return
        }

        guard manager?.peripheralManage.peripheralModel.healthGlanceType == 1 else {
            appendStatus("Custom Micro Test is not supported by this device model.")
            return
        }

        startFunction(.microTest)
        manager?.peripheralManage.veepooSDKMicroTestOpenState(true, andProgress: { [weak self] progress in
            DispatchQueue.main.async {
                self?.ecgTileValueLabel.text = "micro test\n\(progress)%"
                self?.appendStatus("Micro Test progress=\(progress)%")
            }
        }, andFail: { [weak self] error in
            DispatchQueue.main.async {
                self?.appendStatus("Micro Test failed: \(error?.localizedDescription ?? "unknown error")")
                self?.activeFunction = nil
                self?.updateFunctionButtons()
            }
        }, andSuccess: { [weak self] endState, model in
            DispatchQueue.main.async {
                let result = model.map {
                    "heart=\($0.heartRate), oxygen=\($0.bloodOxygen), pressure=\($0.pressure), temp=\($0.bodyTemperature), bp=\($0.systolicBloodPressure)/\($0.diastolicBloodPressure), hrv=\($0.hrv)"
                } ?? "no model"
                if let model {
                    self?.heartTileValueLabel.text = "\(model.heartRate) bpm"
                    self?.oxygenTileValueLabel.text = "\(model.bloodOxygen)%"
                    self?.ecgTileValueLabel.text = "micro test\nhrv \(model.hrv)"
                    self?.viewModel.heartRate = "\(model.heartRate) bpm"
                    self?.viewModel.oxygen = "\(model.bloodOxygen)%"
                    self?.viewModel.ecg = "hrv \(model.hrv)"
                    self?.markUpdated()
                }
                self?.appendStatus("Micro Test end=\(endState), \(result)")
                if endState {
                    self?.activeFunction = nil
                    self?.updateFunctionButtons()
                }
            }
        }, andHeartRate: { [weak self] heartRateStatus in
            DispatchQueue.main.async {
                self?.heartTileValueLabel.text = "\(heartRateStatus) bpm"
                self?.viewModel.heartRate = "\(heartRateStatus) bpm"
                self?.markUpdated()
                self?.appendStatus("Micro Test heart status=\(heartRateStatus)")
            }
        }, andPPG: { [weak self] ppgArray in
            DispatchQueue.main.async {
                self?.appendStatus("Micro Test PPG samples=\(ppgArray?.count ?? 0)")
            }
        })
    }

    @objc private func stopActiveTapped() {
        stopActiveFunction()
    }

    private func startFunction(_ function: ActiveFunction) {
        guard isVerified else {
            appendStatus("Connect to a watch before starting \(function.rawValue).")
            return
        }

        if activeFunction != nil {
            stopActiveFunction()
        }

        stopStepPolling(log: false)
        activeFunction = function
        updateFunctionButtons()
        appendStatus("Starting \(function.rawValue)...")
    }

    private func stopActiveFunction(log: Bool = true) {
        guard let function = activeFunction else { return }

        switch function {
        case .heartRate:
            manager?.peripheralManage.veepooSDKTestHeartStart(false, testResult: nil)
        case .bloodOxygen:
            manager?.peripheralManage.veepooSDKTestOxygenStart(false, testResult: nil)
        case .oxygenAndHeart:
            manager?.peripheralManage.veepooSDKTestOxygenAndHeartStart(false, testResult: nil)
        case .ecg:
            manager?.peripheralManage.veepooSDKTestECGStart(false, testResult: nil)
        case .temperature:
            manager?.peripheralManage.veepooSDK_temperatureTestStart(false, result: nil)
        case .healthGlance:
            manager?.peripheralManage.veepooSDK_healthGlanceTestStart(false, andProgress: nil, andResult: nil)
        case .microTest:
            manager?.peripheralManage.veepooSDKMicroTestOpenState(false, andProgress: nil, andFail: nil, andSuccess: nil, andHeartRate: nil, andPPG: nil)
        }

        activeFunction = nil
        updateFunctionButtons()

        if log {
            appendStatus("Stopped \(function.rawValue).")
        }
    }

    private func clearActiveIfEnded(_ rawState: Int, endingValues: Set<Int>) {
        guard activeFunction != nil, endingValues.contains(rawState) else { return }
        activeFunction = nil
        updateFunctionButtons()
    }

    private func updateDeviceTile() {
        guard let model = manager?.peripheralManage.peripheralModel else {
            deviceTileValueLabel.text = "--"
            return
        }

        let name = model.deviceName?.isEmpty == false ? model.deviceName! : "Device"
        let address = model.deviceAddress ?? "unknown"
        deviceTileValueLabel.text = "\(name)\n\(address)"
        watchStatusNameLabel.text = name
        profileNameLabel.text = name
        profileAddressLabel.text = "Address: \(address)"
        viewModel.deviceName = name
        viewModel.deviceAddress = address
    }

    private func resetResultTiles() {
        deviceTileValueLabel.text = "--"
        batteryTileValueLabel.text = "--"
        watchStatusNameLabel.text = "ES02"
        watchStatusSyncLabel.text = "Last synced: not yet"
        profileNameLabel.text = "ES02"
        profileAddressLabel.text = "Address: --"
        profileBatteryLabel.text = "Battery: --"
        heartTileValueLabel.text = "--"
        oxygenTileValueLabel.text = "--"
        ecgTileValueLabel.text = "--"
        updatedTileValueLabel.text = "--"
        stepsTileValueLabel.text = "--"
        temperatureTileValueLabel.text = "--"
        heartSparklineView.values = []
        oxygenSparklineView.values = []
        ecgProgressView.progress = 0
        viewModel.battery = "--"
        viewModel.heartRate = "--"
        viewModel.oxygen = "--"
        viewModel.ecg = "--"
        viewModel.hrv = "--"
        viewModel.bloodPressure = "--"
        viewModel.bloodGlucose = "--"
        viewModel.sleepDuration = "--"
        viewModel.sleepScore = "--"
        viewModel.sleepScoreDetail = "No sleep score yet"
        viewModel.steps = "--"
        viewModel.distance = "--"
        viewModel.calories = "--"
        viewModel.temperature = "--"
        viewModel.updatedAt = "--"
        viewModel.metricDetails = [:]
    }

    private func markUpdated() {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        let updated = formatter.string(from: Date())
        updatedTileValueLabel.text = updated
        viewModel.updatedAt = updated
    }

    private func heartStateName(_ state: VPTestHeartState) -> String {
        switch state {
        case .start:
            return "starting"
        case .testing:
            return "testing"
        case .notWear:
            return "not worn"
        case .deviceBusy:
            return "device busy"
        case .over:
            return "ended"
        @unknown default:
            return "state \(state.rawValue)"
        }
    }

    private func oxygenStateName(_ state: VPTestOxygenState) -> String {
        switch state {
        case .start:
            return "starting"
        case .testing:
            return "testing"
        case .notWear:
            return "not worn"
        case .deviceBusy:
            return "device busy"
        case .over:
            return "ended"
        case .noFunction:
            return "not supported"
        case .calibration:
            return "calibrating"
        case .calibrationComplete:
            return "calibration complete"
        case .invalid:
            return "invalid"
        @unknown default:
            return "state \(state.rawValue)"
        }
    }

    private func ecgStateName(_ state: VPTestECGState) -> String {
        switch state {
        case .start:
            return "starting"
        case .testing:
            return "testing"
        case .notLead:
            return "lead off"
        case .deviceBusy:
            return "device busy"
        case .over:
            return "ended"
        case .failure:
            return "failed"
        case .complete:
            return "complete"
        case .noFunction:
            return "not supported"
        @unknown default:
            return "state \(state.rawValue)"
        }
    }

    private func temperatureStateName(_ state: VPTemperatureTestState) -> String {
        switch state {
        case .unsupported:
            return "not supported"
        case .open:
            return "testing"
        case .close:
            return "ended"
        case .notWear:
            return "not worn"
        @unknown default:
            return "state \(state.rawValue)"
        }
    }

    private func appendHeartTrend(_ value: UInt) {
        appendTrendValue(Double(value), to: heartSparklineView)
    }

    private func appendOxygenTrend(_ value: UInt) {
        appendTrendValue(Double(value), to: oxygenSparklineView)
    }

    private func appendTrendValue(_ value: Double, to view: SparklineView) {
        guard value > 0 else { return }
        var values = view.values
        values.append(value)
        if values.count > 60 {
            values.removeFirst(values.count - 60)
        }
        view.values = values
    }

    private struct LatestHeartRate {
        let date: String
        let time: String
        let value: Int
        let average: Int
        let count: Int
    }

    private struct LatestMetricValue {
        let date: String
        let time: String
        let value: String
        let count: Int

        func rows(prefix: String, unit: String) -> [MetricDetailRow] {
            [
                MetricDetailRow("Date", date),
                MetricDetailRow("Time", time),
                MetricDetailRow(prefix, "\(value)\(unit)"),
                MetricDetailRow("Samples", "\(count)")
            ]
        }
    }

    private struct LatestBloodPressure {
        let date: String
        let time: String
        let systolic: Int
        let diastolic: Int
        let count: Int
    }

    private struct LatestGlucose {
        let date: String
        let time: String
        let value: String
        let count: Int
    }

    private struct LatestSleep {
        let date: String
        let record: [String: Any]
    }

    private struct SleepScoreBreakdown {
        let total: Int
        let category: String
        let durationMinutes: Int
        let durationPoints: Int
        let consistencyPoints: Int
        let interruptionPoints: Int
    }

    private func snapshotDays(from payload: [String: Any]) -> [[String: Any]] {
        let rawDays = payload["days"] as? [Any] ?? []
        return rawDays
            .compactMap { $0 as? [String: Any] }
            .sorted { ($0["date"] as? String ?? "") > ($1["date"] as? String ?? "") }
    }

    private func firstDay(in days: [[String: Any]], where predicate: ([String: Any]) -> Bool) -> [String: Any]? {
        days.first(where: predicate)
    }

    private func latestHeartRate(from days: [[String: Any]]) -> LatestHeartRate? {
        for day in days {
            guard let date = day["date"] as? String,
                  let samples = day["heartHalfHour"] as? [String: Any] else { continue }

            let readings = samples.compactMap { key, value -> (time: String, value: Int)? in
                guard let dictionary = value as? [String: Any],
                      let heart = intValue(from: dictionary["heartValue"]),
                      heart > 0 else { return nil }
                return (key, heart)
            }
            .sorted { $0.time < $1.time }

            guard let latest = readings.last else { continue }
            let average = Int(round(Double(readings.reduce(0) { $0 + $1.value }) / Double(readings.count)))
            return LatestHeartRate(date: date, time: latest.time, value: latest.value, average: average, count: readings.count)
        }
        return nil
    }

    private func latestDictionaryValue(
        from days: [[String: Any]],
        metric: String,
        valueKeys: [String],
        requirePositive: Bool
    ) -> LatestMetricValue? {
        for day in days {
            guard let date = day["date"] as? String,
                  let records = day[metric] as? [[String: Any]],
                  !records.isEmpty else { continue }

            let matching = records.reversed().first { record in
                guard let value = valueForFirstKey(in: record, keys: valueKeys) else { return false }
                guard requirePositive else { return true }
                return (doubleValue(from: value) ?? 0) > 0
            }

            guard let record = matching,
                  let rawValue = valueForFirstKey(in: record, keys: valueKeys) else { continue }
            return LatestMetricValue(
                date: date,
                time: stringValue(from: record["Time"] ?? record["time"] ?? record["date"]),
                value: stringValue(from: rawValue),
                count: records.count
            )
        }
        return nil
    }

    private func latestBloodPressure(from days: [[String: Any]]) -> LatestBloodPressure? {
        for day in days {
            guard let date = day["date"] as? String,
                  let records = day["bloodPressure"] as? [[String: Any]],
                  !records.isEmpty else { continue }

            for record in records.reversed() {
                guard let systolic = intValue(from: record["systolic"]),
                      let diastolic = intValue(from: record["diastolic"]),
                      systolic > 0,
                      diastolic > 0 else { continue }
                return LatestBloodPressure(
                    date: date,
                    time: stringValue(from: record["Time"] ?? record["time"]),
                    systolic: systolic,
                    diastolic: diastolic,
                    count: records.count
                )
            }
        }
        return nil
    }

    private func latestGlucose(from days: [[String: Any]]) -> LatestGlucose? {
        for day in days {
            guard let date = day["date"] as? String,
                  let records = day["bloodGlucose"] as? [[String: Any]],
                  !records.isEmpty else { continue }

            for record in records.reversed() {
                let glucoseArray = record["bloodGlucoses"] as? [Any] ?? []
                let value = glucoseArray.compactMap { stringValue(from: $0) == "--" ? nil : stringValue(from: $0) }.last
                    ?? stringValue(from: record["bloodGlucose"] ?? record["value"])
                guard value != "--" else { continue }
                return LatestGlucose(
                    date: date,
                    time: stringValue(from: record["time"] ?? record["Time"]),
                    value: value,
                    count: records.count
                )
            }
        }
        return nil
    }

    private func latestSleepRecord(from days: [[String: Any]]) -> LatestSleep? {
        for day in days {
            guard let date = day["date"] as? String else { continue }
            for key in ["accurateSleep", "sleep"] {
                guard let payload = day[key] as? [String: Any],
                      let records = payload["records"] as? [[String: Any]],
                      let record = records.first else { continue }
                return LatestSleep(date: date, record: record)
            }
        }
        return nil
    }

    private func sleepScore(for record: [String: Any], in days: [[String: Any]]) -> SleepScoreBreakdown {
        let durationMinutes = intValue(from: record["sleepDuration"])
            ?? ((intValue(from: record["deepDuration"]) ?? 0) + (intValue(from: record["lightDuration"]) ?? 0))
        let goalMinutes = 480
        let durationPoints = min(50, max(0, Int(round((Double(durationMinutes) / Double(goalMinutes)) * 50.0))))

        let currentStart = sleepStartMinute(from: record)
        let baselineStarts = days
            .compactMap { day -> [String: Any]? in
                guard let date = day["date"] as? String,
                      let sleepDate = record["sleepTime"] as? String,
                      !sleepDate.hasPrefix(date) else { return nil }
                return latestSleepRecord(from: [day])?.record
            }
            .compactMap { sleepStartMinute(from: $0) }

        let consistencyPoints: Int
        if let currentStart, !baselineStarts.isEmpty {
            let average = Int(round(Double(baselineStarts.reduce(0, +)) / Double(baselineStarts.count)))
            let drift = circularMinuteDistance(currentStart, average)
            consistencyPoints = max(0, 30 - max(0, drift - 60) / 10)
        } else {
            consistencyPoints = currentStart == nil ? 24 : 30
        }

        let awakeMinutes = intValue(from: record["getUpDuration"]) ?? 0
        let wakeEvents = intValue(from: record["getUpTimes"]) ?? 0
        let awakePenalty = max(0, awakeMinutes - 11) / 4
        let eventPenalty = max(0, wakeEvents - 2) / 2
        let interruptionPoints = max(0, 20 - awakePenalty - eventPenalty)
        let total = min(100, max(0, durationPoints + consistencyPoints + interruptionPoints))

        return SleepScoreBreakdown(
            total: total,
            category: sleepScoreCategory(total),
            durationMinutes: durationMinutes,
            durationPoints: durationPoints,
            consistencyPoints: consistencyPoints,
            interruptionPoints: interruptionPoints
        )
    }

    private func sleepStartMinute(from record: [String: Any]) -> Int? {
        guard let sleepTime = record["sleepTime"] as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let date = formatter.date(from: sleepTime) else { return nil }
        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func circularMinuteDistance(_ lhs: Int, _ rhs: Int) -> Int {
        let direct = abs(lhs - rhs)
        return min(direct, 1440 - direct)
    }

    private func sleepScoreCategory(_ score: Int) -> String {
        switch score {
        case 96...100: return "Very High"
        case 81...95: return "High"
        case 61...80: return "OK"
        case 41...60: return "Low"
        default: return "Very Low"
        }
    }

    private func durationText(minutes: Int) -> String {
        guard minutes > 0 else { return "0m" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }

    private func displayTimestamp(_ value: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: value) {
            return displayTime(date)
        }
        return value
    }

    private func isNonEmptyDictionary(_ value: Any?) -> Bool {
        guard let dictionary = value as? [String: Any] else { return false }
        return !dictionary.isEmpty
    }

    private func recordCount(_ value: Any?) -> Int {
        if let array = value as? [Any] { return array.count }
        if let dictionary = value as? [String: Any],
           let records = dictionary["records"] as? [Any] {
            return records.count
        }
        if let dictionary = value as? [String: Any], !dictionary.isEmpty { return 1 }
        return 0
    }

    private func valueForFirstKey(in dictionary: [String: Any], keys: [String]) -> Any? {
        for key in keys {
            if let value = dictionary[key] {
                return value
            }
        }
        return nil
    }

    private func intValue(from value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String {
            if let int = Int(string) { return int }
            if let double = Double(string), double.isFinite { return Int(double) }
        }
        return nil
    }

    private func doubleValue(from value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private func stringValue(from value: Any?) -> String {
        if let string = value as? String {
            return string
        }

        if let number = value as? NSNumber {
            return number.stringValue
        }

        return "--"
    }

    private func setFunctionButtonsVisible(_ visible: Bool) {
        functionPanel.isHidden = !visible
    }

    private func setResultsPanelVisible(_ visible: Bool) {
        resultsPanel.isHidden = !visible
    }

    private func setCollectionPanelVisible(_ visible: Bool) {
        collectionPanel.isHidden = !visible
    }

    private func applyCurrentTabVisibility() {
        let showMainUI = isVerified
        tabControl.isHidden = !showMainUI
        resultsPanel.isHidden = !(showMainUI && currentTab == .insights)
        collectionPanel.isHidden = !(showMainUI && currentTab == .profile)
        functionPanel.isHidden = !(showMainUI && currentTab == .profile)
        debugLogButton.isHidden = !(showMainUI && currentTab == .profile)
        statusLabel.isHidden = !(showMainUI && currentTab == .profile && isDebugLogVisible)
    }

    private func updateCollectionLabels() {
        if isCollectionSyncing {
            collectionStatusLabel.text = "Status: syncing"
        } else if isManuallyDisconnected {
            collectionStatusLabel.text = "Status: manual disconnect, auto-sync paused"
        } else if isAutoCollectionEnabled {
            collectionStatusLabel.text = isVerified ? "Status: auto-sync every 10 minutes" : "Status: waiting for watch"
        } else {
            collectionStatusLabel.text = "Status: auto-sync off"
        }

        if lastSyncLabel.text?.isEmpty ?? true {
            lastSyncLabel.text = "Last sync: not yet"
        }

        if let nextCollectionDate {
            nextSyncLabel.text = "Next sync: \(displayTime(nextCollectionDate))"
        } else {
            nextSyncLabel.text = "Next sync: not scheduled"
        }

        localStorageLabel.text = "Local data: \(WatchResearchStore.shared.localStorageDetailSummary())"
        autoCollectionButton.setTitle(isAutoCollectionEnabled ? "Auto-sync On" : "Auto-sync Off", for: .normal)
        exportLatestSyncButton.isEnabled = WatchResearchStore.shared.latestSyncFileURL() != nil
        watchStatusAutoLabel.text = isAutoCollectionEnabled ? "Auto-sync on" : "Auto-sync off"
        viewModel.autoSyncEnabled = isAutoCollectionEnabled
        viewModel.localStorage = WatchResearchStore.shared.localStorageDetailSummary()
        viewModel.canExport = WatchResearchStore.shared.latestSyncFileURL() != nil
        if let nextCollectionDate {
            viewModel.nextSync = displayTime(nextCollectionDate)
        } else {
            viewModel.nextSync = "not scheduled"
        }
        if let lastText = lastSyncLabel.text?.replacingOccurrences(of: "Last sync: ", with: ""), !lastText.isEmpty {
            viewModel.lastSync = lastText
        }
    }

    private func updateFunctionButtons() {
        let connected = isVerified
        let hasActiveFunction = activeFunction != nil
        let isPollingSteps = stepTimer != nil
        let model = manager?.peripheralManage.peripheralModel

        readCapabilitiesButton.isEnabled = connected && !hasActiveFunction && !isPollingSteps
        readBatteryButton.isEnabled = connected && !hasActiveFunction && !isPollingSteps
        syncNowButton.isEnabled = connected && !hasActiveFunction && !isPollingSteps && !isCollectionSyncing
        exportLatestSyncButton.isEnabled = WatchResearchStore.shared.latestSyncFileURL() != nil
        profileDisconnectButton.isEnabled = connected
        heartRateButton.isEnabled = connected && (activeFunction == nil || activeFunction == .heartRate)
        bloodOxygenButton.isEnabled = connected && (activeFunction == nil || activeFunction == .bloodOxygen)
        oxygenAndHeartButton.isEnabled = connected && (activeFunction == nil || activeFunction == .oxygenAndHeart)
        ecgButton.isEnabled = connected && (activeFunction == nil || activeFunction == .ecg) && (model?.ecgType ?? 0 != 0)
        stepPollingButton.isEnabled = connected && !hasActiveFunction
        temperatureButton.isEnabled = connected && (activeFunction == nil || activeFunction == .temperature) && (model?.temperatureType ?? 0 != 0)
        healthGlanceButton.isEnabled = connected && (activeFunction == nil || activeFunction == .healthGlance) && (model?.healthGlanceType ?? 0 > 1)
        microTestButton.isEnabled = connected && (activeFunction == nil || activeFunction == .microTest) && (model?.healthGlanceType == 1)
        stopActiveTestButton.isEnabled = connected && hasActiveFunction

        heartRateButton.setTitle(activeFunction == .heartRate ? "Stop Heart Rate" : "Start Heart Rate", for: .normal)
        bloodOxygenButton.setTitle(activeFunction == .bloodOxygen ? "Stop Blood Oxygen" : "Start Blood Oxygen", for: .normal)
        oxygenAndHeartButton.setTitle(activeFunction == .oxygenAndHeart ? "Stop O2 + Heart" : "Start O2 + Heart", for: .normal)
        ecgButton.setTitle(activeFunction == .ecg ? "Stop ECG" : "Start ECG", for: .normal)
        stepPollingButton.setTitle(isPollingSteps ? "Stop Step Polling" : "Start Step Polling", for: .normal)
        temperatureButton.setTitle(activeFunction == .temperature ? "Stop Temperature" : "Start Temperature", for: .normal)
        healthGlanceButton.setTitle(activeFunction == .healthGlance ? "Stop Health Glance" : "Health Glance", for: .normal)
        microTestButton.setTitle(activeFunction == .microTest ? "Stop Micro Test" : "Micro Test", for: .normal)

        functionButtons.forEach { button in
            button.alpha = button.isEnabled ? 1.0 : 0.45
        }
        viewModel.canSync = syncNowButton.isEnabled
        viewModel.canExport = exportLatestSyncButton.isEnabled
        viewModel.canDisconnect = profileDisconnectButton.isEnabled
    }

    private func hexString(_ data: Data?) -> String {
        guard let data, !data.isEmpty else {
            return "none"
        }

        return data.map { String(format: "%02x", $0) }.joined()
    }

    private func readStateName(_ state: VPReadDeviceBaseDataState) -> String {
        switch state {
        case .start:
            return "start"
        case .reading:
            return "reading"
        case .complete:
            return "complete"
        case .invalid:
            return "invalid"
        @unknown default:
            return "state \(state.rawValue)"
        }
    }

    private func capabilityPayload(from model: VPPeripheralModel) -> [String: Any] {
        [
            "heartRateType": model.heartRateType,
            "oxygenType": model.oxygenType,
            "bloodOxygenType": model.bloodOxygenType,
            "ecgType": model.ecgType,
            "hrvType": model.hrvType,
            "temperatureType": model.temperatureType,
            "sleepType": model.sleepType,
            "saveDays": model.saveDays,
            "hrvSupportAllDay": model.hrvSupportAllDay,
            "runningType": model.runningType,
            "runningSaveTimes": model.runningSaveTimes,
            "bloodGlucoseType": model.bloodGlucoseType,
            "bloodAnalysisType": model.bloodAnalysisType,
            "bodyCompositionType": model.bodyCompositionType
        ]
    }

    private func displayTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }

    private func appendStatus(_ message: String) {
        let previous = statusLabel.text ?? ""
        let next = previous.isEmpty ? message : "\(message)\n\(previous)"
        statusLabel.text = next
            .split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(80)
            .joined(separator: "\n")
        viewModel.appendLog(message)
        print("[WatchProbe] \(message)")
    }

    private func displayName(for model: VPPeripheralModel) -> String {
        let name = model.deviceName?.isEmpty == false ? model.deviceName! : "Unnamed"
        let address = model.deviceAddress ?? "no-address"
        return "\(name) / \(address)"
    }
}

extension ProbeViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        devices.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "DeviceCell")
        let model = devices[indexPath.row]
        cell.textLabel?.text = displayName(for: model)
        cell.detailTextLabel?.text = "RSSI \(model.rssi?.stringValue ?? "?")"
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        connect(to: devices[indexPath.row])
    }
}

private extension UInt16 {
    static func littleEndianValues(from data: Data?) -> [UInt16] {
        guard let data else { return [] }
        var values: [UInt16] = []
        values.reserveCapacity(data.count / 2)

        var index = data.startIndex
        while index < data.endIndex {
            let nextIndex = data.index(after: index)
            guard nextIndex < data.endIndex else { break }
            let low = UInt16(data[index])
            let high = UInt16(data[nextIndex]) << 8
            values.append(low | high)
            index = data.index(after: nextIndex)
        }

        return values
    }
}

final class SparklineView: UIView {
    var values: [Double] = [] {
        didSet { setNeedsDisplay() }
    }

    var lineColor: UIColor = .systemBlue {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .tertiarySystemBackground
        layer.cornerRadius = 6
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .tertiarySystemBackground
        layer.cornerRadius = 6
        clipsToBounds = true
    }

    override func draw(_ rect: CGRect) {
        guard values.count >= 2, let context = UIGraphicsGetCurrentContext() else { return }

        let inset: CGFloat = 8
        let drawRect = rect.insetBy(dx: inset, dy: inset)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 1)
        let step = drawRect.width / CGFloat(values.count - 1)

        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(2)
        context.setLineJoin(.round)
        context.setLineCap(.round)

        for (index, value) in values.enumerated() {
            let x = drawRect.minX + CGFloat(index) * step
            let normalized = (value - minValue) / range
            let y = drawRect.maxY - CGFloat(normalized) * drawRect.height

            if index == 0 {
                context.move(to: CGPoint(x: x, y: y))
            } else {
                context.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.strokePath()
    }
}
