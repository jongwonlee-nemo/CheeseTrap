#!/bin/zsh
set -euo pipefail

cd -- "${0:A:h}"

was_running=0
if pgrep -x 'CheeseTrap|MCSC' >/dev/null; then
    # Quit before replacing the signed binary; the app keeps no state that needs a graceful exit.
    was_running=1
    pkill -x 'CheeseTrap|MCSC' || true
    for _ in {1..50}; do
        pgrep -x 'CheeseTrap|MCSC' >/dev/null || break
        sleep 0.1
    done
    if pgrep -x 'CheeseTrap|MCSC' >/dev/null; then
        print -u2 'CheeseTrap did not quit. Quit it manually, then run ./build.sh again.'
        exit 1
    fi
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

# Ad-hoc signatures change every build and reset Accessibility; a stable local identity keeps the grant.
sign_name='CheeseTrap Local'
signing_identity() {
    security find-identity -p codesigning | awk -v n="\"$sign_name\"" 'index($0, n) && !found++ { print $2 }'
}
sign_id=$(signing_identity)
if [[ -z $sign_id ]]; then
    # First build on this Mac: create a self-signed identity in the login keychain; only the temp copy is deleted.
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    pass=$(openssl rand -hex 16)
    openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -subj "/CN=$sign_name" \
        -addext 'basicConstraints=critical,CA:false' -addext 'keyUsage=critical,digitalSignature' \
        -addext 'extendedKeyUsage=critical,codeSigning' -keyout "$tmp/key.pem" -out "$tmp/cert.pem"
    openssl pkcs12 -export -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -out "$tmp/id.p12" -passout "pass:$pass"
    security import "$tmp/id.p12" -P "$pass" -T /usr/bin/codesign >/dev/null
    sign_id=$(signing_identity)
fi
codesign --force --sign "$sign_id" --options runtime --entitlements MCSC.entitlements "$app_path"
codesign --verify --deep --strict "$app_path"
print "Built: $app_path"
if (( was_running )); then open "$app_path"; fi
