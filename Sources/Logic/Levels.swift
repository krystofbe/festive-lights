import Foundation

/// Werte der 5-stufigen Regler. Index 2 ist die Mittelstellung und der Standard.
enum Levels {
    static let tempo: [Double] = [0.5, 0.75, 1.0, 1.5, 2.2]
    static let bulbSize: [Double] = [0.7, 0.85, 1.0, 1.2, 1.4]
    static let spacing: [Double] = [0.75, 0.88, 1.0, 1.2, 1.45]
    /// Durchhang (ab 1.2): Mittelstellung wie bisher, Stufe 1 etwa ein Fünftel, Stufe 5 doppelt so tief.
    static let sag: [Double] = [0.2, 0.6, 1.0, 1.5, 2.0]
    static let snowAmount: [Double] = [30, 55, 80, 170, 320]
    static let flakeSize: [Double] = [0.6, 0.8, 1.0, 1.3, 1.7]
    static let snowSpeed: [Double] = [0.5, 0.75, 1.0, 1.4, 1.9]
    static let snowAvoid: [Double] = [30, 55, 80, 110, 140]

    static func value(_ table: [Double], _ level: Int) -> Double {
        table[min(max(level, 0), table.count - 1)]
    }
}

/// Stabiler Pseudozufall aus ganzen Zahlen, 0..<1.
func stableRandom(_ a: Int, _ b: Int = 0, _ c: Int = 0) -> Double {
    var h = UInt64(truncatingIfNeeded: a) &* 0x9E3779B97F4A7C15
    h ^= UInt64(truncatingIfNeeded: b) &* 0xC2B2AE3D27D4EB4F &+ 0x165667B19E3779F9
    h = (h ^ (h >> 29)) &* 0xBF58476D1CE4E5B9
    h ^= UInt64(truncatingIfNeeded: c) &* 0x94D049BB133111EB &+ 0x27D4EB2F165667C5
    h = (h ^ (h >> 32)) &* 0x94D049BB133111EB
    h ^= h >> 31
    return Double(h >> 11) / Double(1 << 53)
}
