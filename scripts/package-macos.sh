#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Rewind"
BUNDLE_ID="com.example.rewind"
VERSION="0.1.0"
BUILD_NUMBER="1"
MIN_MACOS="13.0"
DIST_DIR="dist"
SIGN_IDENTITY=""
NOTARIZE=false
NOTARY_PROFILE=""
CLEAN=false

usage() {
  cat <<'EOF'
Build and package Rewind as a macOS app bundle.

Usage:
  scripts/package-macos.sh [options]

Options:
  --bundle-id <id>          CFBundleIdentifier (default: com.example.rewind)
  --version <value>         CFBundleShortVersionString (default: 0.1.0)
  --build-number <value>    CFBundleVersion (default: 1)
  --min-macos <value>       LSMinimumSystemVersion (default: 13.0)
  --dist-dir <path>         Output directory (default: dist)
  --sign-identity <name>    Developer ID Application identity for codesign
  --notarize                Submit resulting zip for notarization
  --notary-profile <name>   notarytool keychain profile name
  --clean                   Remove dist directory before packaging
  -h, --help                Show this help

Examples:
  scripts/package-macos.sh --clean --version 1.0.0 --bundle-id io.example.rewind

  scripts/package-macos.sh \
    --clean \
    --version 1.0.0 \
    --bundle-id io.example.rewind \
    --sign-identity "Developer ID Application: Your Name (TEAMID)"

  scripts/package-macos.sh \
    --clean \
    --version 1.0.0 \
    --bundle-id io.example.rewind \
    --sign-identity "Developer ID Application: Your Name (TEAMID)" \
    --notarize \
    --notary-profile "AC_NOTARY"
EOF
}

while (($#)); do
  case "$1" in
    --bundle-id)
      BUNDLE_ID="${2:?missing value for --bundle-id}"
      shift 2
      ;;
    --version)
      VERSION="${2:?missing value for --version}"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="${2:?missing value for --build-number}"
      shift 2
      ;;
    --min-macos)
      MIN_MACOS="${2:?missing value for --min-macos}"
      shift 2
      ;;
    --dist-dir)
      DIST_DIR="${2:?missing value for --dist-dir}"
      shift 2
      ;;
    --sign-identity)
      SIGN_IDENTITY="${2:?missing value for --sign-identity}"
      shift 2
      ;;
    --notarize)
      NOTARIZE=true
      shift
      ;;
    --notary-profile)
      NOTARY_PROFILE="${2:?missing value for --notary-profile}"
      shift 2
      ;;
    --clean)
      CLEAN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "$NOTARIZE" == true ]]; then
  if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "--notarize requires --sign-identity" >&2
    exit 1
  fi

  if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "--notarize requires --notary-profile" >&2
    exit 1
  fi
fi

if [[ "$CLEAN" == true ]]; then
  rm -rf "$DIST_DIR"
fi

mkdir -p "$DIST_DIR"

echo "Building release binary..."
swift build -c release

BIN_DIR="$(swift build -c release --show-bin-path)"
BIN_PATH="${BIN_DIR}/${APP_NAME}"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Missing binary at ${BIN_PATH}" >&2
  exit 1
fi

APP_ROOT="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_ROOT}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

rm -rf "$APP_ROOT"
mkdir -p "$MACOS_DIR"
cp "$BIN_PATH" "${MACOS_DIR}/${APP_NAME}"
chmod 755 "${MACOS_DIR}/${APP_NAME}"

cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_MACOS}</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

printf 'APPL????' > "${CONTENTS_DIR}/PkgInfo"

if [[ -n "$SIGN_IDENTITY" ]]; then
  echo "Signing app with '${SIGN_IDENTITY}'..."
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "${MACOS_DIR}/${APP_NAME}"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "${APP_ROOT}"
  codesign --verify --deep --strict "${APP_ROOT}"
fi

ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.zip"
echo "Creating archive ${ZIP_PATH}..."
ditto -c -k --sequesterRsrc --keepParent "${APP_ROOT}" "${ZIP_PATH}"

if [[ "$NOTARIZE" == true ]]; then
  echo "Submitting ${ZIP_PATH} for notarization..."
  xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARY_PROFILE}" --wait
  xcrun stapler staple "${APP_ROOT}"
  xcrun stapler validate "${APP_ROOT}"

  ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}-notarized.zip"
  echo "Creating notarized archive ${ZIP_PATH}..."
  ditto -c -k --sequesterRsrc --keepParent "${APP_ROOT}" "${ZIP_PATH}"
fi

echo "App bundle: ${APP_ROOT}"
echo "Archive: ${ZIP_PATH}"
