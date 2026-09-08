import Foundation
import Testing
@testable import Kumihimo

/// Task 025-2: a number about a braid's shape has to say where it came from.
struct BraidMeasurementTests {
    @Test func aMeasuredValueSaysSoAndSaysFromWhere() {
        let ratio = BraidMeasurement.observed(3.3359, from: "book A p96")
        #expect(ratio.isObserved)
        #expect(!ratio.isDerived)
        #expect(ratio.source.origin == "book A p96")
    }

    @Test func aWorkedOutValueSaysSoAndSaysFromWhat() {
        let thickness = BraidMeasurement.derived(0.75, by: "t = d^2 / w")
        #expect(thickness.isDerived)
        #expect(!thickness.isObserved)
        #expect(thickness.source.origin == "t = d^2 / w")
    }

    @Test func aBandIsCheckedAgainstItsValue() {
        let inside = BraidMeasurement.observed(2.0, spread: 1.8...2.15,
                                               from: "photographs, Task 005I")
        let outside = BraidMeasurement.observed(2.4, spread: 1.8...2.15,
                                                from: "photographs, Task 005I")
        #expect(inside.agreesWithItsSpread)
        #expect(!outside.agreesWithItsSpread)
    }

    @Test func aValueWithNoBandHasNothingToDisagreeWith() {
        #expect(BraidMeasurement.observed(0.45, from: "book A p96").agreesWithItsSpread)
    }

    /// The round braid's crest height and aspect ratio: the photographs hold their
    /// product and neither one alone. That has to be visible on the value itself.
    @Test func aValueCanSayItIsNotSettledOnItsOwn() {
        let crest = BraidMeasurement.observed(
            0.12, from: "Task 005J",
            unsettled: "only the product with the aspect ratio is held by the photographs"
        )
        #expect(!crest.isSettled)
        #expect(BraidMeasurement.observed(0.45, from: "book A p96").isSettled)
    }
}

extension BraidMeasurementTests {
    /// **A length has to say what it is a fraction of.** The construction can only
    /// use one given in thread diameters, and it converts nothing.
    @Test func aValueSaysWhatItIsAFractionOf() {
        let inDiameters = BraidMeasurement.observed(
            0.45, basis: .threadDiameters, from: "book A p96"
        )
        let inSomethingElse = BraidMeasurement.observed(
            0.12, basis: .fractionOf("the tube's nominal radius"), from: "Task 005J"
        )
        #expect(inDiameters.isInThreadDiameters)
        #expect(!inSomethingElse.isInThreadDiameters)
        // A bare ratio is the default, because most of these are ratios.
        #expect(BraidMeasurement.observed(3.3359, from: "a section").basis == .aRatio)
    }
}
