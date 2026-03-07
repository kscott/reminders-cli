// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "reminders-cli",
    platforms: [.macOS(.v14)],
    targets: [
        // Pure logic — no Apple framework dependencies, fully testable
        .target(
            name: "RemindersLib",
            path: "Sources/RemindersLib"
        ),
        // Main binary — depends on RemindersLib plus EventKit/AppKit
        .executableTarget(
            name: "reminders-bin",
            dependencies: ["RemindersLib"],
            path: "Sources/RemindersCLI",
            linkerSettings: [
                .linkedFramework("EventKit"),
                .linkedFramework("AppKit"),
            ]
        ),
        // Test runner — executable rather than XCTest target so it works
        // with just the Swift CLI toolchain (no Xcode required)
        .executableTarget(
            name: "reminders-tests",
            dependencies: ["RemindersLib"],
            path: "Tests/RemindersLibTests"
        ),
    ]
)
