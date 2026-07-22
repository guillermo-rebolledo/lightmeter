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
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 52, weight: .thin))
                .foregroundStyle(.white)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if showsSettingsLink,
               let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: settingsURL)
                    .font(.body.weight(.semibold))
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 40)
        // Cap the copy to a comfortable measure and center it, so the message
        // stays legible in landscape instead of stretching to the full width.
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
