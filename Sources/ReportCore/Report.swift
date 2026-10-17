import Foundation

/// Where reports go and what they include. One per app.
public struct ReportConfiguration: Sendable {
    /// The name in subjects and the sheet's title ("Report a problem with Medium Raw").
    public var appName: String
    /// Email addresses that receive reports.
    public var recipients: [String]
    /// The app's `Logger` subsystem. Its entries from the last `logWindow` are attached.
    /// Nil attaches no log.
    public var logSubsystem: String?
    public var logWindow: TimeInterval
    /// Recent crash and hang reports to attach (from MetricKit), newest first.
    public var crashReportLimit: Int

    public init(
        appName: String,
        recipients: [String],
        logSubsystem: String? = nil,
        logWindow: TimeInterval = 10 * 60,
        crashReportLimit: Int = 3
    ) {
        self.appName = appName
        self.recipients = recipients
        self.logSubsystem = logSubsystem
        self.logWindow = logWindow
        self.crashReportLimit = crashReportLimit
    }
}

/// A file sent with a report.
public struct ReportAttachment: Equatable, Sendable {
    public var filename: String
    public var mimeType: String
    public var data: Data

    public init(filename: String, mimeType: String, data: Data) {
        self.filename = filename
        self.mimeType = mimeType
        self.data = data
    }
}

/// One report, ready to send: what the person wrote, the diagnostics, and the files.
public struct Report: Sendable {
    public var message: String
    public var diagnostics: Diagnostics
    public var attachments: [ReportAttachment]

    public init(message: String, diagnostics: Diagnostics, attachments: [ReportAttachment] = []) {
        self.message = message
        self.diagnostics = diagnostics
        self.attachments = attachments
    }

    /// "Medium Raw v0.2.0 (9): Settings button does nothing". The first line of the message,
    /// shortened, so a mailbox lists reports usefully.
    public var subject: String {
        let first = message.split(whereSeparator: \.isNewline).first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let head = "\(diagnostics.app) \(diagnostics.label)"
        guard !first.isEmpty else { return "\(head): report" }
        let short = first.count > 60 ? first.prefix(57) + "…" : Substring(first)
        return "\(head): \(short)"
    }

    /// The message, then the diagnostics as text, then a list of what's attached.
    public var body: String {
        var parts = [message.trimmingCharacters(in: .whitespacesAndNewlines)]
        parts.append("---\n" + diagnostics.text)
        if !attachments.isEmpty {
            parts.append("Attached: " + attachments.map(\.filename).joined(separator: ", "))
        }
        return parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}
