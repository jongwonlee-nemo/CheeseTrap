# Mission Control Shortcuts

Keyboard window selection in the native macOS Mission Control view.

Press Control–Up Arrow as usual, then select a window without reaching for the mouse.

| Key | Action |
| --- | --- |
| Tab / Shift+Tab | Select the next / previous visible window |
| Type an app name | Filter windows by their application's name |
| Up / Down while searching | Select the previous / next match |
| Return / Enter | Activate the selected window |
| Backspace | Delete the last search character |
| Escape | Clear the search; with no query, leave Mission Control |

Search uses case-insensitive prefix and substring matching of app names.
Window titles and browser tab titles are not searched. Search text stays visible until cleared or a window is activated.
Selection moves the pointer to a thumbnail and uses Mission Control's native highlight; activation synthesizes a click.

## Requirements and build

- macOS 27.0 or later
- Xcode 27 or later with the macOS 27 SDK
- Accessibility access, granted when the app first launches

Clone this fork and build the `MCSC` scheme in `MCSC.xcodeproj`:

```sh
git clone https://github.com/jongwonlee-nemo/mission-control-shortcuts.git
cd mission-control-shortcuts
open MCSC.xcodeproj
```

The menu bar icon provides access to the permission settings when needed and a Quit action.
Navigation starts after Accessibility access is granted.

## Scope and privacy

This fork keeps keyboard window selection only. Window closing, force quit, minimization, resizing,
tiling, desktop movement, gestures, hover action buttons, launch at login, and their settings are removed.

There is no application logging, diagnostic export, crash handler, telemetry, or update downloader.
Search input is held in memory and cleared when the session ends. macOS may still create its own system crash reports.

Mission Control is detected through Dock notifications and its WindowServer layers.
Thumbnail geometry comes from Accessibility, and window candidates are limited to active display Spaces.
The input tap is installed only for a Mission Control session, and each key checks that Mission Control is still open.
Apple's private Accessibility and Spaces interfaces may change in future macOS updates.

## Credits

Forked from [ShubhamJ010/mission-control-shortcuts](https://github.com/ShubhamJ010/mission-control-shortcuts).
The keyboard navigation builds on the techniques described in
[OpenMissionControl PR #3](https://github.com/nohackjustnoobb/OpenMissionControl/pull/3).
