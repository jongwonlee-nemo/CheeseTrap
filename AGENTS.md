# Project scope

CheeseTrap builds and launches through `./build.sh` as `build/CheeseTrap.app`.
Keep upstream license notices in source and local builds. Do not add release or installation workflows.

Keep keyboard window selection and the requested close/force-quit commands in the native macOS Mission Control view:
Tab/Shift+Tab within one monitor, Option+Tab/Option+Shift+Tab between monitors,
app-name search, Up/Down through search results, Return, Escape, and Backspace.
Command+W closes the selected window; Command+Q force quits its application.

Capture the starting monitor from the pointer on Mission Control entry; synthetic pointer movement must not change it.
Handle monitor shortcuts only inside Mission Control with multiple monitors. Do not register global hotkeys.

- Do not restore other window management actions, gestures, settings, or launch at login.
- Do not log input, search queries, window metadata, or diagnostics. Do not add telemetry or crash handlers.
- Preserve Accessibility permission checks, Mission Control detection, Space filtering, and input-tap cleanup.
- Keep AppKit services small and use weak references in callbacks.
- Keep the idle memory footprint under the existing 13 MB target; do not create panels before use.
- Do not add automated unit, integration, or UI test files to this repository.
- Use short comments for macOS behavior that is not apparent from the code.
