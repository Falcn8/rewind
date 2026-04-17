import AppKit
import CoreGraphics
import Foundation

@MainActor
final class RewindViewModel: ObservableObject {
    @Published private(set) var screenshots: [ScreenshotEntry] = []
    @Published private(set) var statusMessage: String = "Capture paused"
    @Published private(set) var nextCaptureProgress: Double = 0
    @Published private(set) var hasScreenRecordingPermission: Bool = CGPreflightScreenCaptureAccess()
    @Published private(set) var captureIntervalSeconds: Double = 30
    @Published var isCaptureEnabled: Bool = false

    private let storage: ScreenshotStorage
    private let captureService: ScreenshotCaptureService
    private let defaults: UserDefaults
    private var nextCaptureAt: Date?
    private var countdownTask: Task<Void, Never>?

    private let enabledDefaultsKey = "rewind.captureEnabled"

    init(storage: ScreenshotStorage = ScreenshotStorage(), defaults: UserDefaults = .standard) {
        self.storage = storage
        self.captureService = ScreenshotCaptureService(storage: storage)
        self.defaults = defaults

        screenshots = storage.loadAllScreenshots()

        captureService.onCapture = { [weak self] entry in
            guard let self else {
                return
            }
            self.screenshots.insert(entry, at: 0)
        }

        captureService.onStatus = { [weak self] message in
            self?.statusMessage = message
        }

        captureService.onNextCaptureAt = { [weak self] date in
            self?.nextCaptureAt = date
        }

        captureService.updateInterval(seconds: captureIntervalSeconds)

        countdownTask = Task { [weak self] in
            await self?.runCountdownLoop()
        }

        let shouldResumeCapture = defaults.bool(forKey: enabledDefaultsKey)
        if shouldResumeCapture {
            setCaptureEnabled(true)
        }
    }

    deinit {
        countdownTask?.cancel()
    }

    func setCaptureEnabled(_ enabled: Bool) {
        if enabled {
            guard ensureScreenRecordingPermission(interactive: true) else {
                isCaptureEnabled = false
                defaults.set(false, forKey: enabledDefaultsKey)
                statusMessage = "Screen Recording permission is required"
                nextCaptureAt = nil
                nextCaptureProgress = 0
                return
            }

            captureService.updateInterval(seconds: captureIntervalSeconds)
            captureService.start()
            statusMessage = "Capture enabled • every \(Int(captureIntervalSeconds))s"
        } else {
            captureService.stop()
            statusMessage = "Capture paused"
            nextCaptureAt = nil
            nextCaptureProgress = 0
        }

        isCaptureEnabled = enabled
        defaults.set(enabled, forKey: enabledDefaultsKey)
    }

    func requestScreenRecordingPermission() {
        _ = ensureScreenRecordingPermission(interactive: true)
    }

    func refreshScreenshots() {
        screenshots = storage.loadAllScreenshots()
    }

    func openStorageFolder() {
        NSWorkspace.shared.open(storage.rootDirectory)
    }

    private func ensureScreenRecordingPermission(interactive: Bool) -> Bool {
        let preflight = CGPreflightScreenCaptureAccess()
        hasScreenRecordingPermission = preflight

        guard !preflight, interactive else {
            return preflight
        }

        let requested = CGRequestScreenCaptureAccess()
        hasScreenRecordingPermission = requested
        return requested
    }

    private func runCountdownLoop() async {
        while !Task.isCancelled {
            if isCaptureEnabled {
                if let nextCaptureAt {
                    let remaining = max(nextCaptureAt.timeIntervalSinceNow, 0)
                    let interval = max(captureIntervalSeconds, 1)
                    let progress = 1 - (remaining / interval)
                    nextCaptureProgress = min(max(progress, 0), 1)
                } else {
                    nextCaptureProgress = 0
                }
            } else {
                nextCaptureProgress = 0
            }

            try? await Task.sleep(for: .milliseconds(120))
        }
    }
}
