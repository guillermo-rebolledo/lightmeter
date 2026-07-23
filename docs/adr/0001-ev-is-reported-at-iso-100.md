# 1. EV is reported at ISO 100

- **Status:** Accepted
- **Date:** 2026-07-23
- **Context issue:** #91

## Context

The app reports a scene's brightness as an **exposure value (EV)**. EV is only
meaningful relative to a reference sensitivity: the *same light* is EV 12.3 at
ISO 100 and EV 14.3 at ISO 400. A bare "EV 12.3" is therefore incomplete —
it means nothing without the ISO it is quoted at.

The codebase has always quoted EV at ISO 100. It is named `evAtISO100`
throughout the exposure engine and the view-model, and the readout that
originally displayed it was labelled `EV @ ISO 100` for exactly this reason.

Two things have made that convention easy to break by accident:

1. **The label drifted away from the value.** When the meter's hero changed from
   EV to the solved exposure leg, EV moved to a quieter position and, in some
   treatments, lost the `@ ISO 100` qualifier. The convention survived only in
   the identifier name.
2. **Design references omit it.** The Direction 1b handoff labels the value
   simply `EXPOSURE VALUE` while placing an `ISO 400` readout in the same glass
   bar, inches away. Any photographer reading that bar would reasonably conclude
   the EV is quoted at ISO 400. It is not. The handoff's own sample values are
   internally inconsistent in exactly this way.

Direction 1b promotes EV to the largest element on the screen, which raises the
cost of getting this wrong from "a quiet number is ambiguous" to "the headline
is wrong."

We considered reporting EV at the photographer's **current** ISO instead. It
would be internally consistent with an ISO readout sitting beside it, and it
matches a naive first expectation.

## Decision

**EV is always reported at ISO 100, and every surface that displays it says so.**

- The value shown is `evAtISO100` — a property of the *scene*, not of the
  photographer's settings.
- Changing ISO, aperture, shutter, priority mode, or exposure compensation
  **does not change the displayed EV**. Only a change in the light does.
- Any UI presenting EV carries the ISO 100 qualifier in its label, its value, or
  its accessibility text — near enough to the number that it cannot be read as
  applying to some other ISO on screen.

## Consequences

**Good**

- EV means one thing everywhere in the app, and it is the conventional meaning
  photographers and published exposure tables already use.
- A light meter's reading does not move when the light did not. Watching EV jump
  because you changed ISO would undermine the instrument's basic credibility.
- Readings stay comparable across sessions and across settings, which matters for
  the planned reading log.

**Bad / accepted costs**

- The label is wordier than a design reference is likely to draw it. Where a
  layout genuinely cannot hold the full qualifier, it may be shortened, but it
  may not be dropped.
- A beginner shooting at ISO 400 may briefly expect EV to reflect their ISO. This
  is a teaching problem, addressed with the label, not a modelling problem.
- Any surface showing EV and ISO together needs deliberate attention so the two
  do not read as one quoted figure.

## Compliance

This decision is load-bearing for the meter's largest readout. Changing EV to
track the current ISO is a change to what the app *measures*, not a display
tweak, and requires superseding this ADR rather than editing a label.
