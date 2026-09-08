#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

APP_NAME="AIQuotaBar"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 正在編譯 ${APP_NAME} (Release 模式)..."
swift build -c release --scratch-path "$ROOT_DIR/.build"

echo "📦 正在建立 macOS App Bundle: ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# 複製編譯產出的二進位執行檔
cp ".build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# 建立 Info.plist (關鍵設定 LSUIElement=true 代表為選單列背景 App，不常駐 Dock)
cat << 'EOF' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_TW</string>
    <key>CFBundleExecutable</key>
    <string>AIQuotaBar</string>
    <key>CFBundleIdentifier</key>
    <string>com.ai.AIQuotaBar</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AIQuotaBar</string>
    <key>CFBundleDisplayName</key>
    <string>AI 額度與重置監控</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# 本地 Ad-hoc 簽署
echo "🔏 正在進行本地簽署..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ 打包完成！產出位於：$(pwd)/${APP_BUNDLE}"
echo "💡 您可以直接在終端機執行 'open ${APP_BUNDLE}' 或雙擊打開常駐於選單列！"
