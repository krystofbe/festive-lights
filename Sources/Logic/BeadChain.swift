import Foundation

/// Birnen als Perlen auf einer Schnur: Positionen entlang des Kabels, mit Feder zur Ruheposition.
/// Der Zeiger schiebt Perlen zur Seite und lässt eine Lücke, Nachbarn rücken zusammen (Mindestabstand), nichts überholt oder überlappt.
struct BeadChain {
    let rest: [Double]
    let length: Double
    let minGap: Double      // Mindestabstand der Mittelpunkte
    let halfGap: Double     // halbe Lückenbreite bei voller Stärke
    /// Ausdehnung jeder Perle nach links und rechts (zum Beispiel Nadelspitzen), die nicht in die Lücke ragen darf.
    let extents: [(left: Double, right: Double)]
    private(set) var pos: [Double]
    private(set) var vel: [Double]

    struct Params { var omega: Double; var zeta: Double }
    /// Weich und träge, reagiert innerhalb von 0,1 s.
    static let push = Params(omega: 24, zeta: 0.8)
    /// Zurückrutschen in etwa 0,6 s mit leichtem Überschwingen.
    static let release = Params(omega: 11, zeta: 0.5)

    init(rest: [Double], length: Double, minGap: Double, halfGap: Double, extents: [(left: Double, right: Double)]? = nil) {
        self.rest = rest; self.length = length; self.minGap = minGap; self.halfGap = halfGap
        self.extents = extents ?? Array(repeating: (0, 0), count: rest.count)
        pos = rest; vel = Array(repeating: 0, count: rest.count)
    }

    /// Zielpositionen: Perlen im Lückenbereich werden an die Ränder geschoben, ihre Nachbarn rücken mit.
    static func targets(rest: [Double], pointer: Double?, strength k: Double, halfGap: Double, minGap: Double, length: Double, extents: [(left: Double, right: Double)]? = nil) -> [Double] {
        guard let p = pointer, k > 0, !rest.isEmpty else { return rest }
        let h = halfGap * min(max(k, 0), 1)
        var t = rest
        let n = rest.count
        let margin = minGap / 2
        // linke Seite: von der Lücke nach außen
        let leftIdx = (0..<n).filter { rest[$0] < p }
        let ex = extents ?? Array(repeating: (left: 0.0, right: 0.0), count: n)
        var edge = Double.infinity
        for i in leftIdx.reversed() {
            t[i] = min(rest[i], edge, p - h - ex[i].right)
            edge = t[i] - minGap
        }
        let rightIdx = (0..<n).filter { rest[$0] >= p }
        edge = -Double.infinity
        for i in rightIdx {
            t[i] = max(rest[i], edge, p + h + ex[i].left)
            edge = t[i] + minGap
        }
        // Kettenenden: Perlen können nicht über das Ende hinaus, sie stauen sich dort
        for i in 0..<n { t[i] = max(t[i], margin + Double(i) * minGap) }
        for i in (0..<n).reversed() { t[i] = min(t[i], length - margin - Double(n - 1 - i) * minGap) }
        return t
    }

    mutating func step(dt: Double, pointer: Double?, strength k: Double) {
        let tg = Self.targets(rest: rest, pointer: pointer, strength: k, halfGap: halfGap, minGap: minGap, length: length, extents: extents)
        let steps = max(1, Int(ceil(dt / 0.004)))
        let h = dt / Double(steps)
        for _ in 0..<steps {
            for i in pos.indices {
                // beim Wegschieben straff, beim Zurückkehren schwingend
                let away = abs(tg[i] - rest[i]) > abs(pos[i] - rest[i]) - 0.01 && tg[i] != rest[i]
                let p = away ? Self.push : Self.release
                let a = -p.omega * p.omega * (pos[i] - tg[i]) - 2 * p.zeta * p.omega * vel[i]
                vel[i] += a * h
                pos[i] += vel[i] * h
            }
            enforce()
        }
    }

    /// Hartes Verbot von Überholen und Überlappen, auch beim Überschwingen.
    mutating func enforce() {
        let n = pos.count
        guard n > 1 else { return }
        for i in 1..<n where pos[i] < pos[i - 1] + minGap {
            pos[i] = pos[i - 1] + minGap
            if vel[i] < vel[i - 1] { vel[i] = vel[i - 1] }
        }
        let maxLast = length - minGap / 2
        if pos[n - 1] > maxLast {
            pos[n - 1] = maxLast
            vel[n - 1] = min(vel[n - 1], 0)
            for i in stride(from: n - 2, through: 0, by: -1) where pos[i] > pos[i + 1] - minGap {
                pos[i] = pos[i + 1] - minGap
                vel[i] = min(vel[i], vel[i + 1])
            }
        }
    }

    func isSettled(eps: Double = 0.05) -> Bool {
        for i in pos.indices where abs(pos[i] - rest[i]) > eps || abs(vel[i]) > eps * 4 { return false }
        return true
    }

    mutating func snapToRest() { pos = rest; vel = Array(repeating: 0, count: rest.count) }
}
