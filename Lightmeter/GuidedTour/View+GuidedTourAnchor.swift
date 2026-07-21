import SwiftUI

extension View {
    func guidedTourAnchor(_ step: GuidedTourStep) -> some View {
        anchorPreference(
            key: GuidedTourAnchorPreferenceKey.self,
            value: .bounds,
            transform: { [step: $0] }
        )
    }
}
