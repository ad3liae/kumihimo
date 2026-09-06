import Foundation
@testable import Kumihimo

/// The colourings the books print beside their own samples, read off their
/// starting diagrams.
///
/// **Nothing here is invented.** Task 020 forbids making up a colour experiment:
/// a sample is only evidence if the book both set it up and photographed the
/// result. Each of these is transcribed from the disk drawn on the page, position
/// by position, and mapped onto the nearest colours the app's catalogue has.
enum BraidReferenceColourings {
    /// Book A p97, left. Faces 1 and 3 in one neutral; on each side the far and
    /// near threads one colour and the middle two another — gold and rust on the
    /// east, teal and olive on the west.
    ///
    /// One sample, two claims: the body comes out plain, and the edging comes out
    /// in arrow feather.
    static var bookAP97Left: [ThreadAssignment] {
        colouring(
            north: Array(repeating: "natural", count: 4),
            east: ["yellow", "orange", "orange", "yellow"],
            south: Array(repeating: "natural", count: 4),
            west: ["green", "light-blue", "light-blue", "green"]
        )
    }

    /// Book A p97, right. The far half of the stand in one colour and the near
    /// half in another — positions 13, 14, 15, 16, 1, 2, 3, 4 against 5 to 12,
    /// which is what its disk shows. The braid comes out a ladder whose rungs
    /// reverse between the two faces.
    static var bookAP97Right: [ThreadAssignment] {
        colouring(
            north: Array(repeating: "brown", count: 4),
            east: ["brown", "brown", "yellow", "yellow"],
            south: Array(repeating: "yellow", count: 4),
            west: ["brown", "brown", "yellow", "yellow"]
        )
    }

    /// Book A p96's starting diagram: faces 1 and 3 west to east as mauve, mauve,
    /// black, vermilion, everything else salmon. The finished braid is photographed
    /// at the head of the same page.
    static var bookAP96: [ThreadAssignment] {
        colouring(
            north: ["purple", "purple", "black", "orange"],
            east: Array(repeating: "pink", count: 4),
            south: ["purple", "purple", "black", "orange"],
            west: Array(repeating: "pink", count: 4)
        )
    }

    // MARK: - The round braid

    /// Book A p94's own colouring: the north face rose, salmon, salmon, rose and
    /// the south face sage, vermilion, vermilion, sage, with the east and west
    /// faces all in navy. Its finished braid is photographed at the head of the
    /// page, with the loose ends showing at one end.
    static var bookAP94MaruGenji: [ThreadAssignment] {
        colouring(
            north: ["pink", "orange", "orange", "pink"],
            east: Array(repeating: "black", count: 4),
            south: ["natural", "red", "red", "natural"],
            west: Array(repeating: "black", count: 4)
        )
    }

    /// Book A p95, left: "give the far and the near halves different colours and
    /// an arrow feather appears". The far half of the stand — positions 13, 14,
    /// 15, 16, 1, 2, 3, 4 — against the near half.
    static var bookAP95ArrowFeather: [ThreadAssignment] {
        colouring(
            north: Array(repeating: "yellow", count: 4),
            east: ["yellow", "yellow", "blue", "blue"],
            south: Array(repeating: "blue", count: 4),
            west: ["yellow", "yellow", "blue", "blue"]
        )
    }

    /// Book A p95, right: "make faces 1 and 3, and faces 2 and 4, each
    /// symmetrical in two colours, and it comes out in lengthwise stripes".
    ///
    /// **The only reference colouring that can tell the two column orders apart**
    /// — see `BraidDerivationMaruGenjiGridTests`. It needs the direction along the
    /// braid to be known, and the photograph shows no end.
    static var bookAP95VerticalStripe: [ThreadAssignment] {
        colouring(
            north: ["yellow", "yellow", "blue", "blue"],
            east: ["light-blue", "light-blue", "green", "green"],
            south: ["yellow", "yellow", "blue", "blue"],
            west: ["light-blue", "light-blue", "green", "green"]
        )
    }

    /// Book B p73, colouring a: two opposite quarters of the stand in each colour.
    static var bookBMaruGenjiA: [ThreadAssignment] {
        colouring(
            north: ["blue", "blue", "white", "white"],
            east: ["white", "white", "blue", "blue"],
            south: ["white", "white", "blue", "blue"],
            west: ["blue", "blue", "white", "white"]
        )
    }

    /// Book B p73, colouring b: the north and south faces in two colours, the east
    /// and west faces plain.
    static var bookBMaruGenjiB: [ThreadAssignment] {
        colouring(
            north: ["blue", "blue", "red", "red"],
            east: Array(repeating: "white", count: 4),
            south: ["blue", "blue", "red", "red"],
            west: Array(repeating: "white", count: 4)
        )
    }

    /// The groups are listed the way the books list them — outermost first, which
    /// for the south and west groups runs against the ring.
    private static func colouring(
        north: [String], east: [String], south: [String], west: [String]
    ) -> [ThreadAssignment] {
        var colours = [Int: String]()
        for (group, names) in [
            (HiraGenjiBoardState.initial.north, north),
            (HiraGenjiBoardState.initial.east, east),
            (HiraGenjiBoardState.initial.south, south),
            (HiraGenjiBoardState.initial.west, west),
        ] {
            for (position, name) in zip(group, names) { colours[position] = name }
        }
        return (1...16).map {
            ThreadAssignment(position: $0, colorID: ThreadColorID(rawValue: colours[$0] ?? "white"))
        }
    }
}
