# ReportKit

In-app bug reports for 1041 Soft's iOS apps, independent of TestFlight. No dependencies, no
servers, no keys: a report leaves the phone only when the person sends it, by email or the
share sheet.

**What a report holds:** what the person wrote; the screen they were on (captured before the
sheet opens); the app's version, build, device, system, locale and free disk; the app's own
context (screen, layout, account: whatever it supplies); its log from the last 10 minutes;
and recent crash and hang reports from MetricKit. The person can turn off the screenshot and
the diagnostics, and sees exactly what's included before sending.

**How it opens:** a `ReportButton` (put it in Settings), shaking the device, or an offer after
the person takes a screenshot. Each can be turned off.

**How it sends:** Mail, with the files attached, when the device has a Mail account. Otherwise
the share sheet (Gmail, Messages, Notes, Save to Files, AirDrop), or Copy report as text.

## Add it to an app

`project.yml` (XcodeGen):

```yaml
packages:
  ReportKit:
    path: ../ReportKit          # or url: https://github.com/billdonner/ReportKit, from: 0.1.2
targets:
  MyApp:
    dependencies:
      - package: ReportKit
```

The app:

```swift
import ReportKit

@main struct MyApp: App {
    @State private var reporter = Reporter(
        ReportConfiguration(appName: "Qross", recipients: ["support@1041soft.com"],
                            logSubsystem: "com.billdonner.qross"),
        context: { ["screen": Router.shared.screenName] }   // anything that helps, read on open
    )

    var body: some Scene {
        WindowGroup { RootView().reportable(reporter) }
    }
}

// In Settings:
ReportButton()            // "Report a problem"
```

The sheet opens over whatever is showing, including the app's own sheets, so `ReportButton`
works inside a Settings sheet. For details that change as the person moves around, set them as
they change: `reporter.details["tab"] = "Your posts"`. They're merged over `context`.

Log with `Logger(subsystem: "com.billdonner.qross", category: ...)` and those lines come with
every report. `context` runs on the main actor each time the sheet opens.

**Privacy:** the package ships its own privacy manifest (free disk space, reason 7D9E.1:
an optional bug report). Nothing is collected by the app or sent anywhere automatically, so the App Store
answer stays "Data Not Collected". Crash reports stay in Caches until a report is sent.

## Layout

| Target | What | Platforms |
|---|---|---|
| `ReportCore` | `Diagnostics`, `Report`, `ReportConfiguration`, `CrashStore`, `LogCollector`. Foundation only. | iOS, macOS (so `swift test` runs on the Mac) |
| `ReportKit` | `Reporter`, `.reportable(_:)`, `ReportButton`, the sheet, Mail and share fallbacks, shake, screenshot offer, MetricKit. Re-exports `ReportCore`. | iOS 17+ |
| `Demo/` | A one-screen app and a UI test that opens, fills and sends a report | iOS |

## Test

```bash
swift test                                    # ReportCore, on the Mac
cd Demo && xcodegen generate && xcodebuild test -project ReportDemo.xcodeproj \
  -scheme ReportDemo -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Later

Sending straight into GitHub issues needs a small relay server that holds the GitHub key
(never the app). The `Report` value is already the payload; only a new sender is needed.
