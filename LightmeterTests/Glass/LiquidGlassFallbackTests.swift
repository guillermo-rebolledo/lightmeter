import SwiftUI
import Testing
@testable import Lightmeter

/// The standing fallback rule, made enforceable.
///
/// Every Liquid Glass surface ships a complete, intentional pre-iOS-26 fallback —
/// but only iOS 26 runtimes are installed, so until now nothing verified that the
/// fallback branch even runs, let alone draws something. These tests pin the three
/// things that make the rule checkable rather than aspirational:
///
/// 1. **One gate.** No file outside `LiquidGlass.swift` reaches for an iOS 26 API
///    or an availability check of its own, so there is a single decision to force.
/// 2. **The force reaches it.** The debug launch argument turns the gate off, and
///    only in a debug build.
/// 3. **The forced path draws.** Every surface renders on its fallback path, and
///    the surfaces that must be visible on their own are visibly there.
///
/// **Known limitation, accepted:** this proves *iOS 26 running the fallback code
/// path*, not *iOS 17 rendering it*. Material rendering differs subtly across OS
/// versions, so the fallback's true appearance on the deployment target stays
/// unverified — see `docs/design-harness.md`.
@MainActor
struct LiquidGlassFallbackTests {
    // MARK: - The launch argument

    @Test func absentFlagLeavesTheGateAlone() {
        #expect(DesignHarness.forcesGlassFallback(launchArguments: []) == false)
        #expect(
            DesignHarness.forcesGlassFallback(
                launchArguments: ["/path/to/Lightmeter", "-design-harness"]
            ) == false
        )
    }

    /// Forcing the fallback is deliberately *not* behind `-design-harness`: the
    /// fallback is worth seeing over the real camera on a device as well as over a
    /// stand-in scene, and the reference shots come from pairing the two.
    @Test func theForceFlagStandsAloneAndComposesWithTheHarness() {
        #expect(DesignHarness.forcesGlassFallback(launchArguments: ["-force-glass-fallback"]))
        #expect(
            DesignHarness.forcesGlassFallback(
                launchArguments: [
                    "-design-harness", "-harness-scene", "blown-sky", "-force-glass-fallback",
                ]
            )
        )
    }

    /// Nothing is forced unless it was asked for. An unflagged run on an OS with
    /// glass renders glass — which is what makes the force an *opt-in* debug tool
    /// rather than a change to the app everyone else sees.
    @Test func anUnflaggedRunRendersGlassWhereTheOSHasIt() throws {
        try #require(
            DesignHarness.forcesGlassFallback == false,
            "this run was launched with the force flag, so it cannot judge the default"
        )

        if #available(iOS 26, *) {
            #expect(LiquidGlass.isEnabled)
        } else {
            // Below 26 there is no glass to force off; the fallback *is* the app.
            #expect(LiquidGlass.isEnabled == false)
        }
    }

    // MARK: - One gate

    /// The one-gate rule, checked against the sources themselves.
    ///
    /// A test cannot force a fallback that a view decided for itself, so the
    /// invariant worth pinning is structural: iOS 26 APIs and availability checks
    /// live in `LiquidGlass.swift` and nowhere else. Adding a `#available(iOS 26,
    /// *)` to a new surface fails here rather than quietly reintroducing a branch
    /// no launch argument can reach.
    @Test func onlyTheGateFileBranchesOnIOS26() throws {
        try ShippingSources.expectAbsent(
            Self.gateOnlyTokens,
            exceptIn: Self.gatePath,
            reason: "route it through GlassSurface instead"
        )
    }

    /// The tokens that may only appear in the gate file: the iOS 26 glass API
    /// surface, and the availability checks that unlock it.
    ///
    /// Deliberately broad — `glassEffect` unanchored catches `glassEffectID` and
    /// a call written without its leading dot — so prose that merely *names* the
    /// API elsewhere trips this too. That is the intended strictness: a comment
    /// naming `glassEffect` in a view is a comment describing a decision that
    /// view no longer makes.
    private static let gateOnlyTokens = [
        "glassEffect",
        "GlassEffect",
        "#available(iOS 26",
        "#unavailable(iOS 26",
        "@available(iOS 26",
        ".glass)",
        ".glassProminent",
    ]

    /// The gate, by repository-relative path — not by file name, so a second file
    /// called `LiquidGlass.swift` somewhere else cannot exempt itself.
    private static let gatePath = "Lightmeter/Views/Glass/LiquidGlass.swift"

    // MARK: - The forced path draws

    /// What the suite below is walking is `GlassSurface.all`, so a surface
    /// missing from that list is a surface nothing here tests. `kind` is an
    /// exhaustive switch, so a new case cannot compile without appearing in
    /// ``GlassSurface/Kind`` — and this then fails until it is in `all` too.
    @Test func allCoversEverySurface() {
        #expect(Set(GlassSurface.all.map(\.kind)) == Set(GlassSurface.Kind.allCases))
    }

    /// Every surface renders on the forced path. This is the run that no simulator
    /// runtime could otherwise produce: the fallback branch of every glass surface
    /// in the app, executed.
    @Test(arguments: GlassSurface.all)
    func everySurfaceRendersItsForcedFallback(_ surface: GlassSurface) throws {
        _ = try #require(render(surface, isGlassEnabled: false))
    }

    /// The gate is what decides, and it decides for every surface: forcing it off
    /// changes what is drawn. Without this, a surface could ignore the flag
    /// entirely and the rest of the suite would not notice.
    ///
    /// `.group` and `.settingsGear` are exempt only from the *rendering*
    /// comparison, not from the gate: their fallbacks are deliberate
    /// passthroughs, so on the fallback path there is by design nothing to see.
    @Test(arguments: LiquidGlassFallbackTests.surfacesThatMustBeSeen)
    func forcingTheGateOffChangesWhatIsDrawn(_ surface: GlassSurface) throws {
        try #require(
            LiquidGlass.isEnabled,
            "this run is already on the fallback path, so it cannot compare the two"
        )

        let asShipped = try #require(renderThroughTheGate(surface))
        let forced = try #require(render(surface, isGlassEnabled: false))
        let glass = try #require(render(surface, isGlassEnabled: true))

        // The production entry point reads the gate rather than hard-coding a
        // path: unforced, it draws what the glass path draws.
        #expect(asShipped == glass)
        #expect(forced != glass, "\(surface) ignores the gate")
    }

    /// The rule's real content: a fallback that is *complete*, not an empty
    /// `else`. Each of these surfaces is what separates its control from the
    /// preview behind it, so on the fallback path it has to draw something the
    /// bare content does not.
    ///
    /// `.group` and `.settingsGear` are deliberately absent: their fallbacks are
    /// intentional passthroughs (there is no container to join, and the settings
    /// gear has always been a bare tinted icon), which is a design decision rather
    /// than a missing branch.
    @Test(arguments: LiquidGlassFallbackTests.surfacesThatMustBeSeen)
    func aSurfaceThatMustBeSeenIsDrawnOnTheFallbackPath(_ surface: GlassSurface) throws {
        let unstyled = try #require(render(nil, sizedFor: surface))
        let fallback = try #require(render(surface, isGlassEnabled: false))

        #expect(fallback != unstyled, "\(surface) draws nothing on the fallback path")
    }

    /// The surfaces that carry their control's separation from the preview, and
    /// so have to be visible on their own — everything except the two deliberate
    /// passthroughs.
    static let surfacesThatMustBeSeen: [GlassSurface] = GlassSurface.all.filter { surface in
        switch surface.kind {
        case .group, .settingsGear: false
        case .pill, .lock, .chip, .drawer, .panel: true
        }
    }

    /// Renders `surface` through the app's own entry point — the one that reads
    /// ``LiquidGlass/isEnabled`` — rather than through the injected seam.
    private func renderThroughTheGate(_ surface: GlassSurface) -> Data? {
        pixels(AnyView(Self.content(for: surface).glassSurface(surface)))
    }

    /// Renders `surface` over stand-in content, on the path `isGlassEnabled` asks
    /// for, and returns its pixels. `nil` renders the content alone.
    private func render(_ surface: GlassSurface, isGlassEnabled: Bool) -> Data? {
        render(surface, sizedFor: surface, isGlassEnabled: isGlassEnabled)
    }

    private func render(
        _ surface: GlassSurface?,
        sizedFor sized: GlassSurface,
        isGlassEnabled: Bool = false
    ) -> Data? {
        let content = Self.content(for: sized)
        let view = surface.map { surface in
            AnyView(content.glassSurface(surface, isGlassEnabled: isGlassEnabled))
        } ?? content
        return pixels(view)
    }

    /// One fixed-size render, as PNG bytes — the comparable form.
    private func pixels(_ view: AnyView) -> Data? {
        let renderer = ImageRenderer(content: view.frame(width: 140, height: 70))
        renderer.scale = 1
        return renderer.uiImage?.pngData()
    }

    /// What each surface is applied to: its own shape for the two surfaces that
    /// draw rather than back their receiver (the drawer and the floating panel,
    /// which are handed only a frame to fill), a control's label for the rest.
    private static func content(for surface: GlassSurface) -> AnyView {
        switch surface {
        case .drawer(let edge):
            AnyView(edge.drawerShape)
        case .panel:
            AnyView(FloatingPanel.shape)
        default:
            AnyView(Text("f/8").padding(8))
        }
    }
}
