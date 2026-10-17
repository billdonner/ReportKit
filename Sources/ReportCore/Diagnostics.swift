import Foundation

/// Everything about the app and device that a report carries, gathered without asking.
/// The app adds its own context (screen, layout, account) through `context`.
public struct Diagnostics: Codable, Equatable, Sendable {
    public var app: String
    public var version: String
    public var build: String
    public var bundleID: String
    public var device: String
    public var system: String
    public var locale: String
    public var timeZone: String
    public var date: Date
    public var freeDiskMB: Int?
    public var lowPowerMode: Bool
    public var context: [String: String]

    public init(
        app: String, version: String, build: String, bundleID: String, device: String,
        system: String, locale: String, timeZone: String, date: Date, freeDiskMB: Int?,
        lowPowerMode: Bool, context: [String: String]
    ) {
        self.app = app
        self.version = version
        self.build = build
        self.bundleID = bundleID
        self.device = device
        self.system = system
        self.locale = locale
        self.timeZone = timeZone
        self.date = date
        self.freeDiskMB = freeDiskMB
        self.lowPowerMode = lowPowerMode
        self.context = context
    }

    /// Reads what the bundle, process and file system know. `system` is passed in because only
    /// UIKit knows the name ("iOS", "iPadOS"); the default uses ProcessInfo's version string.
    public static func collect(
        appName: String,
        context: [String: String] = [:],
        system: String? = nil,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo,
        now: Date = Date()
    ) -> Diagnostics {
        let info = bundle.infoDictionary ?? [:]
        let os = processInfo.operatingSystemVersion
        return Diagnostics(
            app: appName,
            version: info["CFBundleShortVersionString"] as? String ?? "?",
            build: info["CFBundleVersion"] as? String ?? "?",
            bundleID: bundle.bundleIdentifier ?? "?",
            device: modelIdentifier(processInfo: processInfo),
            system: system ?? "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            date: now,
            freeDiskMB: freeDiskMB(),
            lowPowerMode: processInfo.isLowPowerModeEnabled,
            context: context
        )
    }

    /// The version label apps show on their main screen: `v1.3.0 (34)`.
    public var label: String { "v\(version) (\(build))" }

    /// One line per field, app context last, for an email body or a pasted issue.
    public var text: String {
        var lines = [
            "\(app) \(label)",
            "Device: \(device)",
            "System: \(system)",
            "Locale: \(locale), \(timeZone)",
            "Date: \(date.formatted(.iso8601))",
            "Bundle: \(bundleID)",
        ]
        if let freeDiskMB { lines.append("Free disk: \(freeDiskMB) MB") }
        if lowPowerMode { lines.append("Low Power Mode: on") }
        lines += context.keys.sorted().map { "\($0): \(context[$0]!)" }
        return lines.joined(separator: "\n")
    }

    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// "iPhone17,2" on a device; the simulator reports the model it's simulating.
    static func modelIdentifier(processInfo: ProcessInfo) -> String {
        if let simulated = processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated + " (Simulator)"
        }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    static func freeDiskMB() -> Int? {
        let home = URL(filePath: NSHomeDirectory())
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage.map { Int($0 / 1_000_000) }
    }
}
