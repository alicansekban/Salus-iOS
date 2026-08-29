import CoreGraphics
import Testing

@testable import SalusUI

/// The drawing rules of `SalusSparkline.kt:26-40`, table-tested through the pure
/// ``SparklineGeometry``.
///
/// **Every case here is iOS-only**: Android ships no `SalusSparklineTest.kt` — the Kotlin rules
/// live inside a `Canvas` lambda, which is reachable only from a Compose UI test. Hoisting the
/// geometry out of the view is what makes the same arithmetic assertable off-screen here, so these
/// rows are the port's drift detector rather than a carried-over table.
@Suite("SparklineGeometry")
struct SalusSparklineTests {
    /// The dashboard call site's frame (`HomeScreen.kt`: `Modifier.size(96.dp, 32.dp)`).
    private static let size = CGSize(width: 96, height: 32)

    /// `padY = size.height * 0.1f` (`SalusSparkline.kt:32`).
    private static let padY: CGFloat = 3.2

    /// `drawableHeight = size.height - 2 * padY` (`:33`).
    private static let drawableHeight: CGFloat = 32 - 2 * 3.2

    private func isClose(_ value: CGFloat, _ expected: CGFloat) -> Bool {
        abs(value - expected) < 0.0001
    }

    // MARK: - the two-point minimum

    @Test("no values draw nothing (`if (values.size < 2) return@Canvas`, :26)")
    func noValuesDrawNothing() {
        #expect(SparklineGeometry.points(for: [], in: Self.size).isEmpty)
    }

    @Test("a single value draws nothing — a trend needs two points (:26)")
    func oneValueDrawsNothing() {
        #expect(SparklineGeometry.points(for: [70], in: Self.size).isEmpty)
    }

    // MARK: - the y rule

    @Test("a flat series draws along the bottom pad, not the centre (`span … ?: 1f`, :29, :38)")
    func flatSeriesDrawsAlongTheBottomPad() {
        let points = SparklineGeometry.points(for: [70, 70, 70], in: Self.size)

        // The `?: 1f` fallback only avoids the divide-by-zero; it does not centre the line.
        // Every value equals the minimum, so `(value - min) / span` is 0 and `1 - 0` puts the
        // whole series at the far end of the drawable band — `padY + drawableHeight`. Android
        // draws the identical flat line at the identical height; this row pins the parity.
        #expect(points.count == 3)
        #expect(points.allSatisfy { isClose($0.y, Self.padY + Self.drawableHeight) })
    }

    @Test("an ascending pair spans bottom pad to top pad (`1f - (value - min) / span`, :38)")
    func ascendingPairSpansThePads() throws {
        let points = SparklineGeometry.points(for: [70, 72], in: Self.size)

        #expect(points.count == 2)
        let first = try #require(points.first)
        let last = try #require(points.last)
        // The minimum sits a full drawable height below the top pad — the bottom of the band.
        #expect(isClose(first.y, Self.padY + Self.drawableHeight))
        // The maximum sits on the top pad itself. Higher value, smaller y.
        #expect(isClose(last.y, Self.padY))
    }

    @Test("a descending pair inverts — the first point is the high one (:38)")
    func descendingPairInverts() throws {
        let points = SparklineGeometry.points(for: [72, 70], in: Self.size)

        let first = try #require(points.first)
        let last = try #require(points.last)
        #expect(isClose(first.y, Self.padY))
        #expect(isClose(last.y, Self.padY + Self.drawableHeight))
    }

    @Test("a mid value lands proportionally between the pads (:38)")
    func midValueIsProportional() throws {
        let points = SparklineGeometry.points(for: [70, 71, 74], in: Self.size)

        // span = 4, so 71 is a quarter of the way up: y = padY + 0.75 * drawableHeight.
        #expect(points.count == 3)
        let middle = try #require(points.dropFirst().first)
        #expect(isClose(middle.y, Self.padY + 0.75 * Self.drawableHeight))
    }

    @Test("the line never touches the top or the bottom edge (the 10 % pad, :31-33)")
    func theLineStaysInsideTheVerticalPadding() {
        let points = SparklineGeometry.points(for: [70, 80, 65, 72], in: Self.size)

        #expect(points.allSatisfy { $0.y >= Self.padY - 0.0001 })
        #expect(points.allSatisfy { $0.y <= Self.padY + Self.drawableHeight + 0.0001 })
    }

    // MARK: - the x rule

    @Test("x steps evenly from 0 to the full width (`stepX = width / (size - 1)`, :30, :37)")
    func xStepsEvenly() {
        let points = SparklineGeometry.points(for: [70, 71, 72, 73, 74], in: Self.size)

        #expect(points.count == 5)
        #expect(points.map(\.x) == [0, 24, 48, 72, 96])
    }

    @Test("two points sit on the two horizontal edges (:30, :37)")
    func twoPointsSitOnTheEdges() {
        let points = SparklineGeometry.points(for: [70, 71], in: Self.size)

        #expect(points.map(\.x) == [0, 96])
    }
}
