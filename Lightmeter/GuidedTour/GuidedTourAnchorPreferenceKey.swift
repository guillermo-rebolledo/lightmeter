import SwiftUI

struct GuidedTourAnchorPreferenceKey: PreferenceKey {
    static let defaultValue: [GuidedTourStep: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [GuidedTourStep: Anchor<CGRect>],
        nextValue: () -> [GuidedTourStep: Anchor<CGRect>]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
