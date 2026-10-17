// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ReportKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ReportKit", targets: ["ReportKit"]),
        .library(name: "ReportCore", targets: ["ReportCore"]),
    ],
    targets: [
        // Foundation only: what a report contains. Builds and tests on the Mac in seconds.
        .target(name: "ReportCore"),
        // The iPhone and iPad side: the sheet, shake and screenshot triggers, mail, crash reports.
        .target(name: "ReportKit", dependencies: ["ReportCore"]),
        .testTarget(name: "ReportCoreTests", dependencies: ["ReportCore"]),
    ]
)
