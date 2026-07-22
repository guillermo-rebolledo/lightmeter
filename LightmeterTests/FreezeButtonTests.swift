import Testing
@testable import Lightmeter

/// `FreezeButton` gained an `isCompact` flag that swaps its full labeled pill
/// for a small icon-only button (portrait's decluttered card). These tests
/// pin the stored configuration, that the `onToggle` closure it captures is
/// the one actually invoked, and that `body` stays crash-free across every
/// `isFrozen` × `canFreeze` × `isCompact` combination.
@MainActor
struct FreezeButtonTests {
    // MARK: - isCompact defaulting

    @Test func isCompactDefaultsToFalseWhenOmitted() {
        let view = FreezeButton(isFrozen: false, canFreeze: true, onToggle: {})

        #expect(Mirror.storedValue("isCompact", on: view) == false)
    }

    @Test(arguments: [true, false])
    func isCompactStoresTheExplicitValue(_ isCompact: Bool) {
        let view = FreezeButton(isFrozen: false, canFreeze: true, isCompact: isCompact, onToggle: {})

        #expect(Mirror.storedValue("isCompact", on: view) == isCompact)
    }

    // MARK: - isFrozen / canFreeze storage

    @Test(
        arguments: [
            (isFrozen: true, canFreeze: true),
            (isFrozen: true, canFreeze: false),
            (isFrozen: false, canFreeze: true),
            (isFrozen: false, canFreeze: false),
        ]
    )
    func isFrozenAndCanFreezeAreStoredVerbatim(_ combo: (isFrozen: Bool, canFreeze: Bool)) {
        let view = FreezeButton(isFrozen: combo.isFrozen, canFreeze: combo.canFreeze, onToggle: {})

        #expect(Mirror.storedValue("isFrozen", on: view) == combo.isFrozen)
        #expect(Mirror.storedValue("canFreeze", on: view) == combo.canFreeze)
    }

    // MARK: - onToggle wiring

    @Test func onToggleClosureStoredOnTheButtonIsTheOneProvided() {
        var toggled = false
        let view = FreezeButton(isFrozen: false, canFreeze: true, onToggle: { toggled = true })

        let stored: (() -> Void)? = Mirror.storedValue("onToggle", on: view)
        stored?()

        #expect(toggled)
    }

    // MARK: - body stays crash-free

    @Test(arguments: [
        (isFrozen: true, canFreeze: true, isCompact: true),
        (isFrozen: true, canFreeze: true, isCompact: false),
        (isFrozen: true, canFreeze: false, isCompact: true),
        (isFrozen: true, canFreeze: false, isCompact: false),
        (isFrozen: false, canFreeze: true, isCompact: true),
        (isFrozen: false, canFreeze: true, isCompact: false),
        (isFrozen: false, canFreeze: false, isCompact: true),
        (isFrozen: false, canFreeze: false, isCompact: false),
    ])
    func bodyRendersForEveryStateCombination(
        _ example: (isFrozen: Bool, canFreeze: Bool, isCompact: Bool)
    ) {
        let view = FreezeButton(
            isFrozen: example.isFrozen,
            canFreeze: example.canFreeze,
            isCompact: example.isCompact,
            onToggle: {}
        )
        _ = view.body
    }
}