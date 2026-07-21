import CoreGraphics
import SwiftUI
import Testing
@testable import Lightmeter

struct SpotlightShapeTests {
    @Test(
        "Spotlight cutout is drivable by animatable data",
        .bug("https://github.com/guillermo-rebolledo/lightmeter/issues/29")
    )
    func animatableDataDrivesCutout() {
        var shape = SpotlightShape(
            targetFrame: CGRect(x: 0, y: 0, width: 10, height: 10),
            cornerRadius: 4
        )
        let target = SpotlightShape(
            targetFrame: CGRect(x: 5, y: 6, width: 20, height: 30),
            cornerRadius: 8
        )

        shape.animatableData = target.animatableData

        #expect(shape.targetFrame == target.targetFrame)
        #expect(shape.cornerRadius == target.cornerRadius)
    }

    @Test(
        "Spotlight interpolates halfway between two step targets",
        .bug("https://github.com/guillermo-rebolledo/lightmeter/issues/29")
    )
    func interpolatesBetweenTargets() {
        let start = SpotlightShape(
            targetFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
            cornerRadius: 10
        )
        let end = SpotlightShape(
            targetFrame: CGRect(x: 100, y: 200, width: 300, height: 500),
            cornerRadius: 30
        )

        var midpoint = start
        var data = start.animatableData
        data.scale(by: 0.5)
        var half = end.animatableData
        half.scale(by: 0.5)
        data += half
        midpoint.animatableData = data

        #expect(midpoint.targetFrame == CGRect(x: 50, y: 100, width: 200, height: 300))
        #expect(midpoint.cornerRadius == 20)
    }
}
