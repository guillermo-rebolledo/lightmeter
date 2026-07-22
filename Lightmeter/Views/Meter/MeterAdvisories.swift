import SwiftUI

/// Exposure advisories with the guided-tour height freeze.
///
/// During the tour the advisories are hidden but keep their layout footprint so
/// live warnings cannot shove spotlight targets between steps. The caller passes
/// the frozen snapshot as `advisories` and flags the tour via `isTourActive`.
struct MeterAdvisories: View {
    let advisories: [ExposureAdvisory]
    let isTourActive: Bool
    /// Portrait collapses advisories to one thin line; landscape stacks them.
    var isCompact: Bool = false

    var body: some View {
        AdvisoriesView(advisories: advisories, isCompact: isCompact)
            .opacity(isTourActive ? 0 : 1)
            .allowsHitTesting(isTourActive == false)
            .accessibilityHidden(isTourActive)
    }
}
