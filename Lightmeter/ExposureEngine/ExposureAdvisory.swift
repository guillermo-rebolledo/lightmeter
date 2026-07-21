/// A generic safety warning derived from the current exposure solve.
///
/// V1 intentionally has no camera or lens profile, so shutter guidance uses
/// conservative handheld thresholds and range warnings use the app's standard
/// photographic scales.
enum ExposureAdvisory: Equatable, Hashable, Sendable {
    /// The solved shutter is slower than 1/60 s but faster than 1/15 s.
    case handheldRisk
    /// The solved shutter is 1/15 s or slower.
    case tripodRecommended
    /// The unsnapped solved value falls beyond the corresponding standard scale.
    case outsideTypicalRange(ExposureComponent)
}
