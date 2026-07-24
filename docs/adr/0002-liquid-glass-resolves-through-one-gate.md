# 2. Liquid Glass resolves through one gate

- **Status:** Accepted
- **Date:** 2026-07-23
- **Context issue:** #94 (part of #91)

## Context

The app's deployment target is iOS 17. Liquid Glass arrives in iOS 26. The
standing project rule is therefore that the `.ultraThinMaterial` + accent-tint
styling is the **primary** design and glass is an enhancement layered on top:
every glass surface ships a complete, intentional fallback, never an empty or
broken `else`.

That rule was unenforceable in practice. The availability decision was scattered
— one `if #available(iOS 26, *)` per surface, six of them, plus one deciding a
scrim opacity — and every one of them resolved to "glass" on every machine the
project is developed and tested on. Only iOS 26 Simulator runtimes are installed
and there is no iOS 17/18 device available, so the fallback branches were never
executed by anybody: not in the Simulator, not on a device, not in a test.

A fallback nobody has seen is a fallback nobody knows is complete.

## Decision

**Exactly one gate decides whether the app renders Liquid Glass, and a debug
launch argument can force it off.**

- `LiquidGlass.isEnabled` is the only question any code asks. It is `false`
  below iOS 26, and `false` on iOS 26 when the fallback has been forced.
- Every glass surface is described as data — a `GlassSurface` case — and
  rendered by a single `glassSurface(_:)` helper that asks the gate once. The
  `#available(iOS 26, *)` inside that helper is the compiler's ceremony (it is
  what unlocks the API); the *decision* belongs to the gate.
- No file outside `Lightmeter/Views/Glass/LiquidGlass.swift` mentions iOS 26 or
  the glass API. A test scans the shipping sources to keep it so, because a
  surface that decides for itself is a surface the force cannot reach.
- `-force-glass-fallback` (DEBUG only) turns the gate off, rendering every
  surface's fallback on an iOS 26 Simulator. Release builds compile a constant
  `false` in its place.

## Consequences

**Good**

- The fallback rule is checkable: one flag renders the entire pre-iOS-26 design,
  and a test suite exercises every surface on that path rather than assuming it.
- Adding a glass surface is a single decision in a single file, with both paths
  written side by side — the shape that made the fallbacks complete in the first
  place, now structurally enforced.
- Design review can compare the two paths on today's screen (see
  `docs/design-harness.md`) instead of reasoning about the fallback in the
  abstract.

**Bad / accepted costs**

- **This proves iOS 26 running the fallback code path, not iOS 17 rendering it.**
  Materials are rendered by the OS, and blur radius, vibrancy, and contrast
  differ subtly between releases, so the fallback's true appearance on the
  deployment target stays unverified until it is run on an iOS 17/18 device or
  runtime. Documented, not solved. What the forced path *does* catch is an empty
  branch, a surface that vanishes into the scene, a lost hit region or selection
  ring, and text that stops being legible without the glass.
- Surfaces are enumerated rather than expressed inline at their call sites, which
  is one level of indirection between a control and its background.
- The source-scanning test couples the suite to the repository layout: it reads
  the checkout the tests were compiled from.

## Compliance

The one-gate rule is load-bearing for the fallback rule, not a stylistic
preference — a surface that branches on `#available` itself is invisible to the
force and silently unverified. Re-scattering the availability checks requires
superseding this ADR, not deleting a test.
