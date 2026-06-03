# Manual Verification

Run the app:

```bash
swift run LiteLLMUsageBar
```

## Checklist

- First launch with no stored key shows `Set API Key`.
- Click menu opens with `LiteLLM Usage`, spend rows, `Refresh Now`, `Open LiteLLM UI`, `Settings...`, and `Quit`.
- Settings opens from the menu and shows a secure API-key input.
- Saving an API key writes to Keychain and triggers refresh.
- Clearing an API key removes it from Keychain and returns the app to missing-key state.
- Invalid key returns `API key invalid or unauthorized` while preserving last successful spend if one exists.
- Network or server failure returns `Last refresh failed` while preserving last successful spend if one exists.
- Missing budget shows `Budget unavailable` and no threshold notification is sent.
- Budget at 50%, 80%, and 100% sends each notification once for the current period.
- SwiftPM runs disable notifications because the process is not bundled as a `.app`; verify notification delivery from a bundled app build.
- Quitting from the menu terminates the process.
