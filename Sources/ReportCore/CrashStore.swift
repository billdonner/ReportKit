import Foundation

/// Keeps the newest crash and hang reports on disk so the next report can attach them.
/// MetricKit delivers them on a later launch; nothing leaves the device until someone sends.
public struct CrashStore: Sendable {
    public let folder: URL
    public let keep: Int

    public init(folder: URL = CrashStore.defaultFolder, keep: Int = 5) {
        self.folder = folder
        self.keep = keep
    }

    public static var defaultFolder: URL {
        URL.cachesDirectory.appending(path: "ReportKit/crashes", directoryHint: .isDirectory)
    }

    /// Saves one payload (MetricKit's JSON) and drops the oldest past `keep`.
    public func save(_ payload: Data, at date: Date = Date()) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Int(date.timeIntervalSince1970 * 1000)
        try payload.write(to: folder.appending(path: "\(stamp).json"), options: .atomic)
        for old in files().dropFirst(keep) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    /// Up to `limit` saved reports, newest first, as attachments.
    public func attachments(limit: Int) -> [ReportAttachment] {
        files().prefix(limit).compactMap { url in
            (try? Data(contentsOf: url)).map {
                ReportAttachment(filename: "crash-\(url.lastPathComponent)", mimeType: "application/json", data: $0)
            }
        }
    }

    public func removeAll() {
        try? FileManager.default.removeItem(at: folder)
    }

    /// Newest first; the names are millisecond timestamps.
    private func files() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "json" }
            .sorted { stamp($0) > stamp($1) }
    }

    private func stamp(_ url: URL) -> Int {
        Int(url.deletingPathExtension().lastPathComponent) ?? 0
    }
}
