import Foundation

final class WatchResearchStore {
    static let shared = WatchResearchStore()

    private let rootDirectoryName = "WatchResearchData"
    private let encoderDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {}

    var rootDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(rootDirectoryName, isDirectory: true)
    }

    func saveSyncSnapshot(
        deviceId: String,
        deviceName: String,
        syncId: String,
        reason: String,
        days: [[String: Any]],
        metadata: [String: Any]
    ) throws -> URL {
        let timestamp = Date()
        let dateKey = Self.dayString(from: timestamp)
        let deviceDirectory = rootDirectory
            .appendingPathComponent(Self.safePathComponent(deviceId), isDirectory: true)
            .appendingPathComponent(dateKey, isDirectory: true)
        try FileManager.default.createDirectory(at: deviceDirectory, withIntermediateDirectories: true)

        var payload: [String: Any] = [
            "schemaVersion": 1,
            "syncId": syncId,
            "syncReason": reason,
            "syncedAt": encoderDateFormatter.string(from: timestamp),
            "device": [
                "id": deviceId,
                "name": deviceName
            ],
            "days": days,
            "metadata": jsonSafe(metadata)
        ]

        payload["recordCounts"] = recordCounts(for: days)

        let data = try JSONSerialization.data(
            withJSONObject: jsonSafe(payload),
            options: [.prettyPrinted, .sortedKeys]
        )
        let filename = "sync-\(Self.fileTimestamp(from: timestamp)).json"
        let fileURL = deviceDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func saveSkippedSync(
        deviceId: String,
        deviceName: String,
        reason: String,
        activeTest: String?
    ) throws -> URL {
        try saveSyncSnapshot(
            deviceId: deviceId,
            deviceName: deviceName,
            syncId: UUID().uuidString,
            reason: reason,
            days: [],
            metadata: [
                "status": "skipped",
                "activeTest": activeTest ?? "none"
            ]
        )
    }

    func localStorageSummary() -> String {
        guard FileManager.default.fileExists(atPath: rootDirectory.path) else {
            return "No local data yet"
        }

        let files = (try? FileManager.default.subpathsOfDirectory(atPath: rootDirectory.path)) ?? []
        let jsonFiles = files.filter { $0.hasSuffix(".json") }
        return "\(jsonFiles.count) sync file(s)"
    }

    func latestSyncFileURL() -> URL? {
        guard let enumerator = FileManager.default.enumerator(
            at: rootDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var latest: (url: URL, date: Date)?
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "json" {
            let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey])
            let modified = values?.contentModificationDate ?? .distantPast
            if latest == nil || modified > latest!.date {
                latest = (fileURL, modified)
            }
        }

        return latest?.url
    }

    func localStorageDetailSummary() -> String {
        guard let latestURL = latestSyncFileURL() else {
            return localStorageSummary()
        }

        return "\(localStorageSummary()), latest: \(latestURL.lastPathComponent)"
    }

    static func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func dayString(daysAgo: Int) -> String {
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return dayString(from: date)
    }

    private static func fileTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private static func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        return value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }.map(String.init).joined()
    }

    private func recordCounts(for days: [[String: Any]]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for day in days {
            for (key, value) in day where key != "date" {
                if let array = value as? [Any] {
                    counts[key, default: 0] += array.count
                } else if let dictionary = value as? [String: Any], !dictionary.isEmpty {
                    counts[key, default: 0] += 1
                }
            }
        }
        return counts
    }

    private func jsonSafe(_ value: Any?) -> Any {
        guard let value else { return NSNull() }

        if value is NSNull || value is String || value is NSNumber {
            return value
        }

        if let date = value as? Date {
            return encoderDateFormatter.string(from: date)
        }

        if let array = value as? [Any] {
            return array.map { jsonSafe($0) }
        }

        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, pair in
                result[pair.key] = jsonSafe(pair.value)
            }
        }

        if let dictionary = value as? NSDictionary {
            var safe: [String: Any] = [:]
            dictionary.forEach { key, value in
                safe[String(describing: key)] = jsonSafe(value)
            }
            return safe
        }

        if let array = value as? NSArray {
            return array.map { jsonSafe($0) }
        }

        return String(describing: value)
    }
}
