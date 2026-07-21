import CoreGraphics

/// The photographer-controlled meter setup preserved across temporary UI flows.
struct MeterViewModelState: Equatable {
    let isFrozen: Bool
    let mode: PriorityMode
    let iso: Double
    let aperture: Double
    let shutter: Double
    let compensation: Double
    let dialTarget: DialTarget?
    let pattern: MeteringPattern
    let spot: CGPoint?
}
