import SwiftUI
import Testing
@testable import Kumihimo

struct ProjectEditorLayoutTests {
    @Test func regularWideWindowUsesTwoColumns() {
        #expect(layout(width: 1_194) == .twoColumn)
        #expect(layout(width: 900) == .twoColumn)
    }

    @Test func phonePortraitAndNarrowSplitViewUseOneColumn() {
        #expect(layout(width: 393, regular: false) == .singleColumn)
        #expect(layout(width: 744) == .singleColumn)
        #expect(layout(width: 899) == .singleColumn)
    }

    @Test func compactSizeClassNeverUsesTwoColumns() {
        #expect(layout(width: 1_194, regular: false) == .singleColumn)
    }

    @Test func accessibilityTextReturnsWideWindowToOneColumn() {
        #expect(layout(width: 1_194, typeSize: .accessibility1) == .singleColumn)
        #expect(layout(width: 1_194, typeSize: .accessibility5) == .singleColumn)
    }

    @Test func invalidWidthsFailClosedToOneColumn() {
        #expect(layout(width: .nan) == .singleColumn)
        #expect(layout(width: .infinity) == .singleColumn)
        #expect(layout(width: -1) == .singleColumn)
    }

    private func layout(
        width: CGFloat,
        regular: Bool = true,
        typeSize: DynamicTypeSize = .large
    ) -> ProjectEditorLayout {
        ProjectEditorLayoutCalculator.layout(
            width: width,
            hasRegularHorizontalSizeClass: regular,
            dynamicTypeSize: typeSize
        )
    }
}
