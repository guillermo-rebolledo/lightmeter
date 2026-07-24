# 3. The accent and the numeric face are tokens, and only tokens

- **Status:** Accepted
- **Date:** 2026-07-23
- **Context issue:** #95 (part of #91)

## Context

The design handoff gives the app a visual voice: a muted brass gold in place of
system yellow, and a monospaced numeric face in place of the rounded one. Both
are app-wide — the meter, Settings, the launcher control, the spot reticle — and
both land before any layout work, because both are independently visible and
neither depends on where anything sits.

Two things made that risky to apply by hand.

The accent already had a token, `Color.appAccent`, introduced by #76 — but it
resolved to `Color.yellow` with a comment saying the production value would be
matched later, and two asset-catalog `AccentColor` entries carried yellow of
their own. "One token" was a convention, not a fact: nothing stopped a surface
from naming a colour, and nothing noticed that the catalogs had drifted.

The numeric face had no token at all. Each readout named its own font, and
several reached for `.monospacedDigit()` on a rounded face. That is a half
measure: it widens the digits and leaves everything else proportional, so the
slash in "1/125" and the `"` in `30"` still shuffle as a live value changes.

The handoff also specified a 9pt floor for its uppercase tracked captions, and
said nothing about what happens at the accessibility text sizes.

## Decision

**One token decides the accent, one decides the numeric face, and reading the
sources back is what keeps that true.**

- `Color.appAccent` is the sole source of the tint — `#E7B85C`. Both asset
  catalogs' `AccentColor` (which the *OS* draws with: the app icon, system
  chrome) mirror it, and a test parses them out of the checkout and compares.
  `AppAccent.swift` is compiled into the widget extension as well as the app, so
  the launcher control reads the token rather than a second catalog.
- `AppTypography` owns the numeric face. Numerals are *declared* through it —
  `numeral(fixedSize:)` for the large fixed tiers, `numeral(_:)` for the small
  relative ones — never assembled at a call site. The face is `.monospaced`, not
  a proportional face with the digits patched.
- Dynamic Type is split by tier. Large numerals are fixed and scale to fit; they
  already exceed any Dynamic Type size, so growing them buys no legibility. Small
  tiers are relative and hold at `accessibility3`, declared **once** on the meter
  screen's root — which is what makes landscape inherit the ceiling instead of
  implementing it.
- The label floor is 11pt, raised from the handoff's 9pt. 9pt tracked gold on
  glass, over a live scene, is not readable; the designer was working in a frame
  where 9px looked like about 11pt.
- `DesignTokensTests` scans the shipping sources and fails on a second accent, a
  surviving rounded face, a `.monospacedDigit()` patch, or a point size below the
  floor. It is the second rule enforced that way, so the sweep itself moved into
  a shared `ShippingSources` helper that ADR-0002's one-gate test now reads too —
  a third shipping target is one edit, not two.

## Consequences

**Good**

- Re-theming is the one-line change the token always claimed to be, and the
  claim is now checked rather than asserted.
- The catalogs cannot drift silently. They are data, so nothing about them
  *derives* from the token; the test is the only thing that could have caught it,
  and it caught prose naming the old accent on the first run.
- The Dynamic Type split lives in one modifier, so a new meter control inherits
  the ceiling by being on the screen.

**Bad / accepted costs**

- The source scan is deliberately broad: it matches `.yellow` in a *comment* as
  well as in code. That is the intended strictness — prose naming the old accent
  is prose describing a decision the file no longer makes — but it does mean a
  design test can fail on a comment. It is *not* extended to orange (#76's
  superseded accent): a blocklist is the wrong instrument for a colour a warning
  might legitimately want, and the catalog-mirror test carries the single-source
  guarantee anyway.
- Like ADR-0002's sweep, it couples the suite to the repository layout: it reads
  the checkout the tests were compiled from.
- The catalogs still exist as a second *place*, even though they are no longer a
  second *source*. Xcode requires a global accent asset per target; the mirror is
  the price.
- Monospaced numerals are wider than the proportional ones they replace. Every
  numeric readout is paired with scale-to-fit rather than given more room, which
  is the right answer for a HUD but does mean values shrink earlier than before.

## Compliance

The tokens are load-bearing for the handoff's voice being *app-wide*, not a
stylistic preference. A surface that names its own colour or font is a surface
the next re-theme will miss, so adding one requires superseding this ADR rather
than exempting a file from the sweep.
