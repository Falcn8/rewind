# Rewind

Rewind is a macOS SwiftUI app that captures the frontmost window on an interval and stores JPEG snapshots in day-based folders under:

`~/Library/Application Support/Rewind/Screenshots`

## Local Development

```bash
swift run Rewind
```

## Test and Build

```bash
swift test
swift build -c release
```

## Package a Shippable `.app`

The repository includes `scripts/package-macos.sh`, which:
1. Builds the release binary.
2. Assembles `dist/Rewind.app`.
3. Optionally signs and notarizes it.
4. Produces a `.zip` archive for distribution.

Unsigned package:

```bash
chmod +x scripts/package-macos.sh
scripts/package-macos.sh \
  --clean \
  --version 1.0.0 \
  --build-number 1 \
  --bundle-id io.yourcompany.rewind
```

Signed package:

```bash
scripts/package-macos.sh \
  --clean \
  --version 1.0.0 \
  --build-number 1 \
  --bundle-id io.yourcompany.rewind \
  --sign-identity "Developer ID Application: Your Name (TEAMID)"
```

Signed + notarized package:

```bash
# one-time setup for notarytool profile
xcrun notarytool store-credentials "AC_NOTARY" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

scripts/package-macos.sh \
  --clean \
  --version 1.0.0 \
  --build-number 1 \
  --bundle-id io.yourcompany.rewind \
  --sign-identity "Developer ID Application: Your Name (TEAMID)" \
  --notarize \
  --notary-profile "AC_NOTARY"
```

## GitHub Actions

- `.github/workflows/ci.yml` runs tests and release builds on PRs/pushes.
- `.github/workflows/release.yml` generates a packaged zip when a `v*` tag is pushed or manually triggered.

## First Launch Requirement

On first launch, macOS will prompt for Screen Recording permission. Rewind cannot capture windows until this permission is granted.
