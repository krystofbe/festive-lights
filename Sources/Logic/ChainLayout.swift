import CoreGraphics
import Foundation

/// Geometrie einer Lichterkette entlang einer Strecke der Länge `length`:
/// gleichmäßige flache Bögen, Birnen gleichmäßig verteilt.
struct ChainLayout {
    let length: Double
    let arcCount: Int
    let arcLength: Double
    let bulbsPerArc: Int
    let bulbPositions: [Double]

    var bulbCount: Int { bulbPositions.count }

    /// `irregular`: etwa 40 % weniger Birnen, Abstände je Birne ±35 % um den Mittelwert, gelegentlich zwei nah beieinander. Der Zufall hängt nur an der
    /// Position in der Gesamtlänge, deshalb passen die Abschnitte mehrerer Bildschirme nahtlos aneinander.
    init(length: Double, spacing: Double, bulbsPerArc target: Int = 6, irregular: Bool = false) {
        self.length = max(length, 1)
        let arcs = max(1, Int((self.length / (Double(target) * spacing)).rounded()))
        arcCount = arcs
        let arcLen = self.length / Double(arcs)
        arcLength = arcLen
        let even = max(1, Int((arcLen / spacing).rounded()))
        let per = irregular ? max(2, Int((Double(even) * 0.6).rounded())) : even
        bulbsPerArc = per
        var pos: [Double] = []
        for a in 0..<arcs {
            if irregular {
                // Abschnitte: halber Rand, per-1 Zwischenräume, halber Rand
                var w: [Double] = (0...per).map { j in
                    let r = stableRandom(a * 64 + j, 7)
                    var g = 1 + 0.35 * (2 * r - 1)
                    if j > 0 && j < per && stableRandom(a * 64 + j, 8) < 0.15 { g = 0.5 }   // zwei nah beieinander
                    return (j == 0 || j == per) ? g * 0.5 : g
                }
                let total = w.reduce(0, +)
                w = w.map { $0 / total * arcLen }
                var u = Double(a) * arcLen
                for j in 0..<per { u += w[j]; pos.append(u) }
                continue
            }
            for j in 0..<per {
                pos.append(Double(a) * arcLen + arcLen * (Double(j) + 0.5) / Double(per))
            }
        }
        bulbPositions = pos
    }

    /// Durchhang 0...1 (0 an den Aufhängepunkten, 1 in der Bogenmitte), Parabel.
    func sagFactor(at u: Double) -> Double {
        let local = (u / arcLength).truncatingRemainder(dividingBy: 1)
        let t = local < 0 ? local + 1 : local
        return 4 * t * (1 - t)
    }

    /// Stabile Neigung der Birne in Grad, höchstens ±15.
    static func tilt(index: Int) -> Double { (stableRandom(index, 99) * 2 - 1) * 15 }

    /// Größe, Helligkeit (je ±10 %) und Hängetiefe (in Birnenhöhen, ±0,12) der Birnen von "Tanne warmgold", stabil je globaler Nummer.
    static func sizeJitter(index: Int) -> Double { 1 + 0.2 * (stableRandom(index, 11) - 0.5) }
    static func brightJitter(index: Int) -> Double { 1 + 0.2 * (stableRandom(index, 12) - 0.5) }
    static func depthJitter(index: Int) -> Double { 0.24 * (stableRandom(index, 13) - 0.5) }

    static func bulbHeight(menuBarHeight: Double, level: Int) -> Double {
        max(menuBarHeight, 22) * Levels.value(Levels.bulbSize, level)
    }

    static func spacing(bulbHeight: Double, level: Int) -> Double {
        bulbHeight * 1.95 * Levels.value(Levels.spacing, level)
    }
}
