import AppKit
import SwiftUI

struct ScrollWheelCaptureView: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

final class ScrollWheelNSView: NSView {
    var onScroll: (CGFloat) -> Void = { _ in }

    override func scrollWheel(with event: NSEvent) {
        let rawDelta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY * 12
        let tunedDelta = rawDelta * (event.hasPreciseScrollingDeltas ? 0.72 : 1.0)

        guard abs(tunedDelta) > 0.001 else {
            return
        }

        onScroll(tunedDelta)
    }
}
