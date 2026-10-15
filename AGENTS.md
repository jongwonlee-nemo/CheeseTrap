# Project scope

Keep only keyboard window selection in the native macOS Mission Control view:
Tab/Shift+Tab within one monitor, Option+Tab/Option+Shift+Tab between monitors,
app-name search, Up/Down through search results, Return, Escape, and Backspace.

Capture the starting monitor from the pointer on Mission Control entry; synthetic pointer movement must not change it.
Handle monitor shortcuts only inside Mission Control with multiple monitors. Do not register global hotkeys.

- Do not restore window management actions, gestures, settings, or launch at login.
- Do not log input, search queries, window metadata, or diagnostics. Do not add telemetry or crash handlers.
- Preserve Accessibility permission checks, Mission Control detection, Space filtering, and input-tap cleanup.
- Keep AppKit services small and use weak references in callbacks.
- Keep the idle memory footprint under the existing 13 MB target; do not create panels before use.
- Do not add automated unit, integration, or UI test files to this repository.
- Use short comments for macOS behavior that is not apparent from the code.
