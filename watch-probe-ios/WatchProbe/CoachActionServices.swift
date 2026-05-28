import EventKit
import Foundation
import UIKit

#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

enum CoachCalendarProvider: String, Codable {
    case eventKit
    case google
}

enum CoachCalendarPrivacyMode: String, CaseIterable, Codable {
    case busyOnly
    case titleAware

    var label: String {
        switch self {
        case .busyOnly: return "Busy only"
        case .titleAware: return "Use titles"
        }
    }
}

struct CoachCalendarInfo: Identifiable, Codable, Equatable {
    let id: String
    let provider: CoachCalendarProvider
    let title: String
    let canWrite: Bool

    var storageId: String {
        "\(provider.rawValue):\(id)"
    }
}

struct CoachCalendarBusyBlock: Codable, Equatable {
    let start: Date
    let end: Date
    let title: String?
    let provider: CoachCalendarProvider
}

struct CoachSuggestedTimeSlot: Identifiable, Equatable {
    let id: String
    let start: Date
    let end: Date
    let score: Int
    let reason: String

    var timeLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d h:mm a"
        return formatter.string(from: start)
    }

    var durationLabel: String {
        let minutes = max(1, Int(end.timeIntervalSince(start) / 60))
        return "\(minutes) min"
    }
}

struct CoachCalendarAvailabilitySnapshot {
    let blocks: [CoachCalendarBusyBlock]
    let selectedCalendarCount: Int
    let selectedCalendarNames: [String]

    var summaryText: String {
        if selectedCalendarCount == 0 {
            return "No calendars selected yet."
        }
        let names = selectedCalendarNames.prefix(2).joined(separator: ", ")
        let suffix = selectedCalendarNames.count > 2 ? " + \(selectedCalendarNames.count - 2) more" : ""
        return "Checked \(blocks.count) busy block\(blocks.count == 1 ? "" : "s") from \(names)\(suffix)."
    }
}

struct CoachScheduledCalendarEvent: Identifiable, Codable, Equatable {
    let id: String
    let provider: CoachCalendarProvider
    let calendarId: String
    let actionId: String
    let title: String
    let start: Date
    let end: Date
    let createdAt: Date
}

final class CoachCalendarService: ObservableObject {
    static let shared = CoachCalendarService()

    @Published private(set) var calendars: [CoachCalendarInfo] = []
    @Published private(set) var status = "Calendar not connected"
    @Published private(set) var scheduledEvents: [CoachScheduledCalendarEvent] = []
    var calendarContextChanged: (() -> Void)?
    @Published var privacyMode: CoachCalendarPrivacyMode {
        didSet {
            UserDefaults.standard.set(privacyMode.rawValue, forKey: Self.privacyKey)
        }
    }
    @Published var selectedCalendarStorageIds: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(selectedCalendarStorageIds), forKey: Self.selectedCalendarsKey)
        }
    }
    @Published var writeCalendarStorageId: String {
        didSet {
            UserDefaults.standard.set(writeCalendarStorageId, forKey: Self.writeCalendarKey)
        }
    }

    var hasUsableCalendarContext: Bool {
        !calendars.isEmpty
    }

    var contextFingerprint: String {
        let selected = selectedCalendarStorageIds.sorted().joined(separator: ",")
        return "\(privacyMode.rawValue)|\(selected)|\(writeCalendarStorageId)"
    }

    private static let selectedCalendarsKey = "WatchProbe.selectedCalendarIds"
    private static let writeCalendarKey = "WatchProbe.writeCalendarId"
    private static let privacyKey = "WatchProbe.calendarPrivacyMode"
    private static let scheduledEventsKey = "WatchProbe.scheduledCalendarEvents"
    private let eventStore = EKEventStore()
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {
        let rawPrivacy = UserDefaults.standard.string(forKey: Self.privacyKey) ?? CoachCalendarPrivacyMode.busyOnly.rawValue
        privacyMode = CoachCalendarPrivacyMode(rawValue: rawPrivacy) ?? .busyOnly
        selectedCalendarStorageIds = Set(UserDefaults.standard.stringArray(forKey: Self.selectedCalendarsKey) ?? [])
        writeCalendarStorageId = UserDefaults.standard.string(forKey: Self.writeCalendarKey) ?? ""
        scheduledEvents = Self.loadScheduledEvents()
        refreshEventKitCalendars()
        restoreGoogleCalendarSessionIfAvailable()
    }

    func toggleCalendar(_ calendar: CoachCalendarInfo) {
        if selectedCalendarStorageIds.contains(calendar.storageId) {
            selectedCalendarStorageIds.remove(calendar.storageId)
        } else {
            selectedCalendarStorageIds.insert(calendar.storageId)
        }
        if writeCalendarStorageId.isEmpty, calendar.canWrite {
            writeCalendarStorageId = calendar.storageId
        }
        calendarContextChanged?()
    }

    func chooseWriteCalendar(_ calendar: CoachCalendarInfo) {
        guard calendar.canWrite else { return }
        writeCalendarStorageId = calendar.storageId
        calendarContextChanged?()
    }

    func requestEventKitAccess(completion: @escaping (Bool, String) -> Void) {
        let finish: (Bool, Error?) -> Void = { [weak self] granted, error in
            DispatchQueue.main.async {
                if granted {
                    self?.refreshEventKitCalendars()
                    self?.status = "iOS Calendar connected"
                    self?.calendarContextChanged?()
                    completion(true, "iOS Calendar connected")
                } else {
                    self?.status = error?.localizedDescription ?? "Calendar access not allowed"
                    completion(false, self?.status ?? "Calendar access not allowed")
                }
            }
        }

        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents(completion: finish)
        } else {
            eventStore.requestAccess(to: .event, completion: finish)
        }
    }

    func connectGoogleCalendar(presenting viewController: UIViewController, completion: @escaping (Bool, String) -> Void) {
#if canImport(GoogleSignIn)
        let scopes = [
            "https://www.googleapis.com/auth/calendar.calendarlist.readonly",
            "https://www.googleapis.com/auth/calendar.events"
        ]
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController, hint: nil, additionalScopes: scopes) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error {
                    self?.status = error.localizedDescription
                    completion(false, error.localizedDescription)
                    return
                }
                guard result?.user != nil else {
                    self?.status = "Google Calendar sign-in failed"
                    completion(false, "Google Calendar sign-in failed")
                    return
                }
                self?.status = "Google Calendar connected"
                self?.refreshGoogleCalendarsIfAvailable()
                self?.calendarContextChanged?()
                completion(true, "Google Calendar connected")
            }
        }
#else
        status = "Add GoogleSignIn package to enable direct Google Calendar"
        completion(false, status)
#endif
    }

    func connectGoogleCalendar(completion: @escaping (Bool, String) -> Void) {
        guard let viewController = UIApplication.shared.wpTopViewController() else {
            status = "No active window for Google sign-in"
            completion(false, status)
            return
        }
        connectGoogleCalendar(presenting: viewController, completion: completion)
    }

    func refreshCalendars() {
        refreshEventKitCalendars()
        if !refreshGoogleCalendarsIfAvailable() {
            restoreGoogleCalendarSessionIfAvailable()
        }
    }

    func suggestedSlots(for action: CoachSuggestedAction, completion: @escaping ([CoachSuggestedTimeSlot]) -> Void) {
        let lookback = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let lookahead = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        fetchAvailabilitySnapshot(from: lookback, to: lookahead) { [weak self] snapshot in
            guard let self else {
                completion([])
                return
            }
            let slots = self.scoreSlots(action: action, snapshot: snapshot)
            DispatchQueue.main.async {
                completion(slots)
            }
        }
    }

    func suggestedSlotsWithDiagnostics(for action: CoachSuggestedAction, completion: @escaping ([CoachSuggestedTimeSlot], String) -> Void) {
        let lookback = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let lookahead = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        fetchAvailabilitySnapshot(from: lookback, to: lookahead) { [weak self] snapshot in
            guard let self else {
                completion([], "Calendar availability could not be read.")
                return
            }
            let slots = self.scoreSlots(action: action, snapshot: snapshot)
            DispatchQueue.main.async {
                completion(slots, snapshot.summaryText)
            }
        }
    }

    func add(action: CoachSuggestedAction, at slot: CoachSuggestedTimeSlot, completion: @escaping (Bool, String, CoachScheduledCalendarEvent?) -> Void) {
        guard let calendar = selectedWriteCalendar() else {
            completion(false, "Choose a write calendar first.", nil)
            return
        }
        switch calendar.provider {
        case .eventKit:
            addEventKitEvent(action: action, slot: slot, calendarId: calendar.id, completion: completion)
        case .google:
            addGoogleEvent(action: action, slot: slot, calendarId: calendar.id, completion: completion)
        }
    }

    func scheduledEvents(for actionId: String) -> [CoachScheduledCalendarEvent] {
        scheduledEvents.filter { $0.actionId == actionId }.sorted { $0.start < $1.start }
    }

    func delete(event: CoachScheduledCalendarEvent, completion: @escaping (Bool, String) -> Void) {
        switch event.provider {
        case .eventKit:
            deleteEventKitEvent(event, completion: completion)
        case .google:
            deleteGoogleEvent(event, completion: completion)
        }
    }

    func availabilitySummaryForAI(completion: @escaping ([[String: String]]) -> Void) {
        let start = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        fetchBusyBlocks(from: start, to: end) { [weak self] blocks in
            guard let self else {
                completion([])
                return
            }
            let summary = blocks.prefix(80).map { block in
                [
                    "start": self.isoFormatter.string(from: block.start),
                    "end": self.isoFormatter.string(from: block.end),
                    "title": self.privacyMode == .titleAware ? (block.title ?? "Busy") : "Busy",
                    "provider": block.provider.rawValue
                ]
            }
            completion(summary)
        }
    }

    func availabilityContextForAI(completion: @escaping ([String: Any]) -> Void) {
        let start = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        fetchAvailabilitySnapshot(from: start, to: end) { [weak self] snapshot in
            guard let self else {
                completion([:])
                return
            }
            let blocks = snapshot.blocks.prefix(120).map { block in
                [
                    "start": self.isoFormatter.string(from: block.start),
                    "end": self.isoFormatter.string(from: block.end),
                    "title": self.privacyMode == .titleAware ? (block.title ?? "Busy") : "Busy",
                    "provider": block.provider.rawValue
                ]
            }
            completion([
                "privacyMode": self.privacyMode.rawValue,
                "window": "previous 14 days and next 14 days",
                "selectedCalendarCount": snapshot.selectedCalendarCount,
                "selectedCalendarNames": snapshot.selectedCalendarNames,
                "busyBlockCount": snapshot.blocks.count,
                "busyBlocks": Array(blocks)
            ])
        }
    }

    private func refreshEventKitCalendars() {
        let eventKitCalendars = eventStore.calendars(for: .event).map {
            CoachCalendarInfo(
                id: $0.calendarIdentifier,
                provider: .eventKit,
                title: $0.title,
                canWrite: $0.allowsContentModifications
            )
        }
        mergeCalendars(eventKitCalendars, provider: .eventKit)
    }

    private func mergeCalendars(_ incoming: [CoachCalendarInfo], provider: CoachCalendarProvider) {
        let other = calendars.filter { $0.provider != provider }
        calendars = (other + incoming).sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        let refreshedProviderPrefix = "\(provider.rawValue):"
        let incomingIds = Set(incoming.map(\.storageId))
        selectedCalendarStorageIds = selectedCalendarStorageIds.filter { storageId in
            guard storageId.hasPrefix(refreshedProviderPrefix) else {
                return true
            }
            return incoming.isEmpty || incomingIds.contains(storageId)
        }

        if writeCalendarStorageId.isEmpty {
            writeCalendarStorageId = calendars.first(where: \.canWrite)?.storageId ?? ""
        } else if writeCalendarStorageId.hasPrefix(refreshedProviderPrefix), !incoming.isEmpty, !incomingIds.contains(writeCalendarStorageId) {
            writeCalendarStorageId = calendars.first(where: \.canWrite)?.storageId ?? ""
        }
    }

    private func selectedCalendars() -> [CoachCalendarInfo] {
        let selected = calendars.filter { selectedCalendarStorageIds.contains($0.storageId) }
        return selected.isEmpty ? calendars : selected
    }

    private func selectedWriteCalendar() -> CoachCalendarInfo? {
        calendars.first { $0.storageId == writeCalendarStorageId && $0.canWrite }
            ?? calendars.first(where: \.canWrite)
    }

    private func fetchBusyBlocks(from start: Date, to end: Date, completion: @escaping ([CoachCalendarBusyBlock]) -> Void) {
        let selected = selectedCalendars()
        var blocks: [CoachCalendarBusyBlock] = []

        let eventKitIds = Set(selected.filter { $0.provider == .eventKit }.map(\.id))
        let ekCalendars = eventStore.calendars(for: .event).filter { eventKitIds.isEmpty || eventKitIds.contains($0.calendarIdentifier) }
        if !ekCalendars.isEmpty {
            let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: ekCalendars)
            blocks += eventStore.events(matching: predicate)
                .filter { !$0.isAllDay }
                .map {
                    CoachCalendarBusyBlock(
                        start: $0.startDate,
                        end: $0.endDate,
                        title: privacyMode == .titleAware ? $0.title : nil,
                        provider: .eventKit
                    )
                }
        }

        fetchGoogleBusyBlocks(from: start, to: end, selected: selected) { googleBlocks in
            completion((blocks + googleBlocks).sorted { $0.start < $1.start })
        }
    }

    private func fetchAvailabilitySnapshot(from start: Date, to end: Date, completion: @escaping (CoachCalendarAvailabilitySnapshot) -> Void) {
        let selected = selectedCalendars()
        fetchBusyBlocks(from: start, to: end) { blocks in
            completion(CoachCalendarAvailabilitySnapshot(
                blocks: blocks,
                selectedCalendarCount: selected.count,
                selectedCalendarNames: selected.map(\.title)
            ))
        }
    }

    private func scoreSlots(action: CoachSuggestedAction, snapshot: CoachCalendarAvailabilitySnapshot) -> [CoachSuggestedTimeSlot] {
        let now = Date()
        let calendar = Calendar.current
        let duration = TimeInterval(max(5, action.durationMinutes) * 60)
        let futureBlocks = snapshot.blocks.filter { $0.end > now }
        let historyBlocks = snapshot.blocks.filter { $0.end <= now }
        var candidates: [CoachSuggestedTimeSlot] = []

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { continue }
            for hour in 8...20 {
                for minute in stride(from: 0, through: 45, by: 15) {
                    guard let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { continue }
                    if start < now.addingTimeInterval(30 * 60) { continue }
                    let end = start.addingTimeInterval(duration)
                    if calendar.component(.hour, from: end) >= 21 { continue }
                    if overlaps(start: start, end: end, blocks: futureBlocks) { continue }

                    var score = 70 - (dayOffset * 3)
                    let historicalPenalty = patternPenalty(for: start, end: end, historyBlocks: historyBlocks)
                    score -= historicalPenalty
                    if action.category == "sleep", hour >= 19 { score += 18 }
                    if action.category == "hydration", hour >= 9, hour <= 18 { score += 10 }
                    if action.category == "activity", hour >= 10, hour <= 18 { score += 10 }
                    if hour == 8 { score -= 8 }
                    if hour >= 19 { score -= action.category == "sleep" ? 0 : 10 }
                    if action.intensity.lowercased() == "high", hour >= 18 { score -= 10 }

                    let reason = slotReason(
                        start: start,
                        end: end,
                        futureBlocks: futureBlocks,
                        historyBlocks: historyBlocks,
                        historicalPenalty: historicalPenalty,
                        checkedBlockCount: snapshot.blocks.count
                    )

                    candidates.append(CoachSuggestedTimeSlot(
                        id: "\(Int(start.timeIntervalSince1970))-\(action.id)",
                        start: start,
                        end: end,
                        score: score,
                        reason: reason
                    ))
                }
            }
        }

        return candidates
            .sorted { $0.score == $1.score ? $0.start < $1.start : $0.score > $1.score }
            .reduce(into: [CoachSuggestedTimeSlot]()) { partial, slot in
                guard partial.count < 4 else { return }
                let samePartOfDay = partial.contains { abs($0.start.timeIntervalSince(slot.start)) < 90 * 60 }
                if !samePartOfDay {
                    partial.append(slot)
                }
            }
    }

    private func slotReason(
        start: Date,
        end: Date,
        futureBlocks: [CoachCalendarBusyBlock],
        historyBlocks: [CoachCalendarBusyBlock],
        historicalPenalty: Int,
        checkedBlockCount: Int
    ) -> String {
        let calendar = Calendar.current
        let sameDayFutureBlocks = futureBlocks
            .filter { calendar.isDate($0.start, inSameDayAs: start) || calendar.isDate($0.end, inSameDayAs: start) }
            .sorted { $0.start < $1.start }
        let previous = sameDayFutureBlocks.last { $0.end <= start }
        let next = sameDayFutureBlocks.first { $0.start >= end }

        var details: [String] = []
        if let previous {
            details.append("Starts \(durationPhrase(from: previous.end, to: start)) after \(eventLabel(previous)).")
        }
        if let next {
            details.append("You have \(durationPhrase(from: end, to: next.start)) free before \(eventLabel(next)) at \(timeLabel(next.start)).")
        } else if previous != nil {
            details.append("No selected-calendar events later that day.")
        } else if checkedBlockCount == 0 {
            details.append("No busy events were found on your selected calendars.")
        } else {
            details.append("No selected-calendar events are nearby that day.")
        }

        if historicalPenalty >= 25 {
            details.append("Similar past times are often busy, so this was ranked lower.")
        } else if nearbyProtectedPattern(start: start, historyBlocks: historyBlocks) {
            details.append("This avoids a repeated unavailable pattern from your calendar history.")
        }

        return details.joined(separator: " ")
    }

    private func eventLabel(_ block: CoachCalendarBusyBlock) -> String {
        let title = block.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? "your next calendar event" : title
    }

    private func timeLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func durationPhrase(from start: Date, to end: Date) -> String {
        let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(remainder) min"
    }

    private func overlaps(start: Date, end: Date, blocks: [CoachCalendarBusyBlock]) -> Bool {
        blocks.contains { start < $0.end && end > $0.start }
    }

    private func patternPenalty(for start: Date, end: Date, historyBlocks: [CoachCalendarBusyBlock]) -> Int {
        let calendar = Calendar.current
        let targetWeekday = calendar.component(.weekday, from: start)
        let targetMinute = calendar.component(.hour, from: start) * 60 + calendar.component(.minute, from: start)
        let matches = historyBlocks.filter { block in
            let blockWeekday = calendar.component(.weekday, from: block.start)
            let blockStartMinute = calendar.component(.hour, from: block.start) * 60 + calendar.component(.minute, from: block.start)
            let blockEndMinute = calendar.component(.hour, from: block.end) * 60 + calendar.component(.minute, from: block.end)
            return blockWeekday == targetWeekday
                && targetMinute >= blockStartMinute - 30
                && targetMinute <= blockEndMinute + 30
        }
        let titlePenalty = privacyMode == .titleAware && matches.contains { block in
            let title = (block.title ?? "").lowercased()
            return title.contains("lunch") || title.contains("meal") || title.contains("class") || title.contains("work")
        }
        return min(45, matches.count * 14 + (titlePenalty ? 12 : 0))
    }

    private func nearbyProtectedPattern(start: Date, historyBlocks: [CoachCalendarBusyBlock]) -> Bool {
        patternPenalty(for: start, end: start.addingTimeInterval(15 * 60), historyBlocks: historyBlocks) > 0
    }

    private func addEventKitEvent(action: CoachSuggestedAction, slot: CoachSuggestedTimeSlot, calendarId: String, completion: @escaping (Bool, String, CoachScheduledCalendarEvent?) -> Void) {
        guard let calendar = eventStore.calendar(withIdentifier: calendarId) ?? eventStore.defaultCalendarForNewEvents else {
            completion(false, "No writable iOS calendar is available.", nil)
            return
        }
        let event = EKEvent(eventStore: eventStore)
        event.calendar = calendar
        event.title = action.title
        event.startDate = slot.start
        event.endDate = slot.end
        event.notes = action.rationale.isEmpty ? "Added from AI Coach." : action.rationale
        do {
            try eventStore.save(event, span: .thisEvent)
            let record = CoachScheduledCalendarEvent(
                id: event.eventIdentifier,
                provider: .eventKit,
                calendarId: calendar.calendarIdentifier,
                actionId: action.id,
                title: action.title,
                start: slot.start,
                end: slot.end,
                createdAt: Date()
            )
            saveScheduledEvent(record)
            completion(true, "Added to \(calendar.title)", record)
        } catch {
            completion(false, error.localizedDescription, nil)
        }
    }

    @discardableResult
    private func refreshGoogleCalendarsIfAvailable() -> Bool {
#if canImport(GoogleSignIn)
        guard GIDSignIn.sharedInstance.currentUser != nil else { return false }
        googleAccessToken { [weak self] token in
            guard let self, let token else { return }
            var request = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/users/me/calendarList")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: request) { data, _, _ in
                guard let data,
                      let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let items = raw["items"] as? [[String: Any]] else { return }
                let calendars = items.compactMap { item -> CoachCalendarInfo? in
                    guard let id = item["id"] as? String else { return nil }
                    let title = item["summary"] as? String ?? id
                    let role = item["accessRole"] as? String ?? "reader"
                    return CoachCalendarInfo(
                        id: id,
                        provider: .google,
                        title: title,
                        canWrite: role != "reader" && role != "freeBusyReader"
                    )
                }
                DispatchQueue.main.async {
                    self.mergeCalendars(calendars, provider: .google)
                    self.status = "Google Calendar connected"
                }
            }.resume()
        }
        return true
#else
        return false
#endif
    }

    private func restoreGoogleCalendarSessionIfAvailable() {
#if canImport(GoogleSignIn)
        if GIDSignIn.sharedInstance.currentUser != nil {
            _ = refreshGoogleCalendarsIfAvailable()
            return
        }
        let hasSavedGoogleSelection = selectedCalendarStorageIds.contains {
            $0.hasPrefix("\(CoachCalendarProvider.google.rawValue):")
        } || writeCalendarStorageId.hasPrefix("\(CoachCalendarProvider.google.rawValue):")
        if hasSavedGoogleSelection {
            status = "Restoring Google Calendar..."
        }
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if user != nil {
                    self.status = "Google Calendar connected"
                    _ = self.refreshGoogleCalendarsIfAvailable()
                    self.calendarContextChanged?()
                } else if hasSavedGoogleSelection {
                    self.status = "Google Calendar needs reconnect"
                }
            }
        }
#endif
    }

    private func fetchGoogleBusyBlocks(from start: Date, to end: Date, selected: [CoachCalendarInfo], completion: @escaping ([CoachCalendarBusyBlock]) -> Void) {
#if canImport(GoogleSignIn)
        let googleCalendars = selected.filter { $0.provider == .google }
        guard !googleCalendars.isEmpty else {
            completion([])
            return
        }
        googleAccessToken { [weak self] token in
            guard let self, let token else {
                completion([])
                return
            }
            let group = DispatchGroup()
            var blocks: [CoachCalendarBusyBlock] = []
            for calendar in googleCalendars {
                group.enter()
                var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendar.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendar.id)/events")!
                components.queryItems = [
                    URLQueryItem(name: "timeMin", value: self.isoFormatter.string(from: start)),
                    URLQueryItem(name: "timeMax", value: self.isoFormatter.string(from: end)),
                    URLQueryItem(name: "singleEvents", value: "true"),
                    URLQueryItem(name: "orderBy", value: "startTime")
                ]
                guard let url = components.url else {
                    group.leave()
                    continue
                }
                var request = URLRequest(url: url)
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                URLSession.shared.dataTask(with: request) { data, _, _ in
                    defer { group.leave() }
                    guard let data,
                          let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let items = raw["items"] as? [[String: Any]] else { return }
                    for item in items {
                        guard let startRaw = item["start"] as? [String: Any],
                              let endRaw = item["end"] as? [String: Any],
                              let startText = startRaw["dateTime"] as? String,
                              let endText = endRaw["dateTime"] as? String,
                              let blockStart = ISO8601DateFormatter().date(from: startText),
                              let blockEnd = ISO8601DateFormatter().date(from: endText) else { continue }
                        blocks.append(CoachCalendarBusyBlock(
                            start: blockStart,
                            end: blockEnd,
                            title: self.privacyMode == .titleAware ? item["summary"] as? String : nil,
                            provider: .google
                        ))
                    }
                }.resume()
            }
            group.notify(queue: .main) {
                completion(blocks)
            }
        }
#else
        completion([])
#endif
    }

    private func addGoogleEvent(action: CoachSuggestedAction, slot: CoachSuggestedTimeSlot, calendarId: String, completion: @escaping (Bool, String, CoachScheduledCalendarEvent?) -> Void) {
#if canImport(GoogleSignIn)
        googleAccessToken { [weak self] token in
            guard let self, let token else {
                completion(false, "Google Calendar is not signed in.", nil)
                return
            }
            let encodedId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId
            guard let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(encodedId)/events") else {
                completion(false, "Invalid Google calendar.", nil)
                return
            }
            let payload: [String: Any] = [
                "summary": action.title,
                "description": action.rationale.isEmpty ? "Added from AI Coach." : action.rationale,
                "start": ["dateTime": self.isoFormatter.string(from: slot.start)],
                "end": ["dateTime": self.isoFormatter.string(from: slot.end)]
            ]
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    if let error {
                        completion(false, error.localizedDescription, nil)
                        return
                    }
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    guard (200..<300).contains(status) else {
                        completion(false, "Google Calendar returned \(status)", nil)
                        return
                    }
                    let eventId = ((try? JSONSerialization.jsonObject(with: data ?? Data()) as? [String: Any])?["id"] as? String) ?? UUID().uuidString
                    let record = CoachScheduledCalendarEvent(
                        id: eventId,
                        provider: .google,
                        calendarId: calendarId,
                        actionId: action.id,
                        title: action.title,
                        start: slot.start,
                        end: slot.end,
                        createdAt: Date()
                    )
                    self.saveScheduledEvent(record)
                    completion(true, "Added to Google Calendar", record)
                }
            }.resume()
        }
#else
        completion(false, "Add GoogleSignIn package to enable direct Google Calendar.", nil)
#endif
    }

    private func deleteEventKitEvent(_ record: CoachScheduledCalendarEvent, completion: @escaping (Bool, String) -> Void) {
        guard let event = eventStore.event(withIdentifier: record.id) else {
            removeScheduledEvent(record)
            completion(true, "Removed saved event record.")
            return
        }
        do {
            try eventStore.remove(event, span: .thisEvent)
            removeScheduledEvent(record)
            completion(true, "Deleted calendar event.")
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    private func deleteGoogleEvent(_ record: CoachScheduledCalendarEvent, completion: @escaping (Bool, String) -> Void) {
#if canImport(GoogleSignIn)
        googleAccessToken { [weak self] token in
            guard let self, let token else {
                completion(false, "Google Calendar is not signed in.")
                return
            }
            let encodedCalendar = record.calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? record.calendarId
            let encodedEvent = record.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? record.id
            guard let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(encodedCalendar)/events/\(encodedEvent)") else {
                completion(false, "Invalid Google calendar event.")
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: request) { _, response, error in
                DispatchQueue.main.async {
                    if let error {
                        completion(false, error.localizedDescription)
                        return
                    }
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if (200..<300).contains(status) || status == 404 {
                        self.removeScheduledEvent(record)
                        completion(true, status == 404 ? "Event was already gone; removed from app." : "Deleted Google Calendar event.")
                    } else {
                        completion(false, "Google Calendar returned \(status)")
                    }
                }
            }.resume()
        }
#else
        completion(false, "Add GoogleSignIn package to enable direct Google Calendar.")
#endif
    }

    private func saveScheduledEvent(_ record: CoachScheduledCalendarEvent) {
        scheduledEvents.removeAll { $0.id == record.id && $0.provider == record.provider }
        scheduledEvents.append(record)
        persistScheduledEvents()
    }

    private func removeScheduledEvent(_ record: CoachScheduledCalendarEvent) {
        scheduledEvents.removeAll { $0.id == record.id && $0.provider == record.provider }
        persistScheduledEvents()
    }

    private func persistScheduledEvents() {
        guard let data = try? JSONEncoder().encode(scheduledEvents) else { return }
        UserDefaults.standard.set(data, forKey: Self.scheduledEventsKey)
    }

    private static func loadScheduledEvents() -> [CoachScheduledCalendarEvent] {
        guard let data = UserDefaults.standard.data(forKey: scheduledEventsKey),
              let events = try? JSONDecoder().decode([CoachScheduledCalendarEvent].self, from: data) else {
            return []
        }
        return events
    }

#if canImport(GoogleSignIn)
    private func googleAccessToken(completion: @escaping (String?) -> Void) {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            completion(nil)
            return
        }
        user.refreshTokensIfNeeded { user, error in
            guard error == nil else {
                completion(nil)
                return
            }
            completion(user?.accessToken.tokenString)
        }
    }
#endif
}

private extension UIApplication {
    func wpTopViewController() -> UIViewController? {
        let root = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
        return topViewController(from: root)
    }

    private func topViewController(from controller: UIViewController?) -> UIViewController? {
        if let navigation = controller as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = controller as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        if let presented = controller?.presentedViewController {
            return topViewController(from: presented)
        }
        return controller
    }
}
