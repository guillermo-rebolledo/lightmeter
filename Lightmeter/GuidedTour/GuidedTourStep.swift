import Foundation

enum GuidedTourStep: Hashable, CaseIterable {
    case welcome
    case evReadout
    case meteringPattern
    case priorityAndChips
    case dial
    case compensation
    case settings

    /// Whether the step spotlights a real control. The welcome step has no
    /// anchor, so the overlay renders it as a centered intro card instead.
    var hasSpotlight: Bool {
        self != .welcome
    }

    var title: String {
        switch self {
        case .welcome:
            "Welcome"
        case .evReadout:
            "Scene light"
        case .meteringPattern:
            "Metering pattern"
        case .priorityAndChips:
            "Priority and exposure"
        case .dial:
            "Set the value"
        case .compensation:
            "Exposure compensation"
        case .settings:
            "Hold and fine-tune"
        }
    }

    var caption: String {
        switch self {
        case .welcome:
            """
            A light meter tells you the camera settings for a good exposure. \
            The loop is simple: point it at your scene, read the numbers, then \
            lock in the settings you want.

            It reads light through your camera, so treat it as a reliable \
            starting point — a dedicated meter can be more precise in tricky \
            light, and you can fine-tune accuracy in Settings.
            """
        case .evReadout:
            """
            EV (exposure value) is a single number for how bright the scene is — \
            higher means brighter. The live preview and the EV@ISO100 reading \
            show the light your camera sees right now (ISO is how sensitive the \
            sensor is; here it's fixed at 100 so readings compare cleanly).
            """
        case .meteringPattern:
            """
            The metering pattern decides which part of the frame the reading \
            comes from. Use Average for the whole frame, or switch to Spot and \
            tap the preview to read one point — handy for a backlit face or a \
            bright sky.
            """
        case .priorityAndChips:
            """
            Priority: pick which setting you control. Aperture is the lens \
            opening (the f-number) that also sets how much is in focus; shutter \
            is how long the sensor is exposed. Choose Aperture and you set the \
            f-number while the app works out the shutter speed for you (or the \
            reverse). The solved chip follows the light, with advisories when \
            the result needs support.
            """
        case .dial:
            """
            Tap an editable chip, then sweep the ruler dial to change its value \
            in real exposure stops — one stop halves or doubles the light. The \
            solved setting keeps pace so the exposure stays balanced.
            """
        case .compensation:
            """
            Exposure compensation nudges the whole exposure brighter or darker \
            without changing your fixed settings. Reach for it when you want a \
            scene lighter or darker than the meter's neutral reading — think \
            snow or a spotlit stage.
            """
        case .settings:
            """
            Hold freezes the current reading so it won't drift while you dial \
            the numbers into your camera. Exposure increments and calibration \
            for fine-tuning accuracy live in Settings.
            """
        }
    }

    var advanceButtonTitle: String {
        self == .settings ? "Done" : "Next"
    }
}
