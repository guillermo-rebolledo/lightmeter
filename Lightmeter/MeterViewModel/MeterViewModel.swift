import Foundation

// MARK: - MeterViewModel (state layer between LightSource and the UI)
//
// Second test seam. Driven by an injected `LightSource` so its behavior is tested
// with a fake — no camera required. Owns, in later tickets:
//   - latest reading + derived exposure triangle (#3)
//   - active priority mode and which chip the dial is bound to (#4, #5)
//   - metering pattern + spot location (#6)
//   - EV compensation (#8)
//   - freeze/hold state and surfaced advisories (#7)
//
// The concrete AVFoundation `LightSource` lives in Camera/ and is the thin,
// hand-validated edge that is deliberately not unit-tested.

// Placeholder namespace; the observable model type arrives in ticket #3.
enum MeterViewModelModule {}
