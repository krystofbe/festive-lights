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

    init(length: Double, spacing: Double, bulbsPerArc target: Int = 6) {
        self.length = max(length, 1)
        let arcs = max(1, Int((self.length / (Double(target) * spacing)).rounded()))
        arcCount = arcs
        arcLength = self.length / Double(arcs)
        let per = max(1, Int((arcLength / spacing).rounded()))
        bulbsPerArc = per
        var pos: [Double] = []
        for a in 0..<arcs {
            for j in 0..<per {
                pos.append(Double(a) * arcLength + arcLength * (Double(j) + 0.5) / Double(per))
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

    static func bulbHeight(menuBarHeight: Double, level: Int) -> Double {
        max(menuBarHeight, 22) * Levels.value(Levels.bulbSize, level)
    }

    static func spacing(bulbHeight: Double, level: Int) -> Double {
        bulbHeight * 1.95 * Levels.value(Levels.spacing, level)
    }
}
