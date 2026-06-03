# LiteLLM UsageBar Design

## Summary

Build `litellm-usagebar`, a native macOS menu bar app that shows the current user's LiteLLM gateway usage cost.

The app is inspired by MeetingBar's interaction model: the most important status is visible directly in the macOS menu bar, and clicking the menu bar item opens a compact summary menu with actions and settings.

## Repository

- Path: `/Users/debanshu.rout/repo/litellm-usagebar`
- App name: `LiteLLM UsageBar`
- Implementation: native Swift/SwiftUI macOS app
- Gateway: `https://llm-gateway.razorpay.com`
- Auth header: `x-litellm-api-key: Bearer <api-key>`

## Goals

- Show month-to-date LiteLLM spend for the current configured user in the macOS menu bar.
- Show today's spend, budget progress, last refresh time, and actions on click.
- Store the LiteLLM API key securely in macOS Keychain.
- Refresh usage automatically every 5 minutes and support manual refresh.
- Send macOS notifications when budget usage crosses 50%, 80%, and 100%.

## Non-Goals

- No multi-user or team view in v1.
- No browser SSO in v1; leave an extension point for a future login flow.
- No editable gateway URL in v1.
- No rich dashboard or historical charting in v1.
- No network calls in tests.

## Architecture

### Components

- `StatusBarController`: owns the `NSStatusItem`, menu bar title, and click menu.
- `UsageService`: coordinates refresh timing, cache updates, and usage computation.
- `LiteLLMClient`: wraps `URLSession`, adds the Razorpay LiteLLM auth header, and decodes API responses.
- `KeychainStore`: stores, loads, updates, and clears the LiteLLM API key.
- `UsageViewModel`: exposes display-ready state for menu bar and menu content.
- `NotificationService`: requests notification permission and deduplicates budget threshold alerts.
- `SettingsView`: SwiftUI settings window for API key management and notification state.

### Data Flow

1. On first launch, the app shows a setup state and asks the user to enter a LiteLLM API key.
2. The app stores the key in macOS Keychain.
3. `UsageService` starts a 5-minute refresh timer when a key is present.
4. `LiteLLMClient` fetches usage from `https://llm-gateway.razorpay.com`.
5. `UsageService` converts the API response into a `UsageSnapshot`.
6. `UsageViewModel` formats month-to-date spend, today's spend, budget progress, last updated time, and error state.
7. `StatusBarController` updates the menu bar item and menu.
8. `NotificationService` sends threshold notifications when budget progress first crosses 50%, 80%, or 100% in the current budget period.

## LiteLLM API Usage

Primary endpoints:

- `/user/daily/activity`: source for daily spend, month-to-date aggregation, token counts, and request counts.
- `/user/info`: source for total user spend and user/key budget metadata.

The app uses the configured key as the current user identity. It does not ask for a user ID, email, team ID, or admin key.

Request header:

```text
x-litellm-api-key: Bearer <api-key>
```

Month-to-date spend is computed by requesting daily activity for the current calendar month and summing spend values. Today's spend is read from the daily activity row for the current local date.

Budget comes from LiteLLM user/key data. Prefer user-level budget fields when present, then key-level budget fields. If LiteLLM does not return a budget, the app shows spend without budget progress and does not send threshold notifications.

Currency is USD unless the API exposes a currency field.

Endpoint access is scoped to the configured user's key. If a budget or user-info route requires an admin key, explicit user ID, or broader gateway permission, the app must not escalate or ask for an admin key in v1. It should show `Budget unavailable` and continue showing spend data from accessible endpoints.

## UI Behavior

### Menu Bar

Default title:

```text
$42.10 MTD
```

Other title states:

- Loading: `Usage...`
- Missing API key: `Set API Key`
- No usable data: `Usage unavailable`

If refresh fails but cached data exists, keep showing the last known month-to-date spend in the menu bar. Surface the failure in the click menu.

### Click Menu

Use the approved "Summary First" layout.

Menu content:

- Header: `LiteLLM Usage`
- Month-to-date spend
- Today's spend
- Budget progress, shown as amount and percent when available
- Last updated time
- Error or stale-data message when applicable
- `Refresh Now`
- `Open LiteLLM UI`
- `Settings...`
- `Quit`

`Open LiteLLM UI` opens:

```text
https://llm-gateway.razorpay.com/ui
```

### Settings

Settings window:

- API key secure input
- Save/update API key
- Clear API key
- Read-only gateway URL: `https://llm-gateway.razorpay.com`
- Notification permission/status
- App version

The app should not show a dock icon during normal menu bar operation.

## Refresh And Caching

- Poll every 5 minutes when an API key is configured.
- `Refresh Now` triggers an immediate refresh.
- Manual refresh supersedes any in-flight background refresh.
- Cache the last successful usage snapshot in memory.
- Persist a lightweight last-successful snapshot locally so the app can show last known spend after restart.
- Do not persist the API key outside Keychain.

## Notifications

Budget thresholds:

- 50%
- 80%
- 100%

Notification behavior:

- Request macOS notification permission before sending threshold notifications.
- Send each threshold notification once per budget period.
- If LiteLLM exposes a budget reset date, use it to reset sent-threshold state.
- If no reset date is available, reset sent-threshold state on the calendar month boundary.
- Do not send threshold notifications when the budget is unavailable.

## Error Handling

- Missing API key: show setup state and do not poll.
- 401/403: show `API key invalid or unauthorized`; keep the key until the user clears or replaces it.
- Network/server failure: show last successful data and `Last refresh failed`.
- Missing budget: show spend and `Budget unavailable`; disable threshold notifications.
- Malformed response: show `Usage data format changed` and keep last known data.
- Spend above budget: show progress above 100% and send the 100% notification once for the current budget period.

## Testing

Unit tests:

- Decode LiteLLM `/user/daily/activity` responses.
- Decode LiteLLM `/user/info` responses.
- Aggregate today's spend and month-to-date spend.
- Compute budget percentage.
- Format menu bar and menu display values.
- Deduplicate notification thresholds.
- Handle missing budget, invalid response, and unauthorized response states.

Design for testability:

- Define a mockable `LiteLLMClient` protocol.
- Define a mockable `KeychainStore` protocol or wrapper.
- Avoid real gateway calls in unit tests.

Manual verification checklist:

- First launch with no key.
- Save key and refresh successfully.
- Invalid key shows unauthorized state.
- Manual refresh updates the menu.
- 5-minute background refresh updates cached state.
- Last successful data appears after app restart.
- Budget unavailable state is clear.
- Notification threshold deduping works.

## Future Enhancements

- Browser SSO/login flow.
- Editable gateway URL.
- Multi-user or team summary.
- Model/provider breakdown.
- Historical charts.
- Configurable notification thresholds.
