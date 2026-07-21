import Foundation

// MARK: - Camera / LightSource (thin, hand-validated edge)
//
// The `LightSource` protocol abstracts the source of exposure metadata so the
// view-model can be driven by a fake in tests. The production implementation
// (arriving in ticket #3) wraps AVFoundation: it configures the capture session,
// runs auto-exposure, streams ISO / exposureDuration / aperture, and sets the AE
// region of interest for spot metering (#6).
//
// This layer is intentionally NOT unit-tested — mocking AVFoundation buys little
// and costs a lot; it is validated by hand on-device.

// Protocol + AVFoundation adapter land in ticket #3.
enum CameraModule {}
