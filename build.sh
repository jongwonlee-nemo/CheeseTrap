#!/bin/zsh
set -euo pipefail

cd -- "${0:A:h}"

if pgrep -x MCSC >/dev/null; then
    print -u2 'Quit MCSC before rebuilding, then run ./build.sh again.'
    exit 1
elif (( $? != 1 )); then
    print -u2 'Could not check whether MCSC is running. Build stopped.'
    exit 1
fi

app_path="$PWD/build/MCSC.app"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"

xcrun swiftc -O -swift-version 5 -default-isolation MainActor \
    -enable-upcoming-feature MemberImportVisibility -warnings-as-errors \
    -module-name MCSC -target "$(uname -m)-apple-macosx27.0" \
    -module-cache-path "${TMPDIR:-/tmp}/mcsc-swift-module-cache" \
    MCSC/**/*.swift -o "$app_path/Contents/MacOS/MCSC"

cp Info.plist "$app_path/Contents/Info.plist"
plutil -replace CFBundleName -string MCSC "$app_path/Contents/Info.plist"
plutil -insert CFBundleExecutable -string MCSC "$app_path/Contents/Info.plist"
cp MCSC/AppIcon.icns "$app_path/Contents/Resources/AppIcon.icns"

codesign --force --sign - --options runtime --entitlements MCSC.entitlements "$app_path"
codesign --verify --deep --strict "$app_path"
print "Built: $app_path"
open "$app_path"
