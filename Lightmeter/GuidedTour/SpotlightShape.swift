import SwiftUI

struct SpotlightShape: Shape {
    var targetFrame: CGRect
    var cornerRadius: Double

    /// Interpolating the cutout's frame and corner radius lets the spotlight
    /// slide and resize between tour steps instead of snapping to each target.
    var animatableData: AnimatablePair<CGRect.AnimatableData, Double> {
        get { AnimatablePair(targetFrame.animatableData, cornerRadius) }
        set {
            targetFrame.animatableData = newValue.first
            cornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: targetFrame,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return path
    }
}
