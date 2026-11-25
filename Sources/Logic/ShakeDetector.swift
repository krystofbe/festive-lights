import CoreGraphics

/// Erkennt Schütteln beim Ziehen: mindestens 3 Richtungswechsel innerhalb von 1 s,
/// danach löst jeder weitere Richtungswechsel einen Abschüttel-Schritt aus.
struct ShakeDetector {
    var threshold: CGFloat = 30
    var window: Double = 1.0

    private struct Axis {
        var dir = 0
        var extreme: CGFloat = 0
        var start: CGFloat = 0
        var started = false

        mutating func feed(_ p: CGFloat, threshold: CGFloat) -> Bool {
            if !started { started = true; start = p; extreme = p; return false }
            if dir == 0 {
                if abs(p - start) >= threshold { dir = p > start ? 1 : -1; extreme = p }
                return false
            }
            if (dir > 0 && p > extreme) || (dir < 0 && p < extreme) { extreme = p; return false }
            if abs(p - extreme) >= threshold {
                dir = -dir; extreme = p
                return true
            }
            return false
        }
    }

    private var x = Axis()
    private var y = Axis()
    private var reversals: [Double] = []
    private(set) var armed = false

    /// Gibt die Zahl neuer Abschüttel-Schritte zurück (0 oder 1).
    mutating func feed(time t: Double, position p: CGPoint) -> Int {
        let rx = x.feed(p.x, threshold: threshold)
        let ry = y.feed(p.y, threshold: threshold)
        guard rx || ry else { return 0 }
        if armed, let last = reversals.last, t - last > window { armed = false; reversals.removeAll() }
        reversals.append(t)
        reversals.removeAll { t - $0 > window }
        if armed { return 1 }
        if reversals.count >= 3 { armed = true }
        return 0
    }

    mutating func reset() { self = ShakeDetector(threshold: threshold, window: window) }
}
