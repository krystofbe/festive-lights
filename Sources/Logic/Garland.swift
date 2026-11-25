import Foundation

enum ChainStyleKind: String, CaseIterable {
    case classic, firColor, firGold
    var isFir: Bool { self != .classic }
}

enum BranchLayer: String { case back, mid, hang, front }

struct GarlandBranch: Equatable {
    var layer: BranchLayer
    var sprite: Int          // 1-basiert, passend zu fir-<layer>-<n>.png
    var u: Double            // Ansatzpunkt entlang der Kette
    var mirrored: Bool
    var rotation: Double     // Grad
}

struct GarlandPlan: Equatable {
    var branches: [GarlandBranch] = []
    var cones: [Double] = []   // u-Positionen
    var bows: [Double] = []
}

/// Zentrale Stellschrauben der Tannengirlande (Praxistest, bitte hier nachjustieren).
enum Garland {
    /// Dichte des Grüns: Vielfaches der Zweigzahl des Zielbilds (1,0 = dicht wie im Zielbild).
    static let density = 0.4
    /// Länge der hängenden Zweige als Vielfaches (1,0 reicht bei Mittelstellung etwa 40 pt unter das Kabel).
    static let hangLength = 1.0
    /// Skalierung der Zweige gegenüber der Zweig-Leinwand: geschlossenes Grün bei Mittelstellung etwa 30 pt tief, kein Zweig tiefer als etwa 45 pt.
    static let branchScale = 0.45
    static let hangScale = 0.21
    static let coneScale = 0.6
    static let bowScale = 0.6
    static let spriteCounts: [BranchLayer: Int] = [.back: 4, .mid: 4, .hang: 3, .front: 3]

    static func anchorSpacing(scale s: Double, dock: Bool = false) -> Double { dock ? 16 : 22 * s / max(density, 0.1) }

    /// Stabile Platzierung: gleiche Eingaben ergeben immer denselben Plan.
    static func plan(length: Double, arcLength: Double, arcCount: Int, scale s: Double, style: ChainStyleKind, dock: Bool) -> GarlandPlan {
        guard style.isFir, length > 0 else { return GarlandPlan() }
        var plan = GarlandPlan()
        let n = max(1, Int(length / anchorSpacing(scale: s, dock: dock)))
        let step = length / Double(n)
        func pick(_ layer: BranchLayer, _ k: Int, _ salt: Int) -> Int { 1 + Int(stableRandom(k, salt, 11) * Double(spriteCounts[layer]!)) % spriteCounts[layer]! }
        func rot(_ k: Int, _ salt: Int, _ range: Double) -> Double { (stableRandom(k, salt, 12) * 2 - 1) * range }
        for k in 0..<n {
            let u = (Double(k) + 0.5) * step
            plan.branches.append(GarlandBranch(layer: .back, sprite: pick(.back, k, 1), u: u, mirrored: k % 2 == 1, rotation: rot(k, 1, 12)))
            if stableRandom(k, 2, 13) < 0.75 {
                plan.branches.append(GarlandBranch(layer: .mid, sprite: pick(.mid, k, 2), u: u + step * 0.3, mirrored: k % 2 == 0, rotation: rot(k, 2, 12)))
            }
            if !dock && (k + 2) % 5 == 0 {
                plan.branches.append(GarlandBranch(layer: .hang, sprite: pick(.hang, k, 3), u: u, mirrored: stableRandom(k, 3, 14) < 0.5, rotation: rot(k, 3, 8)))
            }
            if stableRandom(k, 4, 15) < 0.22 {
                plan.branches.append(GarlandBranch(layer: .front, sprite: pick(.front, k, 4), u: u - step * 0.2, mirrored: stableRandom(k, 4, 16) < 0.5, rotation: rot(k, 4, 10)))
            }
        }
        if !dock {
            for a in 0..<max(arcCount, 1) {
                plan.cones.append((Double(a) + 0.2 + 0.6 * stableRandom(a, 5, 17)) * arcLength)
            }
            if style == .firGold {
                for a in 0...max(arcCount, 1) { plan.bows.append(Double(a) * arcLength) }
            }
        }
        return plan
    }
}
