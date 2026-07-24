import SwiftUI
import UIKit

/// The exposure-compensation track: a permanent, genuinely draggable scale in the
/// dial panel, so bias is visible at a glance and adjustable without opening
/// anything. It replaces the compensation status pill and the transient takeover
/// of the ruler dial — the dial's identity stays "the leg or ISO you are turning",
/// and compensation gets a track of its own.
///
/// It is a *real* control, not a display: a knob that looked draggable and was not
/// would undercut the instrument harder than any other detail on the screen. So
/// the knob follows the thumb one-to-one along the track, clicks a detent per
/// third of a stop crossed — the same `UISelectionFeedbackGenerator` tick the
/// ruler fires, so the two feel like one instrument — and settles onto a real,
/// dial-able third with a spring.
///
/// Three things it does that a plain slider does not:
///
/// - **The thin track wears a full touch target.** The visible rule is a couple
///   of points tall, but the gesture and the hit area fill a 44pt band, so the
///   knob is grabbable without aiming at a hairline.
/// - **Drift buys precision.** The track is short, so pulling the thumb away from
///   it slows the sweep (`CompensationSlider.sensitivity`), which is what lets the
///   last third be set on a track this size without a hair-trigger.
/// - **It is adjustable under VoiceOver.** A thin track is not draggable with the
///   rotor, so it exposes an increment/decrement action that steps a third at a
///   time, and speaks the signed value.
///
/// All the drag-to-value, clamping, snapping and reduced-sensitivity math lives in
/// the view-free ``CompensationSlider`` so it can be tested with no view involved;
/// this view is the gesture, the haptics, and the drawing on top of it.
struct CompensationSliderView: View {
    /// The current bias in stops — `MeterViewModel.compensation`.
    let value: Double
    /// The signed value shown alongside the track — `MeterViewModel.compensationLabel`.
    let label: String
    /// Reports a new bias, already snapped to a third — routes to
    /// `MeterViewModel.setCompensation`, so the view-model's behaviour is untouched.
    let onChange: (Double) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The continuous bias while a drag is in flight; `nil` at rest, where `value`
    /// is the source of truth. Lets the knob slide smoothly and settle onto its
    /// detent, the way the ruler's `dragPosition` does.
    @State private var dragValue: Double?
    /// The bias captured when the current drag began — the anchor every movement
    /// is measured from, so the knob never jumps to the touch point.
    @State private var dragAnchor = 0.0
    /// The last detent reported during the current drag, so a fast sweep clicks
    /// once per third crossed rather than once for the whole gesture.
    @State private var committedIndex = 0
    /// The mechanical detent tick — the same generator, driven the same imperative
    /// way, as the ruler dial's, so compensation and the dial click identically.
    @State private var haptics = UISelectionFeedbackGenerator()

    /// The full bias range, in stops. Fixed at ±3 — compensation steps in thirds
    /// regardless of the chosen exposure increment.
    private let extent = 3.0
    private let step = 1.0 / 3

    /// The visible track's thickness, and the knob riding it. The knob is a real
    /// target on its own; the band around it (below) makes the whole rule one.
    private let trackHeight: CGFloat = 3
    private let knobDiameter: CGFloat = 22

    /// The full-height touch band. The visible track is a hairline; the gesture
    /// and hit area fill 44pt so the knob is grabbable without aiming at it — the
    /// AC's padded hit target.
    private let hitHeight: CGFloat = 44

    /// The vertical drift at which the drag's sensitivity halves — passed into the
    /// value model, and the knee of the precise-adjustment curve.
    private let sensitivityFalloff: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            caption
            track
        }
        .accessibilityElement()
        .accessibilityLabel("Exposure compensation")
        .accessibilityValue(label)
        // A thin track is not draggable under VoiceOver, so it exposes an
        // adjustable action instead — stepping a third at a time, the same grain
        // the knob snaps to.
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(clampToThird(value + step))
            case .decrement: onChange(clampToThird(value - step))
            @unknown default: break
            }
        }
    }

    /// What the track is, and where it is now — the value displayed *alongside* the
    /// track, as the AC asks, rather than riding the knob where the thumb covers it.
    private var caption: some View {
        HStack {
            Text("Exposure comp")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.5)

            Spacer(minLength: 8)

            Text(label)
                .font(AppTypography.numeral(.caption2, weight: .semibold))
                .foregroundStyle(isZero ? AnyShapeStyle(.white) : AnyShapeStyle(.tint))
                // Counts as it steps under the thumb, like every other numeric
                // readout on the screen; fixed to one line so a widening value
                // ("+3.0 EV") never grows the panel's height.
                .contentTransition(.numericText())
                .scaledToFitOnOneLine(minimumScale: 0.7)
        }
        // The value change springs (it is a value the photographer *moves*) and
        // collapses to a snap under Reduce Motion, matching the panel numeral.
        .animation(reduceMotion ? nil : .snappy, value: value)
        .accessibilityHidden(true)
    }

    /// The track, its knob, and the invisible band that makes the hairline a real
    /// target. `GeometryReader` gives the drag both the track's width (for the 1:1
    /// mapping) and its centre line (to measure vertical drift from).
    private var track: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let slider = CompensationSlider(
                extent: extent,
                step: step,
                trackWidth: max(width - knobDiameter, 1),
                sensitivityFalloff: sensitivityFalloff
            )
            let midY = hitHeight / 2

            ZStack(alignment: .leading) {
                rule(width: width)
                knob(in: slider, width: width)
            }
            .frame(width: width, height: hitHeight)
            // The whole 44pt band is the target, not just the hairline — the same
            // explicit content shape the pills and gear carry.
            .contentShape(Rectangle())
            .gesture(dragGesture(slider: slider, midY: midY))
        }
        .frame(height: hitHeight)
    }

    /// The hairline rule with its centre zero mark and the whole-stop ticks either
    /// side, plus the accent fill running from centre to the knob — a bipolar
    /// slider, so the eye reads how far the bias is pushed and which way.
    private func rule(width: CGFloat) -> some View {
        let centerX = width / 2
        let knobX = knobCenterX(for: displayValue, width: width)
        return ZStack(alignment: .leading) {
            // The base rule.
            Capsule()
                .fill(.white.opacity(0.18))
                .frame(height: trackHeight)

            // Accent fill from the centre out to the knob — the bias, shown.
            Capsule()
                .fill(.tint)
                .frame(width: abs(knobX - centerX), height: trackHeight)
                .offset(x: min(centerX, knobX))

            // Whole-EV ticks, the centre one taller and brighter — the scale's
            // graduations, the way the ruler numbers its full stops.
            ForEach(-Int(extent)...Int(extent), id: \.self) { stop in
                let isZeroMark = stop == 0
                Capsule()
                    .fill(.white.opacity(isZeroMark ? 0.55 : 0.28))
                    .frame(width: 1.5, height: isZeroMark ? 10 : 6)
                    .offset(x: knobCenterX(for: Double(stop), width: width) - 0.75)
            }
        }
        .frame(height: hitHeight)
    }

    /// The draggable knob — a filled accent disc that reads as grabbable because it
    /// is: it rides to wherever the thumb puts it and settles onto a detent.
    private func knob(in slider: CompensationSlider, width: CGFloat) -> some View {
        Circle()
            .fill(.tint)
            .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
            .frame(width: knobDiameter, height: knobDiameter)
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            .offset(x: knobCenterX(for: displayValue, width: width) - knobDiameter / 2)
    }

    private func dragGesture(slider: CompensationSlider, midY: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                if dragValue == nil {
                    dragAnchor = value
                    committedIndex = slider.detentIndex(for: value)
                    haptics.prepare()
                }

                let verticalDistance = abs(drag.location.y - midY)
                let newValue = slider.value(
                    from: dragAnchor,
                    translation: drag.translation.width,
                    verticalDistance: verticalDistance
                )
                dragValue = newValue

                let index = slider.detentIndex(for: newValue)
                guard index != committedIndex else { return }

                // One tick per third actually crossed, so a flick across several
                // stops feels like several detents — the ruler's rule, kept here so
                // the two controls click the same.
                for _ in 0..<abs(index - committedIndex) {
                    haptics.selectionChanged()
                }
                haptics.prepare()
                committedIndex = index
                onChange(slider.snap(newValue))
            }
            .onEnded { _ in
                // Settle the fractional overshoot onto the snapped third with a
                // spring — the knob arrives like something with mass rather than
                // easing (a slider) or jumping (a picker) — and snap instantly
                // under Reduce Motion.
                withAnimation(reduceMotion ? nil : Self.settle) { dragValue = nil }
            }
    }

    /// How the knob comes to rest — the ruler dial's settle, so a released
    /// compensation knob and a released dial arrive the same way.
    private static let settle = Animation.spring(response: 0.32, dampingFraction: 0.72)

    // MARK: - Geometry helpers

    /// The bias the knob is drawn at: the live drag while dragging, else the model
    /// value.
    private var displayValue: Double { dragValue ?? value }

    private var isZero: Bool { abs(value) < 1e-6 }

    /// The knob's centre x for a bias, inset by its own radius at both ends so the
    /// disc stays fully on the track at ±3.
    private func knobCenterX(for value: Double, width: CGFloat) -> CGFloat {
        let usable = max(width - knobDiameter, 0)
        let slider = CompensationSlider(extent: extent, step: step, trackWidth: usable)
        return knobDiameter / 2 + slider.position(for: value) * usable
    }

    /// Clamps a stepped value onto the range's third-stop grid — the adjustable
    /// action's guard, so stepping at an end stays on the end rather than past it.
    private func clampToThird(_ value: Double) -> Double {
        let slider = CompensationSlider(extent: extent, step: step, trackWidth: 1)
        return slider.snap(value)
    }
}

#Preview {
    struct Harness: View {
        @State private var value = 0.0
        var body: some View {
            ZStack {
                LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                CompensationSliderView(
                    value: value,
                    label: value.formatted(.number.sign(strategy: .always()).precision(.fractionLength(1))) + " EV",
                    onChange: { value = $0 }
                )
                .padding()
            }
            .tint(.appAccent)
            .preferredColorScheme(.dark)
        }
    }
    return Harness()
}
