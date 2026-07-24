# Direction 1b — integrate and verify (#100)

The honest account of what was checked for Direction 1b before it was handed
over, and what could not be checked here and so falls to a device. Part of #91;
this is the ticket that closes the variant.

There is **no CI** in this repo. Nothing runs the tests but us, so "tests green"
below is a gate that was actually run, not an assumption. Verified on
**2026-07-23** against branch `polish`, built with Xcode for the iOS 26.5
Simulator.

## What the build did

- `xcodebuild … build` (Debug) — **succeeded**.
- `xcodebuild … test` — **272 tests in 29 suites, all passed.** Includes the
  layout-invariance suites that pin the no-shift requirements (the advisory slot,
  the dial panel height across bindings and compensation, the bar across freeze),
  the compensation-geometry and graduation-rule pure-logic tests, dial re-binding,
  segment independence, and the EV readout / VoiceOver-text tests.
- `xcodebuild … -configuration Release build` — **succeeded**, and the harness is
  provably inert in it (see [release build](#no-harness-in-a-release-build)).

Run the content size back to `large` before testing: the layout tests measure
real `UIHostingController` fitting sizes, so a Simulator left at an accessibility
size fails a layout-invariance test by a fraction of a point with nothing wrong
in the code (documented in `docs/design-harness.md`).

## The instrument is Direction 1b, end to end

Portrait is the instrument face with no leftover chrome from the previous
design: a floating **EV bar** (`EXPOSURE VALUE @ ISO 100` over `EV 15.0`, the
solved leg and `ISO 100` at its trailing end, freeze padlock and settings gear at
the two ends), a **dial panel** naming its bound leg over a graduated ruler under
a fixed needle, a real draggable **exposure-compensation slider**, a constant
**advisory footer**, and the **segmented row** carrying priority and metering
pattern as two independent pairs. The **reticle appears only when spot metering**.
The status-pill layer is gone in portrait.

| State | Shot |
| --- | --- |
| Aperture-priority · average · live | [01](design-harness/direction-1b/01-aperture-average.png) |
| Aperture-priority · **spot** (reticle) | [02](design-harness/direction-1b/02-aperture-spot.png) |
| **Shutter-priority** · average | [03](design-harness/direction-1b/03-shutter-average.png) |
| Shutter-priority · spot | [04](design-harness/direction-1b/04-shutter-spot.png) |
| **Frozen** (padlock closed) | [05](design-harness/direction-1b/05-frozen.png) |
| **Pending** (before first reading) | [06](design-harness/direction-1b/06-pending.png) |
| **Compensated** +1.0 EV | [07](design-harness/direction-1b/07-compensated.png) |
| No advisory (footer reserved, empty) | [08](design-harness/direction-1b/08-no-advisory.png) |
| Handheld-risk advisory | [09](design-harness/direction-1b/09-handheld.png) |
| Tripod advisory | [10](design-harness/direction-1b/10-tripod.png) |
| Out-of-range advisory | [11](design-harness/direction-1b/11-out-of-range.png) |

All four priority/pattern combinations are covered by shots 01–04, and each
highlights exactly one segment per pair — two highlights at once, never four
exclusive cells.

## Both glass paths

The fallback was forced on the iOS 26 Simulator with `-force-glass-fallback`.
Panels render as solid, intentional surfaces rather than an empty `else`; text
stays legible without the glass, and the segments keep their selection rings.

| Scene | Glass | Fallback |
| --- | --- | --- |
| blown-sky | [01](design-harness/direction-1b/01-aperture-average.png) | [12](design-harness/direction-1b/12-fallback-blown-sky.png) |
| dim-interior | (10, tripod) | [13](design-harness/direction-1b/13-fallback-dim-interior.png) |
| mixed-contrast · spot | [02](design-harness/direction-1b/02-aperture-spot.png) | [14](design-harness/direction-1b/14-fallback-mixed.png) |

## Text sizes

Set from outside the app, so it composes with any state.

- Default (`large`) — the shots above.
- [`accessibility3`](design-harness/direction-1b/15-a11y3.png) — the EV bar's
  header reflows onto multiple lines rather than crushing the headline; the
  instrument stays a coherent layout.
- [`accessibility5`](design-harness/direction-1b/16-a11y5.png) — **pixel-identical
  to `accessibility3`**, confirming `AppTypography.maximumDynamicTypeSize` holds
  the small tiers at the ceiling as designed.

At the accessibility tiers the segmented row truncates its labels
(`APERT…` / `SHUTT…`) rather than breaking the row — acceptable degradation, worth
an eye on device.

## Narrowest and widest devices

- **Narrowest: iPhone 17e at 390pt** — [17](design-harness/direction-1b/17-narrowest-17e.png).
  This is *narrower* than the 393pt the ticket anticipated. Layout holds; note the
  ISO pill in the bar truncates to `ISO…` at this width — legible-but-tight, flagged
  for the device check. (The 375pt SE-class case is still unverified — see the gaps.)
- **Widest: iPhone 17 Pro Max at 440pt** — [18](design-harness/direction-1b/18-widest-promax.png).

## Landscape and rotation

Landscape is **today's design**, working — the docked drawer with the solved-leg
hero and the status pills — now inheriting the **brass accent** and the **restyled
ruler dial**. The status pills are conditional on orientation and appear only
here. Shot: [19](design-harness/direction-1b/19-landscape.png).

Rotating portrait → landscape → portrait left neither layout broken; the return
to portrait is clean ([20](design-harness/direction-1b/20-back-to-portrait.png)).
(Programmatic rotation cycling in the Simulator was flaky under automation —
`simctl io screenshot` captures the device-native buffer, so orientation reads
ambiguously from the tooling; a hands-on rotate-both-ways is on the device
checklist below to close it fully.)

## No harness in a Release build

The Release build was launched with the full harness arguments
(`-design-harness -harness-scene blown-sky`). It **ignored them** and went
straight to the real camera — the system camera-permission dialog appeared and no
stand-in scene was drawn ([21](design-harness/direction-1b/21-release-harness-inert.png)).

At the source level: every file under `Lightmeter/DesignHarness/` is `#if DEBUG`
at file scope, and the two production concessions are gated with explicit
`#else` fallbacks — `injectedLightSource` compiles to `nil` (the real camera) and
`LiquidGlass.isForcedOff` compiles to the constant `false`. There is no reachable
harness affordance in Release.

## Reduce Motion

`@Environment(\.accessibilityReduceMotion)` is honoured across all twelve
Direction-1b views (32 guards), each nil-ing its animation when set — e.g. the EV
bar's needle transition becomes `.animation(nil)`. Launched with Reduce Motion on,
the screen renders correctly with no layout change
([22](design-harness/direction-1b/22-reduce-motion.png)). The remaining
"is anything *still* animating mid-gesture" question is on the device checklist.

## VoiceOver (structure verified; interactive sweep on device)

The accessibility tree is wired to the requirement:

- **EV is read first**, in visual order: the bar exposes the EV headline, then the
  solved leg, then ISO as separate labelled elements.
- **ISO is its own element with a hint** and takes `.isSelected` when the dial is
  bound to it — the only non-sighted route to a required input.
- **The dial and the compensation slider are adjustable** — both expose
  `.accessibilityAdjustableAction` (a thin track is not draggable under VoiceOver);
  compensation steps a third per increment.
- **Segments report selection per pair** — each carries its label and
  `.isSelected`, so mode and metering pattern read as two independent choices.
- **Advisories are announced** — labelled `Exposure warning: …`.

These are also pinned by the readout and control test suites. A genuine
end-to-end VoiceOver *sweep* — turning it on and swiping through — is a device
task and is on the checklist.

---

## Manual device checklist (what the Simulator cannot answer)

The Simulator has no camera, one material-rendering OS version, no haptics, and
no thumb. These must be checked on a real iPhone running iOS 26, over a genuinely
bright real scene:

- [ ] **Gold-on-glass contrast over a blown-out real scene.** Meter a bright sky
      or a white wall in sun. Is `EV`, the small uppercase labels, the tick
      numbers, and the gold solved leg all readable on the floating bar and panel?
      The drawn stand-in scenes approximate this but are not a real HDR capture.
- [ ] **The dial under a thumb.** Does the ruler track your finger one-to-one, snap
      onto real stops, and spring as it settles after a flick? Does it click once
      per stop crossed on a fast sweep?
- [ ] **The compensation slider under a thumb.** Is the thin track comfortably
      grabbable (the hit area is padded)? Does sensitivity ease off as you move
      your finger away from the track, so you can land an exact third?
- [ ] **Haptics.** One detent per stop on the dial; one per third on compensation;
      the settle. Do they match, and do they feel mechanical rather than buzzy?
- [ ] **A real VoiceOver sweep.** Turn VoiceOver on. Confirm EV is reached first,
      ISO is reachable with its hint, the dial and compensation slider adjust with
      swipe-up/down, each segment announces its selection, and advisories are
      spoken.
- [ ] **Rotate both ways by hand.** Portrait → landscape → portrait and back the
      other way; confirm neither layout breaks (closes the automation ambiguity above).
- [ ] **The narrowest real phone you have.** Especially the ISO pill truncation at
      ≤390pt, and the 375pt SE case which no installed Simulator can show.

## Accepted verification gaps

These are recorded so a future reader does not mistake this pass for coverage it
does not have:

1. **The pre-iOS-26 fallback is only ever seen as iOS 26 running the fallback
   *code path*, never as iOS 17/18 *rendering* it.** Only iOS 26.3/26.5 runtimes
   are installed and no iOS 17/18 device is to hand. `.ultraThinMaterial` and the
   material stack are drawn by the OS and differ between releases, so the
   fallback's true appearance on its actual deployment target is **unverified**.
   Closing it needs an old runtime (~7GB) or a device; neither is in scope.
2. **The narrowest testable width was 390pt** (iPhone 17e) — narrower than the
   393pt anticipated, but the **375pt SE-class case remains unverified** because no
   SE-class Simulator is installed.

## Recorded departure: the floating panel scrim is denser than the handoff

The floating panel (bar and dial panel) does **not** use the handoff's more
translucent panel value. It **borrows the docked drawer's legibility scrim** —
`0.28` opacity on the glass path, `0.32` on the fallback — composited *in front
of* the glass, because a scrim tinted under Liquid Glass is overpowered exactly
where the text sits. That is denser than a faithful-to-handoff rendering would
be, and it is deliberate: the bar and panel float with bright scene on all four
sides where the drawer has only one, and gold-on-glass is lower contrast than the
white the handoff was drawn against.

At `0.28`/`0.32` the readouts held contrast over the drawn stand-in scenes in
every shot above. Whether they hold over a genuinely blown-out real scene — and
so whether the scrim must go denser still — is the first item on the device
checklist. The value lives in one place (`DrawerSurface.glassScrimOpacity` /
`fallbackScrimOpacity` in `LiquidGlass.swift`), so tightening it is a
one-line change if the device says so.
