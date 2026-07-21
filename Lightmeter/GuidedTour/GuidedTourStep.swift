import Foundation

enum GuidedTourStep: Hashable, CaseIterable {
    case evReadout
    case meteringPattern
    case priorityAndChips
    case arcDial
    case compensation
    case settings

    var title: String {
        switch self {
        case .evReadout:
            "Scene light"
        case .meteringPattern:
            "Metering pattern"
        case .priorityAndChips:
            "Priority and exposure"
        case .arcDial:
            "Set the value"
        case .compensation:
            "Exposure compensation"
        case .settings:
            "Hold and fine-tune"
        }
    }

    var caption: String {
        switch self {
        case .evReadout:
            "Live preview and EV@ISO100 show the light your camera sees."
        case .meteringPattern:
            "Use Average for the frame or Spot, then tap the preview to place the reading."
        case .priorityAndChips:
            "Fix ISO and aperture or shutter; the solved chip follows the light, with advisories when the result needs support."
        case .arcDial:
            "Tap an editable chip, then sweep the arc dial through real exposure stops."
        case .compensation:
            "Bias the solved exposure up or down without changing your fixed settings."
        case .settings:
            "Hold freezes the reading while you transfer it; increments and calibration live in Settings."
        }
    }

    var advanceButtonTitle: String {
        self == .settings ? "Done" : "Next"
    }
}
