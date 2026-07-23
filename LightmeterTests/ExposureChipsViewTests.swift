import Testing
@testable import Lightmeter

/// The chips' one piece of real logic: mapping each leg to its role — bound,
/// editable, or AUTO — the three-state visual language that makes the chips the
/// priority control. Pure over `(triangle, boundComponent)`, so it's tested
/// without a view.
struct ExposureChipsViewTests {
    /// A solved aperture-priority triangle (EV 15, sunny 16): ISO and aperture are
    /// set, the shutter is solved.
    private func triangle(mode: PriorityMode) -> ExposureTriangle {
        ExposureEngine.solvedTriangle(
            mode: mode, evAtISO100: 15, iso: 100, aperture: 16, shutter: 1.0 / 125
        )
    }

    private func role(
        _ component: ExposureComponent,
        mode: PriorityMode,
        boundComponent: ExposureComponent?
    ) -> ExposureChipsView.ChipRole {
        ExposureChipsView.role(
            for: component,
            triangle: triangle(mode: mode),
            boundComponent: boundComponent
        )
    }

    /// Aperture-priority: shutter is solved (AUTO), the bound aperture wears the
    /// ring, and ISO reads as a plain editable leg.
    @Test func aperturePriorityRolesAtAGlance() {
        #expect(role(.shutter, mode: .aperturePriority, boundComponent: .aperture) == .auto)
        #expect(role(.aperture, mode: .aperturePriority, boundComponent: .aperture) == .bound)
        #expect(role(.iso, mode: .aperturePriority, boundComponent: .aperture) == .editable)
    }

    /// Shutter-priority flips it: aperture is AUTO, the bound shutter wears the
    /// ring, ISO stays editable.
    @Test func shutterPriorityRolesFlip() {
        #expect(role(.aperture, mode: .shutterPriority, boundComponent: .shutter) == .auto)
        #expect(role(.shutter, mode: .shutterPriority, boundComponent: .shutter) == .bound)
        #expect(role(.iso, mode: .shutterPriority, boundComponent: .shutter) == .editable)
    }

    /// The ring follows the dial, not the priority leg: binding the dial to ISO
    /// moves the ring there, leaving the (still-editable) priority aperture plain.
    /// Exactly one chip is ever bound.
    @Test func exactlyOneChipIsBoundAndItFollowsTheDial() {
        #expect(role(.iso, mode: .aperturePriority, boundComponent: .iso) == .bound)
        #expect(role(.aperture, mode: .aperturePriority, boundComponent: .iso) == .editable)
        #expect(role(.shutter, mode: .aperturePriority, boundComponent: .iso) == .auto)
    }

    /// While the compensation overlay owns the dial (`boundComponent == nil`) no
    /// chip is bound: the two set legs both read as editable and the solved leg
    /// stays AUTO.
    @Test func noChipIsBoundWhileCompensationOwnsTheDial() {
        #expect(role(.iso, mode: .aperturePriority, boundComponent: nil) == .editable)
        #expect(role(.aperture, mode: .aperturePriority, boundComponent: nil) == .editable)
        #expect(role(.shutter, mode: .aperturePriority, boundComponent: nil) == .auto)
    }
}
