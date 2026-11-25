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
        // ein großer Satz aus dem Stand ist keine Handbewegung: Der Zeiger wurde versetzt
        if hypot(p.x - l.p.x, p.y - l.p.y) > 150, hypot(velocity.dx, velocity.dy) < 1500 { velocity = .zero; return }
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

/// Aufstöbern: Der Zeiger schiebt keine Flocken an, er bewegt die Luft (`AirField`).
/// Jede Flocke nähert ihre Geschwindigkeit träge der Luft plus ihrem Sinken an (`Drift`).
enum Stir {
    static let minSpeed = 350.0
    static let fullSpeed = 1600.0
    /// Anteil des Zeigertempos, den die mitgerissene Luft annimmt.
    static let entrain = 0.7
    /// Obergrenze der Luftgeschwindigkeit (pt/s), auch wenn sich Bahnen überlagern.
    static let maxAir = 1400.0
    /// Lebensdauer eines Luftpakets: Der Nachlauf ist nach etwa 1 s ruhig.
    static let life = 1.0
    /// Dauer des kräftigen Schwalls direkt hinter dem Zeiger.
    static let gustTime = 0.12
    static let maxPuffs = 40
    /// Aufwind hinter einem aufwärts fahrenden Zeiger hebt Flocken nur gedämpft und kurz.
    static let liftDamping = 0.4, liftTime = 0.3

    /// 0 bei langsamer Bewegung, 1 bei sehr schneller.
    static func strength(speed: Double) -> Double {
        let t = min(max((speed - minSpeed) / (fullSpeed - minSpeed), 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Radius eines Luftpakets: je schneller, desto mehr Flocken.
    static func radius(strength s: Double) -> Double { 45 + 45 * s }

    /// Relaxationszeit einer Flocke (s). Tiefe 0 = klein und leicht, 1 = groß: Kleine folgen der Luft schneller.
    static func relaxation(depth z: Double) -> Double { 0.08 + 0.16 * min(max(z, 0), 1) }

    /// Bewegung einer Flocke relativ zu ihrem Sinken.
    struct Drift {
        var vx = 0.0, vy = 0.0, lift = 0.0, spin = 0.0
        var isZero: Bool { vx == 0 && vy == 0 && lift == 0 && spin == 0 }

        /// Ein Zeitschritt. Liefert die Geschwindigkeit der Flocke samt Sinken (y nach unten).
        /// Die Geschwindigkeit ist immer ein gewichtetes Mittel der bisher gespürten Luft, also nie schneller als diese.
        mutating func step(air: AirField.Sample, sink: Double, tau: Double, dt: Double) -> CGVector {
            let k = 1 - exp(-dt / tau)
            vx += (air.dx - vx) * k
            // Aufwind teilt sich in den Anteil mit Hebe-Erlaubnis (gedämpft) und den Rest, der nur das Sinken bremst
            let net = air.down + air.up + air.lifted
            let licensed = net < 0 ? air.lifted / (air.up + air.lifted) : 0
            vy += (max(net * (1 - licensed), -0.85 * max(0, sink)) - vy) * k
            lift += (Stir.liftDamping * net * licensed - lift) * k
            spin += (max(-10, min(10, air.curl / 2)) - spin) * k
            if air.isZero, abs(vx) + abs(vy) + abs(lift) < 0.5 { self = Drift() }
            // ohne Aufwind eines aufwärts fahrenden Zeigers wird das Sinken höchstens gebremst, nie umgekehrt
            return CGVector(dx: vx, dy: max(sink + vy, min(sink, 0)) + lift)
        }
    }
}

/// Luftströmung um die jüngste Zeigerbahn: eine Kette kurzlebiger Luftpakete. Jedes Paket ist ein Wirbelpaar
/// (Strahl in Bewegungsrichtung, seitliche Verdrängung davor, Rückströmung an den Flanken) plus ein kleiner
/// Einzelwirbel, abwechselnd links und rechts der Bahn. Das Feld ist divergenzfrei. Koordinaten mit y nach unten.
struct AirField {
    struct Puff {
        var x, y: Double            // Mitte
        var ux, uy: Double          // Richtung der Zeigerbewegung (Einheitsvektor)
        var r0, u0: Double          // Radius und Luftgeschwindigkeit bei Entstehung
        var side: Double            // +1 oder -1: Seite und Drehsinn des Einzelwirbels
        var lift0: Double           // 0...1: Anteil, der Flocken heben darf (Zeiger fuhr aufwärts)
        var age = 0.0
        var u = 0.0, g = 0.0, inv = 0.0, lift = 0.0, reach = 0.0   // aktuelle Werte, siehe refresh()

        mutating func refresh() {
            let t = 1 - age / Stir.life
            let r = r0 * (1 + 0.5 * age / Stir.life)
            // kurzer kräftiger Schwall direkt hinter dem Zeiger, danach ein schwacher Nachlauf, in dem die Wirbel überwiegen
            u = u0 * t * t * (0.25 + 0.75 * exp(-age / Stir.gustTime))
            g = 0.35 * u0 * t * t * r * side
            inv = 1 / (r * r)
            reach = r * 2.45
            lift = lift0 * exp(-age / Stir.liftTime)
        }
    }

    /// Luft an einem Punkt. `down`, `up`, `lifted` sind die senkrechten Anteile: abwärts, aufwärts ohne und mit Hebe-Erlaubnis.
    struct Sample {
        var dx = 0.0, down = 0.0, up = 0.0, lifted = 0.0, curl = 0.0
        var isZero: Bool { dx == 0 && down == 0 && up == 0 && lifted == 0 }
        var velocity: CGVector { CGVector(dx: dx, dy: down + up + lifted) }
        var speed: Double { hypot(dx, down + up + lifted) }
    }

    private(set) var puffs: [Puff] = []
    private var travel = 0.0, side = 1.0
    private var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0

    var isActive: Bool { !puffs.isEmpty }

    /// Der Zeiger ist seit dem letzten Bild von a nach b gefahren, mit geglätteter Geschwindigkeit v.
    mutating func feed(from a: CGPoint, to b: CGPoint, velocity v: CGVector) {
        let speed = hypot(Double(v.dx), Double(v.dy)), s = Stir.strength(speed: speed)
        let len = Double(hypot(b.x - a.x, b.y - a.y))
        guard s > 0, len > 0 else { return }
        let r = Stir.radius(strength: s)
        let spacing = max(0.75 * r, speed * Stir.life / Double(Stir.maxPuffs))
        let ux = Double(v.dx) / speed, uy = Double(v.dy) / speed
        // überlappende Pakete addieren sich: so normiert, dass auf der Bahn etwa entrain * Tempo herrscht
        let u0 = Stir.entrain * min(speed, 2000) * s * min(1, spacing / (r * 1.7725))
        let up = min(max((-uy - 0.35) / 0.45, 0), 1)
        travel = puffs.isEmpty ? spacing : travel + len
        while travel >= spacing {
            travel -= spacing
            let t = max(0, len - travel) / len
            var p = Puff(x: Double(a.x) + Double(b.x - a.x) * t - uy * side * 0.3 * r, y: Double(a.y) + Double(b.y - a.y) * t + ux * side * 0.3 * r,
                         ux: ux, uy: uy, r0: r, u0: u0, side: side, lift0: up * up * (3 - 2 * up))
            p.refresh()
            if puffs.count >= Stir.maxPuffs { puffs.removeFirst() }
            puffs.append(p)
            side = -side
        }
        updateBounds()
    }

    /// Pakete altern, wandern langsam weiter, werden größer und schwächer.
    mutating func step(dt: Double) {
        guard !puffs.isEmpty else { return }
        for i in puffs.indices {
            puffs[i].age += dt
            puffs[i].x += puffs[i].ux * puffs[i].u * 0.3 * dt
            puffs[i].y += puffs[i].uy * puffs[i].u * 0.3 * dt
            puffs[i].refresh()
        }
        puffs.removeAll { $0.age >= Stir.life }
        updateBounds()
    }

    private mutating func updateBounds() {
        minX = .infinity; maxX = -.infinity; minY = .infinity; maxY = -.infinity
        for p in puffs {
            minX = min(minX, p.x - p.reach); maxX = max(maxX, p.x + p.reach)
            minY = min(minY, p.y - p.reach); maxY = max(maxY, p.y + p.reach)
        }
    }

    func sample(x: Double, y: Double) -> Sample {
        var out = Sample()
        guard x > minX, x < maxX, y > minY, y < maxY else { return out }
        for p in puffs {
            let dx = x - p.x, dy = y - p.y
            let q = (dx * dx + dy * dy) * p.inv
            if q > 6 { continue }
            let e = exp(-q)
            let s = dx * p.ux + dy * p.uy, n = dy * p.ux - dx * p.uy
            // Stromfunktion (u * n + g) * e mit Strahl u und Einzelwirbel g: Geschwindigkeit längs = d/dn, quer = -d/ds
            let along = (p.u * (1 - 2 * n * n * p.inv) - 2 * p.g * n * p.inv) * e
            let across = (p.u * n + p.g) * 2 * s * p.inv * e
            out.dx += along * p.ux - across * p.uy
            let vy = along * p.uy + across * p.ux
            if vy >= 0 { out.down += vy } else { out.lifted += vy * p.lift; out.up += vy * (1 - p.lift) }
            out.curl += (p.u * n * (8 - 4 * q) + 4 * p.g * (1 - q)) * p.inv * e
        }
        let v = out.speed
        if v > Stir.maxAir { let k = Stir.maxAir / v; out.dx *= k; out.down *= k; out.up *= k; out.lifted *= k }
        return out
    }
}
