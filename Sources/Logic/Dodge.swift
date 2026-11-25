import CoreGraphics
import Foundation

enum Dodge {
    /// Nähe 0...1 für den Abstand zum Kabel: 1 direkt am Zeiger, 0 ab `radius`.
    static func proximity(distance d: Double, radius: Double = 60) -> Double {
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

    struct Push { var vx: Double; var dir: Double; var fallScale: Double }

    /// Höchste Ausweichgeschwindigkeit einer Flocke in pt/s.
    static let maxPush = 280.0

    /// Schnee weicht dem Zeiger seitlich aus (Schwerkraft gewinnt immer): Die Flocke bekommt eine seitliche Geschwindigkeit weg vom
    /// Zeiger, die ausläuft, sobald sie die freie Zone verlassen hat. Die Verschiebung bleibt, die Flocke kehrt nie von selbst zurück.
    /// Flocken über dem Zeiger fallen langsamer. Nie senkrecht. Koordinaten mit y nach unten.
    /// `prevDir` hält die Richtung fest, damit sie nicht umspringt, wenn der Zeiger an der Flocke vorbeifährt (Umkehr erst bei
    /// deutlichem Seitenwechsel). Außerhalb des Radius ist `dir` 0.
    static func push(flake: CGPoint, pointer: CGPoint, radius R: Double, prevDir: Double, side: Double = 1) -> Push {
        let hx = Double(flake.x - pointer.x), vy = Double(flake.y - pointer.y)
        let d = hypot(hx, vy)
        guard R > 0, d < R else { return Push(vx: 0, dir: 0, fallScale: 1) }
        let t = 1 - d / R
        let w = t * t * (3 - 2 * t)
        var dir = prevDir
        if dir == 0 { dir = abs(hx) > 0.5 ? (hx > 0 ? 1 : -1) : (side >= 0 ? 1 : -1) }
        else if abs(hx) > 10 && (hx > 0 ? 1.0 : -1.0) != dir { dir = hx > 0 ? 1 : -1 }
        let hole = R * 0.55
        let speed = maxPush * w * max(0, 1 - abs(hx) / hole)
        return Push(vx: dir * speed, dir: dir, fallScale: vy < 0 ? 1 - 0.65 * w : 1)
    }
}

struct Spring {
    var value = 0.0
    var velocity = 0.0

    struct Params { var omega: Double; var zeta: Double }
    /// Pendeln der Birne.
    static let sway = Params(omega: 13, zeta: 0.28)
    /// Zweige biegen sich weich weg und federn zurück.
    static let branch = Params(omega: 10, zeta: 0.4)

    mutating func step(target: Double, dt: Double, params p: Params) {
        let n = max(1, Int(ceil(dt / 0.004)))
        let h = dt / Double(n)
        for _ in 0..<n {
            let a = -p.omega * p.omega * (value - target) - 2 * p.zeta * p.omega * velocity
            velocity += a * h
            value += velocity * h
        }
    }
}
