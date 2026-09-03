import RealityKit
import Testing
@testable import Kumihimo

@MainActor
struct MaruGenjiViewerControllerTests {
    @Test func rotationOnlyChangesTheLongAxisRoll() {
        let controller = MaruGenjiViewerController()
        let root = Entity()
        controller.connect(modelRoot: root)

        controller.rotate(horizontal: .pi / 4)

        #expect(abs(controller.roll - .pi / 4) < 0.000_001)
        #expect(abs(root.orientation.imag.y) < 0.000_001)
        #expect(abs(root.orientation.imag.z) < 0.000_001)
    }

    @Test func zoomIsClampedAndResetRestoresRotationAndScale() {
        let controller = MaruGenjiViewerController()
        let root = Entity()
        controller.connect(modelRoot: root)

        controller.rotate(horizontal: .pi / 3)
        controller.zoom(by: 0.001)
        #expect(controller.scale == MaruGenjiViewerController.minimumScale)
        controller.zoom(by: 1_000)
        #expect(controller.scale == MaruGenjiViewerController.maximumScale)

        controller.reset()
        #expect(controller.roll == 0)
        #expect(controller.scale == 1)
        #expect(root.orientation == simd_quatf(angle: 0, axis: SIMD3<Float>(1, 0, 0)))
        #expect(root.scale == SIMD3<Float>(repeating: 1))
    }
}
