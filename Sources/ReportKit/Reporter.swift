#if canImport(UIKit)
import Observation
import ReportCore
import SwiftUI
import UIKit

/// The app's one reporter. Create it at launch, attach it with `.reportable(reporter)`,
/// and open the sheet with `reporter.present()` (a Settings row) or by shaking the device.
@Observable
@MainActor
public final class Reporter {
    public let configuration: ReportConfiguration
    /// The app's own context, read when a report opens: screen, layout, account, settings.
    @ObservationIgnored public var context: @MainActor () -> [String: String]

    /// Offer a report after someone takes a screenshot.
    public var offersAfterScreenshot = true
    /// Open the sheet when the device is shaken.
    public var opensOnShake = true
    /// Details the app keeps current as things change (the tab, the layout). Merged over
    /// `context` when a report opens.
    @ObservationIgnored public var details: [String: String] = [:]

    var draft: Draft?
    @ObservationIgnored private weak var sheet: UIViewController?

    let crashes: CrashStore
    @ObservationIgnored private var crashCollector: CrashCollector?

    public init(
        _ configuration: ReportConfiguration,
        crashes: CrashStore = CrashStore(),
        context: @escaping @MainActor () -> [String: String] = { [:] }
    ) {
        self.configuration = configuration
        self.crashes = crashes
        self.context = context
        crashCollector = CrashCollector(store: crashes)
    }

    /// Captures the screen as it is now, then opens the sheet over whatever is showing,
    /// including the app's own sheets.
    public func present() {
        guard draft == nil, let top = ScreenCapture.topController() else { return }
        draft = Draft(screenshot: ScreenCapture.keyWindow(), diagnostics: diagnostics())
        let host = UIHostingController(rootView: ReportSheet(reporter: self))
        sheet = host
        top.present(host, animated: true)
    }

    /// After a screenshot: asks whether to report it.
    func offer() {
        guard draft == nil, let top = ScreenCapture.topController(), !(top is UIAlertController) else { return }
        let alert = UIAlertController(
            title: "Report a problem?",
            message: "Send this screen to the \(configuration.appName) team with a note.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Not now", style: .cancel))
        alert.addAction(UIAlertAction(title: "Report", style: .default) { [weak self] _ in self?.present() })
        top.present(alert, animated: true)
    }

    func close() {
        sheet?.dismiss(animated: true)
        closed()
    }

    /// The sheet went away, by Cancel, Send or a swipe.
    func closed() {
        sheet = nil
        draft = nil
    }

    func diagnostics() -> Diagnostics {
        let device = UIDevice.current
        return Diagnostics.collect(
            appName: configuration.appName,
            context: context().merging(details) { _, detail in detail },
            system: "\(device.systemName) \(device.systemVersion)"
        )
    }

    /// The report as it will be sent, with only the parts the person kept.
    func report(from draft: Draft) -> Report {
        var files: [ReportAttachment] = []
        if draft.includesScreenshot, let png = draft.screenshot?.pngData() {
            files.append(ReportAttachment(filename: "screenshot.png", mimeType: "image/png", data: png))
        }
        if draft.includesDiagnostics {
            if let json = try? draft.diagnostics.json() {
                files.append(ReportAttachment(filename: "diagnostics.json", mimeType: "application/json", data: json))
            }
            if let subsystem = configuration.logSubsystem {
                let log = LogCollector.recent(subsystem: subsystem, window: configuration.logWindow)
                files.append(ReportAttachment(filename: "log.txt", mimeType: "text/plain", data: Data(log.utf8)))
            }
            files += crashes.attachments(limit: configuration.crashReportLimit)
        }
        let diagnostics = draft.includesDiagnostics ? draft.diagnostics : draft.diagnostics.withoutContext
        return Report(message: draft.message, diagnostics: diagnostics, attachments: files)
    }

    /// What the sheet is editing.
    struct Draft: Identifiable {
        let id = UUID()
        var message = ""
        var screenshot: UIImage?
        var diagnostics: Diagnostics
        var includesScreenshot = true
        var includesDiagnostics = true

        init(screenshot: UIImage?, diagnostics: Diagnostics) {
            self.screenshot = screenshot
            self.diagnostics = diagnostics
            includesScreenshot = screenshot != nil
        }
    }
}

extension Diagnostics {
    /// The version and device stay even when the person turns diagnostics off; the app's
    /// own context (which may name their account) doesn't.
    var withoutContext: Diagnostics {
        var copy = self
        copy.context = [:]
        return copy
    }
}
#endif
