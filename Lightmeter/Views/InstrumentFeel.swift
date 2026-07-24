import SwiftUI
import UIKit

/// The shared physical feel of the instrument's two draggable controls — the
/// ruler dial and the compensation track. Both settle the same way and click the
/// same way *by design*: they are meant to read as one instrument, so the values
/// that decide "like something with mass" and "one detent per stop crossed" live
/// here once rather than being retuned in two files.
enum InstrumentFeel {
    /// How a flicked control comes to rest: just enough bounce to feel like mass,
    /// short enough that the value under the needle (or knob) is never in doubt. A
    /// released dial and a released compensation knob arrive identically because
    /// they arrive on this spring.
    static let settle = Animation.spring(response: 0.32, dampingFraction: 0.72)
}

extension UISelectionFeedbackGenerator {
    /// Fires one selection tick per detent actually crossed, then re-primes for the
    /// next crossing — so a fast flick over several stops feels like several
    /// detents, not one. Driven imperatively (rather than SwiftUI's edge-triggered
    /// `.sensoryFeedback`) precisely so the count can be more than one, and shared
    /// so the dial and the compensation track click the same. A zero or negative
    /// count is a no-op that still re-primes.
    func clickDetents(crossing count: Int) {
        for _ in 0..<max(count, 0) {
            selectionChanged()
        }
        prepare()
    }
}
