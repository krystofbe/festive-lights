import CoreGraphics
import Foundation

enum Dodge {
    /// Gewicht 0...1 für den Abstand zum Kabel: 1 direkt am Zeiger, 0 ab `radius`.
    static func liftWeight(distance d: Double, radius: Double = 60) -> Double {
        guard d < radius else { return 0 }
        let t = 1 - max(d, 0) / radius
        return t * t * (3 - 2 * t)
    }

    /// Abstand des Punktes zur Strecke a-b.
    static func distance(from p: CGPoint, toSegment a: CGPoint, _ b: CGPoint) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        let t = len2 == 0 ? 0 : max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return Double(hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy)))
    }

    /// Deckkraft der Birnen bei Gewicht w: bis auf 30 %.
    static func opacity(forWeight w: Double) -> Double { 1 - 0.7 * min(max(w, 0), 1) }

    /// Schneeflocken: verschobener Abstand zum Zeiger. Stetig, monoton, im Zentrum eine freie Zone von s*R.
    static func dodgedDistance(_ d: Double, radius R: Double, strength s: Double = 0.5) -> Double {
        guard d < R, R > 0 else { return d }
        let u = R - d
        return R - u * (1 - s * u / R)
    }
}

struct Spring {
    var value = 0.0
    var velocity = 0.0

    struct Params { var omega: Double; var zeta: Double }
    /// Schnelles Heben: gut gedämpft, reagiert in unter 0,1 s.
    static let attack = Params(omega: 70, zeta: 1.0)
    /// Senken in etwa 0,5 s mit leichtem Nachschwingen.
    static let release = Params(omega: 14, zeta: 0.55)
    /// Pendeln der Birne.
    static let sway = Params(omega: 13, zeta: 0.28)

    mutating func step(target: Double, dt: Double, params p: Params) {
        let n = max(1, Int(ceil(dt / 0.004)))
        let h = dt / Double(n)
        for _ in 0..<n {
            let a = -p.omega * p.omega * (value - target) - 2 * p.zeta * p.omega * velocity
            velocity += a * h
            value += velocity * h
        }
    }

    mutating func lift(target: Double, dt: Double) {
        step(target: target, dt: dt, params: target > value ? Spring.attack : Spring.release)
    }

    func isSettled(target: Double, eps: Double = 0.002) -> Bool {
        abs(value - target) < eps && abs(velocity) < eps * 4
    }
}
