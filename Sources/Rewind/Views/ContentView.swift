import AppKit
import SwiftUI

@MainActor
private enum UIFormatters {
    static let captureTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()
}

private enum Theme {
    static let background = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let surface = Color.white
    static let surfaceBorder = Color(red: 0.83, green: 0.85, blue: 0.88).opacity(0.65)
    static let textPrimary = Color(red: 0.12, green: 0.15, blue: 0.19)
    static let textSecondary = Color(red: 0.46, green: 0.50, blue: 0.56)
    static let accentA = Color(red: 0.10, green: 0.43, blue: 0.99)
    static let accentB = Color(red: 0.42, green: 0.71, blue: 1.00)
}

@MainActor
struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var viewModel = RewindViewModel()

    @State private var selectedScreenshotID: UUID?
    @State private var hoveredScreenshotID: UUID?
    @State private var wheelAccumulator: CGFloat = 0
    @State private var markerMidpoints: [UUID: CGFloat] = [:]

    private var screenshots: [ScreenshotEntry] {
        viewModel.screenshots
    }

    private var selectedEntry: ScreenshotEntry? {
        guard let selectedScreenshotID else {
            return screenshots.first
        }
        return screenshots.first(where: { $0.id == selectedScreenshotID }) ?? screenshots.first
    }

    private var hoveredEntry: ScreenshotEntry? {
        guard let hoveredScreenshotID else {
            return nil
        }
        return screenshots.first(where: { $0.id == hoveredScreenshotID })
    }

    private var selectedIndex: Int? {
        guard !screenshots.isEmpty else {
            return nil
        }

        guard let selectedScreenshotID else {
            return 0
        }

        return screenshots.firstIndex(where: { $0.id == selectedScreenshotID }) ?? 0
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                headerPanel
                viewerPanel
            }
            .padding(24)
            .frame(maxWidth: 1_280)
        }
        .frame(minWidth: 1_050, minHeight: 700)
        .onAppear {
            syncSelection()
        }
        .onChange(of: viewModel.screenshots) { _ in
            syncSelection()
        }
    }

    private var headerPanel: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Rewind")
                    .font(.system(size: 46, weight: .semibold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)

                Text("Focused-window captures in day folders, with frame-style playback.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: 520, alignment: .leading)

                HStack(spacing: 10) {
                    LiveStatusIndicator(isLive: viewModel.isCaptureEnabled)
                    Text(viewModel.statusMessage)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 10) {
                HStack(spacing: 10) {
                    CaptureProgressRing(
                        progress: viewModel.nextCaptureProgress,
                        isActive: viewModel.isCaptureEnabled,
                        reduceMotion: reduceMotion
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEXT CAPTURE")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .tracking(0.9)
                            .foregroundStyle(Theme.textSecondary)

                        Text("Every \(Int(viewModel.captureIntervalSeconds))s")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                    }
                }

                HStack(spacing: 8) {
                    Toggle(
                        "Capture",
                        isOn: Binding(
                            get: { viewModel.isCaptureEnabled },
                            set: { viewModel.setCaptureEnabled($0) }
                        )
                    )
                    .toggleStyle(CaptureToggleButtonStyle(reduceMotion: reduceMotion))
                    .pointingHandCursor()

                    Button("Open Folder") {
                        viewModel.openStorageFolder()
                    }
                    .buttonStyle(SecondaryActionButtonStyle(reduceMotion: reduceMotion))
                    .pointingHandCursor()

                    if !viewModel.hasScreenRecordingPermission {
                        Button("Grant Permission") {
                            viewModel.requestScreenRecordingPermission()
                        }
                        .buttonStyle(SecondaryActionButtonStyle(reduceMotion: reduceMotion))
                        .pointingHandCursor()
                    }
                }
            }
        }
        .padding(22)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.surfaceBorder, lineWidth: 1)
        )
        .shadow(color: Theme.accentA.opacity(0.05), radius: 30, x: 0, y: 18)
    }

    private var viewerPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()

                if let selectedEntry {
                    Text("\(selectedEntry.appName) • \(UIFormatters.captureTime.string(from: selectedEntry.capturedAt)) • \(UIFormatters.byteCount.string(fromByteCount: Int64(selectedEntry.byteSize)))")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            frameArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            scrubber
        }
        .padding(20)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Theme.surfaceBorder, lineWidth: 1)
        )
        .shadow(color: Theme.accentA.opacity(0.04), radius: 24, x: 0, y: 14)
    }

    private var frameArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.92))

            GeometryReader { geometry in
                if let entry = selectedEntry, let image = NSImage(contentsOf: entry.fileURL) {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    placeholder(message: "No screenshots yet")
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.black.opacity(0.16), lineWidth: 1)
        )
        .overlay {
            ScrollWheelCaptureView { delta in
                handleScrollWheel(delta: delta)
            }
            .background(Color.clear)
        }
    }

    private var scrubber: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(Array(screenshots.reversed())) { entry in
                            marker(entry: entry)
                        }
                    }
                    .frame(minWidth: max(proxy.size.width - 8, 0), alignment: .center)
                    .padding(.top, 4)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
                }
                .zIndex(1)
            }
            .coordinateSpace(name: "scrubber-track")
            .overlay(alignment: .bottomLeading) {
                if let entry = hoveredEntry, let midX = markerMidpoints[entry.id] {
                    MarkerTooltip(entry: entry)
                        .frame(width: 200, height: 122)
                        .offset(
                            x: clampedTooltipX(centerX: midX, containerWidth: proxy.size.width, tooltipWidth: 200),
                            y: -52
                        )
                        .transition(.opacity)
                        .allowsHitTesting(false)
                        .zIndex(5)
                }
            }
            .onPreferenceChange(MarkerMidpointPreferenceKey.self) { value in
                markerMidpoints = value
            }
        }
        .frame(height: 52)
    }

    private func marker(entry: ScreenshotEntry) -> some View {
        let isSelected = entry.id == selectedEntry?.id
        let isHovered = entry.id == hoveredScreenshotID

        return Button {
            selectedScreenshotID = entry.id
            wheelAccumulator = 0
        } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(entry.appColor.opacity(isSelected ? 0.96 : 0.36))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(Color.black.opacity(isSelected ? 0.62 : 0.2), lineWidth: isSelected ? 1.2 : 0.9)
                )
                .frame(width: isSelected ? 8 : 6, height: isSelected ? 48 : 40)
                .shadow(
                    color: isHovered ? entry.appColor.opacity(0.28) : .clear,
                    radius: isHovered ? 8 : 0,
                    x: 0,
                    y: 2
                )
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: MarkerMidpointPreferenceKey.self,
                            value: [entry.id: geometry.frame(in: .named("scrubber-track")).midX]
                        )
                    }
                )
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .onHover { inside in
            if inside {
                hoveredScreenshotID = entry.id
            } else if hoveredScreenshotID == entry.id {
                hoveredScreenshotID = nil
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isHovered)
    }

    private func clampedTooltipX(centerX: CGFloat, containerWidth: CGFloat, tooltipWidth: CGFloat) -> CGFloat {
        let proposed = centerX - (tooltipWidth / 2)
        let minX: CGFloat = 0
        let maxX = max(containerWidth - tooltipWidth, 0)
        return min(max(proposed, minX), maxX)
    }

    private func placeholder(message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "photo")
                .font(.system(size: 30))
                .foregroundStyle(Theme.textSecondary.opacity(0.6))
            Text(message)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func syncSelection() {
        guard !screenshots.isEmpty else {
            selectedScreenshotID = nil
            hoveredScreenshotID = nil
            markerMidpoints = [:]
            return
        }

        if let selectedScreenshotID, screenshots.contains(where: { $0.id == selectedScreenshotID }) {
            return
        }

        selectedScreenshotID = screenshots.first?.id
    }

    private func handleScrollWheel(delta: CGFloat) {
        guard !screenshots.isEmpty else {
            return
        }

        wheelAccumulator += delta
        let threshold: CGFloat = 46

        if wheelAccumulator <= -threshold {
            stepFrame(by: 1)
            wheelAccumulator = 0
        } else if wheelAccumulator >= threshold {
            stepFrame(by: -1)
            wheelAccumulator = 0
        }
    }

    private func stepFrame(by offset: Int) {
        guard let selectedIndex else {
            return
        }

        let targetIndex = max(0, min(selectedIndex + offset, screenshots.count - 1))
        guard targetIndex != selectedIndex else {
            return
        }

        selectedScreenshotID = screenshots[targetIndex].id
    }
}

private struct AtmosphereBackground: View {
    var body: some View {
        ZStack {
            Theme.background

            RadialGradient(
                colors: [Theme.accentA.opacity(0.15), .clear],
                center: .topLeading,
                startRadius: 80,
                endRadius: 500
            )
            .offset(x: -120, y: -160)

            RadialGradient(
                colors: [Theme.accentB.opacity(0.15), .clear],
                center: .bottomTrailing,
                startRadius: 100,
                endRadius: 560
            )
            .offset(x: 160, y: 140)

            DotPattern()
                .opacity(0.34)
        }
    }
}

private struct DotPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 26
            let radius: CGFloat = 0.85
            let columns = Int(size.width / spacing) + 2
            let rows = Int(size.height / spacing) + 2

            for col in 0..<columns {
                for row in 0..<rows {
                    let x = CGFloat(col) * spacing
                    let y = CGFloat(row) * spacing
                    let rect = CGRect(x: x, y: y, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.black.opacity(0.05)))
                }
            }
        }
    }
}

private struct CaptureProgressRing: View {
    let progress: Double
    let isActive: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.12), lineWidth: 5)

            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0.001))
                .stroke(
                    AngularGradient(
                        colors: [Theme.accentA, Theme.accentB],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(isActive ? Theme.accentA.opacity(0.17) : Color.black.opacity(0.08))
                .frame(width: 14, height: 14)
        }
        .frame(width: 38, height: 38)
        .opacity(isActive ? 1 : 0.56)
        .animation(reduceMotion ? nil : .linear(duration: 0.12), value: progress)
    }
}

private struct MarkerTooltip: View {
    let entry: ScreenshotEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = NSImage(contentsOf: entry.fileURL) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 200, height: 122)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.08))
            }

            LinearGradient(
                colors: [Color.black.opacity(0.62), .clear],
                startPoint: .bottom,
                endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(UIFormatters.captureTime.string(from: entry.capturedAt))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.92))
                .padding(8)
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.black.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 7)
    }
}

private struct LiveStatusIndicator: View {
    let isLive: Bool
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(isLive ? Theme.accentA : Theme.textSecondary.opacity(0.5))
            .frame(width: 8, height: 8)
            .scaleEffect(isLive && pulse ? 1.45 : 1.0)
            .opacity(isLive && pulse ? 0.55 : 0.95)
            .onAppear {
                pulse = true
            }
            .animation(
                isLive ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : nil,
                value: pulse
            )
    }
}

private struct CaptureToggleButtonStyle: ToggleStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        let fillStyle = configuration.isOn
            ? AnyShapeStyle(
                LinearGradient(
                    colors: [Theme.accentA, Theme.accentB],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            : AnyShapeStyle(Color.white)

        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                Text("Capture")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(configuration.isOn ? Color.white : Theme.textPrimary)

                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    RoundedRectangle(cornerRadius: 999, style: .continuous)
                        .fill(configuration.isOn ? Color.white.opacity(0.24) : Color.black.opacity(0.08))
                        .frame(width: 34, height: 18)

                    Circle()
                        .fill(configuration.isOn ? Color.white : Theme.textPrimary.opacity(0.76))
                        .frame(width: 14, height: 14)
                        .padding(.horizontal, 2)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(fillStyle)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(configuration.isOn ? Color.white.opacity(0.35) : Theme.surfaceBorder, lineWidth: 1)
            )
            .shadow(
                color: configuration.isOn ? Theme.accentA.opacity(0.26) : Color.black.opacity(0.05),
                radius: configuration.isOn ? 12 : 7,
                x: 0,
                y: configuration.isOn ? 6 : 3
            )
            .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: configuration.isOn)
        .accessibilityLabel("Capture")
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

private struct AccentActionButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                LinearGradient(
                    colors: [Theme.accentA, Theme.accentB],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 0.8)
            )
            .shadow(color: Theme.accentA.opacity(configuration.isPressed ? 0.12 : 0.26), radius: configuration.isPressed ? 6 : 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

private struct SecondaryActionButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Theme.surfaceBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.02 : 0.05), radius: configuration.isPressed ? 2 : 7, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

private struct MarkerMidpointPreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]

    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

private struct PointerCursorModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside && !isHovering {
                    NSCursor.pointingHand.push()
                    isHovering = true
                } else if !inside && isHovering {
                    NSCursor.pop()
                    isHovering = false
                }
            }
            .onDisappear {
                if isHovering {
                    NSCursor.pop()
                    isHovering = false
                }
            }
    }
}

private extension View {
    func pointingHandCursor() -> some View {
        modifier(PointerCursorModifier())
    }
}
