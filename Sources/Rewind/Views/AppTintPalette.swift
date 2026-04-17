import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

@MainActor
enum AppTintPalette {
    private static var colorCache: [String: Color] = [:]
    private static let ciContext = CIContext(
        options: [
            .workingColorSpace: NSNull(),
            .outputColorSpace: NSNull()
        ]
    )

    static func color(for key: String, bundleIdentifier: String?, appName _: String) -> Color {
        if let cached = colorCache[key] {
            return cached
        }

        let resolved = iconDerivedColor(bundleIdentifier: bundleIdentifier) ?? hashFallbackColor(for: key)
        colorCache[key] = resolved
        return resolved
    }

    private static func iconDerivedColor(bundleIdentifier: String?) -> Color? {
        guard let iconImage = appIconImage(bundleIdentifier: bundleIdentifier) else {
            return nil
        }

        let average = averageRGBA(from: iconImage)
        guard let average else {
            return nil
        }

        let red = CGFloat(average.r) / 255
        let green = CGFloat(average.g) / 255
        let blue = CGFloat(average.b) / 255
        let alpha = CGFloat(average.a) / 255

        guard alpha > 0.05 else {
            return nil
        }

        guard let nsColor = NSColor(srgbRed: red, green: green, blue: blue, alpha: 1).usingColorSpace(.deviceRGB) else {
            return nil
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var convertedAlpha: CGFloat = 0
        nsColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &convertedAlpha)

        guard saturation > 0.10 else {
            return nil
        }

        let adjustedSaturation = min(max(saturation * 1.18, 0.30), 0.86)
        let adjustedBrightness = min(max(brightness * 0.92, 0.28), 0.76)

        return Color(
            hue: Double(hue),
            saturation: Double(adjustedSaturation),
            brightness: Double(adjustedBrightness)
        )
    }

    private static func appIconImage(bundleIdentifier: String?) -> NSImage? {
        if
            let bundleIdentifier,
            let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 64, height: 64)
            return icon
        }

        return nil
    }

    private static func averageRGBA(from image: NSImage) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8)? {
        guard let cgImage = cgImage(from: image) else {
            return nil
        }

        let inputImage = CIImage(cgImage: cgImage)
        let extent = inputImage.extent

        guard !extent.isEmpty else {
            return nil
        }

        let filter = CIFilter.areaAverage()
        filter.inputImage = inputImage
        filter.extent = extent

        guard let outputImage = filter.outputImage else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return (bitmap[0], bitmap[1], bitmap[2], bitmap[3])
    }

    private static func cgImage(from image: NSImage) -> CGImage? {
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cgImage
        }

        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }

        return bitmap.cgImage
    }

    private static func hashFallbackColor(for key: String) -> Color {
        let hash = key.unicodeScalars.reduce(5_381) { partialResult, scalar in
            ((partialResult << 5) &+ partialResult) &+ Int(scalar.value)
        }

        let hue = Double(abs(hash % 360)) / 360.0
        let saturation = 0.42 + Double(abs((hash / 7) % 24)) / 100.0
        let brightness = 0.35 + Double(abs((hash / 11) % 26)) / 100.0

        return Color(
            hue: hue,
            saturation: min(saturation, 0.78),
            brightness: min(brightness, 0.70)
        )
    }
}
