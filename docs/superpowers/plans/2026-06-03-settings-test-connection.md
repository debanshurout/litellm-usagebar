# Settings Test Connection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an always-visible settings `Test Connection` button that validates the active API key and displays green/red HTTP status feedback.

**Architecture:** Add a small core connection-result model and a lightweight `/user/info` status method on `LiteLLMClient`. Bind the settings view model to that method and render a status line with semantic color in SwiftUI.

**Tech Stack:** SwiftPM, Swift, SwiftUI, URLSession, XCTest-style tests where the local toolchain supports them.

---

### Task 1: Connection Test Result Model

**Files:**
- Create: `Sources/LiteLLMUsageBarCore/ConnectionTestResult.swift`
- Create: `Tests/LiteLLMUsageBarCoreTests/ConnectionTestResultTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import LiteLLMUsageBarCore

final class ConnectionTestResultTests: XCTestCase {
    func testSuccessMessageIncludesHTTPStatus() {
        let result = ConnectionTestResult(statusCode: 200)

        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.message, "Connection successful (HTTP 200)")
    }

    func testFailureMessageIncludesHTTPStatus() {
        let result = ConnectionTestResult(statusCode: 401)

        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.message, "Connection failed (HTTP 401)")
    }

    func testFailureMessageWithoutHTTPStatus() {
        let result = ConnectionTestResult(statusCode: nil)

        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.message, "Connection failed (no HTTP status)")
    }
}
```

- [ ] **Step 2: Run targeted test**

Run: `swift test --filter ConnectionTestResultTests`

Expected: compile failure before implementation, or the known local `no such module 'XCTest'` toolchain failure.

- [ ] **Step 3: Implement result model**

```swift
public struct ConnectionTestResult: Equatable {
    public let statusCode: Int?

    public var isSuccess: Bool {
        guard let statusCode else {
            return false
        }
        return (200..<300).contains(statusCode)
    }

    public var message: String {
        guard let statusCode else {
            return "Connection failed (no HTTP status)"
        }
        if isSuccess {
            return "Connection successful (HTTP \(statusCode))"
        }
        return "Connection failed (HTTP \(statusCode))"
    }

    public init(statusCode: Int?) {
        self.statusCode = statusCode
    }
}
```

### Task 2: LiteLLM Client Status Probe

**Files:**
- Modify: `Sources/LiteLLMUsageBarCore/LiteLLMClient.swift`
- Modify: `Tests/LiteLLMUsageBarCoreTests/UsageServiceTestDoubles.swift`

- [ ] **Step 1: Add protocol method**

```swift
func testConnection(apiKey: String) async -> ConnectionTestResult
```

- [ ] **Step 2: Implement URLSession probe**

Build a `GET /user/info` request with the same `x-litellm-api-key` and `Accept` headers as the existing client. Return `ConnectionTestResult(statusCode: httpResponse.statusCode)` for HTTP responses and `ConnectionTestResult(statusCode: nil)` for transport or malformed-response failures.

- [ ] **Step 3: Update test doubles**

`RecordingLiteLLMClient` should expose `connectionTestResult = ConnectionTestResult(statusCode: 200)` and increment `connectionTestCalls` when `testConnection(apiKey:)` is called.

### Task 3: Settings UI Binding

**Files:**
- Modify: `Sources/LiteLLMUsageBar/SettingsWindowController.swift`
- Modify: `Sources/LiteLLMUsageBar/SettingsView.swift`
- Modify: `Sources/LiteLLMUsageBar/AppDelegate.swift`

- [ ] **Step 1: Inject client into settings**

Pass the existing `URLSessionLiteLLMClient` instance to both `UsageService` and `SettingsWindowController`, so settings can run the status probe without creating a second client.

- [ ] **Step 2: Add view model state**

Add:

```swift
@Published var connectionStatusText = ""
@Published var connectionStatusColor: Color = .secondary
@Published var isTestingConnection = false
```

- [ ] **Step 3: Add view model action**

Add `testConnection()` that trims the current key, handles empty key with red status, sets neutral loading state, awaits `client.testConnection(apiKey:)`, then applies green/red status based on `result.isSuccess`.

- [ ] **Step 4: Render always-visible button**

Show `Test Connection` in both saved and edit modes, disabled while `isTestingConnection` is true. Render the connection result line below the API key controls using `connectionStatusColor`.

### Task 4: Verify and Commit

**Files:**
- All changed files

- [ ] **Step 1: Build**

Run: `swift build`

Expected: build completes successfully.

- [ ] **Step 2: Relaunch**

Stop the running app process and run: `swift run LiteLLMUsageBar`

Expected: app launches. Settings includes the always-visible `Test Connection` button. Connection test messages include HTTP status codes.

- [ ] **Step 3: Commit**

```bash
git add Sources Tests docs
git commit -m "feat: add settings connection test"
```
