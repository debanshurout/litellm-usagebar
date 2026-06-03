# Settings Test Connection Design

## Goal

Add an always-visible `Test Connection` button to the settings API key section so users can verify whether the current or saved LiteLLM API key works.

## Interaction

`Test Connection` is always visible in the API key section.

When the key is saved, the API key section shows:

- `API key saved`
- `Test Connection`
- `Resave Key`

When the key is being edited, the API key section shows:

- secure API key field
- `Save`
- `Paste`
- `Test Connection`
- `Clear`

Clicking `Test Connection` uses the key currently relevant to the view:

- edit mode: the typed key
- saved mode: the saved key already loaded by the settings view model

If the key is empty, the status text is red and reads `Enter an API key to test`.

## Network Behavior

The app calls `GET /user/info` because it is the lightest existing endpoint that validates the key. The connection test must return the raw HTTP status code without decoding the response body, so the settings UI can show a clear result even for authentication and gateway failures.

## Status Display

While the request is running, the settings UI shows `Testing connection...` in the neutral secondary color and disables the test button.

For HTTP `200..<300`, show a green message:

`Connection successful (HTTP 200)`

For all non-2xx HTTP statuses, show a red message:

`Connection failed (HTTP <status>)`

For transport failures where no HTTP response exists, show a red message:

`Connection failed (no HTTP status)`

## Scope

Do not change the menu bar usage refresh flow, Keychain persistence behavior, LiteLLM spend aggregation, or notification behavior.
