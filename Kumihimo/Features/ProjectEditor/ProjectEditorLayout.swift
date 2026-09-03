import SwiftUI

enum ProjectEditorLayout: Equatable, Sendable {
    case singleColumn
    case twoColumn
}

enum ProjectEditorLayoutCalculator {
    static let minimumTwoColumnWidth: CGFloat = 900

    static func layout(
        width: CGFloat,
        hasRegularHorizontalSizeClass: Bool,
        dynamicTypeSize: DynamicTypeSize
    ) -> ProjectEditorLayout {
        guard
            width.isFinite,
            width >= minimumTwoColumnWidth,
            hasRegularHorizontalSizeClass,
            !dynamicTypeSize.isAccessibilitySize
        else {
            return .singleColumn
        }
        return .twoColumn
    }
}
