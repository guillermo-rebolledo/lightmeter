import Foundation

enum GuidedTourStep: Hashable {
    case evReadout

    var title: String {
        switch self {
        case .evReadout:
            "Scene light"
        }
    }

    var caption: String {
        switch self {
        case .evReadout:
            "This is the scene’s exposure value normalized to ISO 100."
        }
    }
}
