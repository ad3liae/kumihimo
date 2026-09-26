import simd
import Testing
@testable import Kumihimo

struct ThreadColorRenderingTests {
    @Test func everyCatalogColorUsesOneFiniteSRGBSourceForTwoDAndThreeD() {
        for color in ThreadColorCatalog.colors {
            let rendered = ThreadColorRendering.renderColor(for: color)
            let expected = SIMD3<Float>(
                Float(color.value.red),
                Float(color.value.green),
                Float(color.value.blue)
            )

            #expect(rendered.sRGB == expected)
            #expect(isFiniteUnitColor(rendered.sRGB))
            #expect(isFiniteUnitColor(rendered.boundarySRGB))
            #expect(isFiniteUnitColor(rendered.fiberHighlightSRGB))
            #expect(
                ThreadColorRendering.relativeLuminance(of: rendered.boundarySRGB)
                    < ThreadColorRendering.relativeLuminance(of: rendered.sRGB)
            )
            #expect(channelOrdering(of: rendered.boundarySRGB) == channelOrdering(of: rendered.sRGB))
        }
    }

    /// **Changed on purpose in Task 063**: the five were blue, pink, natural, white
    /// and black of the twelve provisional colours, and became the five of the
    /// 38 those are read as. **Changed again in Task 065**, to the five of the 30
    /// they are read as — 513 青, 505 ローズ, 501 オフホワイト, 524 黒 — but for
    /// white, which the 30 read as 501 like natural, so 529 ベージュ stands in for
    /// a second pale colour. The formula is unchanged; only the colours are new.
    @Test func representativeColorsKeepTheirFixedRenderingValues() throws {
        let expected: [String: (base: SIMD3<Float>, boundary: SIMD3<Float>, highlight: SIMD3<Float>)] = [
            "amerry-f-513": (.init(0.192, 0.361, 0.576), .init(0.155334, 0.299246, 0.482330), .init(0.362705, 0.459660, 0.624544)),
            "amerry-f-505": (.init(0.827, 0.443, 0.467), .init(0.696070, 0.369074, 0.389511), .init(0.842595, 0.518763, 0.537076)),
            "amerry-f-501": (.init(0.976, 0.961, 0.890), .init(0.822952, 0.810179, 0.749718), .init(0.977949, 0.964197, 0.899462)),
            "amerry-f-529": (.init(0.886, 0.796, 0.682), .init(0.746312, 0.669672, 0.572595), .init(0.895834, 0.814850, 0.714530)),
            "amerry-f-524": (.init(0.031, 0.043, 0.047), .init(0.021080, 0.029303, 0.032256), .init(0.317505, 0.319126, 0.319705)),
        ]

        for (rawID, values) in expected {
            let color = try #require(
                ThreadColorCatalog.color(for: ThreadColorID(rawValue: rawID))
            )
            let rendered = ThreadColorRendering.renderColor(for: color)
            expect(rendered.sRGB, approximatelyEquals: values.base)
            expect(rendered.boundarySRGB, approximatelyEquals: values.boundary)
            expect(rendered.fiberHighlightSRGB, approximatelyEquals: values.highlight)
        }
    }

    private func expect(
        _ actual: SIMD3<Float>,
        approximatelyEquals expected: SIMD3<Float>
    ) {
        #expect(simd_distance(actual, expected) < 0.000_002)
    }

    private func isFiniteUnitColor(_ color: SIMD3<Float>) -> Bool {
        color.x.isFinite && color.y.isFinite && color.z.isFinite
            && (0...1).contains(color.x)
            && (0...1).contains(color.y)
            && (0...1).contains(color.z)
    }

    private func channelOrdering(of color: SIMD3<Float>) -> [Bool] {
        [color.x <= color.y, color.y <= color.z, color.x <= color.z]
    }
}
