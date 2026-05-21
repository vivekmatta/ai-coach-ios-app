import Foundation
import SQLite3

final class HealthDataStore {
    static let shared = HealthDataStore()

    private let databaseURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private let dateParsers: [DateFormatter] = {
        [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSS"
        ].map {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = $0
            return formatter
        }
    }()
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private init() {
        databaseURL = WatchResearchStore.shared.rootDirectory.appendingPathComponent("watch-health.sqlite")
        try? FileManager.default.createDirectory(
            at: WatchResearchStore.shared.rootDirectory,
            withIntermediateDirectories: true
        )
        migrateIfNeeded()
    }

    func ingestSnapshot(payload: [String: Any], fileURL: URL?) {
        guard let syncId = payload["syncId"] as? String, !syncId.isEmpty else { return }
        let syncedAt = payload["syncedAt"] as? String ?? isoFormatter.string(from: Date())
        let reason = payload["syncReason"] as? String ?? ""
        let device = payload["device"] as? [String: Any] ?? [:]
        let deviceId = stringValue(device["id"])
        let deviceName = stringValue(device["name"])
        let metrics = metricSummaries(from: payload)

        withDatabase { db in
            execute(
                db,
                """
                INSERT OR REPLACE INTO sync_snapshots(sync_id, synced_at, reason, device_id, device_name, json_path)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                [syncId, syncedAt, reason, deviceId, deviceName, fileURL?.path ?? ""]
            )

            execute(db, "DELETE FROM metric_summaries WHERE sync_id = ?", [syncId])
            for metric in metrics {
                execute(
                    db,
                    """
                    INSERT INTO metric_summaries(sync_id, metric_id, title, value, unit, date, detail)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                    [syncId, metric.metricId, metric.title, metric.value, metric.unit, metric.date, metric.detail]
                )
            }
        }
    }

    func latestMetricSummaries() -> [HealthMetricSummary] {
        var syncId = ""
        withDatabase { db in
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, "SELECT sync_id FROM sync_snapshots ORDER BY synced_at DESC LIMIT 1", -1, &statement, nil) == SQLITE_OK,
               sqlite3_step(statement) == SQLITE_ROW {
                syncId = columnString(statement, 0)
            }
            sqlite3_finalize(statement)
        }
        guard !syncId.isEmpty else { return [] }
        return metricSummaries(syncId: syncId)
    }

    func metricSummaries(syncId: String) -> [HealthMetricSummary] {
        var metrics: [HealthMetricSummary] = []
        withDatabase { db in
            var statement: OpaquePointer?
            let sql = """
            SELECT metric_id, title, value, unit, date, detail
            FROM metric_summaries
            WHERE sync_id = ?
            ORDER BY metric_id
            """
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
            sqlite3_bind_text(statement, 1, syncId, -1, SQLITE_TRANSIENT)
            while sqlite3_step(statement) == SQLITE_ROW {
                metrics.append(HealthMetricSummary(
                    metricId: columnString(statement, 0),
                    title: columnString(statement, 1),
                    value: columnString(statement, 2),
                    unit: columnString(statement, 3),
                    date: columnString(statement, 4),
                    detail: columnString(statement, 5)
                ))
            }
            sqlite3_finalize(statement)
        }
        return metrics
    }

    func cachedCoachAnalysis(syncId: String) -> AICoachAnalysis? {
        var analysis: AICoachAnalysis?
        withDatabase { db in
            var statement: OpaquePointer?
            let sql = "SELECT analysis_json FROM ai_analyses WHERE sync_id = ? LIMIT 1"
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
            sqlite3_bind_text(statement, 1, syncId, -1, SQLITE_TRANSIENT)
            if sqlite3_step(statement) == SQLITE_ROW,
               let raw = sqlite3_column_text(statement, 0) {
                let data = Data(String(cString: raw).utf8)
                analysis = try? decoder.decode(AICoachAnalysis.self, from: data)
            }
            sqlite3_finalize(statement)
        }
        return analysis
    }

    func saveCoachAnalysis(_ analysis: AICoachAnalysis) {
        guard let data = try? encoder.encode(analysis),
              let json = String(data: data, encoding: .utf8) else { return }
        withDatabase { db in
            execute(
                db,
                """
                INSERT OR REPLACE INTO ai_analyses(sync_id, generated_at, source, analysis_json)
                VALUES (?, ?, ?, ?)
                """,
                [analysis.syncId, analysis.generatedAt, analysis.source, json]
            )
        }
    }

    func coachPromptContext(syncId: String) -> String {
        let metrics = metricSummaries(syncId: syncId)
        var payload: [String: Any] = [
            "syncId": syncId,
            "metrics": metrics.map {
                [
                    "metricId": $0.metricId,
                    "title": $0.title,
                    "value": $0.value,
                    "unit": $0.unit,
                    "date": $0.date,
                    "detail": $0.detail
                ]
            }
        ]
        if let snapshot = snapshotPayload(syncId: syncId) {
            payload["timeCorrelations"] = timeCorrelationContext(from: snapshot)
        }
        let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    func localFallbackAnalysis(syncId: String) -> AICoachAnalysis {
        AICoachAnalysis.localFallback(
            syncId: syncId,
            generatedAt: isoFormatter.string(from: Date()),
            metrics: metricSummaries(syncId: syncId)
        )
    }

    private func migrateIfNeeded() {
        withDatabase { db in
            execute(
                db,
                """
                CREATE TABLE IF NOT EXISTS sync_snapshots(
                    sync_id TEXT PRIMARY KEY,
                    synced_at TEXT NOT NULL,
                    reason TEXT,
                    device_id TEXT,
                    device_name TEXT,
                    json_path TEXT
                )
                """,
                []
            )
            execute(
                db,
                """
                CREATE TABLE IF NOT EXISTS metric_summaries(
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    sync_id TEXT NOT NULL,
                    metric_id TEXT NOT NULL,
                    title TEXT NOT NULL,
                    value TEXT NOT NULL,
                    unit TEXT,
                    date TEXT,
                    detail TEXT
                )
                """,
                []
            )
            execute(
                db,
                """
                CREATE TABLE IF NOT EXISTS ai_analyses(
                    sync_id TEXT PRIMARY KEY,
                    generated_at TEXT NOT NULL,
                    source TEXT NOT NULL,
                    analysis_json TEXT NOT NULL
                )
                """,
                []
            )
            execute(db, "CREATE INDEX IF NOT EXISTS idx_metric_summaries_sync ON metric_summaries(sync_id)", [])
        }
    }

    private func withDatabase(_ body: (OpaquePointer) -> Void) {
        var db: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &db) == SQLITE_OK, let db else {
            sqlite3_close(db)
            return
        }
        body(db)
        sqlite3_close(db)
    }

    private func execute(_ db: OpaquePointer, _ sql: String, _ values: [String]) {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        for (index, value) in values.enumerated() {
            sqlite3_bind_text(statement, Int32(index + 1), value, -1, SQLITE_TRANSIENT)
        }
        sqlite3_step(statement)
        sqlite3_finalize(statement)
    }

    private func snapshotPayload(syncId: String) -> [String: Any]? {
        var path = ""
        withDatabase { db in
            var statement: OpaquePointer?
            let sql = "SELECT json_path FROM sync_snapshots WHERE sync_id = ? LIMIT 1"
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
            sqlite3_bind_text(statement, 1, syncId, -1, SQLITE_TRANSIENT)
            if sqlite3_step(statement) == SQLITE_ROW {
                path = columnString(statement, 0)
            }
            sqlite3_finalize(statement)
        }
        guard !path.isEmpty else { return nil }
        return try? WatchResearchStore.shared.loadSyncSnapshot(from: URL(fileURLWithPath: path))
    }

    private func metricSummaries(from payload: [String: Any]) -> [HealthMetricSummary] {
        let days = snapshotDays(from: payload)
        return [
            sleepSummary(from: days),
            heartRateSummary(from: days),
            dictionarySummary(from: days, metricId: "oxygen", title: "Blood Oxygen", key: "bloodOxygen", valueKeys: ["OxygenValue", "oxygenValue", "value"], unit: "%", requirePositive: true),
            bloodPressureSummary(from: days),
            hrvSummary(from: days),
            glucoseSummary(from: days),
            activitySummary(from: days),
            dictionarySummary(from: days, metricId: "temperature", title: "Temperature", key: "temperature", valueKeys: ["value", "temperature", "bodyTemperature"], unit: "C", requirePositive: false),
            ecgSummary(from: days),
            HealthMetricSummary(metricId: "updated", title: "Updated", value: payload["syncedAt"] as? String ?? "--", unit: "", date: "", detail: "Latest saved sync timestamp")
        ]
    }

    private func snapshotDays(from payload: [String: Any]) -> [[String: Any]] {
        (payload["days"] as? [Any] ?? [])
            .compactMap { $0 as? [String: Any] }
            .sorted { ($0["date"] as? String ?? "") > ($1["date"] as? String ?? "") }
    }

    private func sleepSummary(from days: [[String: Any]]) -> HealthMetricSummary {
        for day in days {
            let date = day["date"] as? String ?? ""
            for key in ["accurateSleep", "sleep"] {
                guard let payload = day[key] as? [String: Any],
                      let records = payload["records"] as? [[String: Any]],
                      let record = records.first else { continue }
                let duration = intValue(record["sleepDuration"])
                    ?? ((intValue(record["deepDuration"]) ?? 0) + (intValue(record["lightDuration"]) ?? 0))
                return HealthMetricSummary(
                    metricId: "sleep",
                    title: "Sleep",
                    value: durationText(minutes: duration),
                    unit: "",
                    date: date,
                    detail: "Sleep \(stringValue(record["sleepTime"])) to \(stringValue(record["wakeTime"]))"
                )
            }
        }
        return missingMetric("sleep", "Sleep")
    }

    private func heartRateSummary(from days: [[String: Any]]) -> HealthMetricSummary {
        for day in days {
            guard let date = day["date"] as? String,
                  let samples = day["heartHalfHour"] as? [String: Any] else { continue }
            let readings = samples.compactMap { key, value -> (String, Int)? in
                guard let dictionary = value as? [String: Any],
                      let heart = intValue(dictionary["heartValue"]),
                      heart > 0 else { return nil }
                return (key, heart)
            }
            .sorted { $0.0 < $1.0 }
            guard let latest = readings.last else { continue }
            let average = Int(round(Double(readings.reduce(0) { $0 + $1.1 }) / Double(readings.count)))
            return HealthMetricSummary(metricId: "heartRate", title: "Heart Rate", value: "\(latest.1)", unit: "bpm", date: date, detail: "Latest at \(latest.0), average \(average) bpm across \(readings.count) samples")
        }
        return missingMetric("heartRate", "Heart Rate")
    }

    private func dictionarySummary(
        from days: [[String: Any]],
        metricId: String,
        title: String,
        key: String,
        valueKeys: [String],
        unit: String,
        requirePositive: Bool
    ) -> HealthMetricSummary {
        for day in days {
            guard let date = day["date"] as? String,
                  let records = day[key] as? [[String: Any]] else { continue }
            for record in records.reversed() {
                guard let rawValue = valueForFirstKey(in: record, keys: valueKeys) else { continue }
                if requirePositive, (doubleValue(rawValue) ?? 0) <= 0 { continue }
                let time = stringValue(record["Time"] ?? record["time"] ?? record["date"])
                return HealthMetricSummary(metricId: metricId, title: title, value: stringValue(rawValue), unit: unit, date: date, detail: "Latest at \(time), \(records.count) stored samples")
            }
        }
        return missingMetric(metricId, title)
    }

    private func bloodPressureSummary(from days: [[String: Any]]) -> HealthMetricSummary {
        for day in days {
            guard let date = day["date"] as? String,
                  let records = day["bloodPressure"] as? [[String: Any]] else { continue }
            for record in records.reversed() {
                guard let systolic = intValue(record["systolic"]),
                      let diastolic = intValue(record["diastolic"]),
                      systolic > 0,
                      diastolic > 0 else { continue }
                return HealthMetricSummary(metricId: "bloodPressure", title: "Blood Pressure", value: "\(systolic)/\(diastolic)", unit: "mmHg", date: date, detail: "\(records.count) stored samples")
            }
        }
        return missingMetric("bloodPressure", "Blood Pressure")
    }

    private func hrvSummary(from days: [[String: Any]]) -> HealthMetricSummary {
        for day in days {
            guard let date = day["date"] as? String, let hrv = day["hrv"] else { continue }
            if let dictionary = hrv as? [String: Any], dictionary["skipped"] as? Bool == true {
                return HealthMetricSummary(metricId: "hrv", title: "HRV", value: "Skipped", unit: "", date: date, detail: stringValue(dictionary["reason"]))
            }
            return HealthMetricSummary(metricId: "hrv", title: "HRV", value: "\(recordCount(hrv))", unit: "records", date: date, detail: "Stored HRV records")
        }
        return missingMetric("hrv", "HRV")
    }

    private func glucoseSummary(from days: [[String: Any]]) -> HealthMetricSummary {
        for day in days {
            guard let date = day["date"] as? String,
                  let records = day["bloodGlucose"] as? [[String: Any]] else { continue }
            for record in records.reversed() {
                let values = record["bloodGlucoses"] as? [Any] ?? []
                let value = values.compactMap { stringValue($0) == "--" ? nil : stringValue($0) }.last
                    ?? stringValue(record["bloodGlucose"] ?? record["value"])
                guard value != "--" else { continue }
                return HealthMetricSummary(metricId: "bloodGlucose", title: "Glucose", value: value, unit: "", date: date, detail: "\(records.count) stored samples")
            }
        }
        return missingMetric("bloodGlucose", "Glucose")
    }

    private func activitySummary(from days: [[String: Any]]) -> HealthMetricSummary {
        for day in days {
            guard let date = day["date"] as? String,
                  let steps = day["steps"] as? [String: Any],
                  !steps.isEmpty else { continue }
            return HealthMetricSummary(
                metricId: "activity",
                title: "Activity",
                value: stringValue(steps["Step"]),
                unit: "steps",
                date: date,
                detail: "\(stringValue(steps["Dis"])) km, \(stringValue(steps["Cal"])) kcal"
            )
        }
        return missingMetric("activity", "Activity")
    }

    private func ecgSummary(from days: [[String: Any]]) -> HealthMetricSummary {
        let count = days.reduce(0) { $0 + recordCount($1["offlineECG"]) }
        return HealthMetricSummary(metricId: "ecg", title: "ECG", value: count > 0 ? "\(count)" : "--", unit: "records", date: days.first?["date"] as? String ?? "", detail: "Offline ECG records in local JSON")
    }

    private func missingMetric(_ metricId: String, _ title: String) -> HealthMetricSummary {
        HealthMetricSummary(metricId: metricId, title: title, value: "--", unit: "", date: "", detail: "No saved value yet")
    }

    private func timeCorrelationContext(from payload: [String: Any]) -> [String: Any] {
        let days = snapshotDays(from: payload).prefix(4)
        var sleepWindowRows: [[String: Any]] = []
        var heartSamples: [[String: Any]] = []

        for day in days {
            guard let date = day["date"] as? String else { continue }
            sleepWindowRows.append(contentsOf: sleepWindows(in: day, date: date))

            guard let samples = day["heartHalfHour"] as? [String: Any] else { continue }
            for sample in samples {
                guard let dictionary = sample.value as? [String: Any],
                      let heart = intValue(dictionary["heartValue"]),
                      heart > 0 else { continue }
                let time = sample.key
                let sampleDate = dateTime(day: date, time: time)
                heartSamples.append([
                    "date": date,
                    "time": time,
                    "heartRateBpm": heart,
                    "timestamp": sampleDate.map { isoFormatter.string(from: $0) } ?? "",
                    "insideSleepWindow": sampleDate.map { date in
                        sleepWindowRows.contains { window in
                            guard let start = window["_startDate"] as? Date,
                                  let end = window["_endDate"] as? Date else { return false }
                            return date >= start && date <= end
                        }
                    } ?? false,
                    "sleepWindowId": sampleDate.flatMap { date in
                        sleepWindowRows.first { window in
                            guard let start = window["_startDate"] as? Date,
                                  let end = window["_endDate"] as? Date else { return false }
                            return date >= start && date <= end
                        }?["id"] as? String
                    } ?? ""
                ])
            }
        }

        let safeSleepWindows = sleepWindowRows.map { window in
            window.filter { !$0.key.hasPrefix("_") }
        }
        return [
            "purpose": "Use these timestamp-linked samples for cross-metric reasoning. Only claim a relationship when timestamps overlap or trends are directly present here.",
            "sleepWindows": safeSleepWindows,
            "heartRateSamples": Array(heartSamples.sorted {
                stringValue($0["timestamp"]) < stringValue($1["timestamp"])
            }.suffix(96)),
            "heartRateDuringSleep": heartRateSummary(samples: heartSamples.filter { ($0["insideSleepWindow"] as? Bool) == true }),
            "heartRateOutsideSleep": heartRateSummary(samples: heartSamples.filter { ($0["insideSleepWindow"] as? Bool) != true })
        ]
    }

    private func sleepWindows(in day: [String: Any], date dateString: String) -> [[String: Any]] {
        var windows: [[String: Any]] = []
        for key in ["accurateSleep", "sleep"] {
            guard let payload = day[key] as? [String: Any],
                  let records = payload["records"] as? [[String: Any]] else { continue }
            for (index, record) in records.enumerated() {
                let startText = stringValue(record["sleepTime"])
                let endText = stringValue(record["wakeTime"])
                guard let start = date(from: startText),
                      var end = date(from: endText) else { continue }
                if end < start {
                    end = Calendar.current.date(byAdding: .day, value: 1, to: end) ?? end
                }
                let duration = intValue(record["sleepDuration"])
                    ?? Int(end.timeIntervalSince(start) / 60)
                let id = "\(dateString)-sleep-\(index + 1)"
                windows.append([
                    "id": id,
                    "date": dateString,
                    "source": key,
                    "sleepTime": startText,
                    "wakeTime": endText,
                    "durationMinutes": max(0, duration),
                    "_startDate": start,
                    "_endDate": end
                ])
            }
        }
        return windows
    }

    private func heartRateSummary(samples: [[String: Any]]) -> [String: Any] {
        let values = samples.compactMap { intValue($0["heartRateBpm"]) }
        guard !values.isEmpty else {
            return ["sampleCount": 0]
        }
        let average = Int(round(Double(values.reduce(0, +)) / Double(values.count)))
        return [
            "sampleCount": values.count,
            "averageBpm": average,
            "minBpm": values.min() ?? 0,
            "maxBpm": values.max() ?? 0
        ]
    }

    private func dateTime(day: String, time: String) -> Date? {
        if let fullDate = date(from: time) {
            return fullDate
        }
        guard let dayDate = dayFormatter.date(from: day) else { return nil }
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        return Calendar.current.date(
            bySettingHour: parts[0],
            minute: parts.count > 1 ? parts[1] : 0,
            second: parts.count > 2 ? parts[2] : 0,
            of: dayDate
        )
    }

    private func date(from text: String) -> Date? {
        guard text != "--", !text.isEmpty else { return nil }
        if let date = isoFormatter.date(from: text) {
            return date
        }
        for parser in dateParsers {
            if let date = parser.date(from: text) {
                return date
            }
        }
        return nil
    }

    private func valueForFirstKey(in dictionary: [String: Any], keys: [String]) -> Any? {
        for key in keys where dictionary[key] != nil {
            return dictionary[key]
        }
        return nil
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

    private func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String {
            if let int = Int(string) { return int }
            if let double = Double(string), double.isFinite { return Int(double) }
        }
        return nil
    }

    private func doubleValue(_ value: Any?) -> Double? {
        if let double = value as? Double { return double }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    private func stringValue(_ value: Any?) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return "--"
    }

    private func durationText(minutes: Int) -> String {
        guard minutes > 0 else { return "--" }
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func columnString(_ statement: OpaquePointer?, _ index: Int32) -> String {
    guard let raw = sqlite3_column_text(statement, index) else { return "" }
    return String(cString: raw)
}
