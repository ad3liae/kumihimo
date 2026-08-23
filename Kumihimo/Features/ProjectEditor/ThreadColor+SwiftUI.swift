import SwiftUI

extension ThreadColor {
    var swiftUIColor: Color {
        Color(red: value.red, green: value.green, blue: value.blue)
    }
}
