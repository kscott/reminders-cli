// main.swift — test runner for RemindersLib
//
// Harness only. Test suites live in their own files, one per source file.
// Run via:  swift run reminders-tests

import Foundation

// MARK: - Minimal test harness

final class TestRunner: @unchecked Sendable {
    private var passed = 0
    private var failed = 0

    func expect(_ description: String, _ condition: Bool, file: String = #file, line: Int = #line) {
        if condition {
            print("  ✓ \(description)")
            passed += 1
        } else {
            print("  ✗ \(description)  [\(URL(fileURLWithPath: file).lastPathComponent):\(line)]")
            failed += 1
        }
    }

    func suite(_ name: String, _ body: () -> Void) {
        print("\n\(name)")
        body()
    }

    func finish() {
        print("\n\(passed + failed) tests: \(passed) passed, \(failed) failed")
        if failed > 0 { exit(1) }
    }
}

// MARK: - Entry point

let t = TestRunner()
runDateParserTests(t)
runRecurrenceParsingTests(t)
runOptionsParsingTests(t)
t.finish()
