import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: MeterPreferences

    var body: some View {
        Form {
            Section {
                Picker("Stop increment", selection: $preferences.increment) {
                    ForEach(StopIncrement.allCases) { increment in
                        Text(increment.label)
                    }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Controls the spacing used to snap ISO, aperture, and shutter values.")
            }

            Section {
                Stepper(
                    value: $preferences.calibrationOffset,
                    in: -3...3,
                    step: 1.0 / 3
                ) {
                    LabeledContent("Offset", value: calibrationLabel)
                }
            } header: {
                Text("Calibration")
            } footer: {
                Text("Use a positive offset when this meter consistently reads lower than a trusted meter or camera.")
            }
        }
        .navigationTitle("Settings")
    }

    private var calibrationLabel: String {
        let thirds = Int((preferences.calibrationOffset * 3).rounded())
        guard thirds != 0 else { return "0 EV" }

        let sign = thirds > 0 ? "+" : "−"
        let magnitude = abs(thirds)
        let whole = magnitude / 3
        let remainder = magnitude % 3
        let value = switch (whole, remainder) {
        case (0, 1): "1/3"
        case (0, 2): "2/3"
        case (_, 0): "\(whole)"
        case (_, 1): "\(whole) 1/3"
        default: "\(whole) 2/3"
        }
        return "\(sign)\(value) EV"
    }
}

#Preview {
    NavigationStack {
        SettingsView(preferences: MeterPreferences())
    }
}
