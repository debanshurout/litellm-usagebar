# Menu Bar Amount Toggle Design

## Goal

Let users choose whether the macOS menu bar shows the LiteLLM month-to-date amount directly or hides the amount behind a dollar icon.

## Settings Interaction

Add a `Menu Bar` section in Settings.

The section has one button:

- `Hide Amount on Bar` when the amount is currently visible
- `Show Amount on Bar` when the amount is currently hidden

Default behavior remains the existing amount display, for example `$87.35 MTD`.

## Menu Bar Behavior

When amount display is enabled, keep the existing menu bar text behavior.

When amount display is disabled, the status item shows only a blue dollar icon inspired by the provided reference image. The dropdown menu content remains unchanged, including month-to-date, today, budget, refresh, UI, settings, and quit rows.

The setting is persisted in `UserDefaults` and updates the status item immediately when the user clicks the settings button.

## Scope

Do not change LiteLLM API calls, spend aggregation, menu dropdown contents, API key settings, notification behavior, or keyboard shortcuts.
