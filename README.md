# LiteLLM UsageBar

Native macOS menu bar app for viewing current-user LiteLLM gateway spend from `https://llm-gateway.razorpay.com`.

## Features

- Month-to-date spend in the macOS menu bar
- Click menu with today's spend, budget progress, last updated time, and refresh actions
- Secure API key storage in macOS Keychain
- Automatic refresh every 5 minutes
- Manual refresh from the menu
- Budget notifications at 50%, 80%, and 100% when LiteLLM exposes a budget

## Build

```bash
swift build
```

## Test

```bash
swift test
```

## Run

```bash
swift run LiteLLMUsageBar
```

Running with SwiftPM starts a plain executable, not a bundled `.app`. The app still runs, but macOS notifications are disabled in that mode because `UNUserNotificationCenter` requires an app bundle.

The app stores the LiteLLM key only in macOS Keychain. It uses this request header:

```text
x-litellm-api-key: Bearer <api-key>
```

The LiteLLM UI action opens:

```text
https://llm-gateway.razorpay.com/ui
```
