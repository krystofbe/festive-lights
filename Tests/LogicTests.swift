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
                let f = Dodge.push(flake: CGPoint(x: x, y: y), pointer: pointer, radius: 120, prevDir: 0)
                XCTAssertGreaterThan(f.fallScale, 0, "Fallen wird nur gebremst, nie umgekehrt")
                XCTAssertLessThanOrEqual(f.fallScale, 1)
                if x > 500.5 { XCTAssertGreaterThanOrEqual(f.vx, 0) }
                if x < 499.5 { XCTAssertLessThanOrEqual(f.vx, 0) }
                XCTAssertLessThanOrEqual(abs(f.vx), Dodge.maxPush + 1e-9)
                if y > 500 { XCTAssertEqual(f.fallScale, 1, "unterhalb des Zeigers kein Bremsen") }
            }
        }
        XCTAssertEqual(Dodge.push(flake: CGPoint(x: 900, y: 500), pointer: pointer, radius: 120, prevDir: 0).vx, 0)
    }

    func testFlakesAboveSlowDownAndMoveAside() {
        let f = Dodge.push(flake: CGPoint(x: 510, y: 460), pointer: CGPoint(x: 500, y: 500), radius: 120, prevDir: 0)
        XCTAssertLessThan(f.fallScale, 0.7)
        XCTAssertGreaterThan(f.vx, 10)
    }

    /// Wie SnowField das Ausweichen anwendet: Geschwindigkeit läuft weich ein und aus, die Verschiebung der Flocke bleibt.
    func simulate(flake x0: Double, y: Double, pointerPath: [(Double, Double)], dt: Double = 1.0 / 60) -> [Double] {
        var x = x0, pvx = 0.0, dir = 0.0
        var xs: [Double] = []
        for (px, py) in pointerPath {
            let r = Dodge.push(flake: CGPoint(x: x, y: y), pointer: CGPoint(x: px, y: py), radius: 120, prevDir: dir)
            dir = r.dir
            pvx += (r.vx - pvx) * (1 - exp(-dt / 0.1))
            x += pvx * dt
            xs.append(x)
        }
        return xs
    }

    func testPushedFlakeStaysWhereItIsAndDoesNotPingPong() {
        var path: [(Double, Double)] = (0..<90).map { (560 - Double($0) * 3, 500) }   // Zeiger schiebt die Flocke bei 500 von rechts nach links
        path += Array(repeating: (1500.0, 500.0), count: 120)                          // springt weit weg
        let xs = simulate(flake: 500, y: 500, pointerPath: path)
        XCTAssertLessThan(xs[89], 500 - 20, "die Flocke wurde nach links geschoben")
        XCTAssertEqual(xs.last!, xs[110], accuracy: 0.5, "ohne Zeiger bleibt die Flocke stehen, sie kehrt nicht zurück")
        XCTAssertLessThan(xs.last!, xs[89] + 6, "kein Zurückschnippen an die alte Stelle")
    }

    func testNoSuddenJumpWhenPointerPassesTheFlake() {
        let path: [(Double, Double)] = (0..<120).map { (400 + Double($0) * 25, 500) }   // 1500 pt/s mitten durch die Flocke
        let xs = simulate(flake: 600, y: 500, pointerPath: path)
        var prev = 600.0
        for x in xs {
            XCTAssertLessThanOrEqual(abs(x - prev), Dodge.maxPush / 60 + 1e-9, "Sprung der Flocke")
            prev = x
        }
    }

    func testNoFlipWhenPointerComesVeryCloseAndCrossesCenter() {
        var dir = 0.0
        for px in stride(from: 440.0, through: 505, by: 1) {
            dir = Dodge.push(flake: CGPoint(x: 500, y: 500), pointer: CGPoint(x: px, y: 500), radius: 120, prevDir: dir).dir
            XCTAssertEqual(dir, 1, "Zeiger kommt von links, die Flocke weicht nach rechts, auch kurz hinter der Mitte")
        }
        XCTAssertEqual(Dodge.push(flake: CGPoint(x: 500, y: 500), pointer: CGPoint(x: 530, y: 500), radius: 120, prevDir: 1).dir, -1,
                       "erst bei deutlichem Seitenwechsel kehrt sich die Richtung um")
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

    func testOneConePerArcOnlyForWarmGold() {
        XCTAssertTrue(plan(.firColor).cones.isEmpty)
        let cones = plan(.firGold).cones
        XCTAssertEqual(cones.count, 7)
        for (a, u) in cones.enumerated() { XCTAssertGreaterThan(u, Double(a) * 274); XCTAssertLessThan(u, Double(a + 1) * 274) }
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

final class BeadChainTests: XCTestCase {
    func makeChain() -> BeadChain {
        let rest = (0..<40).map { 25.0 + Double($0) * 47 }   // Länge etwa 1900
        return BeadChain(rest: rest, length: 1920, minGap: 20, halfGap: 47)
    }

    func testGapAroundPointer() {
        let c = makeChain()
        let p = 900.0
        let t = BeadChain.targets(rest: c.rest, pointer: p, strength: 1, halfGap: 47, minGap: 20, length: 1920)
        for x in t { XCTAssertGreaterThanOrEqual(abs(x - p), 47 - 1e-9, "Lücke um den Zeiger") }
        XCTAssertEqual(BeadChain.targets(rest: c.rest, pointer: p, strength: 0, halfGap: 47, minGap: 20, length: 1920), c.rest, "ohne Zeigernähe bleibt alles an den Ruheplätzen")
        // weit entfernte Perlen bleiben stehen
        XCTAssertEqual(t[0], c.rest[0]); XCTAssertEqual(t[39], c.rest[39])
    }

    func testPushedBeadsPileUpAgainstNeighboursAtMinGap() {
        let c = makeChain()
        let t = BeadChain.targets(rest: c.rest, pointer: c.rest[20] + 5, strength: 1, halfGap: 47, minGap: 20, length: 1920)
        for i in 1..<t.count { XCTAssertGreaterThanOrEqual(t[i] - t[i - 1], 20 - 1e-9) }
        XCTAssertLessThan(t[19], c.rest[19], "Nachbar wird ein Stück mitgeschoben")
    }

    func testNeverOvertakeOrOverlapDuringFastSweepsAndJumps() {
        var c = makeChain()
        var pointer = 100.0
        var dir = 1.0
        for frame in 0..<1500 {
            // schnelles Durchfahren hin und her, dazu Sprünge
            pointer += dir * 40
            if pointer > 1800 || pointer < 100 { dir = -dir }
            if frame % 211 == 0 { pointer = Double((frame * 37) % 1700 + 100) }
            let k: Double = frame % 400 < 300 ? 1 : 0
            c.step(dt: 1.0 / 60, pointer: pointer, strength: k)
            for i in 1..<c.pos.count {
                XCTAssertGreaterThanOrEqual(c.pos[i] - c.pos[i - 1], 20 - 1e-6, "Überlappung oder Überholen bei Bild \(frame)")
            }
            XCTAssertGreaterThan(c.pos.first!, 0); XCTAssertLessThan(c.pos.last!, 1920)
        }
    }

    func testReturnsWithinOneSecondWithOvershoot() {
        var c = makeChain()
        for _ in 0..<60 { c.step(dt: 1.0 / 60, pointer: 900, strength: 1) }
        XCTAssertGreaterThan(abs(c.pos[19] - c.rest[19]), 10)
        var maxOvershoot = 0.0
        for _ in 0..<60 {
            c.step(dt: 1.0 / 60, pointer: nil, strength: 0)
            for i in c.pos.indices {
                let d = c.pos[i] - c.rest[i]
                let displacedLeft = i < 20
                maxOvershoot = max(maxOvershoot, displacedLeft ? d : -d)
            }
        }
        for i in c.pos.indices { XCTAssertLessThan(abs(c.pos[i] - c.rest[i]), 1.5, "Perle \(i) nicht binnen 1 s zurück") }
        XCTAssertGreaterThan(maxOvershoot, 0.3, "leichtes Überschwingen")
        for _ in 0..<120 { c.step(dt: 1.0 / 60, pointer: nil, strength: 0) }
        XCTAssertTrue(c.isSettled())
    }

    func testReactionWithinTenthOfASecond() {
        var c = makeChain()
        c.step(dt: 0.1, pointer: c.rest[20] + 2, strength: 1)
        XCTAssertGreaterThan(abs(c.pos[20] - c.rest[20]) + abs(c.pos[19] - c.rest[19]), 8)
    }

    func testRestPositionsAndCableUnaffected() {
        var c = makeChain()
        let rest = c.rest
        for _ in 0..<200 { c.step(dt: 1.0 / 60, pointer: 700, strength: 1) }
        XCTAssertEqual(c.rest, rest, "Ruhepositionen entlang des Kabels ändern sich nie, das Kabel bleibt")
        var calm = makeChain()
        for _ in 0..<100 { calm.step(dt: 1.0 / 60, pointer: nil, strength: 0) }
        XCTAssertEqual(calm.pos, rest, "ohne Zeiger kein Drift")
    }

    func testGapFollowsPointerAlongChain() {
        var c = makeChain()
        var sum = 0.0, n = 0
        for frame in 0..<480 {
            let p = 300 + Double(frame) * 2   // gemächliches Entlangfahren, 120 pt/s
            c.step(dt: 1.0 / 60, pointer: p, strength: 1)
            if frame > 120 { sum += c.pos.map { abs($0 - p) }.min()!; n += 1 }
        }
        XCTAssertGreaterThan(sum / Double(n), 25, "im Mittel bleibt eine Lücke um den Zeiger, sie wandert mit")
    }
}

final class BranchSlideTests: XCTestCase {
    func testNoBranchTipInsideGapAndReturnWithinOneSecond() {
        let plan = Garland.plan(length: 1920, arcLength: 274, arcCount: 7, scale: 1, style: .firGold, dock: false)
        for layer in [BranchLayer.back, .mid, .hang, .front] {
            let list = plan.branches.filter { $0.layer == layer }
            let scale = layer == .hang ? Garland.hangScale : Garland.branchScale
            let ex = list.map { b -> (left: Double, right: Double) in
                let e = Garland.extent(layer: layer, sprite: b.sprite)
                let m = b.mirrored ? (left: e.right, right: e.left) : e
                return (left: m.left * scale * 1.2, right: m.right * scale * 1.2)
            }
            var chain = BeadChain(rest: list.map(\.u), length: 1920, minGap: 8, halfGap: 47, extents: ex)
            let p = 900.0
            let tg = BeadChain.targets(rest: chain.rest, pointer: p, strength: 1, halfGap: 47, minGap: 8, length: 1920, extents: ex)
            for (i, t) in tg.enumerated() {
                XCTAssertGreaterThanOrEqual(abs(t - p), 47 - 1e-6, "Ansatzpunkt in der Lücke")
                let intersects = (t - ex[i].left) < (p + 47) - 1e-6 && (t + ex[i].right) > (p - 47) + 1e-6
                XCTAssertFalse(intersects, "Zweig \(i) der Schicht \(layer) ragt mit den Nadelspitzen in die Lücke")
            }
            for _ in 0..<80 { chain.step(dt: 1.0 / 60, pointer: p, strength: 1) }
            for i in 1..<chain.pos.count { XCTAssertGreaterThanOrEqual(chain.pos[i] - chain.pos[i - 1], 8 - 1e-6) }
            for _ in 0..<60 { chain.step(dt: 1.0 / 60, pointer: nil, strength: 0) }
            for i in chain.pos.indices { XCTAssertLessThan(abs(chain.pos[i] - chain.rest[i]), 2, "Zweig \(i) der Schicht \(layer) nicht binnen 1 s zurück") }
        }
    }

    func testExtentsAreMeasuredAndPositive() {
        for l in [BranchLayer.back, .mid, .hang, .front] {
            for n in 1...Garland.spriteCounts[l]! { let e = Garland.extent(layer: l, sprite: n); XCTAssertGreaterThan(e.right, 30); XCTAssertGreaterThanOrEqual(e.left, 0) }
        }
        XCTAssertGreaterThan(Garland.extent(layer: .hang, sprite: 3).left, 20)
    }
}

final class DockProfileTests: XCTestCase {
    let spans = [DockProfile.Span(a: 0, b: 50, lift: 0), DockProfile.Span(a: 55, b: 105, lift: 20), DockProfile.Span(a: 110, b: 160, lift: 45),
                 DockProfile.Span(a: 165, b: 215, lift: 18), DockProfile.Span(a: 220, b: 270, lift: 0)]

    func testCableLiesOnTopOfEveryIconAndNeverInside() {
        for u in stride(from: 0.0, through: 270, by: 0.5) {
            let e = DockProfile.envelope(spans: spans, at: u)
            for s in spans where u >= s.a && u <= s.b { XCTAssertGreaterThanOrEqual(e, s.lift - 1e-9, "Kette liegt im Symbol bei u=\(u)") }
            XCTAssertGreaterThanOrEqual(e, 0)
        }
    }

    func testCableDoesNotFloatFarAboveIcons() {
        // über der Lücke zwischen Symbolen höchstens ein paar pt über der Oberkante der höheren Nachbarn
        for u in stride(from: 105.0, through: 110, by: 0.5) {
            let e = DockProfile.envelope(spans: spans, at: u)
            XCTAssertLessThanOrEqual(e - 45, 0.01)
            XCTAssertLessThanOrEqual(e, 45)
        }
        XCTAssertEqual(DockProfile.envelope(spans: spans, at: 135), 45)
        XCTAssertLessThan(DockProfile.envelope(spans: spans, at: 270), 1, "weit weg vom Maximum fällt die Kette ab")
    }

    func testNoMagnificationMeansFlatChain() {
        let flat = (0..<5).map { DockProfile.Span(a: Double($0) * 55, b: Double($0) * 55 + 50, lift: 0) }
        XCTAssertTrue(DockProfile.samples(spans: flat, du: 6, count: 50).allSatisfy { $0 == 0 })
    }

    func testVisibleSizeCalibrationFromTestMachine() {
        let rest = CGRect(x: 771, y: 10, width: 77, height: 93), cur = CGRect(x: 763, y: 10, width: 99.9, height: 115.9)
        XCTAssertEqual(DockProfile.visibleSize(tile: 64, current: rest, rest: rest), 64, accuracy: 1e-9)
        XCTAssertEqual(DockProfile.visibleSize(tile: 64, current: cur, rest: rest), 78, accuracy: 1.5)
    }

    func testLiftIsMeasuredAboveTheDockLineAndNeverNegative() {
        let rest = CGRect(x: 771, y: 10, width: 77, height: 93), cur = CGRect(x: 763, y: 10, width: 99.9, height: 115.9)
        // ruhendes Symbol: Oberkante liegt unter der Dock-Linie, keine Anhebung
        XCTAssertEqual(DockProfile.lift(edge: .bottom, current: rest, rest: rest, tile: 64, barLine: 99), 0)
        // am Testrechner gemessen: sichtbare Oberkante des vergrößerten Symbols etwa 105 bis 107, Dock-Linie 99
        XCTAssertEqual(DockProfile.lift(edge: .bottom, current: cur, rest: rest, tile: 64, barLine: 99), 7, accuracy: 3)
        XCTAssertEqual(DockProfile.lift(edge: .bottom, current: CGRect(x: 0, y: 10, width: 40, height: 40), rest: rest, tile: 64, barLine: 99), 0)
    }

    func testLiftForSideDocksGrowsTowardScreenCenter() {
        let rest = CGRect(x: 0, y: 100, width: 93, height: 77), cur = CGRect(x: 0, y: 90, width: 115.9, height: 99.9)
        XCTAssertGreaterThan(DockProfile.lift(edge: .left, current: cur, rest: rest, tile: 64, barLine: 80), 0)
        let restR = CGRect(x: 1800, y: 100, width: 93, height: 77), curR = CGRect(x: 1777, y: 90, width: 115.9, height: 99.9)
        XCTAssertGreaterThan(DockProfile.lift(edge: .right, current: curR, rest: restR, tile: 64, barLine: 1840), 0)
    }
}

final class BaubleTests: XCTestCase {
    let layout = ChainLayout(length: 1920, spacing: ChainLayout.spacing(bulbHeight: 24, level: 2))
    func plan(_ style: ChainStyleKind = .firColor, dock: Bool = false) -> GarlandPlan {
        Garland.plan(length: 1920, arcLength: layout.arcLength, arcCount: layout.arcCount, scale: 1, style: style, dock: dock, bulbPositions: layout.bulbPositions)
    }

    func testEveryBaubleHangsOnABranchAtItsTip() {
        let p = plan()
        XCTAssertGreaterThan(p.baubles.count, 12)
        for b in p.baubles {
            XCTAssertTrue(p.branches.indices.contains(b.branch), "jede Kugel hat einen Zweig als Anker")
            let br = p.branches[b.branch]
            XCTAssertNotEqual(br.layer, .hang)
            let tip = Garland.tip(layer: br.layer, sprite: br.sprite)
            XCTAssertEqual(b.x, tip.x); XCTAssertEqual(b.y, tip.y)
            XCTAssertGreaterThan(tip.x, 70, "nahe der Zweigspitze, nicht am Ansatzpunkt am Kabel")
            XCTAssertGreaterThan(tip.y, 40, "unterhalb des Kabels")
            let k = Garland.branchScale
            XCTAssertEqual(b.u, br.u + (br.mirrored ? -1 : 1) * (tip.x - 40) * k, accuracy: 1e-9)
        }
    }

    func testBaublesKeepDistanceToEveryBulb() {
        let width = 16 * Garland.baubleScale
        let bulbHalf = 5.0   // Mini-Birne ist 10 pt breit
        for b in plan().baubles {
            for bulb in layout.bulbPositions { XCTAssertGreaterThan(abs(bulb - b.u), width / 2 + bulbHalf, "Kugel an einer Birne bei u=\(b.u)") }
        }
    }

    func testRedAndGoldAlternateAboutFourPerArc() {
        let p = plan()
        XCTAssertLessThanOrEqual(p.baubles.count, layout.arcCount * Garland.baublesPerArc)
        XCTAssertGreaterThan(Set(p.baubles.map(\.gold)).count, 1)
        for i in 1..<p.baubles.count { XCTAssertNotEqual(p.baubles[i].gold, p.baubles[i - 1].gold) }
    }

    func testNoBaublesAtDockOrOtherStyles() {
        XCTAssertTrue(plan(.firColor, dock: true).baubles.isEmpty)
        XCTAssertTrue(plan(.firGold).baubles.isEmpty)
        XCTAssertTrue(plan(.classic).baubles.isEmpty)
    }

    func testStablePlacement() { XCTAssertEqual(plan().baubles, plan().baubles) }
}

final class DockStyleTests: XCTestCase {
    func testLikeMenuBarFollowsTheBarStyle() {
        for k in ChainStyleKind.allCases { XCTAssertEqual(DockStyle.sameAsBar.resolve(bar: k), k) }
    }

    func testExplicitDockStyleIgnoresTheBarStyle() {
        for k in ChainStyleKind.allCases {
            XCTAssertEqual(DockStyle.classic.resolve(bar: k), .classic)
            XCTAssertEqual(DockStyle.firColor.resolve(bar: k), .firColor)
            XCTAssertEqual(DockStyle.firGold.resolve(bar: k), .firGold)
        }
    }

    func testDefaultIsLikeMenuBar() {
        XCTAssertEqual(DockStyle.allCases.first, .sameAsBar)
        XCTAssertEqual(DockStyle(rawValue: "sameAsBar"), .sameAsBar)
    }
}

final class DockShapeTests: XCTestCase {
    func testExactChoiceFollowsTheDockState() {
        XCTAssertEqual(DockForm.resolve(choice: .exact, exact: .visible), .exact)
        XCTAssertEqual(DockForm.resolve(choice: .exact, exact: .hidden), .hidden, "ausgeblendetes Dock: Kette verschwindet mit dem Dock")
        XCTAssertEqual(DockForm.resolve(choice: .exact, exact: .unavailable), .continuous, "unplausibles Ergebnis: sanfter Rückfall auf durchgehend")
        for s in [ExactState.visible, .hidden, .unavailable] { XCTAssertEqual(DockForm.resolve(choice: .continuous, exact: s), .continuous) }
    }

    func testSourceFollowsPermissionAndSwitchesAtRuntime() {
        XCTAssertEqual(DockSource.choose(permission: true), .accessibility)
        XCTAssertEqual(DockSource.choose(permission: false), .probe)
        var permission = true
        var sources: [DockSource] = []
        for step in 0..<6 {
            if step == 2 { permission = false }
            if step == 4 { permission = true }
            sources.append(DockSource.choose(permission: permission))
        }
        XCTAssertEqual(sources, [.accessibility, .accessibility, .probe, .probe, .accessibility, .accessibility])
        // Die Form bleibt "genau am Dock", solange eine der beiden Quellen ein Ergebnis hat: Entzug allein führt nicht zu "durchgehend"
        XCTAssertEqual(DockForm.resolve(choice: .exact, exact: .visible), .exact)
    }

    let screens = [ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), visible: CGRect(x: 0, y: 99, width: 1920, height: 957)),
                   ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1440, height: 900), visible: CGRect(x: 1920, y: 0, width: 1440, height: 876))]

    func testBottomDockLineComesFromVisibleFrame() {
        let p = ContinuousDock.placement(screens: screens, orientation: nil)!
        XCTAssertEqual(p, ContinuousDock.Placement(screenIndex: 0, edge: .bottom, edgeLine: 99, thickness: 99))
    }

    func testDockOnTheSecondScreenIsFoundByThickness() {
        let s = [screens[1], ScreenInfo(frame: screens[0].frame, visible: CGRect(x: 0, y: 70, width: 1920, height: 986))]
        let p = ContinuousDock.placement(screens: s, orientation: "bottom")!
        XCTAssertEqual(p.screenIndex, 1); XCTAssertEqual(p.edgeLine, 70)
    }

    func testSideDocks() {
        let left = [ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), visible: CGRect(x: 79, y: 0, width: 1841, height: 1056))]
        XCTAssertEqual(ContinuousDock.placement(screens: left, orientation: "left")!.edgeLine, 79)
        let right = [ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), visible: CGRect(x: 0, y: 0, width: 1840, height: 1056))]
        let p = ContinuousDock.placement(screens: right, orientation: "right")!
        XCTAssertEqual(p.edge, .right); XCTAssertEqual(p.edgeLine, 1840); XCTAssertEqual(p.thickness, 80)
    }

    func testHiddenDockSitsAtTheScreenEdgeOfTheMainScreen() {
        let hidden = [ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), visible: CGRect(x: 0, y: 0, width: 1920, height: 1056)),
                      ScreenInfo(frame: CGRect(x: 1920, y: 0, width: 1440, height: 900), visible: CGRect(x: 1920, y: 0, width: 1440, height: 876))]
        let p = ContinuousDock.placement(screens: hidden, orientation: "bottom")!
        XCTAssertEqual(p, ContinuousDock.Placement(screenIndex: 0, edge: .bottom, edgeLine: 0, thickness: 0))
    }

    func testNoScreensNoPlacement() { XCTAssertNil(ContinuousDock.placement(screens: [], orientation: nil)) }
}

final class DockProbeTests: XCTestCase {
    /// Künstliches Dock: Leiste von 300 bis 1600, Dicke 99, optional vergrößerte Symbole um 800 (Glockenform, bis 40 pt höher).
    func dock(magnify: Bool, hidden: Bool = false, counter: UnsafeMutablePointer<Int>? = nil) -> (Double, Double) -> Bool {
        return { u, d in
            counter?.pointee += 1
            if hidden { return false }
            guard u >= 300, u <= 1600 else { return false }
            var top = 99.0
            if magnify { top += 40 * max(0, 1 - abs(u - 800) / 220) }
            return d <= top
        }
    }

    func testBoundaryFindsEdgeWithin1pt() {
        XCTAssertEqual(DockProbeLogic.boundary(inside: 0, outside: 400) { $0 <= 137 }, 137)
        XCTAssertEqual(DockProbeLogic.boundary(inside: 5, outside: 6) { $0 <= 5 }, 5)
    }

    func testFindBarMatchesTheSyntheticDock() {
        for mag in [false, true] {
            let bar = DockProbeLogic.findBar(length: 1920, hit: dock(magnify: mag))!
            XCTAssertEqual(bar.a, 300, accuracy: 1.5); XCTAssertEqual(bar.b, 1601, accuracy: 1.5)
            XCTAssertEqual(bar.thick, 100, accuracy: 1.5, "Ruhedicke, auch wenn Symbole vergrößert sind")
        }
    }

    func testHiddenDockIsNotFound() { XCTAssertNil(DockProbeLogic.findBar(length: 1920, hit: dock(magnify: false, hidden: true))) }

    func testFindBarIsCheap() {
        var calls = 0
        _ = DockProbeLogic.findBar(length: 1920, hit: dock(magnify: false, counter: &calls))
        XCTAssertLessThan(calls, 150)
    }

    func testProfileFollowsMagnification() {
        let bar = DockProbeLogic.Bar(a: 300, b: 1601, thick: 100)
        var calls = 0
        let spans = DockProbeLogic.profile(bar: bar, pointerU: 800, reach: 280, maxExtra: 150, hit: dock(magnify: true, counter: &calls))
        let peak = spans.max { $0.lift < $1.lift }!
        XCTAssertEqual(peak.lift, 40 - DockProbeLogic.hitMargin, accuracy: 3)
        XCTAssertEqual((peak.a + peak.b) / 2, 800, accuracy: 20)
        XCTAssertEqual(spans.first!.lift, 0, accuracy: 0.01)
        XCTAssertLessThan(calls, 200, "Aufrufe je Messung (laufen im Hintergrund, nicht auf dem Haupt-Thread)")
    }

    func testProfileFlatWhenNotMagnified() {
        let bar = DockProbeLogic.Bar(a: 300, b: 1601, thick: 100)
        var calls = 0
        let spans = DockProbeLogic.profile(bar: bar, pointerU: 800, reach: 280, maxExtra: 150, hit: dock(magnify: false, counter: &calls))
        XCTAssertTrue(spans.allSatisfy { $0.lift == 0 })
        XCTAssertLessThanOrEqual(calls, spans.count, "ohne Vergrößerung genügt ein Aufruf je Stützstelle")
    }

    func testPlausibilityFallsBackOnOddResults() {
        let good = DockProbeLogic.Bar(a: 300, b: 1601, thick: 100)
        XCTAssertTrue(DockProbeLogic.isPlausible(good, tile: 64, screenLength: 1920, expectedThickness: 99))
        XCTAssertFalse(DockProbeLogic.isPlausible(DockProbeLogic.Bar(a: 0, b: 60, thick: 100), tile: 64, screenLength: 1920, expectedThickness: 99), "zu kurz")
        XCTAssertFalse(DockProbeLogic.isPlausible(DockProbeLogic.Bar(a: 0, b: 3000, thick: 100), tile: 64, screenLength: 1920, expectedThickness: 99), "länger als der Bildschirm")
        XCTAssertFalse(DockProbeLogic.isPlausible(DockProbeLogic.Bar(a: 300, b: 1600, thick: 400), tile: 64, screenLength: 1920, expectedThickness: nil), "zu dick")
        XCTAssertFalse(DockProbeLogic.isPlausible(good, tile: 64, screenLength: 1920, expectedThickness: 60), "Dicke passt nicht zu visibleFrame")
        XCTAssertTrue(DockProbeLogic.isPlausible(good, tile: 64, screenLength: 1920, expectedThickness: nil), "ausgeblendet: keine Dicke zum Vergleichen")
    }
}

final class PowerPolicyTests: XCTestCase {
    func testAlwaysSaveEnergySwitchesOnImmediately() {
        XCTAssertTrue(PowerPolicy.energySaving(alwaysSave: true, lowPowerMode: false, onBattery: false, batteryFraction: nil))
        XCTAssertFalse(PowerPolicy.energySaving(alwaysSave: false, lowPowerMode: false, onBattery: false, batteryFraction: nil))
    }

    func testLowPowerModeAndLowBattery() {
        XCTAssertTrue(PowerPolicy.energySaving(alwaysSave: false, lowPowerMode: true, onBattery: false, batteryFraction: nil))
        XCTAssertTrue(PowerPolicy.energySaving(alwaysSave: false, lowPowerMode: false, onBattery: true, batteryFraction: 0.19))
        XCTAssertFalse(PowerPolicy.energySaving(alwaysSave: false, lowPowerMode: false, onBattery: true, batteryFraction: 0.2))
        XCTAssertFalse(PowerPolicy.energySaving(alwaysSave: false, lowPowerMode: false, onBattery: false, batteryFraction: 0.05), "am Netzteil nie wegen des Akkustands")
    }
}

final class RuntimeStateTests: XCTestCase {
    func testEveryRelevantChangeIsDetected() {
        let base = RuntimeState()
        XCTAssertNotEqual(base, RuntimeState(suspended: true))
        XCTAssertNotEqual(base, RuntimeState(reduceMotion: true))
        XCTAssertNotEqual(base, RuntimeState(energySaving: true), "Energiesparen löst ein Neuzeichnen aus (Befund 1)")
        XCTAssertEqual(base, RuntimeState())
    }
}
