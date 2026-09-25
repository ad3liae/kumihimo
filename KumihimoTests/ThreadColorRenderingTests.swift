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
    /// and black of the twelve provisional colours, and are now the five of the
    /// 38 those are read as. The formula is unchanged; only the colours are new.
    @Test func representativeColorsKeepTheirFixedRenderingValues() throws {
        let expected: [String: (base: SIMD3<Float>, boundary: SIMD3<Float>, highlight: SIMD3<Float>)] = [
            "ruri": (.init(0.200, 0.220, 0.686), .init(0.162146, 0.179177, 0.576001), .init(0.366291, 0.375758, 0.717996)),
            "fuji": (.init(0.902, 0.663, 0.804), .init(0.759937, 0.556416, 0.676485), .init(0.910358, 0.698127, 0.821994)),
            "zoge": (.init(0.898, 0.855, 0.675), .init(0.756531, 0.719914, 0.566634), .init(0.906724, 0.867795, 0.708474)),
            "hakudo": (.init(1.000, 0.973, 0.839), .init(0.843389, 0.820397, 0.706289), .init(1.000000, 0.975197, 0.853379)),
            "shikkoku": (.init(0.110, 0.063, 0.055), .init(0.085506, 0.045483, 0.038664), .init(0.333105, 0.322340, 0.320959)),
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
