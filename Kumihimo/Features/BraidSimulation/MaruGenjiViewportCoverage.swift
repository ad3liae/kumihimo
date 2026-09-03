import Foundation
import simd

struct MaruGenjiViewportCoverage: Equatable, Sendable {
    let tileCount: Int
    let coveredLength: Float
    let requiredLength: Float
}

enum MaruGenjiViewportCoverageCalculator {
    static let maximumTileCount = 31
    static let offscreenMarginInScreenWidths: Float = 1

    static func calculate(
        viewportSize: SIMD2<Float>,
        cameraDistance: Float,
        verticalFieldOfView: Float,
        minimumScale: Float,
        tileLength: Float
    ) -> MaruGenjiViewportCoverage? {
        guard
            viewportSize.x.isFinite,
            viewportSize.y.isFinite,
            viewportSize.x > 0,
            viewportSize.y > 0,
            cameraDistance.isFinite,
            cameraDistance > 0,
            verticalFieldOfView.isFinite,
            verticalFieldOfView > 0,
            verticalFieldOfView < .pi,
            minimumScale.isFinite,
            minimumScale > 0,
            tileLength.isFinite,
            tileLength > 0
        else {
            return nil
        }

        let aspectRatio = viewportSize.x / viewportSize.y
        let visibleWidth = 2 * cameraDistance * tan(verticalFieldOfView / 2) * aspectRatio
        let marginMultiplier = 1 + 2 * offscreenMarginInScreenWidths
        let requiredLength = visibleWidth * marginMultiplier / minimumScale
        guard visibleWidth.isFinite, requiredLength.isFinite else { return nil }

        var tileCount = max(1, Int(ceil(requiredLength / tileLength)))
        if tileCount.isMultiple(of: 2) {
            tileCount += 1
        }
        tileCount = min(tileCount, maximumTileCount)

        return MaruGenjiViewportCoverage(
            tileCount: tileCount,
            coveredLength: Float(tileCount) * tileLength,
            requiredLength: requiredLength
        )
    }

    static func tileOffsets(tileCount: Int, tileLength: Float) -> [Float]? {
        guard
            tileCount > 0,
            tileCount <= maximumTileCount,
            !tileCount.isMultiple(of: 2),
            tileLength.isFinite,
            tileLength > 0
        else {
            return nil
        }

        let halfCount = tileCount / 2
        return (-halfCount...halfCount).map { Float($0) * tileLength }
    }
}
