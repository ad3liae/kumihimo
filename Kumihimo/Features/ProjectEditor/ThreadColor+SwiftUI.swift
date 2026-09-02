import SwiftUI
import UIKit

extension ThreadColor {
    var renderColor: ThreadRenderColor {
        ThreadColorRendering.renderColor(for: self)
    }

    var swiftUIColor: Color {
        Color(sRGB: renderColor.sRGB)
    }

    var uiColor: UIColor {
        UIColor(sRGB: renderColor.sRGB)
    }

    var boundaryUIColor: UIColor {
        UIColor(sRGB: renderColor.boundarySRGB)
    }
}

private extension Color {
    init(sRGB: SIMD3<Float>) {
        self.init(
            .sRGB,
            red: Double(sRGB.x),
            green: Double(sRGB.y),
            blue: Double(sRGB.z),
            opacity: 1
        )
    }
}

private extension UIColor {
    convenience init(sRGB: SIMD3<Float>) {
        self.init(
            red: CGFloat(sRGB.x),
            green: CGFloat(sRGB.y),
            blue: CGFloat(sRGB.z),
            alpha: 1
        )
    }
}
