// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "reminders-cli",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/kscott/get-clear.git", branch: "main"),
        .package(url: "https://github.com/Quick/Quick.git", from: "7.0.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0"),
    ],
    targets: [
        // Pure logic — no Apple framework dependencies, fully testable
        .target(
            name: "RemindersLib",
            path: "Sources/RemindersLib"
        ),
        // Main binary — depends on RemindersLib plus EventKit/AppKit
        .executableTarget(
            name: "reminders-bin",
            dependencies: [
                "RemindersLib",
                .product(name: "GetClearKit", package: "get-clear"),
            ],
            path: "Sources/RemindersCLI",
            linkerSettings: [
                .linkedFramework("EventKit"),
                .linkedFramework("AppKit"),
            ]
        ),
        // Test suite — run via: swift test
        .testTarget(
            name: "RemindersLibTests",
            dependencies: [
                "RemindersLib",
                .product(name: "GetClearKit", package: "get-clear"),
                .product(name: "Quick", package: "Quick"),
                .product(name: "Nimble", package: "Nimble"),
            ],
            path: "Tests/RemindersLibTests"
        ),
    ]
)
