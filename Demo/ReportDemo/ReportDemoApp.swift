import OSLog
import ReportKit
import SwiftUI

@main
struct ReportDemoApp: App {
    @State private var reporter = Reporter(
        ReportConfiguration(appName: "Report Demo", recipients: ["support@1041soft.com"],
                            logSubsystem: "com.billdonner.ReportDemo"),
        context: { ["palette": "coral"] }
    )
    @State private var showsSettings = false

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                List {
                    Button("Settings") { showsSettings = true }
                }
                .navigationTitle("Report Demo")
                .onAppear {
                    reporter.details["screen"] = "Home"
                    Logger(subsystem: "com.billdonner.ReportDemo", category: "demo").notice("home appeared")
                }
                // Like most apps: the report row lives in a Settings sheet.
                .sheet(isPresented: $showsSettings) {
                    NavigationStack {
                        List { Section("Feedback") { ReportButton() } }
                            .navigationTitle("Settings")
                    }
                }
            }
            .reportable(reporter)
        }
    }
}
