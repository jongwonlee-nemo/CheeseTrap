<p align="center">
  <img src="cheese.png" alt="CheeseTrap icon" width="128">
</p>

# CheeseTrap

Use the keyboard to select, activate, close, and force quit windows in macOS Mission Control.
CheeseTrap is a focused fork of Mission Control Shortcuts with navigation across multiple monitors.

## Build

Requires macOS 27.0 or later and Xcode 27 or Command Line Tools with the macOS 27 SDK.

Quit any running CheeseTrap or older MCSC instance, then run:

```sh
git clone https://github.com/jongwonlee-nemo/CheeseTrap.git
cd CheeseTrap
./build.sh
```

`build.sh` compiles the app, applies an ad-hoc signature, verifies it, and opens
`build/CheeseTrap.app`. Run the same script to rebuild after changing the source.
This repository provides source for local builds; it does not publish app downloads or an installer.

Grant **Accessibility** access in **System Settings → Privacy & Security → Accessibility**.
The menu bar offers **Grant Accessibility Access…** when approval is missing and **Quit CheeseTrap**.
After a rebuild, macOS may require you to remove the old permission entry and add the rebuilt app again.

## Usage

Open Mission Control with **Control+Up Arrow**, then use these keys:

| Key | Action |
| --- | --- |
| Tab / Shift+Tab | Select the next / previous window on the current monitor |
| Option+Tab / Option+Shift+Tab | Select the next / previous monitor |
| Type an app name | Filter windows on the current monitor by app name |
| Up / Down while searching | Select the previous / next match |
| Return / Enter | Activate the selected window and leave Mission Control |
| Command+W | Close the selected window |
| Command+Q | Force quit the selected window's application |
| Backspace | Delete the last search character |
| Escape | Clear the search; with no query, leave Mission Control |

## Upstream license and credits

The upstream [Mission Control Shortcuts](https://github.com/ShubhamJ010/mission-control-shortcuts)
README declares MIT licensing. Its attribution and MIT terms are retained in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
The upstream project also credits [OpenMissionControl PR #3](https://github.com/nohackjustnoobb/OpenMissionControl/pull/3).

The cheese icon is from [Twemoji](https://github.com/twitter/twemoji), copyright 2019 Twitter, Inc and other contributors,
licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
It was rendered as PNG and resized into a macOS icon; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
