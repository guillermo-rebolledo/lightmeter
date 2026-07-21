import SwiftUI
import UIKit

/// A Halide-style curved dial hugging the bottom edge: the scale's stops fan
/// along an arc and sweep horizontally past a fixed indicator as you drag. Each
/// stop that crosses the indicator fires a selection haptic — the detent tick
/// that makes the dial feel mechanical. Snapping is stop-to-stop; the arc always
/// settles on a real, dial-able mark.
///
/// The dial is a pure controller: `selectedIndex` and `labels` are the source of
/// truth (owned by `MeterViewModel`), and `onSelect` reports each new detent up.
/// A drag is expressed in continuous stop-units and rounded to the nearest stop,
/// so the same gesture drives both the visual sweep and the reported value.
struct ArcDialView: View {
    /// The vertical space the dial requires, including its marks and gesture area.
    static let layoutHeight: CGFloat = 150

    /// The detent labels laid out along the arc.
    let labels: [String]
    /// The stop the fixed indicator currently points at, or `nil` while unbound.
    let selectedIndex: Int?
    /// The leg being dialed, e.g. `"Aperture"` — announced to VoiceOver when bound.
    let caption: String?
    /// Reports a newly selected stop index (already clamped to `stops`).
    let onSelect: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The continuous dial position (in stop-units) while a drag is in flight;
    /// `nil` when at rest, where `selectedIndex` is the source of truth.
    @State private var dragPosition: CGFloat?
    /// The `selectedIndex` captured when the current drag began.
    @State private var dragAnchorIndex = 0
    /// The last stop reported during the current drag. Reset to `selectedIndex`
    /// when a drag begins so a freshly bound (or externally changed) dial never
    /// emits a phantom detent on its first movement.
    @State private var committedIndex = 0
    /// Fires the mechanical detent tick. Driven imperatively so a fast flick that
    /// sweeps several stops in one gesture update ticks once *per* stop crossed —
    /// which SwiftUI's edge-triggered `.sensoryFeedback` can't express.
    @State private var haptics = UISelectionFeedbackGenerator()

    // Arc geometry. A large radius keeps the arc gently curved rather than a
    // tight bowl; `anglePerStop` sets how far apart the marks fan.
    private let radius: CGFloat = 900
    private let anglePerStop = 3.4 * .pi / 180
    private let apexY: CGFloat = 34
    /// How many stops fan out either side of centre before they clip/fade.
    private let visibleSpan = 7
    /// Drag distance (points) that advances the dial one stop.
    private let pointsPerStop: CGFloat = 50

    /// The effective dial position: the live drag while dragging, else the
    /// committed selection.
    private var position: CGFloat { dragPosition ?? CGFloat(selectedIndex ?? 0) }
    /// Whether the dial has a complete target and should reveal its visual content.
    private var isBound: Bool {
        guard let selectedIndex, caption != nil else { return false }
        return labels.indices.contains(selectedIndex)
    }

    var body: some View {
        GeometryReader { geo in
            let centerX = geo.size.width / 2
            let centerY = apexY + radius

            ZStack {
                ForEach(visibleIndices, id: \.self) { index in
                    let angle = (CGFloat(index) - position) * CGFloat(anglePerStop)
                    stopMark(index, angle: angle)
                        .position(
                            x: centerX + radius * sin(angle),
                            y: centerY - radius * cos(angle)
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .mask(edgeFade)
            .transaction { $0.animation = nil }
            .opacity(isBound ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: isBound)

            indicator
                .opacity(isBound ? 1 : 0)
                .position(x: centerX, y: 8)
        }
        .frame(height: Self.layoutHeight)
        .contentShape(Rectangle())
        .gesture(dialGesture)
        .accessibilityElement()
        .accessibilityHidden(isBound == false)
        .accessibilityLabel(caption ?? "")
        .accessibilityValue(selectedIndex.flatMap { labels[safe: $0] } ?? "")
        .accessibilityAdjustableAction { direction in
            guard let selectedIndex else { return }
            switch direction {
            case .increment: onSelect(min(selectedIndex + 1, labels.count - 1))
            case .decrement: onSelect(max(selectedIndex - 1, 0))
            @unknown default: break
            }
        }
    }

    // MARK: - Marks

    /// A single stop on the arc: its label above a tick, rotated to sit radially
    /// and faded by its distance from the indicator. The centred stop is accented.
    private func stopMark(_ index: Int, angle: CGFloat) -> some View {
        let isSelected = Int(position.rounded()) == index
        let distance = abs(CGFloat(index) - position)

        return VStack(spacing: 6) {
            Text(labels[index])
                .font(.system(size: isSelected ? 19 : 15,
                              weight: isSelected ? .semibold : .regular,
                              design: .rounded))
                .monospacedDigit()
                .fixedSize()

            Capsule()
                .frame(width: isSelected ? 2 : 1, height: isSelected ? 14 : 9)
        }
        .foregroundStyle(isSelected
            ? AnyShapeStyle(.tint)
            : AnyShapeStyle(.white.opacity(fade(for: distance))))
        .rotationEffect(.radians(Double(angle)))
        .animation(reduceMotion ? nil : .snappy, value: isSelected)
    }

    /// The fixed indicator the values sweep past — a caret pinned to centre.
    private var indicator: some View {
        Image(systemName: "arrowtriangle.down.fill")
            .font(.system(size: 12))
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
    }

    /// Softens the left and right ends of the arc so marks fade out rather than
    /// clip at a hard edge.
    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.14),
                .init(color: .black, location: 0.86),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Interaction

    private var dialGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard let selectedIndex, labels.indices.contains(selectedIndex) else { return }

                // Drag begins: anchor to the current selection so the first
                // movement is measured from — and ticks relative to — where the
                // dial actually sits, not a stale index from a prior binding.
                if dragPosition == nil {
                    dragAnchorIndex = selectedIndex
                    committedIndex = selectedIndex
                    haptics.prepare()
                }

                // Dragging left advances toward higher values; one `pointsPerStop`
                // of travel is one stop.
                let raw = CGFloat(dragAnchorIndex) - value.translation.width / pointsPerStop
                let clamped = min(max(raw, 0), CGFloat(labels.count - 1))
                dragPosition = clamped

                let rounded = Int(clamped.rounded())
                guard rounded != committedIndex else { return }

                // A tick per stop actually crossed, so a fast flick over several
                // stops feels like several detents, not one.
                for _ in 0..<abs(rounded - committedIndex) {
                    haptics.selectionChanged()
                }
                haptics.prepare()
                committedIndex = rounded
                onSelect(rounded)
            }
            .onEnded { _ in
                // Every crossing was already reported in `onChanged`; just settle
                // the fractional overshoot onto the snapped stop.
                withAnimation(reduceMotion ? nil : .snappy) { dragPosition = nil }
            }
    }

    // MARK: - Helpers

    /// The window of stop indices worth drawing around the current position.
    private var visibleIndices: [Int] {
        guard labels.isEmpty == false else { return [] }
        let center = Int(position.rounded())
        let lower = max(center - visibleSpan, 0)
        let upper = min(center + visibleSpan, labels.count - 1)
        return Array(lower...upper)
    }

    /// Opacity for a mark `distance` stops from the indicator: full at centre,
    /// trailing off toward the edges but never fully invisible.
    private func fade(for distance: CGFloat) -> Double {
        max(0.12, 1 - Double(distance) * 0.13)
    }
}

private extension Array {
    /// Bounds-checked subscript — returns `nil` rather than trapping.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    struct DialPreview: View {
        @State private var index = 18 // f/8 on the aperture scale
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()
                    ArcDialView(
                        labels: PhotographicScale.aperture.stops.map(\.label),
                        selectedIndex: index,
                        caption: "Aperture",
                        onSelect: { index = $0 }
                    )
                }
            }
            .tint(.yellow)
            .preferredColorScheme(.dark)
        }
    }
    return DialPreview()
}
