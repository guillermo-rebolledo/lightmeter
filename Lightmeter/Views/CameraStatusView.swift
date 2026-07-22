import SwiftUI

/// Explains why camera metering cannot start, with a Settings route only when
/// authorization can resolve the problem.
struct CameraStatusView: View {
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let showsSettingsLink: Bool

    init(status: MeterViewModel.Status) {
        switch status {
        case .denied:
            title = "Camera access needed"
            message = "Lightmeter reads the light from your camera to meter exposure. Enable camera access in Settings to start metering."
            showsSettingsLink = true
        case .unavailable:
            title = "Camera unavailable"
            message = "Lightmeter couldn’t start camera capture on this device."
            showsSettingsLink = false
        case .idle, .metering:
            preconditionFailure("CameraStatusView requires a camera failure status")
        }
    }

    var body: some View {
        // ContentUnavailableView handles centering, width, and size-class
        // adaptation, and exposes the label + description to VoiceOver while
        // keeping the icon decorative.
        ContentUnavailableView {
            Label(title, systemImage: "video.slash")
        } description: {
            Text(message)
        } actions: {
            if showsSettingsLink,
               let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: settingsURL)
                    .font(.body.weight(.semibold))
            }
        }
        // The status screen always sits on the black camera surface, so pin the
        // system colors to dark to keep the label + description legible even
        // when the device is in light mode.
        .environment(\.colorScheme, .dark)
    }
}
