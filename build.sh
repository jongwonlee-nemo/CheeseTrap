#!/bin/zsh
set -euo pipefail

cd -- "${0:A:h}"

if pgrep -x 'CheeseTrap|MCSC' >/dev/null; then
    print -u2 'Quit CheeseTrap or any older MCSC instance, then run ./build.sh again.'
    exit 1
elif (( $? != 1 )); then
    print -u2 'Could not check whether CheeseTrap is running. Build stopped.'
    exit 1
fi

app_path="$PWD/build/CheeseTrap.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"

xcrun swiftc -O -swift-version 5 -default-isolation MainActor \
    -enable-upcoming-feature MemberImportVisibility -warnings-as-errors \
    -module-name CheeseTrap -target "$(uname -m)-apple-macosx27.0" \
    -module-cache-path "${TMPDIR:-/tmp}/cheesetrap-swift-module-cache" \
    MCSC/**/*.swift -o "$app_path/Contents/MacOS/CheeseTrap"

cp Info.plist "$app_path/Contents/Info.plist"
plutil -insert CFBundleExecutable -string CheeseTrap "$app_path/Contents/Info.plist"
cp MCSC/AppIcon.icns "$app_path/Contents/Resources/AppIcon.icns"
cp MCSC/MenuBarIcon.pdf "$app_path/Contents/Resources/MenuBarIcon.pdf"
cp THIRD_PARTY_NOTICES.md "$app_path/Contents/Resources/"

codesign --force --sign - --options runtime --entitlements MCSC.entitlements "$app_path"
codesign --verify --deep --strict "$app_path"
print "Built: $app_path"
