import Foundation
import Testing
@testable import ReportCore

private func sample(context: [String: String] = [:]) -> Diagnostics {
    Diagnostics(
        app: "Medium Raw", version: "0.2.0", build: "9", bundleID: "com.example.app",
        device: "iPhone18,2", system: "iOS 27.0", locale: "en_US", timeZone: "America/New_York",
        date: Date(timeIntervalSince1970: 1_800_000_000), freeDiskMB: 1234, lowPowerMode: false,
        context: context
    )
}

@Suite struct DiagnosticsTests {
    @Test func labelMatchesTheMainScreen() {
        #expect(sample().label == "v0.2.0 (9)")
    }

    @Test func textListsTheAppFirstAndContextSortedLast() {
        let lines = sample(context: ["screen": "Settings", "canvas": "compact"]).text.split(separator: "\n")
        #expect(lines.first == "Medium Raw v0.2.0 (9)")
        #expect(lines.suffix(2) == ["canvas: compact", "screen: Settings"])
        #expect(lines.contains("Free disk: 1234 MB"))
        #expect(!lines.contains { $0.hasPrefix("Low Power") })
    }

    @Test func jsonRoundTrips() throws {
        let original = sample(context: ["a": "b"])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(Diagnostics.self, from: original.json()) == original)
    }

    @Test func collectReadsTheProcess() {
        let collected = Diagnostics.collect(appName: "Test", context: ["k": "v"])
        #expect(collected.app == "Test")
        #expect(!collected.device.isEmpty)
        #expect(collected.context == ["k": "v"])
    }
}

@Suite struct ReportTests {
    @Test func subjectUsesTheFirstLine() {
        let report = Report(message: "Settings button does nothing\nI tapped it twice", diagnostics: sample())
        #expect(report.subject == "Medium Raw v0.2.0 (9): Settings button does nothing")
    }

    @Test func subjectShortensLongLinesAndHandlesBlank() {
        let long = Report(message: String(repeating: "x", count: 100), diagnostics: sample())
        #expect(long.subject.hasSuffix("…"))
        #expect(long.subject.count == "Medium Raw v0.2.0 (9): ".count + 58)
        #expect(Report(message: "  ", diagnostics: sample()).subject == "Medium Raw v0.2.0 (9): report")
    }

    @Test func bodyHasMessageDiagnosticsAndFiles() {
        let file = ReportAttachment(filename: "screenshot.png", mimeType: "image/png", data: Data())
        let body = Report(message: "Broke\n", diagnostics: sample(), attachments: [file]).body
        #expect(body.hasPrefix("Broke\n\n---\nMedium Raw v0.2.0 (9)"))
        #expect(body.hasSuffix("Attached: screenshot.png"))
    }
}

@Suite struct CrashStoreTests {
    private func store(keep: Int = 2) -> CrashStore {
        CrashStore(folder: URL.temporaryDirectory.appending(path: "crash-\(UUID().uuidString)"), keep: keep)
    }

    @Test func keepsTheNewestAndReturnsThemFirst() throws {
        let crashes = store()
        for second in [1.0, 3.0, 2.0] {
            try crashes.save(Data("\(Int(second))".utf8), at: Date(timeIntervalSince1970: second))
        }
        let kept = crashes.attachments(limit: 5)
        #expect(kept.map { String(decoding: $0.data, as: UTF8.self) } == ["3", "2"])
        #expect(kept.allSatisfy { $0.filename.hasPrefix("crash-") && $0.mimeType == "application/json" })
        crashes.removeAll()
        #expect(crashes.attachments(limit: 5).isEmpty)
    }

    @Test func emptyWhenNothingSaved() {
        #expect(store().attachments(limit: 3).isEmpty)
    }
}

@Suite struct LogCollectorTests {
    @Test func formatsALine() {
        let line = LogCollector.line(date: Date(timeIntervalSince1970: 0), level: .error, category: "net", message: "timed out")
        #expect(line.hasSuffix("[error] net: timed out"))
    }

    @Test func readsThisProcessWithoutThrowing() {
        let text = LogCollector.recent(subsystem: "com.example.none", window: 60)
        #expect(!text.isEmpty)
    }
}
