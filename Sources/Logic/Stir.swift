import CoreGraphics
import Foundation

/// Zeigertempo aus Mausereignissen, geglättet (pt/s).
struct PointerVelocityTracker {
    private(set) var velocity = CGVector.zero
    private var last: (t: Double, p: CGPoint)?
    var smoothing = 0.045

    mutating func feed(time t: Double, position p: CGPoint) {
        defer { last = (t, p) }
        guard let l = last, t > l.t else { return }
        let dt = max(t - l.t, 0.001)
        if dt > 0.25 { velocity = .zero; return }
        let raw = CGVector(dx: (p.x - l.p.x) / dt, dy: (p.y - l.p.y) / dt)
        let a = 1 - exp(-dt / smoothing)
        velocity = CGVector(dx: velocity.dx + (raw.dx - velocity.dx) * a, dy: velocity.dy + (raw.dy - velocity.dy) * a)
    }

    /// Tempo zum Zeitpunkt t: ohne neue Ereignisse klingt es ab.
    func speed(at t: Double) -> Double {
        guard let l = last else { return 0 }
        let idle = t - l.t
        if idle > 0.12 { return 0 }
        return hypot(velocity.dx, velocity.dy)
    }

    mutating func reset() { self = PointerVelocityTracker() }
}

/// Aufstöbern: schnelle Zeigerbewegung reißt Flocken mit.
enum Stir {
    static let minSpeed = 350.0
    static let fullSpeed = 1600.0

    /// 0 bei langsamer Bewegung, 1 bei sehr schneller.
    static func strength(speed: Double) -> Double {
        let t = min(max((speed - minSpeed) / (fullSpeed - minSpeed), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Einflussradius um die Bewegungsbahn: je schneller, desto mehr Flocken.
    static func radius(strength s: Double) -> Double { 80 + 100 * s }

    /// Impuls auf eine Flocke in Bildschirmkoordinaten mit y nach unten (nach oben ist dy negativ).
    /// `jitter` in -1...1 streut die Stärke leicht.
    static func impulse(flake: CGPoint, from a: CGPoint, to b: CGPoint, velocity v: CGVector, jitter: Double = 0) -> CGVector? {
        let speed = hypot(v.dx, v.dy)
        let s = strength(speed: speed)
        guard s > 0 else { return nil }
        let R = radius(strength: s)
        let d = Dodge.distance(from: flake, toSegment: a, b)
        guard d < R else { return nil }
        let fall = 1 - d / R
        let falloff = fall * fall * (3 - 2 * fall)
        let ux = Double(v.dx) / speed, uy = Double(v.dy) / speed
        let carry = min(speed * 0.55, 900) * falloff * (1 + 0.25 * jitter)
        // überwiegend waagerecht. Aufwärts nur, wenn der Zeiger selbst deutlich nach oben fährt, dann kurz und schwach.
        var dy: Double
        if uy < -0.35 { dy = uy * carry * 0.35 } else { dy = max(0, uy * carry * 0.5) }
        let dx = ux * carry
        return CGVector(dx: dx, dy: dy)
    }

    /// Senkrechte Geschwindigkeit (y nach unten): Fallen mal Bremsfaktor plus Aufstöber-Anteil.
    /// Ohne nach oben gerichteten Aufstöber-Impuls ist das Ergebnis nie negativ.
    static func verticalVelocity(fall: Double, fallScale: Double, stirVy: Double) -> Double {
        fall * max(0, fallScale) + stirVy
    }

    /// Anteil der normalen Fallgeschwindigkeit nach `age` Sekunden: gebremst, nach etwa 1,8 s wieder normal.
    static func fallFactor(age: Double) -> Double {
        let t = min(max(age / 1.8, 0), 1)
        return 0.12 + 0.88 * t * t * (3 - 2 * t)
    }

    /// Wirbelgeschwindigkeit klingt exponentiell ab.
    static func decayed(_ v: CGVector, dt: Double) -> CGVector {
        let k = exp(-dt / 0.55)
        let ky = v.dy < 0 ? exp(-dt / 0.2) : k   // Aufwärtsanteil klingt schnell ab
        return CGVector(dx: v.dx * k, dy: v.dy * ky)
    }
}
