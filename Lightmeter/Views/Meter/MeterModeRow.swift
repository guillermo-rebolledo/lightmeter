import SwiftUI

/// The instrument's mode row below the dial panel: two quiet glass tracks of small
/// caps, holding what the photographer sets apart from how the frame is metered.
///
/// The left track is the **dial-target selector** — the three legs the single
/// ruler can turn: aperture · shutter · ISO. Its one highlight follows
/// ``MeterViewModel/boundComponent`` — *what the dial is turning* — so the lit cell
/// always names what the photographer's thumb drives. The right track is the
/// **metering pattern** — average · spot — driving ``MeterViewModel/pattern``.
///
/// This is the "the dial drives the last thing you tapped" rule made into a row:
///
/// - **Tapping Aperture or Shutter** flips priority *and* aims the dial at that
///   leg, through ``MeterViewModel/setMode(_:)`` — choosing what you hold and what
///   you turn is one gesture. Priority stays legible from the top bar's accent
///   solved leg.
/// - **Tapping ISO** aims the dial at the ISO scale through
///   ``MeterViewModel/selectChip(_:)`` *without* changing priority — setting
///   sensitivity never silently changes which leg you hold. ISO is always an input
///   and never solved, so this is always available.
/// - **The ISO cell shows its live value** (`ISO 400`) — the only cell that shows
///   a value, because it is the only one that doesn't flip priority, so its
///   set-and-glance value would otherwise vanish when the dial is pointed
///   elsewhere. It replaces the ISO control that used to ride the top EV bar.
///
/// Two things about it are decisions rather than drawing:
///
/// - **The tracks are two separate capsule tracks with a gap**, not one
///   five-segment control. Each holds exactly one highlight — the standard
///   segmented-control reading — so the two simultaneous highlights (one per
///   track) read as two independent selections rather than as one control lighting
///   two segments at once, which would look like a rendering fault. (While the
///   ruler is on compensation, ``MeterViewModel/boundComponent`` is `nil` and the
///   left track lights nothing — the comp readout carries the active state then.)
/// - **The tracks are sized 3 : 2** (``WeightedRow``) so all five cells are equal
///   width, rather than two equal halves — which would make the left track's three
///   cells narrower than the right's two, and the longest labels land on the left.
///
/// Like the status pills it replaces in portrait, the row floats over the live
/// scene, so each track carries the same scrim-over-glass treatment for legibility
/// over a bright sky and a complete pre-iOS-26 fallback. Selection is the app's
/// established highlight vocabulary — an accent-tinted cell with an accent label —
/// which reads the same on both glass paths.
struct MeterModeRow: View {
    let model: MeterViewModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The left track's cells, in the dial's own order — the three legs the single
    /// ruler can turn.
    static let dialTargets: [ExposureComponent] = [.aperture, .shutter, .iso]

    /// The gap between the two tracks — wide enough that they read as two separate
    /// controls, which is what keeps their two highlights from being mistaken for
    /// one control lighting two segments.
    private static let trackSpacing: CGFloat = 16

    var body: some View {
        // Widths proportional to each track's cell count (3 : 2), so all five
        // cells land the same width across the two separately-padded tracks.
        WeightedRow(
            weights: [CGFloat(Self.dialTargets.count), CGFloat(MeteringPattern.allCases.count)],
            spacing: Self.trackSpacing
        ) {
            dialTargetTrack
            patternTrack
        }
        // The two tracks are glass among themselves, so adjacent surfaces blend as
        // one system on the glass path — a no-op passthrough on the fallback.
        .glassGroup()
        .animation(reduceMotion ? nil : .snappy, value: model.boundComponent)
        .animation(reduceMotion ? nil : .snappy, value: model.pattern)
    }

    // MARK: - The two tracks

    /// The dial-target track: aperture · shutter · ISO, its highlight following the
    /// leg the dial is bound to.
    private var dialTargetTrack: some View {
        track {
            ForEach(Self.dialTargets, id: \.self) { component in
                cellButton(
                    Self.dialTargetCell(
                        for: component,
                        boundComponent: model.boundComponent,
                        isoMarking: model.triangle.iso.label
                    ),
                    onSelect: { Self.route(component, on: model) }
                )
            }
        }
    }

    /// The metering-pattern track: average · spot, driving `pattern`. Unchanged in
    /// meaning by this row's 3 + 2 restructure.
    private var patternTrack: some View {
        track {
            ForEach(MeteringPattern.allCases, id: \.self) { pattern in
                cellButton(
                    Self.patternCell(for: pattern, selection: model.pattern),
                    // Spot defaults its point to the frame center; average stops
                    // metering that point and drops the reticle (the placed spot is
                    // kept, not cleared, so returning to spot restores it).
                    onSelect: { model.setPattern(pattern) }
                )
            }
        }
    }

    // MARK: - Cell descriptors (pure, so what a cell says is tested without a view)

    /// One cell's presentation and voice — what it draws, whether it is lit, and
    /// what it says to VoiceOver, which can't see the small-caps glyph or the
    /// accent tint. Pure over the domain state, the same shape as
    /// `ExposureChipsView.ChipRole`.
    struct Cell: Equatable {
        /// The on-screen small-caps label — a leg name, a pattern name, or `ISO`
        /// with its live value.
        let title: String
        /// The spoken name of the cell.
        let accessibilityLabel: String
        /// The spoken value, where the cell carries one — only the ISO cell does.
        var accessibilityValue: String?
        /// The spoken hint saying what a tap does.
        var accessibilityHint: String?
        /// Whether this cell is the one lit in its track.
        let isSelected: Bool
    }

    /// A dial-target cell. Aperture and shutter name themselves and speak as a
    /// *priority* (a tap holds that leg and aims the dial at it); ISO shows and
    /// speaks its live value and hints that a tap only re-aims the dial. Lit when
    /// the dial is currently bound to this leg.
    static func dialTargetCell(
        for component: ExposureComponent,
        boundComponent: ExposureComponent?,
        isoMarking: String
    ) -> Cell {
        switch component {
        case .iso:
            Cell(
                title: "ISO \(isoMarking)",
                accessibilityLabel: ExposureComponent.iso.caption,
                accessibilityValue: isoMarking,
                accessibilityHint: Self.isoCellHint,
                isSelected: boundComponent == .iso
            )
        case .aperture, .shutter:
            Cell(
                title: component.caption,
                // Named as a *priority* — tapping it holds this leg — so it can't
                // be mistaken for a metering-pattern cell when read aloud, the same
                // reason the pattern cells name their axis.
                accessibilityLabel: PriorityMode.locking(component)?.accessibilityLabel
                    ?? component.caption,
                accessibilityHint: Self.priorityCellHint,
                isSelected: boundComponent == component
            )
        }
    }

    /// A metering-pattern cell, lit when it is the active pattern.
    static func patternCell(for pattern: MeteringPattern, selection: MeteringPattern) -> Cell {
        Cell(
            title: pattern.label,
            accessibilityLabel: pattern.accessibilityLabel,
            isSelected: pattern == selection
        )
    }

    /// What a tap on a dial-target cell does, routed to already-existing model
    /// entry points. Aperture / shutter flip priority *and* aim the dial
    /// (`setMode`); ISO only aims the dial (`selectChip`). Static so the routing is
    /// pinned by a test driving a real model, without a view.
    static func route(_ component: ExposureComponent, on model: MeterViewModel) {
        switch component {
        case .aperture, .shutter:
            // Re-binds the dial to this leg even when the mode is unchanged — so a
            // tap always aims the dial here, the route home after dialling ISO.
            PriorityMode.locking(component).map(model.setMode)
        case .iso:
            model.selectChip(.iso)
        }
    }

    /// The hint on an aperture / shutter cell — a tap does two things at once, so
    /// VoiceOver is told rather than left to discover the priority half.
    static let priorityCellHint = "Holds this leg and points the dial at it"

    /// The hint on the ISO cell — a value that doesn't look like a control, so the
    /// hint says what the tap does (aim the dial, leave priority alone). Moved here
    /// with ISO when it left the top EV bar.
    static let isoCellHint = "Points the dial at the ISO scale"

    // MARK: - Drawing

    /// One track: equal-width cells (rather than an `HStack`) so a longer label
    /// can't claim more width and drag the selection under the thumb that tapped
    /// it, on the scrim-over-glass surface the floating pills use.
    private func track(@ViewBuilder _ cells: () -> some View) -> some View {
        EqualWidthRow(spacing: Self.cellSpacing) {
            cells()
        }
        .padding(Self.trackPadding)
        // The scrim then the glass surface, in that order — the pills' recipe for a
        // control floating on the raw preview: the scrim darkens the refraction
        // rather than sitting under it.
        .modifier(PreviewFloatingBackground())
        .glassSurface(.pill(isActive: false))
        // Fill the width the weighted row proposes, so the 3 : 2 split holds even
        // when the cells' own content is narrower.
        .frame(maxWidth: .infinity)
    }

    private func cellButton(_ cell: Cell, onSelect: @escaping () -> Void) -> some View {
        Button(action: onSelect) {
            Text(cell.title)
                // The instrument's caption face — the same small-caps tracking the
                // dial panel and the EV bar wear — so the row reads as part of the
                // same instrument rather than a system control bolted on.
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(cell.isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .scaledToFitOnOneLine(minimumScale: 0.6)
                .frame(maxWidth: .infinity)
                .frame(minHeight: Self.cellHeight)
                // The glass surface contributes no hit region, and neither does the
                // tint fill, so pin the tappable area to the whole cell.
                .contentShape(Capsule())
                .background {
                    // The app's highlight vocabulary — a low-opacity accent fill,
                    // as the active status pill wears on the fallback — path-neutral
                    // so both glass paths read the selection identically.
                    if cell.isSelected {
                        Capsule().fill(.tint.opacity(0.22))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cell.accessibilityLabel)
        .accessibilityValue(cell.accessibilityValue ?? "")
        .accessibilityHint(cell.accessibilityHint ?? "")
        // The accent tint is silent, so the selected state has to be spoken.
        .accessibilityAddTraits(cell.isSelected ? .isSelected : [])
    }

    /// The gap between cells within a track — tight, so a track reads as one
    /// control while still leaving the tinted selection a clear edge.
    private static let cellSpacing: CGFloat = 4

    /// The inset holding the cells off the track's rounded ends.
    private static let trackPadding: CGFloat = 3

    /// A cell's minimum height. Below the 44pt chrome minimum on purpose — this is
    /// a quiet secondary strip, and the tappable area is the full column width at
    /// this height, a comfortable target — but tall enough to read as a control
    /// rather than a caption.
    private static let cellHeight: CGFloat = 40
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
