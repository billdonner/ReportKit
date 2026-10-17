import OSLog
import ReportKit
import SwiftUI

@main
struct ReportDemoApp: App {
    @State private var reporter = Reporter(
        ReportConfiguration(appName: "Report Demo", recipients: ["support@1041soft.com"],
                            logSubsystem: "com.billdonner.ReportDemo"),
        context: { ["screen": "Home", "palette": "coral"] }
    )

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    Section("Settings") {
                        ReportButton()
                    }
                }
                .navigationTitle("Report Demo")
                .onAppear { Logger(subsystem: "com.billdonner.ReportDemo", category: "demo").notice("home appeared") }
            }
            .reportable(reporter)
        }
    }
}
