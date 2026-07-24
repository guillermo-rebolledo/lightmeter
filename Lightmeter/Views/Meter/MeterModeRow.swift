import SwiftUI

/// The two mode decisions the meter carries — which exposure leg you hold
/// (**priority**), and how the frame is metered (**pattern**) — as one quiet row
/// of small caps below the dial panel in the portrait instrument face.
///
/// The design handoff drew these as one segmented control of four mutually
/// exclusive segments (`A / S / Inc / Spot`). That is not how the app works:
/// priority and metering pattern are **orthogonal** and combine freely, so
/// choosing spot cannot un-choose aperture-priority. The row keeps the mock's
/// look — a single row of small caps — but is modelled as **two independent
/// pairs**, each an ordinary segmented control with exactly one segment selected:
///
///   - **Priority** — aperture / shutter, driving ``MeterViewModel/mode``.
///   - **Pattern** — average / spot, driving ``MeterViewModel/pattern``.
///
/// (There is no incident-metering segment; ``MeteringPattern`` has no such case,
/// so the pair is average / spot by construction.)
///
/// Two things about it are decisions rather than drawing:
///
/// - **The pairs are two separate capsule tracks with a gap between them**, not
///   one four-segment control. Each track holds exactly one highlight, which is
///   the standard segmented-control reading — so the two simultaneous highlights
///   (one per pair) read as *two independent selections* rather than as a
///   rendering fault where a control lit two segments at once.
/// - **Tapping a priority segment points the dial at that leg**, via
///   ``MeterViewModel/setMode(_:)``, *including when the segment is already
///   active* — `setMode` re-binds the dial to the mode's leg unconditionally.
///   That is the route back after dialling ISO from the bar, and it collapses the
///   whole model to one sentence: the dial drives the last thing you tapped.
///
/// Like the status pills it replaces in portrait, the row floats over the live
/// scene, so each track carries the same scrim-over-glass treatment for
/// legibility over a bright sky and a complete pre-iOS-26 fallback. Selection is
/// the app's established highlight vocabulary — an accent-tinted segment with an
/// accent label — which reads the same on both glass paths.
struct MeterModeRow: View {
    let model: MeterViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The gap between the two pairs — wide enough that the tracks read as two
    /// separate controls rather than one, which is what keeps their two highlights
    /// from being mistaken for a single control lighting two segments.
    private static let pairSpacing: CGFloat = 16

    var body: some View {
        HStack(spacing: Self.pairSpacing) {
            segmentedPair(
                segments: PriorityMode.allCases,
                selection: model.mode,
                label: \.label,
                accessibilityLabel: \.accessibilityLabel,
                // Re-binds the dial to this leg even when the mode is unchanged —
                // the route home after dialling ISO.
                onSelect: { model.setMode($0) }
            )
            .frame(maxWidth: .infinity)

            segmentedPair(
                segments: MeteringPattern.allCases,
                selection: model.pattern,
                label: \.label,
                accessibilityLabel: \.accessibilityLabel,
                // Spot defaults its point to the frame center (so tap-to-place is
                // live and the reticle has somewhere to show); average stops
                // metering that point and drops the reticle (the placed spot is
                // kept, not cleared, so returning to spot restores it).
                onSelect: { model.setPattern($0) }
            )
            .frame(maxWidth: .infinity)
        }
        // The two tracks are glass among themselves, so adjacent surfaces blend as
        // one system on the glass path — a no-op passthrough on the fallback.
        .glassGroup()
        .animation(reduceMotion ? nil : .snappy, value: model.mode)
        .animation(reduceMotion ? nil : .snappy, value: model.pattern)
    }

    /// One independent pair as a capsule-tracked segmented control: equal-width
    /// segments so the highlight never shifts a neighbour, the selected one tinted.
    private func segmentedPair<Item: Hashable>(
        segments: [Item],
        selection: Item,
        label: KeyPath<Item, String>,
        accessibilityLabel: KeyPath<Item, String>,
        onSelect: @escaping (Item) -> Void
    ) -> some View {
        // Equal columns (rather than an `HStack`) so the two segments divide the
        // track exactly, and a longer label can't claim more width and drag the
        // selection under the thumb that just tapped it.
        EqualWidthRow(spacing: Self.segmentSpacing) {
            ForEach(segments, id: \.self) { segment in
                segmentButton(
                    title: segment[keyPath: label],
                    accessibilityLabel: segment[keyPath: accessibilityLabel],
                    isSelected: segment == selection,
                    onSelect: { onSelect(segment) }
                )
            }
        }
        .padding(Self.trackPadding)
        // The scrim then the glass surface, in that order — the pills' recipe for
        // a control floating on the raw preview: the scrim darkens the refraction
        // rather than sitting under it.
        .modifier(PreviewFloatingBackground())
        .glassSurface(.pill(isActive: false))
    }

    private func segmentButton(
        title: String,
        accessibilityLabel: String,
        isSelected: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        Button(action: onSelect) {
            Text(title)
                // The instrument's caption face — the same small-caps tracking the
                // dial panel and the EV bar wear — so the row reads as part of the
                // same instrument rather than as a system control bolted on.
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .scaledToFitOnOneLine(minimumScale: 0.6)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Self.segmentHeight)
                // The glass surface contributes no hit region, and neither does the
                // tint fill, so pin the tappable area to the whole segment.
                .contentShape(Capsule())
                .background {
                    // The app's highlight vocabulary — a low-opacity accent fill,
                    // as the active status pill wears on the fallback — path-neutral
                    // so both glass paths read the selection identically.
                    if isSelected {
                        Capsule().fill(.tint.opacity(0.22))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        // The accent tint is silent, so the selected state has to be spoken.
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The gap between the two segments within a pair — tight, so the pair reads
    /// as one control while still leaving the tinted selection a clear edge.
    private static let segmentSpacing: CGFloat = 4

    /// The inset holding the segments off the track's rounded ends.
    private static let trackPadding: CGFloat = 3

    /// A segment's minimum height. Below the 44pt chrome minimum on purpose — this
    /// is a quiet secondary strip, and the tappable area is the full column width
    /// at this height, which is a comfortable target — but tall enough to read as
    /// a control rather than a caption.
    private static let segmentHeight: CGFloat = 40
}

#Preview {
    ZStack {
        // Stand in for a blown-out sky: the case the row's scrim exists for.
        LinearGradient(colors: [.white, .cyan], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        VStack {
            Spacer()
            MeterModeRow(model: MeterViewModel(source: CameraLightSource()))
                .padding(.horizontal, PortraitMeterLayout.panelInset)
        }
    }
    .tint(.appAccent)
    .preferredColorScheme(.dark)
}
