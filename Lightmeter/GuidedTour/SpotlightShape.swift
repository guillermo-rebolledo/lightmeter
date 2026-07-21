import SwiftUI

struct SpotlightShape: Shape {
    let targetFrame: CGRect
    let cornerRadius: Double

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
