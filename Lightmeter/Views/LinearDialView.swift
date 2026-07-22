import SwiftUI
import UIKit

/// A compact linear ruler dial: the scale's stops lie along a straight ruler and
/// sweep past a fixed indicator as you drag. Each stop that crosses the indicator
/// fires a selection haptic — the detent tick that makes the dial feel mechanical.
/// Snapping is stop-to-stop; the ruler always settles on a real, dial-able mark.
///
/// The dial works along either `axis`. Horizontally it hugs the bottom edge and
/// sweeps left/right (portrait); vertically it hugs the trailing edge and sweeps
/// up/down (landscape). The view is axis-generic — the vertical layout is the
/// horizontal one turned a quarter-turn, reading the matching translation axis.
///
/// The dial is a pure controller: `selectedIndex` and `labels` are the source of
/// truth (owned by `MeterViewModel`), and `onSelect` reports each new detent up.
/// A drag is expressed in continuous stop-units and rounded to the nearest stop,
/// so the same gesture drives both the visual sweep and the reported value. All
/// tick-placement and drag→stop math lives in `LinearDialGeometry`.
struct LinearDialView: View {
    /// The thickness the dial requires across its short axis, including ticks, the
    /// centred label, and gesture area — a height when horizontal, a width when
    /// vertical. Far slimmer than the old arc, reclaiming frame for the preview.
    static let layoutThickness: CGFloat = 64

    /// The detent labels laid out along the ruler.
    let labels: [String]
    /// The stop the fixed indicator currently points at, or `nil` while unbound.
    let selectedIndex: Int?
    /// The leg being dialed, e.g. `"Aperture"` — announced to VoiceOver when bound.
    let caption: String?
    /// The edge the dial hugs and the direction it sweeps. Defaults to horizontal.
    var axis: Axis = .horizontal
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

    /// The tick-placement and drag→stop math, shared with the unit tests. Drag
    /// distance and tick spacing are equal so the ruler tracks the finger 1:1 —
    /// the mark under your thumb stays under it as you sweep (direct manipulation),
    /// which a straight ruler should honour even though the old arc did not.
    private let geometry = LinearDialGeometry(pointsPerStop: 48, tickSpacing: 48)
    /// How many stops fan out either side of centre before they clip/fade.
    private let visibleSpan = 7
    /// Distance from the hugged edge to the centred selected label (nearest edge).
    private let labelInset: CGFloat = 14
    /// Distance from the hugged edge to the fixed indicator caret.
    private let indicatorInset: CGFloat = 34
    /// Distance from the hugged edge to the row of ticks (furthest in).
    private let tickInset: CGFloat = 50

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
            ZStack {
                ForEach(visibleIndices, id: \.self) { index in
                    let offset = geometry.tickOffset(for: index, position: position)
                    tickMark(index)
                        .position(tickPosition(offset: offset, in: geo.size))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .mask(edgeFade)
            .transaction { $0.animation = nil }
            .opacity(isBound ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: isBound)

            selectedLabel
                .opacity(isBound ? 1 : 0)
                .position(labelPosition(in: geo.size))

            indicator
                .opacity(isBound ? 1 : 0)
                .position(indicatorPosition(in: geo.size))
        }
        .frame(
            width: axis == .vertical ? Self.layoutThickness : nil,
            height: axis == .horizontal ? Self.layoutThickness : nil
        )
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

    // MARK: - Geometry

    /// The centre of the ruler along its main axis: the width's midpoint when
    /// horizontal, the height's when vertical. Ticks are placed relative to it.
    private func mainAxisCenter(in size: CGSize) -> CGFloat {
        axis == .horizontal ? size.width / 2 : size.height / 2
    }

    /// Where a tick sits, given its signed `offset` from the fixed indicator along
    /// the main axis. The cross-axis position is fixed at `tickInset` from the edge.
    private func tickPosition(offset: CGFloat, in size: CGSize) -> CGPoint {
        switch axis {
        case .horizontal: CGPoint(x: mainAxisCenter(in: size) + offset, y: tickInset)
        case .vertical: CGPoint(x: size.width - tickInset, y: mainAxisCenter(in: size) + offset)
        }
    }

    /// The centred selected value's anchor, near the hugged edge and lined up with
    /// the fixed indicator along the main axis.
    private func labelPosition(in size: CGSize) -> CGPoint {
        switch axis {
        case .horizontal: CGPoint(x: mainAxisCenter(in: size), y: labelInset)
        case .vertical: CGPoint(x: size.width - labelInset, y: mainAxisCenter(in: size))
        }
    }

    /// The fixed indicator's anchor: between the label and the tick row, at the
    /// ruler's centre, so its caret points inward at the selected tick.
    private func indicatorPosition(in size: CGSize) -> CGPoint {
        switch axis {
        case .horizontal: CGPoint(x: mainAxisCenter(in: size), y: indicatorInset)
        case .vertical: CGPoint(x: size.width - indicatorInset, y: mainAxisCenter(in: size))
        }
    }

    // MARK: - Marks

    /// A single tick on the ruler — a short capsule, accented when selected and
    /// faded by its distance from the indicator. Only ticks are drawn here; the
    /// selected value is labelled once, separately, over the indicator.
    private func tickMark(_ index: Int) -> some View {
        let isSelected = geometry.stop(at: position) == index
        let distance = abs(CGFloat(index) - position)

        return Capsule()
            .frame(
                width: axis == .horizontal ? (isSelected ? 2 : 1) : (isSelected ? 16 : 10),
                height: axis == .horizontal ? (isSelected ? 16 : 10) : (isSelected ? 2 : 1)
            )
            .foregroundStyle(isSelected
                ? AnyShapeStyle(.tint)
                : AnyShapeStyle(.white.opacity(fade(for: distance))))
            .animation(reduceMotion ? nil : .snappy, value: isSelected)
    }

    /// The single labelled value: the selected stop, shown once over the indicator
    /// so the ruler reads as ticks with one number rather than a wall of digits.
    private var selectedLabel: some View {
        Text(labels[safe: geometry.stop(at: position)] ?? "")
            .font(.system(size: 19, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .fixedSize()
            .foregroundStyle(.tint)
            .animation(nil, value: position)
    }

    /// The fixed indicator the values sweep past — a caret pinned over the tick row,
    /// pointing at the selected mark.
    private var indicator: some View {
        Image(systemName: axis == .horizontal ? "arrowtriangle.down.fill" : "arrowtriangle.left.fill")
            .font(.system(size: 11))
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
    }

    /// Softens the ends of the ruler so ticks fade out rather than clip at a hard
    /// edge, along whichever axis the dial sweeps.
    private var edgeFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.14),
                .init(color: .black, location: 0.86),
                .init(color: .clear, location: 1),
            ],
            startPoint: axis == .horizontal ? .leading : .top,
            endPoint: axis == .horizontal ? .trailing : .bottom
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

                // Dragging back along the axis (left / up) advances toward higher
                // values; one `pointsPerStop` of travel is one stop.
                let travel = axis == .horizontal ? value.translation.width : value.translation.height
                let clamped = geometry.position(fromAnchor: dragAnchorIndex, travel: travel, stopCount: labels.count)
                dragPosition = clamped

                let rounded = geometry.stop(at: clamped)
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
        geometry.visibleIndices(around: position, stopCount: labels.count, span: visibleSpan)
    }

    /// Opacity for a tick `distance` stops from the indicator: full at centre,
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

#Preview("Horizontal") {
    struct DialPreview: View {
        @State private var index = 18 // f/8 on the aperture scale
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack {
                    Spacer()
                    LinearDialView(
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

#Preview("Vertical") {
    struct DialPreview: View {
        @State private var index = 18 // f/8 on the aperture scale
        var body: some View {
            ZStack {
                Color.black.ignoresSafeArea()
                HStack {
                    Spacer()
                    LinearDialView(
                        labels: PhotographicScale.aperture.stops.map(\.label),
                        selectedIndex: index,
                        caption: "Aperture",
                        axis: .vertical,
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
