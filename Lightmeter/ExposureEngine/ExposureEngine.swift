import Foundation

// MARK: - ExposureEngine (pure, hardware-free)
//
// Primary test seam. Owns, in later tickets:
//   - camera AE metadata -> scene EV@ISO100 conversion (#3)
//   - exposure-triangle solving for both priority modes (#3, #5)
//   - EV compensation + calibration offset (#8, #9)
//   - snapping to standard photographic scales at 1/3 / 1/2 / full stops (#3, #9)
//   - advisories: handholding / tripod / out-of-range (#7)
//
// No AVFoundation, no SwiftUI — everything here is deterministic and unit-tested.

enum ExposureEngine {}
