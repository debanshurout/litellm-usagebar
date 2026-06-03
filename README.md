# LiteLLM UsageBar

Native macOS menu bar app for viewing current-user LiteLLM gateway spend from `https://llm-gateway.razorpay.com`.

## Features

- Month-to-date spend in the macOS menu bar
- Click menu with today's spend, budget progress, last updated time, and refresh actions
- Secure API key storage in macOS Keychain
- Automatic refresh every 5 minutes
- Manual refresh from the menu
- Budget notifications at 50%, 80%, and 100% when LiteLLM exposes a budget

## Requirements

- macOS 13 or newer
- Xcode Command Line Tools or Xcode
- Git
- A LiteLLM gateway API key

Install the Xcode Command Line Tools if Swift is not available:

```bash
xcode-select --install
```

Verify Swift is available:

```bash
swift --version
```

## Quick Start

Clone and run the app from source:

```bash
git clone https://github.com/debanshurout/litellm-usagebar.git
cd litellm-usagebar
swift run LiteLLMUsageBar
```

Running with SwiftPM starts a plain executable, not a bundled `.app`. The app still runs, but macOS notifications are disabled in this mode because `UNUserNotificationCenter` requires an app bundle.

## Install as a macOS App

For regular use, build a release binary and wrap it in a local `.app` bundle:

```bash
git clone https://github.com/debanshurout/litellm-usagebar.git
cd litellm-usagebar
swift build -c release

APP="$HOME/Applications/LiteLLMUsageBar.app"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/LiteLLMUsageBar "$APP/Contents/MacOS/LiteLLMUsageBar"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>LiteLLMUsageBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.razorpay.litellm-usagebar</string>
    <key>CFBundleName</key>
    <string>LiteLLM UsageBar</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

open "$APP"
```

The app appears as a menu bar item. It does not show a Dock icon.

To start it automatically at login, add `$HOME/Applications/LiteLLMUsageBar.app` in `System Settings > General > Login Items`.

## First Run

1. Open the menu bar item.
2. Click `Settings...`.
3. Paste your LiteLLM API key.
4. Click `Test Connection`.
5. If the HTTP status is successful, click `Save`.

The API key is stored only in macOS Keychain under:

```text
service: com.razorpay.litellm-usagebar
account: litellm-api-key
```

If macOS asks for Keychain access, choose `Always Allow` to avoid repeated prompts.

## Update

Quit the running app from the menu bar, then rebuild and replace the installed binary:

```bash
cd litellm-usagebar
git pull
swift build -c release
cp .build/release/LiteLLMUsageBar "$HOME/Applications/LiteLLMUsageBar.app/Contents/MacOS/LiteLLMUsageBar"
open "$HOME/Applications/LiteLLMUsageBar.app"
```

## Build from Source

```bash
swift build
```

## Run from Source

```bash
swift run LiteLLMUsageBar
```

## Test Suite

```bash
swift test
```

If `swift test` fails with `no such module 'XCTest'`, install full Xcode or select the correct Xcode toolchain:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Troubleshooting

### Usage unavailable

Open `Settings...` and click `Test Connection`. The result shows the HTTP status. Common cases:

- `HTTP 200`: the key is valid. Click `Save`.
- `HTTP 401` or `HTTP 403`: the key is invalid or unauthorized.
- `no HTTP status`: the gateway could not be reached.

### Keychain prompts appear repeatedly

When macOS asks for the `login` keychain password, choose `Always Allow`.

To delete the stored key and start over:

```bash
security delete-generic-password -s com.razorpay.litellm-usagebar -a litellm-api-key
```

Then reopen settings and save the key again.

### Notifications do not work

Notifications are unavailable when running with `swift run`. Use the `.app` install flow above and then click `Refresh Notification Status` in settings.

The app stores the LiteLLM key only in macOS Keychain. It uses this request header:

```text
x-litellm-api-key: Bearer <api-key>
```

The LiteLLM UI action opens:

```text
https://llm-gateway.razorpay.com/ui
```
