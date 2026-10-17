#if canImport(UIKit)
import MetricKit
import ReportCore
import SwiftUI
import UIKit

extension View {
    /// Attaches the report sheet, shake-to-report and the after-screenshot offer.
    /// Put it once on the app's root view.
    public func reportable(_ reporter: Reporter) -> some View {
        modifier(Reportable(reporter: reporter))
    }
}

private struct Reportable: ViewModifier {
    @Bindable var reporter: Reporter

    func body(content: Content) -> some View {
        content
            .environment(reporter)
            .sheet(item: $reporter.draft) { _ in
                ReportSheet(reporter: reporter)
            }
            .alert("Report a problem?", isPresented: $reporter.offeringAfterScreenshot) {
                Button("Report") { reporter.present() }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("Send this screen to the \(reporter.configuration.appName) team with a note.")
            }
            .onReceive(NotificationCenter.default.publisher(for: .reportKitDeviceShaken)) { _ in
                if reporter.opensOnShake { reporter.present() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
                if reporter.offersAfterScreenshot, reporter.draft == nil {
                    reporter.offeringAfterScreenshot = true
                }
            }
    }
}

/// A Settings row or button: "Report a problem".
public struct ReportButton: View {
    @Environment(Reporter.self) private var reporter
    private let title: LocalizedStringKey

    public init(_ title: LocalizedStringKey = "Report a problem") {
        self.title = title
    }

    public var body: some View {
        Button { reporter.present() } label: {
            Label(title, systemImage: "ladybug")
        }
    }
}

extension Notification.Name {
    static let reportKitDeviceShaken = Notification.Name("ReportKit.deviceShaken")
}

extension UIWindow {
    /// UIKit sends shakes to the first responder and up the chain to the window.
    @objc override open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .reportKitDeviceShaken, object: self)
        }
        super.motionEnded(motion, with: event)
    }
}

/// The screen as the person sees it, captured before the sheet covers it.
enum ScreenCapture {
    @MainActor
    static func keyWindow() -> UIImage? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
        guard let window else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }
}

/// Saves MetricKit's crash and hang reports, which iOS delivers on a later launch.
final class CrashCollector: NSObject, MXMetricManagerSubscriber, Sendable {
    let store: CrashStore

    init(store: CrashStore) {
        self.store = store
        super.init()
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            try? store.save(payload.jsonRepresentation(), at: payload.timeStampEnd)
        }
    }
}
#endif
