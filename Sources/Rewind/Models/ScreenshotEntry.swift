import Foundation
import SwiftUI

struct ScreenshotEntry: Identifiable, Hashable {
    let id: UUID
    let fileURL: URL
    let capturedAt: Date
    let appName: String
    let bundleIdentifier: String?
    let byteSize: Int

    var appKey: String {
        bundleIdentifier ?? appName
    }

    @MainActor
    var appColor: Color {
        AppTintPalette.color(
            for: appKey,
            bundleIdentifier: bundleIdentifier,
            appName: appName
        )
    }
}
