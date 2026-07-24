import Foundation

// MARK: - DialGraduations (which marks on the ruler are numbered)
//
// A real instrument does not number every graduation. A lens barrel numbers the
// full stops and cuts a bare tick between them for the intermediate clicks, and
// that is the only thing that keeps a scale readable once the clicks get finer.
// The handoff numbers every graduation, which works only because it was drawn at
// full stops; numbering every stop at thirds would put a wall of digits under the
// needle.
//
// So the rule is: **a graduation is major when it is also a full stop.** Not
// "every third index" — index arithmetic is a coincidence that happens to hold
// for today's scales and would silently draw the wrong marks the moment one of
// them gained or lost a value. Membership is the actual rule, so it is the rule
// the code states.

/// Which stops on a dial scale are numbered, and which are drawn as bare ticks.
///
/// Pure and index-addressed, parallel to the labels the dial lays out, so the
/// view asks a question per tick and the rule is testable with no view at all.
struct DialGraduations: Equatable, Sendable {
    /// `true` at each index whose stop is a major (numbered) graduation.
    private let major: [Bool]

    /// How many graduations the scale has.
    var count: Int { major.count }

    /// Whether the graduation at `index` is numbered. Out-of-range indices are
    /// minor rather than a trap — the dial draws a window of indices it clamps
    /// itself, and a bounds mistake should lose a number, not the app.
    func isMajor(_ index: Int) -> Bool {
        major.indices.contains(index) ? major[index] : false
    }

    /// Marks each of `values` major when it also appears in `majorValues`.
    ///
    /// Matching is by *value* rather than by `PhotographicScale.Stop`, because the
    /// same stop can be marked differently on two scales: 1/2 s is `1/2` on the
    /// full-stop shutter scale and `0.5"` on the third-stop one. It is the same
    /// duration, and it is a full stop on both.
    init(values: [Double], majorValues: [Double]) {
        major = values.map { value in
            majorValues.contains { Self.isSameStop($0, value) }
        }
    }

    /// Whether two scale values are the same stop. A tolerance rather than `==`
    /// because the same duration is written two ways across the scales (`1.0 / 2`
    /// and `0.5`), and because nothing here should depend on two literals landing
    /// on the same float.
    private static func isSameStop(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) <= 1e-9 * max(1, abs(lhs), abs(rhs))
    }
}

extension DialGraduations {
    /// The graduations of an exposure leg's scale at `increment`: the full stops
    /// are numbered, and the half- and third-stop clicks between them are ticks.
    ///
    /// At the full-stop increment the scale *is* its own major scale, so every
    /// graduation is numbered — which is exactly the lens barrel the handoff drew.
    init(component: ExposureComponent, increment: StopIncrement) {
        self.init(
            values: component.scale(for: increment).stops.map(\.value),
            majorValues: component.scale(for: .full).stops.map(\.value)
        )
    }

    /// The graduations of the compensation scale: whole stops of bias are
    /// numbered, the thirds between them are ticks.
    ///
    /// Compensation has no `PhotographicScale` to be a member of — it is a signed
    /// count of stops rather than a leg of the exposure triangle — so "whole EV"
    /// stands in for "full stop". Same rule, same reason: `+1.0` is worth reading,
    /// the two clicks under it are worth feeling.
    init(compensationStops stops: [Double]) {
        self.init(
            values: stops,
            majorValues: stops.filter { $0 == $0.rounded() }
        )
    }
}
