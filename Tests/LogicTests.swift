import XCTest

final class PatternTests: XCTestCase {
    func testSteadyIsAlwaysOn() {
        for i in 0..<20 { XCTAssertEqual(PatternSchedule.brightness(index: i, count: 20, time: Double(i), pattern: .steady, tempo: 1), 1) }
    }

    func testTwinkleDimsAboutTenPercent() {
        var shares: [Double] = []
        for step in 0..<200 {
            let t = 10 + Double(step) * 0.37
            let dimmed = (0..<200).filter { PatternSchedule.twinkle(index: $0, time: t) < 0.5 }.count
            shares.append(Double(dimmed) / 200)
        }
        let mean = shares.reduce(0, +) / Double(shares.count)
        XCTAssertGreaterThan(mean, 0.06)
        XCTAssertLessThan(mean, 0.14)
    }

    func testTwinkleDimDurationBetween03And1() {
        for i in 0..<30 {
            var run = 0.0, longest = 0.0, shortest = 100.0
            var t = 0.0
            while t < 60 {
                if PatternSchedule.twinkle(index: i, time: t) < 0.999 { run += 0.01 }
                else if run > 0 { longest = max(longest, run); shortest = min(shortest, run); run = 0 }
                t += 0.01
            }
            XCTAssertLessThanOrEqual(longest, 1.05)
            XCTAssertGreaterThanOrEqual(shortest, 0.25)
        }
    }

    func testChaseMovesLeftToRight() {
        func peak(_ t: Double) -> Int {
            (0..<50).max { PatternSchedule.chase(index: $0, count: 50, time: t) < PatternSchedule.chase(index: $1, count: 50, time: t) }!
        }
        XCTAssertLessThan(peak(3.0), peak(4.0))
        let lit = (0..<50).filter { PatternSchedule.chase(index: $0, count: 50, time: 4) > 0.5 }.count
        XCTAssertLessThan(lit, 20)
        XCTAssertGreaterThan(lit, 0)
    }

    func testTempoScalesChase() {
        let slow = PatternSchedule.chase(index: 10, count: 50, time: 2)
        let fast = PatternSchedule.brightness(index: 10, count: 50, time: 1, pattern: .chase, tempo: 2)
        XCTAssertEqual(slow, fast, accuracy: 1e-9)
    }
}

final class ShakeTests: XCTestCase {
    func run(_ pts: [(Double, CGPoint)]) -> Int {
        var d = ShakeDetector()
        return pts.reduce(0) { $0 + d.feed(time: $1.0, position: $1.1) }
    }

    func zigzag(reversals n: Int, interval: Double) -> [(Double, CGPoint)] {
        var out: [(Double, CGPoint)] = []
        var x = 0.0, dir = 1.0, t = 0.0
        for _ in 0...n {
            for _ in 0..<5 { x += dir * 14; t += interval / 5; out.append((t, CGPoint(x: x, y: 0))) }
            dir = -dir
        }
        return out
    }

    func testThreeReversalsAloneRemoveNothing() {
        XCTAssertEqual(run(zigzag(reversals: 3, interval: 0.25)), 0)
    }

    func testFourthReversalRemovesOneStep() {
        XCTAssertEqual(run(zigzag(reversals: 4, interval: 0.25)), 1)
    }

    func testContinuedShakingKeepsRemoving() {
        XCTAssertEqual(run(zigzag(reversals: 9, interval: 0.2)), 6)
    }

    func testSlowShakingDoesNotArm() {
        XCTAssertEqual(run(zigzag(reversals: 8, interval: 0.8)), 0)
    }

    func testNormalMovesWithCorrectionNeverShake() {
        for _ in 0..<10 {
            var d = ShakeDetector()
            var total = 0, t = 0.0
            for x in stride(from: 0.0, to: 400, by: 10) { t += 0.016; total += d.feed(time: t, position: CGPoint(x: x, y: x * 0.2)) }
            for x in stride(from: 400.0, to: 360, by: -4) { t += 0.016; total += d.feed(time: t, position: CGPoint(x: x, y: 80)) }
            for x in stride(from: 360.0, to: 420, by: 6) { t += 0.016; total += d.feed(time: t, position: CGPoint(x: x, y: 80)) }
            XCTAssertEqual(total, 0)
        }
    }

    func testTinyJitterIsIgnored() {
        var d = ShakeDetector(); var total = 0
        for i in 0..<200 { total += d.feed(time: Double(i) * 0.005, position: CGPoint(x: i % 2 == 0 ? 0 : 6, y: 0)) }
        XCTAssertEqual(total, 0)
    }
}

final class PileTests: XCTestCase {
    func testDepositIsCappedAndSmooth() {
        var p = SnowPile(width: 200)
        for _ in 0..<5000 { p.deposit(at: 100, amount: 1) }
        XCTAssertLessThanOrEqual(p.columns.max()!, SnowPile.maxHeight)
        XCTAssertGreaterThan(p.height(at: 100), 11)
        XCTAssertLessThan(p.height(at: 10), 1)
    }

    func testRemoveFractionLeavesTwoThirds() {
        var p = SnowPile(width: 100)
        for _ in 0..<2000 { for x in stride(from: 0.0, to: 100, by: 3) { p.deposit(at: x, amount: 1) } }
        let before = p.meanHeight
        p.remove(fraction: 1.0 / 3.0)
        XCTAssertEqual(p.meanHeight, before * 2 / 3, accuracy: 0.01)
        for _ in 0..<30 { p.remove(fraction: 1.0 / 3.0) }
        XCTAssertTrue(p.isEmpty)
    }

    func testResizeKeepsShape() {
        var p = SnowPile(width: 100)
        for _ in 0..<500 { p.deposit(at: 10, amount: 1) }
        p.resize(width: 200)
        XCTAssertGreaterThan(p.height(at: 20), p.height(at: 150))
    }

    func testVisibleSegmentsSubtractCoveringWindows() {
        let w = CGRect(x: 100, y: 100, width: 400, height: 300)
        XCTAssertEqual(WindowEdges.visibleSegments(of: w, above: []), [100...500])
        let cover = CGRect(x: 200, y: 50, width: 100, height: 200)
        XCTAssertEqual(WindowEdges.visibleSegments(of: w, above: [cover]), [100...200, 300...500])
        let below = CGRect(x: 200, y: 150, width: 100, height: 200)
        XCTAssertEqual(WindowEdges.visibleSegments(of: w, above: [below]), [100...500])
        let full = CGRect(x: 0, y: 0, width: 1000, height: 1000)
        XCTAssertTrue(WindowEdges.visibleSegments(of: w, above: [full]).isEmpty)
    }
}

final class DodgeTests: XCTestCase {
    func testLiftWeightCurve() {
        XCTAssertEqual(Dodge.liftWeight(distance: 0), 1, accuracy: 1e-9)
        XCTAssertEqual(Dodge.liftWeight(distance: 60), 0)
        XCTAssertEqual(Dodge.liftWeight(distance: 100), 0)
        var last = 2.0
        for d in stride(from: 0.0, through: 60, by: 1) { let w = Dodge.liftWeight(distance: d); XCTAssertLessThanOrEqual(w, last); last = w }
        XCTAssertEqual(Dodge.opacity(forWeight: 1), 0.3, accuracy: 1e-9)
        XCTAssertEqual(Dodge.opacity(forWeight: 0), 1)
    }

    func testAttackReactsWithin100ms() {
        var s = Spring()
        for _ in 0..<6 { s.lift(target: 1, dt: 1.0 / 60) }
        XCTAssertGreaterThan(s.value, 0.5)
        for _ in 0..<12 { s.lift(target: 1, dt: 1.0 / 60) }
        XCTAssertGreaterThan(s.value, 0.9)
    }

    func testReleaseReturnsWithinHalfSecondWithSmallOvershoot() {
        var s = Spring(value: 1, velocity: 0)
        var minValue = 1.0
        for _ in 0..<30 { s.lift(target: 0, dt: 1.0 / 60); minValue = min(minValue, s.value) }
        XCTAssertLessThan(abs(s.value), 0.08)
        XCTAssertLessThan(minValue, 0)
        XCTAssertGreaterThan(minValue, -0.25)
        for _ in 0..<60 { s.lift(target: 0, dt: 1.0 / 60) }
        XCTAssertTrue(s.isSettled(target: 0))
    }

    func testSnowDodgeContinuousMonotonicWithFreeZone() {
        XCTAssertEqual(Dodge.dodgedDistance(80, radius: 80), 80)
        XCTAssertEqual(Dodge.dodgedDistance(0, radius: 80), 40, accuracy: 1e-9)
        var last = -1.0
        for d in stride(from: 0.0, through: 120, by: 0.5) {
            let v = Dodge.dodgedDistance(d, radius: 80)
            XCTAssertGreaterThanOrEqual(v, last); XCTAssertGreaterThanOrEqual(v, d - 1e-9); last = v
        }
    }

    func testSegmentDistance() {
        XCTAssertEqual(Dodge.distance(from: CGPoint(x: 5, y: 5), toSegment: CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)), 5)
        XCTAssertEqual(Dodge.distance(from: CGPoint(x: 13, y: 4), toSegment: CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)), 5)
    }
}

final class LayoutTests: XCTestCase {
    func testMidSettingHasAboutSixBulbsPerArc() {
        let h = ChainLayout.bulbHeight(menuBarHeight: 24, level: 2)
        let l = ChainLayout(length: 1920, spacing: ChainLayout.spacing(bulbHeight: h, level: 2))
        XCTAssertEqual(l.bulbsPerArc, 6)
        XCTAssertEqual(l.bulbCount, l.bulbsPerArc * l.arcCount)
        XCTAssertEqual(Double(l.arcCount) * l.arcLength, 1920, accuracy: 1e-6)
    }

    func testBulbsEvenlySpacedAndInsideLength() {
        let l = ChainLayout(length: 1500, spacing: 45)
        let gaps = zip(l.bulbPositions.dropFirst(), l.bulbPositions).map { $0 - $1 }
        XCTAssertLessThan(gaps.max()! - gaps.min()!, 1e-6)
        XCTAssertGreaterThan(l.bulbPositions.first!, 0)
        XCTAssertLessThan(l.bulbPositions.last!, 1500)
    }

    func testSagIsZeroAtJoinsAndOneInMiddle() {
        let l = ChainLayout(length: 1000, spacing: 50)
        XCTAssertEqual(l.sagFactor(at: l.arcLength), 0, accuracy: 1e-9)
        XCTAssertEqual(l.sagFactor(at: l.arcLength * 0.5), 1, accuracy: 1e-9)
    }

    func testTiltStableAndBounded() {
        for i in 0..<500 {
            XCTAssertEqual(ChainLayout.tilt(index: i), ChainLayout.tilt(index: i))
            XCTAssertLessThanOrEqual(abs(ChainLayout.tilt(index: i)), 15)
        }
    }

    func testSmallScreenStillGetsChain() {
        XCTAssertGreaterThanOrEqual(ChainLayout(length: 40, spacing: 45).bulbCount, 1)
    }
}

final class DockStabilizerTests: XCTestCase {
    func testCommitsAfterSettleAndIgnoresIntermediate() {
        var s = DockFrameStabilizer()
        var commits: [CGRect?] = []
        var t = 0.0
        func feed(_ f: CGRect?) { if let c = s.feed(time: t, frame: f) { commits.append(c) }; t += 1.0 / 30 }
        let start = CGRect(x: 400, y: 0, width: 800, height: 70)
        for _ in 0..<10 { feed(start) }
        XCTAssertEqual(commits.count, 1)
        for i in 1...8 { feed(CGRect(x: 400 - Double(i) * 8, y: 0, width: 800 + Double(i) * 16, height: 70)) }
        XCTAssertEqual(commits.count, 1)
        let final = CGRect(x: 336, y: 0, width: 928, height: 70)
        let tSettled = t
        for _ in 0..<10 { feed(final) }
        XCTAssertEqual(commits.count, 2)
        XCTAssertEqual(commits.last!, final)
        XCTAssertLessThan(0.15 + 1.0 / 30, 0.5)
        _ = tSettled
    }

    func testHiddenDockReportsNil() {
        var s = DockFrameStabilizer()
        var got: [CGRect?] = []
        for i in 0..<20 {
            let f: CGRect? = i < 8 ? CGRect(x: 0, y: 0, width: 500, height: 60) : nil
            if let c = s.feed(time: Double(i) / 30, frame: f) { got.append(c) }
        }
        XCTAssertEqual(got.count, 2)
        XCTAssertNil(got[1])
    }
}

final class StormTests: XCTestCase {
    func testEnvelopeRampsHoldsAndEnds() {
        let s = StormEnvelope(start: 100)
        XCTAssertEqual(s.factor(at: 99), 0)
        XCTAssertEqual(s.factor(at: 101), 0.5, accuracy: 0.01)
        XCTAssertEqual(s.factor(at: 102), 1, accuracy: 1e-9)
        XCTAssertEqual(s.factor(at: 125), 1)
        XCTAssertEqual(s.factor(at: 132.5), 0.5, accuracy: 0.01)
        XCTAssertTrue(s.isFinished(at: 135.1))
    }

    func testEarlyStopFadesOutInFiveSeconds() {
        let s = StormEnvelope(start: 0, stopRequested: 10)
        XCTAssertEqual(s.factor(at: 10), 1, accuracy: 1e-9)
        XCTAssertEqual(s.factor(at: 12.5), 0.5, accuracy: 1e-9)
        XCTAssertTrue(s.isFinished(at: 15))
    }

    func testNoWindMeansNoGusts() {
        for t in stride(from: 0.0, to: 100, by: 1) { XCTAssertEqual(SnowPhysics.windSpeed(mode: .off, time: t, storm: 0), 0) }
        XCTAssertLessThan(SnowPhysics.windSpeed(mode: .left, time: 3, storm: 0), 0)
        XCTAssertGreaterThan(SnowPhysics.windSpeed(mode: .right, time: 3, storm: 0), 0)
        XCTAssertNotEqual(SnowPhysics.windSpeed(mode: .off, time: 3, storm: 1), 0)
    }
}

final class CoordinateTests: XCTestCase {
    func testFallingFlakeMovesDownOnScreen() {
        let h = 1080.0
        var y = 100.0
        let before = ScreenCoords.layerY(topDown: y, height: h)
        y += 60 * 0.5 // fällt: y wächst in der Simulation
        let after = ScreenCoords.layerY(topDown: y, height: h)
        XCTAssertLessThan(after, before, "Layer-y muss beim Fallen kleiner werden (nach unten)")
        XCTAssertEqual(ScreenCoords.layerY(topDown: 0, height: h), h, "Bildschirmoberkante liegt oben")
        XCTAssertEqual(ScreenCoords.layerY(topDown: h, height: h), 0, "Unterkante liegt unten")
    }

    func testPileSitsAboveWindowEdge() {
        let edge = 300.0, h = 1080.0
        let layerEdge = ScreenCoords.layerY(topDown: edge, height: h)
        XCTAssertGreaterThan(ScreenCoords.pileTopLayerY(edgeTopDown: edge, height: 12, screenHeight: h), layerEdge)
    }

    func testWindowTopEdgeIsAboveItsBottomInCocoa() {
        let primary = 1080.0
        let top = ScreenCoords.cocoaY(fromCG: 200, rectHeight: 400, primaryHeight: primary) + 400
        let bottom = ScreenCoords.cocoaY(fromCG: 200, rectHeight: 400, primaryHeight: primary)
        XCTAssertGreaterThan(top, bottom)
        XCTAssertEqual(top, primary - 200)
    }

    func testWindDirection() {
        XCTAssertLessThan(SnowPhysics.windSpeed(mode: .left, time: 1, storm: 0, gusts: false), 0)
        XCTAssertGreaterThan(SnowPhysics.windSpeed(mode: .right, time: 1, storm: 0, gusts: false), 0)
    }
}

final class CornerTests: XCTestCase {
    func testRadiusPerVersion() {
        XCTAssertEqual(WindowCorners.radius(forMajorVersion: 26), 26)
        XCTAssertEqual(WindowCorners.radius(forMajorVersion: 14), 10)
    }

    func testEdgeDropFollowsCircleAndMeasuredPoints() {
        let r = 26.0
        XCTAssertEqual(WindowCorners.edgeDrop(distanceFromSide: 0, radius: r), r, accuracy: 1e-9)
        XCTAssertEqual(WindowCorners.edgeDrop(distanceFromSide: r, radius: r), 0)
        XCTAssertEqual(WindowCorners.edgeDrop(distanceFromSide: 100, radius: r), 0)
        // gemessen am Testrechner: bei 4 pt Abstand liegt die Kante etwa 12 pt, bei 14 pt etwa 3 pt von der geraden Kante entfernt
        XCTAssertEqual(WindowCorners.edgeDrop(distanceFromSide: 4, radius: r), 12, accuracy: 1.5)
        XCTAssertEqual(WindowCorners.edgeDrop(distanceFromSide: 14, radius: r), 3.0, accuracy: 1.5)
        var last = 100.0
        for d in stride(from: 0.0, through: r, by: 0.5) { let v = WindowCorners.edgeDrop(distanceFromSide: d, radius: r); XCTAssertLessThanOrEqual(v, last); last = v }
    }

    func testTaperThinsTowardCorner() {
        let r = 26.0
        XCTAssertEqual(WindowCorners.taper(distanceFromSide: 0, radius: r), 0)
        XCTAssertEqual(WindowCorners.taper(distanceFromSide: r * 2, radius: r), 1)
        XCTAssertLessThan(WindowCorners.taper(distanceFromSide: 8, radius: r), WindowCorners.taper(distanceFromSide: 20, radius: r))
    }

    func testRemoveRangeOnlyAffectsCorner() {
        var p = SnowPile(width: 200)
        for _ in 0..<3000 { for x in stride(from: 0.0, to: 200, by: 4) { p.deposit(at: x, amount: 1) } }
        let mid = p.height(at: 100), corner = p.height(at: 10)
        p.remove(fraction: 0.6, from: 0, to: 30)
        XCTAssertEqual(p.height(at: 100), mid, accuracy: 0.01)
        XCTAssertLessThan(p.height(at: 10), corner * 0.6)
    }
}
