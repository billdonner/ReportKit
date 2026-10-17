#if canImport(UIKit)
import MessageUI
import ReportCore
import SwiftUI
import UIKit

/// What happened, the screenshot, the diagnostics, then Send. Mail when the device has it set
/// up; otherwise the share sheet (Gmail, Messages, Notes, AirDrop) or Copy.
struct ReportSheet: View {
    @Bindable var reporter: Reporter
    @State private var sending: Report?
    @State private var sharing: [URL]?
    @State private var copied = false
    @FocusState private var writing: Bool

    var body: some View {
        if let draft = Binding($reporter.draft) {
            NavigationStack {
                Form {
                    Section {
                        TextField("What happened, and what did you expect?", text: draft.message, axis: .vertical)
                            .lineLimit(4...12)
                            .focused($writing)
                    } footer: {
                        Text("Screens and steps help most.")
                    }
                    if let image = draft.wrappedValue.screenshot {
                        Section {
                            Toggle("Include this screen", isOn: draft.includesScreenshot)
                            if draft.wrappedValue.includesScreenshot {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 220)
                                    .frame(maxWidth: .infinity)
                                    .accessibilityLabel("Screenshot to send")
                            }
                        }
                    }
                    Section {
                        Toggle("Include diagnostics", isOn: draft.includesDiagnostics)
                        DisclosureGroup("What's included") {
                            Text(details(draft.wrappedValue))
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    } footer: {
                        Text("App version, device and system always go with a report. Diagnostics add the app's details, its recent log and any crash reports.")
                    }
                    Section {
                        Button {
                            UIPasteboard.general.string = reporter.report(from: draft.wrappedValue).body
                            copied = true
                        } label: {
                            Label(copied ? "Copied" : "Copy report as text", systemImage: copied ? "checkmark" : "doc.on.doc")
                        }
                    }
                }
                .navigationTitle("Report a problem")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { reporter.close() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Send") { send(draft.wrappedValue) }
                            .disabled(draft.wrappedValue.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .onAppear { writing = true }
                .onDisappear { reporter.closed() }
                .sheet(item: $sending) { report in
                    MailComposer(report: report, recipients: reporter.configuration.recipients) { sent in
                        sending = nil
                        if sent { finish() }
                    }
                    .ignoresSafeArea()
                }
                .sheet(isPresented: Binding(get: { sharing != nil }, set: { if !$0 { sharing = nil } })) {
                    ShareSheet(items: sharing ?? []) { shared in
                        sharing = nil
                        if shared { finish() }
                    }
                }
            }
        }
    }

    private func details(_ draft: Reporter.Draft) -> String {
        let report = reporter.report(from: draft)
        let files = report.attachments.map(\.filename).joined(separator: ", ")
        return report.diagnostics.text + (files.isEmpty ? "" : "\n\nFiles: \(files)")
    }

    private func send(_ draft: Reporter.Draft) {
        let report = reporter.report(from: draft)
        if MFMailComposeViewController.canSendMail() {
            sending = report
        } else {
            sharing = ReportFiles.write(report)
        }
    }

    private func finish() {
        reporter.crashes.removeAll()
        reporter.close()
    }
}

extension Report: Identifiable {
    public var id: String { subject + diagnostics.date.description }
}

/// Writes a report's body and attachments to a fresh temporary folder for the share sheet.
enum ReportFiles {
    static func write(_ report: Report) -> [URL] {
        let folder = URL.temporaryDirectory.appending(path: "Report-\(UUID().uuidString)", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var urls: [URL] = []
        let body = folder.appending(path: "report.txt")
        if (try? Data((report.subject + "\n\n" + report.body).utf8).write(to: body)) != nil {
            urls.append(body)
        }
        for file in report.attachments {
            let url = folder.appending(path: file.filename)
            if (try? file.data.write(to: url)) != nil { urls.append(url) }
        }
        return urls
    }
}

private struct MailComposer: UIViewControllerRepresentable {
    let report: Report
    let recipients: [String]
    let done: (Bool) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let mail = MFMailComposeViewController()
        mail.mailComposeDelegate = context.coordinator
        mail.setToRecipients(recipients)
        mail.setSubject(report.subject)
        mail.setMessageBody(report.body, isHTML: false)
        for file in report.attachments {
            mail.addAttachmentData(file.data, mimeType: file.mimeType, fileName: file.filename)
        }
        return mail
    }

    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let done: (Bool) -> Void
        init(done: @escaping (Bool) -> Void) { self.done = done }

        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult, error: Error?) {
            done(result == .sent || result == .saved)
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [URL]
    let done: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
        sheet.completionWithItemsHandler = { _, completed, _, _ in done(completed) }
        return sheet
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
#endif
