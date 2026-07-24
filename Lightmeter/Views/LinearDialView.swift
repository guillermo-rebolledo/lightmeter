import SwiftUI
import UIKit

/// A graduated horizontal ruler: the scale's stops lie along a straight rule and
/// sweep past a fixed needle as you drag. Each stop that crosses the needle fires
/// a selection haptic — the detent tick that makes the dial feel mechanical.
/// Snapping is stop-to-stop; the ruler always settles on a real, dial-able mark.
///
/// **Major and minor graduations.** Full stops carry a long tick and a number;
/// the half- and third-stop clicks between them are bare ticks, the way a lens
/// barrel is marked. Which is which is not this view's decision — it asks
/// ``DialGraduations``, which derives it from membership in the full-stop scale.
/// At the full-stop increment every graduation is major, so the ruler reads
/// exactly like a barrel; at thirds it stays a rule with numbers on it rather
/// than a wall of digits.
///
/// **The needle is fixed and the scale moves.** It sits above the graduations,
/// pointing down at the mark it is naming, and never moves — so the photographer's
/// eye has one place to look while the values run under it.
///
/// The dial is a pure controller: `selectedIndex` and `labels` are the source of
/// truth (owned by `MeterViewModel`), and `onSelect` reports each new detent up.
/// A drag is expressed in continuous stop-units and rounded to the nearest stop,
/// so the same gesture drives both the visual sweep and the reported value. All
/// tick-placement and drag→stop math lives in `LinearDialGeometry`.
///
/// It does **not** show the selected value: the dial panel says what is being
/// turned and shows it as its large numeral, directly above. Landscape's drawer
/// composes the same restyled ruler under chips that carry the same values.
struct LinearDialView: View {
    /// The detent labels laid out along the ruler.
    let labels: [String]
    /// Which of those labels are numbered on the rule.
    let graduations: DialGraduations
    /// The stop the fixed needle currently points at, or `nil` while unbound.
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

    /// The gap between adjacent graduations, and — because it is one value — the
    /// drag travel that advances the dial one stop. That is what makes the rule
    /// track the finger 1:1: the mark under your thumb stays under it as you sweep.
    ///
    /// Scaled with Dynamic Type, because the numbers under the ticks are. Holding
    /// the spacing while the numbers grew would run "1/8000" into "1/4000" at the
    /// larger text sizes — an unreadable rule, which is the failure the major /
    /// minor split exists to avoid in the first place.
    @ScaledMetric(relativeTo: .caption2) private var stopSpacing: CGFloat = 48

    /// The tick-placement and drag→stop math, shared with the unit tests.
    private var geometry: LinearDialGeometry { LinearDialGeometry(spacing: stopSpacing) }

    /// How many stops fan out either side of centre before they clip/fade.
    private let visibleSpan = 7
    /// A numbered graduation's tick, long enough to read as the mark its number
    /// belongs to; the clicks between them are half of it.
    private let majorTickHeight: CGFloat = 15
    private let minorTickHeight: CGFloat = 7
    /// The gap between the needle and the rule, and between the rule and its
    /// numbers — the second smaller, so a number reads as belonging to the tick
    /// above it rather than floating between two rows.
    private let needleGap: CGFloat = 5
    private let numberGap: CGFloat = 3

    /// The effective dial position: the live drag while dragging, else the
    /// committed selection.
    private var position: CGFloat { dragPosition ?? CGFloat(selectedIndex ?? 0) }
    /// The stop under the needle right now.
    private var markedIndex: Int { geometry.stop(at: position) }
    /// Whether the dial has a complete target and should reveal its visual content.
    private var isBound: Bool {
        guard let selectedIndex, caption != nil else { return false }
        return labels.indices.contains(selectedIndex)
    }

    var body: some View {
        VStack(spacing: needleGap) {
            needle
            rule
        }
        .frame(maxWidth: .infinity)
        .opacity(isBound ? 1 : 0)
        .animation(.easeOut(duration: 0.15), value: isBound)
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

    // MARK: - The rule

    /// The graduations and their numbers — the part that moves. Masked at both
    /// ends so marks fade out rather than clipping at a hard edge as they sweep.
    private var rule: some View {
        VStack(spacing: numberGap) {
            marks(minHeight: majorTickHeight) { tickMark($0) }
            marks(minHeight: nil) { number($0) }
        }
        .mask(edgeFade)
        // The sweep follows the finger exactly, so it is never animated: the one
        // animation the rule has is the spring that settles `dragPosition`.
        .transaction { $0.animation = nil }
    }

    /// One row of the rule: every visible graduation, offset from the centre by
    /// its distance from the needle.
    ///
    /// `ZStack` centres its children, so an offset from centre is an offset from
    /// the needle — no `GeometryReader`, and the row keeps the height of its
    /// content rather than a hard-coded thickness that Dynamic Type would outgrow.
    private func marks(
        minHeight: CGFloat?,
        @ViewBuilder mark: @escaping (Int) -> some View
    ) -> some View {
        ZStack(alignment: .top) {
            // Reserves the row's height whatever happens to be visible: a window
            // of thirds can hold no numbered stop at all, and a numbers row that
            // collapsed to nothing would take the rule's height down with it.
            Text(" ")
                .font(Self.numberFont)
                .hidden()
                .accessibilityHidden(true)

            ForEach(visibleIndices, id: \.self) { index in
                mark(index)
                    .offset(x: geometry.tickOffset(for: index, position: position))
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .top)
    }

    /// A single graduation: long for a full stop, short for a click between them,
    /// accented under the needle and faded by its distance from it.
    private func tickMark(_ index: Int) -> some View {
        let isMarked = index == markedIndex

        return Capsule()
            .frame(
                width: isMarked ? 2 : 1,
                height: graduations.isMajor(index) ? majorTickHeight : minorTickHeight
            )
            .foregroundStyle(isMarked
                ? AnyShapeStyle(.tint)
                : AnyShapeStyle(.white.opacity(fade(for: index))))
    }

    /// A numbered graduation's marking, under its tick. Minor graduations draw
    /// nothing — that is the whole point of the split.
    @ViewBuilder private func number(_ index: Int) -> some View {
        if graduations.isMajor(index), let label = labels[safe: index] {
            Text(label)
                .font(Self.numberFont)
                // One short marking per tick, with the gap to its neighbour to sit
                // in — it never needs to wrap or shrink, and fixing it is what
                // keeps the offset row from squeezing it to a column of letters.
                .fixedSize()
                .foregroundStyle(index == markedIndex
                    ? AnyShapeStyle(.tint)
                    : AnyShapeStyle(.white.opacity(fade(for: index))))
        }
    }

    /// The fixed needle the graduations sweep past: a caret above the rule,
    /// pointing down at the mark it is naming.
    private var needle: some View {
        Image(systemName: "arrowtriangle.down.fill")
            .font(.system(size: 11))
            .foregroundStyle(.tint)
            .accessibilityHidden(true)
    }

    /// The numbers on the rule — the app's smallest tier, in the numeric face
    /// every other value on the screen wears.
    private static let numberFont = AppTypography.numeral(.caption2, weight: .medium)

    /// Softens the ends of the rule so graduations fade out rather than clip at a
    /// hard edge as they sweep left/right.
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

                // Dragging back (left) advances toward higher values; one
                // `stopSpacing` of travel is one stop.
                let travel = value.translation.width
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
                // Every crossing was already reported in `onChanged`; this settles
                // the fractional overshoot onto the snapped stop — with a spring,
                // because a rule that eased to a stop would read as a slider and
                // one that snapped instantly would read as a picker. A flicked
                // dial should arrive like something with mass.
                withAnimation(reduceMotion ? nil : Self.settle) { dragPosition = nil }
            }
    }

    /// How a flicked rule comes to rest. Just enough bounce to feel like mass,
    /// short enough that the value under the needle is never in doubt.
    private static let settle = Animation.spring(response: 0.32, dampingFraction: 0.72)

    // MARK: - Helpers

    /// The window of stop indices worth drawing around the current position.
    private var visibleIndices: [Int] {
        geometry.visibleIndices(around: position, stopCount: labels.count, span: visibleSpan)
    }

    /// Opacity for the graduation at `index`: full under the needle, trailing off
    /// toward the ends of the rule but never fully invisible.
    private func fade(for index: Int) -> Double {
        max(0.12, 1 - Double(abs(CGFloat(index) - position)) * 0.13)
    }
}

private extension Array {
    /// Bounds-checked subscript — returns `nil` rather than trapping.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview("Thirds") {
    DialPreview(increment: .third)
}

#Preview("Full stops") {
    DialPreview(increment: .full)
}

/// The rule over a dark scene at a chosen increment — the two ends of the
/// major / minor split, side by side in the canvas.
private struct DialPreview: View {
    let increment: StopIncrement

    @State private var index = 0

    private var scale: PhotographicScale { .aperture(for: increment) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                Spacer()
                LinearDialView(
                    labels: scale.stops.map(\.label),
                    graduations: DialGraduations(component: .aperture, increment: increment),
                    selectedIndex: index,
                    caption: ExposureComponent.aperture.caption,
                    onSelect: { index = $0 }
                )
            }
        }
        .tint(.appAccent)
        .preferredColorScheme(.dark)
        .onAppear { index = scale.stops.count / 2 }
    }
}
