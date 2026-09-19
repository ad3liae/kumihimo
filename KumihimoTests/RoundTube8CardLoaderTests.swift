import CoreGraphics
import Foundation
import Testing
@testable import Kumihimo

/// Task 045 addendum 2: **a card shows the picture for the colouring it shows
/// now, whatever order the pictures finish in.**
///
/// These drive the card's own loader (`RoundTube8CardLoader`, the one the view
/// calls from `.task(id:)`) with a drawing step the test holds open and lets
/// finish when it chooses — no waiting on the clock. Leaving a colouring is done
/// the way `.task(id:)` does it: the load for the old key is cancelled and a new
/// one begins.
@MainActor
struct RoundTube8CardLoaderTests {

    /// A drawing step that does not finish until the test says so, and counts
    /// what it was asked to draw.
    @MainActor
    final class Gate {
        private var waiting = [RoundTube8CardImage.Key: CheckedContinuation<CGImage?, Never>]()
        private(set) var asked = [RoundTube8CardImage.Key]()

        func draw(_ pattern: RoundTube8SurfacePattern, _ bundle: RoundTube8Bundle) async -> CGImage? {
            let key = RoundTube8CardImage.Key(pattern: pattern, bundle: bundle)
            asked.append(key)
            return await withCheckedContinuation { waiting[key] = $0 }
        }

        func isDrawing(_ key: RoundTube8CardImage.Key) -> Bool { waiting[key] != nil }

        func finish(_ key: RoundTube8CardImage.Key, with image: CGImage) {
            waiting.removeValue(forKey: key)?.resume(returning: image)
        }
    }

    private func pattern(_ names: [String]) throws -> RoundTube8SurfacePattern {
        let stand = BraidMethodCatalog.stand8
        let recipe = BraidMethodCatalog.yatsuKongoS8Recipe
        let worked = try #require(recipe.worked(on: stand))
        let assignments = names.enumerated().map {
            ThreadAssignment(position: $0.offset + 1, colorID: ThreadColorID(rawValue: $0.element))
        }
        return try #require(RoundTube8SurfacePatternGenerator.generate(
            stand: stand, method: worked.method, crossSection: worked.section, assignments: assignments
        ))
    }

    private var a: RoundTube8SurfacePattern { get throws { try pattern(Array(repeating: "natural", count: 8)) } }
    private var b: RoundTube8SurfacePattern { get throws { try pattern(Array(repeating: "red", count: 8)) } }
    private var c: RoundTube8SurfacePattern {
        get throws { try pattern(["red", "orange", "yellow", "green", "light-blue", "blue", "purple", "pink"]) }
    }

    private func key(_ pattern: RoundTube8SurfacePattern) -> RoundTube8CardImage.Key {
        RoundTube8CardImage.Key(pattern: pattern, bundle: .standard)
    }

    /// A one-pixel picture, told apart from the others by identity.
    private func picture() throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        return try #require(context.makeImage())
    }

    /// Lets the other tasks run until `condition` holds. Bounded, so a load that
    /// never gets there fails the test instead of hanging it.
    private func settle(_ condition: () -> Bool) async {
        for _ in 0..<1_000 where !condition() { await Task.yield() }
    }

    /// **A shown, B being drawn, back to A, then B finishes**: the card keeps
    /// showing A, and B is kept for later but not shown. While B was being
    /// drawn the card showed nothing rather than A.
    @Test func goingBackToADrawnColouringIsNotUndoneWhenBFinishesLate() async throws {
        let (a, b) = (try a, try b)
        let gate = Gate()
        let cache = RoundTube8CardImage.Cache()
        let pictureA = try picture(), pictureB = try picture()
        await cache.keep(pictureA, for: key(a))
        let loader = RoundTube8CardLoader(cache: cache, draw: { p, s in await gate.draw(p, s) })

        await loader.load(pattern: a, bundle: .standard)
        #expect(loader.image(for: key(a)) === pictureA)
        #expect(gate.asked.isEmpty, "A came from the cache")

        let loadingB = Task { await loader.load(pattern: b, bundle: .standard) }
        await settle { gate.isDrawing(key(b)) }
        #expect(gate.isDrawing(key(b)))
        // Waiting for B: nothing for B yet, and A is not what the card shows now.
        #expect(loader.image(for: key(b)) == nil)
        #expect(loader.requested == key(b))

        // Back to A, as `.task(id:)` does it.
        loadingB.cancel()
        await loader.load(pattern: a, bundle: .standard)
        #expect(loader.image(for: key(a)) === pictureA)

        // B finishes last.
        gate.finish(key(b), with: pictureB)
        await loadingB.value
        #expect(loader.requested == key(a))
        #expect(loader.image(for: key(a)) === pictureA)
        #expect(loader.image(for: key(b)) == nil, "B finished late and must not be shown")
        #expect(await cache.image(for: key(b)) === pictureB, "but it is kept for when the card comes back to B")
    }

    /// **B being drawn, then C asked for; C finishes, then B**: the card shows C.
    @Test func aLaterColouringFinishingFirstIsNotReplacedByAnEarlierOne() async throws {
        let (b, c) = (try b, try c)
        let gate = Gate()
        let loader = RoundTube8CardLoader(cache: RoundTube8CardImage.Cache(), draw: { p, s in await gate.draw(p, s) })
        let pictureB = try picture(), pictureC = try picture()

        let loadingB = Task { await loader.load(pattern: b, bundle: .standard) }
        await settle { gate.isDrawing(key(b)) }
        loadingB.cancel()
        let loadingC = Task { await loader.load(pattern: c, bundle: .standard) }
        await settle { gate.isDrawing(key(c)) }
        #expect(gate.isDrawing(key(b)) && gate.isDrawing(key(c)))
        #expect(loader.image(for: key(c)) == nil, "nothing to show for C while it is drawn")

        gate.finish(key(c), with: pictureC)
        await loadingC.value
        #expect(loader.image(for: key(c)) === pictureC)

        gate.finish(key(b), with: pictureB)
        await loadingB.value
        #expect(loader.requested == key(c))
        #expect(loader.image(for: key(c)) === pictureC)
        #expect(loader.image(for: key(b)) == nil)
    }

    /// **The ordinary cases still work**: a first load draws and shows; a second
    /// card on the same cache shows the kept picture without drawing again.
    @Test func aFirstLoadDrawsAndALaterOneComesFromTheCache() async throws {
        let a = try a
        let gate = Gate()
        let cache = RoundTube8CardImage.Cache()
        let pictureA = try picture()

        let first = RoundTube8CardLoader(cache: cache, draw: { p, s in await gate.draw(p, s) })
        let loading = Task { await first.load(pattern: a, bundle: .standard) }
        await settle { gate.isDrawing(key(a)) }
        gate.finish(key(a), with: pictureA)
        await loading.value
        #expect(first.image(for: key(a)) === pictureA)
        #expect(gate.asked == [key(a)])

        let second = RoundTube8CardLoader(cache: cache, draw: { p, s in await gate.draw(p, s) })
        await second.load(pattern: a, bundle: .standard)
        #expect(second.image(for: key(a)) === pictureA)
        #expect(gate.asked == [key(a)], "the second card did not draw again")
    }

    /// **The real drawing step, end to end**: the loader the view uses by
    /// default draws a picture the size the card map is.
    @Test func theDefaultLoaderDrawsTheCardPicture() async throws {
        let a = try a
        let loader = RoundTube8CardLoader(cache: RoundTube8CardImage.Cache())
        await loader.load(pattern: a, bundle: .standard)
        let image = try #require(loader.image(for: key(a)))
        let map = RoundTube8CardImage.shownMap(for: a)
        #expect(image.width == map.width && image.height == map.height)
    }
}
