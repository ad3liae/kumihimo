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

    @Test func representativeColorsKeepTheirFixedRenderingValues() throws {
        let expected: [String: (base: SIMD3<Float>, boundary: SIMD3<Float>, highlight: SIMD3<Float>)] = [
            "blue": (.init(0.12, 0.32, 0.68), .init(0.094022, 0.264333, 0.570892), .init(0.335987, 0.432574, 0.712798)),
            "pink": (.init(0.90, 0.43, 0.57), .init(0.758234, 0.358004, 0.477221), .init(0.908541, 0.509017, 0.619575)),
            "natural": (.init(0.86, 0.81, 0.68), .init(0.724172, 0.681594, 0.570892), .init(0.872307, 0.827359, 0.712798)),
            "white": (.init(0.96, 0.96, 0.94), .init(0.809327, 0.809327, 0.792296), .init(0.963281, 0.963281, 0.944987)),
            "black": (.init(0.08, 0.08, 0.09), .init(0.059960, 0.059960, 0.068475), .init(0.325707, 0.325707, 0.327965)),
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
