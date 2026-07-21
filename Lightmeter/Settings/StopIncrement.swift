import Foundation

/// The spacing between dial-able photographic values.
enum StopIncrement: String, CaseIterable, Identifiable, Sendable {
    case third
    case half
    case full

    var id: Self { self }

    var label: String {
        switch self {
        case .third: "1/3"
        case .half: "1/2"
        case .full: "Full"
        }
    }
}
