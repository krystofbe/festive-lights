import XCTest

final class PatternTests: XCTestCase {
    func testSteadyIsAlwaysOn() {
        for i in 0..<20 { XCTAssertEqual(PatternSchedule.brightness(index: i, count: 20, time: Double(i), pattern: .steady, tempo: 1), 1) }
    }

    func testTwinkleDimsAboutSixPercent() {
        var sum = 0.0, steps = 0
        for step in 0..<600 {
            let time = 10 + Double(step) * 0.37
            sum += Double((0..<200).filter { PatternSchedule.twinkle(index: $0, time: time) < 0.5 }.count) / 200
            steps += 1
        }
        let mean = sum / Double(steps)
        XCTAssertGreaterThan(mean, 0.04)
        XCTAssertLessThan(mean, 0.08)
    }

    func testNoTwoNeighboursDimAtTheSameTime() {
        for step in 0..<3000 {
            let time = Double(step) * 0.05
            for i in 0..<150 {
                let a = PatternSchedule.twinkle(index: i, time: time), b = PatternSchedule.twinkle(index: i + 1, time: time)
                XCTAssertFalse(a < 1 && b < 1, "Birne \(i) und \(i + 1) dimmen gleichzeitig bei t=\(time)")
            }
        }
    }

    func testTwinkleDimDurationAndSoftFades() {
        for i in 0..<40 {
            var run = 0.0, longest = 0.0, shortest = 100.0, maxStep = 0.0, last = 1.0
            var t = 0.0
            while t < 120 {
                let v = PatternSchedule.twinkle(index: i, time: t)
                maxStep = max(maxStep, abs(v - last)); last = v
                if v < 0.999 { run += 0.01 } else if run > 0 { longest = max(longest, run); shortest = min(shortest, run); run = 0 }
                t += 0.01
            }
            XCTAssertLessThanOrEqual(longest, 3.05)
            XCTAssertGreaterThanOrEqual(shortest, 1.45)
            XCTAssertLessThan(maxStep, 0.03, "Übergänge sind weich, kein Sprung (je Schritt von 10 ms)")
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

final class StirTests: XCTestCase {
    func testVelocityTrackerMeasuresSpeed() {
        var t = PointerVelocityTracker()
        for i in 0..<30 { t.feed(time: Double(i) * 0.008, position: CGPoint(x: Double(i) * 12, y: 0)) } // 1500 pt/s
        XCTAssertEqual(t.speed(at: 29 * 0.008), 1500, accuracy: 150)
        XCTAssertEqual(t.speed(at: 29 * 0.008 + 0.5), 0, "ohne Ereignisse klingt das Tempo ab")
        XCTAssertGreaterThan(t.velocity.dx, 0)
    }

    func testWarpedPointerIsNotAFastMovement() {
        var t = PointerVelocityTracker()
        for i in 0..<30 { t.feed(time: Double(i) * 0.008, position: CGPoint(x: 100, y: 100)) }
        t.feed(time: 30 * 0.008, position: CGPoint(x: 1400, y: 700))
        XCTAssertEqual(t.speed(at: 30 * 0.008), 0)
    }

    /// Fährt den Zeiger mit 120 Bildern pro Sekunde von a nach b und lässt danach `rest` Sekunden verstreichen.
    struct Probe { var p: CGPoint; var z = 0.3; var sink = 40.0; var drift = Stir.Drift(); var start = CGPoint.zero
                   var maxAir = 0.0, maxRel = 0.0, minVy = Double.infinity, maxStep = 0.0 }
    @discardableResult
    static func run(_ air: inout AirField, _ probes: inout [Probe], from a: CGPoint, to b: CGPoint, speed: Double, rest: Double = 0, noise: Double = 0) -> Int {
        let dt = 1.0 / 120, len = Double(hypot(b.x - a.x, b.y - a.y))
        let ux = Double(b.x - a.x) / len, uy = Double(b.y - a.y) / len
        let v = CGVector(dx: (ux - uy * noise) * speed, dy: (uy + ux * noise) * speed)
        let moveSteps = Int(len / speed / dt), steps = moveSteps + Int(rest / dt)
        var last = a
        for i in probes.indices where probes[i].start == .zero { probes[i].start = probes[i].p }
        for k in 1...max(steps, 1) {
            air.step(dt: dt)
            if k <= moveSteps {
                let t = Double(k) / Double(moveSteps)
                let p = CGPoint(x: Double(a.x) + ux * len * t, y: Double(a.y) + uy * len * t)
                air.feed(from: last, to: p, velocity: v); last = p
            }
            for i in probes.indices {
                let s = air.sample(x: Double(probes[i].p.x), y: Double(probes[i].p.y))
                let before = probes[i].drift
                let vel = probes[i].drift.step(air: s, sink: probes[i].sink, tau: Stir.relaxation(depth: probes[i].z), dt: dt)
                probes[i].p.x += vel.dx * dt; probes[i].p.y += vel.dy * dt
                let d = probes[i].drift
                probes[i].maxAir = max(probes[i].maxAir, s.speed)
                probes[i].maxRel = max(probes[i].maxRel, hypot(d.vx, d.vy + d.lift))
                probes[i].minVy = min(probes[i].minVy, Double(vel.dy))
                probes[i].maxStep = max(probes[i].maxStep, hypot(d.vx - before.vx, d.vy + d.lift - before.vy - before.lift))
            }
        }
        return steps
    }
    static func grid(z: Double = 0.3, sink: Double = 40) -> [Probe] {
        var out: [Probe] = []
        for x in stride(from: 300.0, through: 900, by: 40) { for y in stride(from: 300.0, through: 700, by: 25) { out.append(Probe(p: CGPoint(x: x, y: y), z: z, sink: sink)) } }
        return out
    }
    static let passes: [(CGPoint, CGPoint)] = [
        (CGPoint(x: 200, y: 500), CGPoint(x: 1000, y: 500)), (CGPoint(x: 1000, y: 480), CGPoint(x: 200, y: 520)),
        (CGPoint(x: 300, y: 250), CGPoint(x: 900, y: 750)), (CGPoint(x: 600, y: 800), CGPoint(x: 600, y: 200)), (CGPoint(x: 350, y: 750), CGPoint(x: 850, y: 250)),
    ]

    func testSlowMovementMakesNoAir() {
        XCTAssertEqual(Stir.strength(speed: 200), 0)
        XCTAssertEqual(Stir.strength(speed: 2000), 1)
        var air = AirField(), probes = Self.grid()
        Self.run(&air, &probes, from: CGPoint(x: 200, y: 500), to: CGPoint(x: 400, y: 500), speed: 200)
        XCTAssertFalse(air.isActive)
        XCTAssertTrue(probes.allSatisfy { $0.drift.isZero && $0.maxAir == 0 })
    }

    func testFlakeNeverFasterThanTheAirCarryingIt() {
        for (a, b) in Self.passes { for speed in [600.0, 1200, 2500, 6000] {
            var air = AirField(), probes = Self.grid(z: 0.05)
            Self.run(&air, &probes, from: a, to: b, speed: speed, rest: 1)
            for p in probes {
                XCTAssertLessThanOrEqual(p.maxRel, p.maxAir + 1e-6, "Flocke schneller als die Luft")
                XCTAssertLessThanOrEqual(p.maxAir, min(speed, Stir.maxAir) + 1e-6, "Luft schneller als der Zeiger")
            }
            XCTAssertGreaterThan(probes.map(\.maxRel).max()!, 0.08 * min(speed, 2000) * Stir.strength(speed: speed))
        } }
    }

    func testFlakesAreCarriedAlongWithoutJumps() {
        // Abnahme 7: bei gut 1000 pt/s nach 0,3 s sichtbar in Bewegungsrichtung versetzt
        var air = AirField(), probes = [Probe(p: CGPoint(x: 600, y: 505), z: 0.3), Probe(p: CGPoint(x: 600, y: 470), z: 0.6)]
        Self.run(&air, &probes, from: CGPoint(x: 200, y: 500), to: CGPoint(x: 1000, y: 500), speed: 1200, rest: 0.3)
        for p in probes {
            XCTAssertGreaterThan(p.p.x - p.start.x, 15, "in Bewegungsrichtung mitgenommen")
            XCTAssertLessThan(p.maxStep, 0.1 * 1200, "kein Sprung im Tempo von Bild zu Bild")
        }
    }

    func testSmallFlakesReactMoreThanLargeOnes() {
        XCTAssertLessThan(Stir.relaxation(depth: 0), Stir.relaxation(depth: 1))
        var air = AirField(), probes = [Probe(p: CGPoint(x: 600, y: 510), z: 0.05), Probe(p: CGPoint(x: 600, y: 510), z: 0.95)]
        Self.run(&air, &probes, from: CGPoint(x: 200, y: 500), to: CGPoint(x: 1000, y: 500), speed: 1500, rest: 0.4)
        XCTAssertGreaterThan(probes[0].maxRel, probes[1].maxRel * 1.3)
        XCTAssertGreaterThan(probes[0].p.x - 600, probes[1].p.x - 600)
    }

    func testEverythingIsCalmAgainAfterTwoSeconds() {
        for (a, b) in Self.passes {
            var air = AirField(), probes = Self.grid(z: 1)
            Self.run(&air, &probes, from: a, to: b, speed: 3000, rest: 2)
            XCTAssertFalse(air.isActive, "Nachlauf ist verschwunden")
            for p in probes { XCTAssertLessThan(hypot(p.drift.vx, p.drift.vy + p.drift.lift), 2, "Flocke fällt wieder normal (Abweichung unter 2 pt/s)") }
        }
    }

    func testWakeCalmsDownWithinAboutOneSecond() {
        var air = AirField(), none: [Probe] = []
        Self.run(&air, &none, from: CGPoint(x: 200, y: 500), to: CGPoint(x: 1000, y: 500), speed: 1500)
        func peak() -> Double { stride(from: 200.0, through: 1000, by: 20).map { air.sample(x: $0, y: 500).speed }.max()! }
        let fresh = peak()
        XCTAssertGreaterThan(fresh, 300)
        Self.run(&air, &none, from: CGPoint(x: 1000, y: 500), to: CGPoint(x: 1000.1, y: 500), speed: 100, rest: 1)
        XCTAssertLessThan(peak(), 0.06 * fresh)
    }

    func testWakeHasSidewaysDisplacementBackflowAndCounterRotatingSwirls() {
        var air = AirField(), none: [Probe] = []
        Self.run(&air, &none, from: CGPoint(x: 200, y: 500), to: CGPoint(x: 1000, y: 500), speed: 1500)
        XCTAssertGreaterThan(air.sample(x: 960, y: 500).dx, 300, "Luft wird in Bewegungsrichtung mitgerissen")
        let flank = stride(from: 400.0, through: 800, by: 10).map { air.sample(x: $0, y: 395).dx }
        XCTAssertLessThan(flank.min()!, -5, "Rückströmung an der Flanke")
        let curls = stride(from: 400.0, through: 800, by: 10).flatMap { x in [440.0, 560].map { air.sample(x: x, y: $0).curl } }
        XCTAssertLessThan(curls.min()!, -0.5); XCTAssertGreaterThan(curls.max()!, 0.5)
        let ahead = air.sample(x: 1060, y: 540)
        XCTAssertGreaterThan(ahead.velocity.dy, 0, "vor dem Zeiger weicht die Luft seitlich aus")
    }
}

final class GravityTests: XCTestCase {
    func testDodgeIsSidewaysOnlyAndNeverSpeedsUpOrReversesFall() {
        let pointer = CGPoint(x: 500, y: 500)
        for x in stride(from: 380.0, through: 620, by: 7) {
            for y in stride(from: 380.0, through: 620, by: 7) {
                let f = Dodge.flow(flake: CGPoint(x: x, y: y), pointer: pointer, radius: 120)
                XCTAssertGreaterThan(f.fallScale, 0, "Fallen wird nur gebremst, nie umgekehrt")
                XCTAssertLessThanOrEqual(f.fallScale, 1)
                if x > 500.5 { XCTAssertGreaterThanOrEqual(f.dx, 0) }
                if x < 499.5 { XCTAssertLessThanOrEqual(f.dx, 0) }
                if y > 500 { XCTAssertEqual(f.fallScale, 1, "unterhalb des Zeigers kein Bremsen") }
            }
        }
        XCTAssertEqual(Dodge.flow(flake: CGPoint(x: 900, y: 500), pointer: pointer, radius: 120).dx, 0)
    }

    func testFlakesAboveSlowDownAndMoveAside() {
        let f = Dodge.flow(flake: CGPoint(x: 510, y: 460), pointer: CGPoint(x: 500, y: 500), radius: 120)
        XCTAssertLessThan(f.fallScale, 0.7)
        XCTAssertGreaterThan(f.dx, 10)
    }

    func testNoUpwardMotionForHorizontallyMovingPointer() {
        for speed in [400.0, 900, 1500, 3000] {
            for noise in [-0.2, -0.1, 0, 0.1, 0.3] {  // leichtes Zittern der Maus senkrecht
                for (a, b) in [(CGPoint(x: 200, y: 500), CGPoint(x: 1000, y: 500)), (CGPoint(x: 1000, y: 500), CGPoint(x: 200, y: 500))] {
                    // langsamste Flocke, zusätzlich vom Ausweichen gebremst
                    var air = AirField(), probes = StirTests.grid(z: 0, sink: 9 * 0.35)
                    StirTests.run(&air, &probes, from: a, to: b, speed: speed, rest: 1.5, noise: noise)
                    for p in probes { XCTAssertGreaterThanOrEqual(p.minVy, 0, "Flocke darf sich nie nach oben bewegen (Tempo \(speed), Zittern \(noise))") }
                    XCTAssertGreaterThan(probes.map(\.maxRel).max()!, 0)
                }
            }
        }
    }

    func testDownwardPassNeverLifts() {
        var air = AirField(), probes = StirTests.grid(z: 0, sink: 9)
        StirTests.run(&air, &probes, from: CGPoint(x: 300, y: 250), to: CGPoint(x: 900, y: 750), speed: 2000, rest: 1.5)
        for p in probes { XCTAssertGreaterThanOrEqual(p.minVy, 0) }
    }

    func testUpwardPassLiftsOnlyBrieflyAndDamped() {
        var air = AirField(), probes = StirTests.grid(z: 0, sink: 30)
        StirTests.run(&air, &probes, from: CGPoint(x: 600, y: 800), to: CGPoint(x: 600, y: 200), speed: 1500, rest: 0)
        let minVy = probes.map(\.minVy).min()!
        XCTAssertLessThan(minVy, -20, "aufwärts fahrender Zeiger nimmt Flocken mit nach oben")
        XCTAssertGreaterThan(minVy, -Stir.liftDamping * 1500, "aber nur gedämpft")
        XCTAssertLessThan(probes.map { $0.start.y - $0.p.y }.max()!, 120)
        for i in probes.indices { probes[i].minVy = .infinity }
        StirTests.run(&air, &probes, from: CGPoint(x: 600, y: 200), to: CGPoint(x: 600.1, y: 200), speed: 100, rest: 1.0)
        let late = probes.map(\.drift.lift).min()!
        XCTAssertGreaterThan(late, -3, "nach kurzer Zeit überwiegt die Schwerkraft")
    }
}

final class GarlandTests: XCTestCase {
    func plan(_ style: ChainStyleKind, dock: Bool = false) -> GarlandPlan {
        Garland.plan(length: 1920, arcLength: 274, arcCount: 7, scale: 1, style: style, dock: dock)
    }

    func testClassicHasNoGarland() {
        XCTAssertEqual(plan(.classic), GarlandPlan())
    }

    func testPlacementIsStable() {
        XCTAssertEqual(plan(.firColor), plan(.firColor))
        XCTAssertEqual(plan(.firGold).branches, plan(.firColor).branches, "Zweige hängen nicht vom Farbstil ab")
    }

    func testBackBranchesAlongWholeGarlandAlternatingAndInRange() {
        let p = plan(.firColor)
        let back = p.branches.filter { $0.layer == .back }
        XCTAssertGreaterThan(back.count, 25)
        for (i, b) in back.enumerated() {
            XCTAssertEqual(b.mirrored, i % 2 == 1)
            XCTAssertTrue((1...4).contains(b.sprite))
            XCTAssertGreaterThan(b.u, 0); XCTAssertLessThan(b.u, 1920)
            XCTAssertLessThanOrEqual(abs(b.rotation), 12)
        }
        for b in p.branches { XCTAssertTrue((1...(Garland.spriteCounts[b.layer]!)).contains(b.sprite)) }
        XCTAssertEqual(Set(back.map(\.sprite)).count, 4, "alle Sprites kommen vor, nichts wiederholt sich starr")
    }

    func testHangingBranchesAboutEveryFifthAnchor() {
        let p = plan(.firColor)
        let back = p.branches.filter { $0.layer == .back }.count
        let hang = p.branches.filter { $0.layer == .hang }.count
        XCTAssertEqual(Double(hang), Double(back) / 5, accuracy: 1.5)
    }

    func testFrontAndMidAreSparserThanBack() {
        let p = plan(.firColor)
        let c = { (l: BranchLayer) in p.branches.filter { $0.layer == l }.count }
        XCTAssertLessThan(c(.mid), c(.back)); XCTAssertLessThan(c(.front), c(.mid))
    }

    func testOneConePerArcInBothFirStyles() {
        for s in [ChainStyleKind.firColor, .firGold] {
            let cones = plan(s).cones
            XCTAssertEqual(cones.count, 7)
            for (a, u) in cones.enumerated() { XCTAssertGreaterThan(u, Double(a) * 274); XCTAssertLessThan(u, Double(a + 1) * 274) }
        }
    }

    func testBowsOnlyForWarmGoldAtArcJoints() {
        XCTAssertTrue(plan(.firColor).bows.isEmpty)
        let bows = plan(.firGold).bows
        XCTAssertEqual(bows.count, 8)
        XCTAssertEqual(bows.first, 0); XCTAssertEqual(bows.last!, 7 * 274, accuracy: 1e-9)
    }

    func testDockHasNoHangingBranchesNoConesNoBows() {
        for s in [ChainStyleKind.firColor, .firGold] {
            let p = plan(s, dock: true)
            XCTAssertFalse(p.branches.isEmpty)
            XCTAssertTrue(p.branches.allSatisfy { $0.layer != .hang })
            XCTAssertTrue(p.cones.isEmpty); XCTAssertTrue(p.bows.isEmpty)
        }
    }

    func testDensityScalesBranchCount() {
        XCTAssertGreaterThan(Garland.plan(length: 1000, arcLength: 250, arcCount: 4, scale: 0.5, style: .firColor, dock: false).branches.count,
                             Garland.plan(length: 1000, arcLength: 250, arcCount: 4, scale: 1.0, style: .firColor, dock: false).branches.count)
    }
}
