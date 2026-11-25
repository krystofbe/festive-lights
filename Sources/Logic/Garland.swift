import Foundation

enum ChainStyleKind: String, CaseIterable {
    case classic, firColor, firGold
    var isFir: Bool { self != .classic }
}

/// Stil der Dock-Kette: "wie Menüleiste" übernimmt den Stil der Menüleisten-Kette.
enum DockStyle: String, CaseIterable {
    case sameAsBar, classic, firColor, firGold

    func resolve(bar: ChainStyleKind) -> ChainStyleKind {
        switch self {
        case .sameAsBar: return bar
        case .classic: return .classic
        case .firColor: return .firColor
        case .firGold: return .firGold
        }
    }
}

enum BranchLayer: String { case back, mid, hang, front }

struct GarlandBranch: Equatable {
    var layer: BranchLayer
    var sprite: Int          // 1-basiert, passend zu fir-<layer>-<n>.png
    var u: Double            // Ansatzpunkt entlang der Kette
    var mirrored: Bool
    var rotation: Double     // Grad
}

/// Christbaumkugel, die an einem Zweig hängt: `branch` ist der Index in `GarlandPlan.branches`.
struct GarlandBauble: Equatable {
    var branch: Int
    var gold: Bool
    var x: Double      // Aufhängepunkt in Zweig-Koordinaten (pt der Leinwand 150 x 175)
    var y: Double
    var u: Double      // Mitte der Kugel entlang der Kette
}

struct GarlandPlan: Equatable {
    var branches: [GarlandBranch] = []
    var baubles: [GarlandBauble] = []
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
    /// Durchhang des Bandes in Birnenhöhen (Praxistest: ein bisschen mehr hängen lassen; vorher 0,2).
    static let sag = 0.45
    static let coneScale = 0.6
    static let baubleScale = 0.6
    static let baublesPerArc = 4
    static let bowScale = 0.6
    /// Ausdehnung der Zweig-Sprites links und rechts vom Ansatzpunkt in pt der Leinwand (aus den Bildern gemessen), ungespiegelt.
    static func extent(layer: BranchLayer, sprite n: Int) -> (left: Double, right: Double) {
        let maxX: [BranchLayer: [Double]] = [.back: [98, 101.5, 102.5, 104], .mid: [92, 95.5, 96, 97], .hang: [87, 86, 87.5], .front: [80.5, 82, 85.5]]
        let minX: [BranchLayer: [Double]] = [.back: [39.5, 39.5, 39.5, 39.5], .mid: [39.5, 39.5, 39.5, 39.5], .hang: [33.5, 35, 15], .front: [39.5, 39.5, 39.5]]
        let i = min(max(n, 1), maxX[layer]!.count) - 1
        return (max(0, 40 - minX[layer]![i]), max(0, maxX[layer]![i] - 40))
    }

    /// Aufhängepunkt für Kugeln: Stelle mit Nadeln nahe der Zweigspitze (85 % des Wegs zur entferntesten Nadel), aus den Bildern gemessen.
    static func tip(layer: BranchLayer, sprite n: Int) -> (x: Double, y: Double) {
        let t: [BranchLayer: [(Double, Double)]] = [
            .back: [(89, 50), (92, 56.5), (92.5, 65.5), (94, 72.5)],
            .mid: [(84, 54.5), (86.5, 61.5), (87, 67.5), (88, 74.5)],
            .hang: [(73, 115.5), (71, 124.5), (60.5, 136.5)],
            .front: [(74.5, 61), (70.5, 71), (77, 79)],
        ]
        let list = t[layer]!
        let p = list[min(max(n, 1), list.count) - 1]
        return (p.0, p.1)
    }

    static let spriteCounts: [BranchLayer: Int] = [.back: 4, .mid: 4, .hang: 3, .front: 3]

    static func anchorSpacing(scale s: Double, dock: Bool = false) -> Double { dock ? 16 : 22 * s / max(density, 0.1) }

    /// Stabile Platzierung: gleiche Eingaben ergeben immer denselben Plan.
    static func plan(length: Double, arcLength: Double, arcCount: Int, scale s: Double, style: ChainStyleKind, dock: Bool, bulbPositions: [Double] = []) -> GarlandPlan {
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
        if !dock && style == .firColor {
            // Kugeln hängen nur an Zweigen (Back, Mitte, vorn), nie am Kabel und nie an einer Birne
            let bw = 16 * baubleScale * s
            var placed: [Double] = []
            for a in 0..<max(arcCount, 1) {
                let lo = Double(a) * arcLength, hi = lo + arcLength
                var cands = plan.branches.indices.filter { plan.branches[$0].layer != .hang && plan.branches[$0].u > lo && plan.branches[$0].u < hi }
                cands.sort { stableRandom($0, 31, 18) < stableRandom($1, 31, 18) }
                var count = 0
                for i in cands where count < baublesPerArc {
                    let b = plan.branches[i]
                    let t = tip(layer: b.layer, sprite: b.sprite)
                    let k = branchScale * s
                    let u = b.u + (b.mirrored ? -1 : 1) * (t.x - 40) * k
                    guard u > bw, u < length - bw,
                          bulbPositions.allSatisfy({ abs($0 - u) > bw / 2 + 5 * s + 2 }),
                          placed.allSatisfy({ abs($0 - u) > bw * 1.6 }) else { continue }
                    plan.baubles.append(GarlandBauble(branch: i, gold: (plan.baubles.count % 2 == 1), x: t.x, y: t.y, u: u))
                    placed.append(u)
                    count += 1
                }
            }
        }
        if !dock && style == .firGold {
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
