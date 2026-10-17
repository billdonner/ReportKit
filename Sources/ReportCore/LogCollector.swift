import Foundation
import OSLog

/// The app's own log entries from the last few minutes, as text. iOS only lets an app read
/// its own process's log, which is exactly what a report needs.
public enum LogCollector {
    public static func recent(subsystem: String, window: TimeInterval, now: Date = Date()) -> String {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let since = store.position(date: now.addingTimeInterval(-window))
            let lines = try store.getEntries(at: since)
                .compactMap { $0 as? OSLogEntryLog }
                .filter { $0.subsystem == subsystem }
                .map { line(date: $0.date, level: $0.level, category: $0.category, message: $0.composedMessage) }
            return lines.isEmpty ? "(no log entries in the last \(Int(window / 60)) minutes)" : lines.joined(separator: "\n")
        } catch {
            return "(log unavailable: \(error.localizedDescription))"
        }
    }

    static func line(date: Date, level: OSLogEntryLog.Level, category: String, message: String) -> String {
        let time = date.formatted(.iso8601.time(includingFractionalSeconds: true))
        return "\(time) [\(name(level))] \(category): \(message)"
    }

    static func name(_ level: OSLogEntryLog.Level) -> String {
        switch level {
        case .debug: "debug"
        case .info: "info"
        case .notice: "notice"
        case .error: "error"
        case .fault: "fault"
        default: "log"
        }
    }
}
