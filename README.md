# Mission Control Shortcuts

Keyboard window selection, closing, and force quit in the native macOS Mission Control view.

Press Control–Up Arrow as usual, then select a window without reaching for the mouse.

| Key | Action |
| --- | --- |
| Tab / Shift+Tab | Select the next / previous window on the current monitor |
| Option+Tab / Option+Shift+Tab | Select the next / previous monitor |
| Type an app name | Filter windows on the current monitor by their application's name |
| Up / Down while searching | Select the previous / next match |
| Return / Enter | Activate the selected window |
| Command+W | Close the selected window |
| Command+Q | Force quit the selected window's application |
| Backspace | Delete the last search character |
| Escape | Clear the search; with no query, leave Mission Control |

Search uses case-insensitive prefix and substring matching of app names.
Window titles and browser tab titles are not searched. Search text stays visible until cleared or a window is activated.
Selection moves the pointer to a thumbnail and uses Mission Control's native highlight; activation synthesizes a click.

Command+W and Command+Q act only on a window selected with Tab or search in Mission Control.
With no selection, they do nothing. After either command, use Tab or search to select a window again.
Command+Q force quits the entire application, including windows on other monitors or Spaces, without a save prompt.
Command+W uses the window's Accessibility close button; for custom title bars it falls back to Cmd+W
only after confirming that the selected window is focused. That fallback may close a tab and leave Mission Control.

The monitor under the pointer when Mission Control opens becomes the current monitor.
Tab wraps within that monitor. Moving the pointer during selection does not change the current monitor.
Monitor shortcuts cycle left to right, then top to bottom, and wrap at the ends. The search query is preserved.
On a monitor with no matching windows, the pointer moves to the monitor's center and Return activates nothing.
The search pill follows the current monitor. If that monitor is disconnected, navigation falls back to the pointer's monitor.

Option+Tab is handled only inside Mission Control and only when more than one monitor is connected.
No global hotkey is registered; Command+Tab, Control+Tab, and unrelated Option shortcuts pass through.
Apps using Option+Tab as a global shortcut, such as AltTab, can still conflict if they intercept the event first.

## Requirements and build

- macOS 27.0 or later
- Xcode 27 or Command Line Tools with the macOS 27 SDK
- Accessibility access, granted when the app first launches

Quit any running MCSC instance, then build and launch this fork:

```sh
git clone https://github.com/jongwonlee-nemo/mission-control-shortcuts.git
cd mission-control-shortcuts
./build.sh
```

The script builds and ad-hoc signs `build/MCSC.app`, then opens that exact app.
You can also build the `MCSC` scheme in `MCSC.xcodeproj` with Xcode.

The menu bar icon provides access to the permission settings when needed and a Quit action.
Navigation starts after Accessibility access is granted.

After rebuilding an ad-hoc signed app, macOS may invalidate its previous Accessibility approval.
If the menu shows “Grant Accessibility Access…” and Tab does nothing, remove the old MCSC entry
from that permission screen and add the rebuilt app from its current location again.

## Scope and privacy

This fork keeps keyboard window selection, window closing, and force quit. Minimization, resizing,
tiling, desktop movement, gestures, hover action buttons, launch at login, and their settings are removed.

There is no application logging, diagnostic export, crash handler, telemetry, or update downloader.
Search input is held in memory and cleared when the session ends. macOS may still create its own system crash reports.

Mission Control is detected through Dock notifications and its WindowServer layers.
Thumbnail geometry comes from Accessibility, and window candidates are limited to the current monitor's active Space.
The input tap is installed only for a Mission Control session, and each key checks that Mission Control is still open.
Apple's private Accessibility and Spaces interfaces may change in future macOS updates.

## Credits

Forked from [ShubhamJ010/mission-control-shortcuts](https://github.com/ShubhamJ010/mission-control-shortcuts).
The keyboard navigation builds on the techniques described in
[OpenMissionControl PR #3](https://github.com/nohackjustnoobb/OpenMissionControl/pull/3).
