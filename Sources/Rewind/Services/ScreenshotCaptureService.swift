import AppKit
import CoreGraphics
import Foundation

enum ScreenshotCaptureError: LocalizedError {
    case imageCaptureFailed
    case imageEncodingFailed

    var errorDescription: String? {
        switch self {
        case .imageCaptureFailed:
            return "Could not capture the focused window."
        case .imageEncodingFailed:
            return "Could not compress the screenshot."
        }
    }
}

@MainActor
final class ScreenshotCaptureService {
    private struct FocusedWindowContext {
        let id: CGWindowID
        let title: String?
    }

    struct Configuration {
        var intervalSeconds: Double = 30
        var maxImageDimension: CGFloat = 1_400
        var preferredImageSizeBytes: Int = 200_000
        var maximumImageSizeBytes: Int = 260_000
    }

    var onCapture: ((ScreenshotEntry) -> Void)?
    var onStatus: ((String) -> Void)?
    var onNextCaptureAt: ((Date?) -> Void)?

    private let storage: ScreenshotStorage
    private let configuration: Configuration
    private var intervalSeconds: Double
    private var loopTask: Task<Void, Never>?

    init(storage: ScreenshotStorage, configuration: Configuration = Configuration()) {
        self.storage = storage
        self.configuration = configuration
        self.intervalSeconds = configuration.intervalSeconds
    }

    var isRunning: Bool {
        loopTask != nil
    }

    func start() {
        guard loopTask == nil else {
            return
        }

        loopTask = Task { [weak self] in
            await self?.runCaptureLoop()
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        onNextCaptureAt?(nil)
    }

    func updateInterval(seconds: Double) {
        intervalSeconds = max(5, min(seconds, 3_600))
    }

    private func runCaptureLoop() async {
        while !Task.isCancelled {
            let nextInterval = intervalSeconds
            let nextCaptureAt = Date().addingTimeInterval(nextInterval)
            onNextCaptureAt?(nextCaptureAt)
            onStatus?("Next capture in \(Int(nextInterval))s")

            let duration = Duration.seconds(nextInterval)
            try? await Task.sleep(for: duration)

            guard !Task.isCancelled else {
                onNextCaptureAt?(nil)
                return
            }

            do {
                if let screenshot = try captureFocusedWindow() {
                    onCapture?(screenshot)
                    onStatus?("Saved \(screenshot.appName) • \(formattedBytes(screenshot.byteSize))")
                } else {
                    onStatus?("No active window detected, skipping this cycle")
                }
            } catch {
                onStatus?("Capture failed: \(error.localizedDescription)")
            }
        }
    }

    private func captureFocusedWindow() throws -> ScreenshotEntry? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        if app.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return nil
        }

        if
            let appBundleID = app.bundleIdentifier,
            let mainBundleID = Bundle.main.bundleIdentifier,
            appBundleID == mainBundleID
        {
            return nil
        }

        let pid = app.processIdentifier
        guard let focusedWindow = focusedWindowContext(for: pid) else {
            return nil
        }

        let imageOptions: CGWindowImageOption = [.boundsIgnoreFraming, .nominalResolution]
        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            focusedWindow.id,
            imageOptions
        ) else {
            throw ScreenshotCaptureError.imageCaptureFailed
        }

        let downscaled = downscaledImage(from: image)
        let jpegData = try compressedJPEGData(from: downscaled)
        let appName = app.localizedName ?? "Unknown App"

        return try storage.saveScreenshot(
            data: jpegData,
            capturedAt: Date(),
            appName: appName,
            bundleIdentifier: app.bundleIdentifier,
            projectName: inferProjectName(from: focusedWindow.title, appName: appName),
            windowTitle: focusedWindow.title
        )
    }

    private func focusedWindowContext(for pid: pid_t) -> FocusedWindowContext? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windows {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid else {
                continue
            }

            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            guard layer == 0 else {
                continue
            }

            let alpha = window[kCGWindowAlpha as String] as? Double ?? 1
            guard alpha > 0.01 else {
                continue
            }

            guard
                let boundsDictionary = window[kCGWindowBounds as String] as? [String: Any],
                let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary),
                bounds.width > 120,
                bounds.height > 120
            else {
                continue
            }

            guard let windowID = window[kCGWindowNumber as String] as? UInt32 else {
                continue
            }

            let windowTitle = (window[kCGWindowName as String] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return FocusedWindowContext(
                id: windowID,
                title: windowTitle?.isEmpty == true ? nil : windowTitle
            )
        }

        return nil
    }

    private func inferProjectName(from windowTitle: String?, appName: String) -> String? {
        guard
            let windowTitle,
            !windowTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        let separators = [" — ", " – ", " - ", " · ", " • ", " | ", ":"]
        var tokens = [windowTitle]
        for separator in separators {
            tokens = tokens.flatMap { $0.components(separatedBy: separator) }
        }

        let normalizedAppName = normalizeWindowToken(appName)
        let genericTokens = Set([
            "new tab",
            "new window",
            "untitled",
            "untitled window",
            "start page",
            "home"
        ])

        var bestToken: String?
        var bestScore = Int.min

        for rawToken in tokens {
            let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
            guard token.count >= 2 else {
                continue
            }

            let normalizedToken = normalizeWindowToken(token)
            guard
                !normalizedToken.isEmpty,
                normalizedToken != normalizedAppName,
                !genericTokens.contains(normalizedToken)
            else {
                continue
            }

            var score = 0
            if token.count <= 40 {
                score += 2
            } else {
                score -= 1
            }

            if token.range(of: #"\.[A-Za-z0-9]{1,5}$"#, options: .regularExpression) == nil {
                score += 2
            } else {
                score -= 2
            }

            if token.range(of: #"[A-Za-z0-9]"#, options: .regularExpression) != nil {
                score += 1
            }

            if score > bestScore {
                bestScore = score
                bestToken = token
            }
        }

        guard let bestToken, bestScore >= 1 else {
            return nil
        }

        return bestToken
    }

    private func normalizeWindowToken(_ token: String) -> String {
        token
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func downscaledImage(from image: CGImage) -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let maxSide = max(width, height)
        let scale = min(configuration.maxImageDimension / maxSide, 1)

        guard scale < 0.999 else {
            return image
        }

        let targetWidth = max(Int(width * scale), 1)
        let targetHeight = max(Int(height * scale), 1)
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return image
        }

        context.interpolationQuality = .low
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: CGFloat(targetWidth), height: CGFloat(targetHeight))
        )

        return context.makeImage() ?? image
    }

    private func compressedJPEGData(from image: CGImage) throws -> Data {
        let representation = NSBitmapImageRep(cgImage: image)
        let qualityCandidates = stride(from: 0.95, through: 0.35, by: -0.05)
        var selectedData: Data?
        var selectedDistance = Int.max
        var fallbackSmallest: Data?

        for quality in qualityCandidates {
            let properties: [NSBitmapImageRep.PropertyKey: Any] = [.compressionFactor: quality]
            guard let data = representation.representation(using: .jpeg, properties: properties) else {
                continue
            }

            if fallbackSmallest == nil || data.count < fallbackSmallest?.count ?? .max {
                fallbackSmallest = data
            }

            guard data.count <= configuration.maximumImageSizeBytes else {
                continue
            }

            let distance = abs(data.count - configuration.preferredImageSizeBytes)
            if distance < selectedDistance {
                selectedData = data
                selectedDistance = distance
            }
        }

        guard let data = selectedData ?? fallbackSmallest else {
            throw ScreenshotCaptureError.imageEncodingFailed
        }

        return data
    }

    private func formattedBytes(_ count: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB]
        return formatter.string(fromByteCount: Int64(count))
    }
}
