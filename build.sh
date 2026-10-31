#!/bin/bash
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

APP="Etherlynx Battery.app"
echo "Building $APP ..."

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# swift-version 5 — без суворої Swift 6 concurrency
swiftc Sources/*.swift \
    -o "$APP/Contents/MacOS/EtherlynxBattery" \
    -framework Cocoa -framework IOKit -framework SwiftUI -framework ServiceManagement -framework CoreBluetooth \
    -swift-version 5 \
    -target arm64-apple-macos14.0 \
    -O

# Root-хелпер ліміту заряду: ставиться в систему лише з налаштувань апки, з паролем адміністратора
mkdir -p "$APP/Contents/Library/LaunchServices"
swiftc Helper/main.swift Sources/SMC.swift Sources/Battery.swift Sources/ChargeConfig.swift \
    -o "$APP/Contents/Library/LaunchServices/xyz.etherlynx.battery.helper" \
    -framework IOKit -swift-version 5 -target arm64-apple-macos14.0 -O

cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/Fonts Resources/Marks Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP" 2>/dev/null || true

echo "✅ Done: $DIR/$APP"
