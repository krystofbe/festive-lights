import Foundation

enum ChainStyleKind: String, CaseIterable {
    case classic, firColor, firGold
    var isFir: Bool { self != .classic }
}

enum BranchLayer: String, CaseIterable {
    case back, mid, hang, front, cluster
    var index: Int { Self.allCases.firstIndex(of: self)! }
}

struct GarlandBranch: Equatable {
    var layer: BranchLayer
    var sprite: Int          // 1-basiert, passend zu fir-<layer>-<n>.png
    var u: Double            // Ansatzpunkt entlang der Kette
    var mirrored: Bool
    var rotation: Double     // Grad
    var scale = 1.0          // Größe gegenüber der Grundgröße (Büschel von "Tanne bunt")
}

/// Christbaumkugel, die an einem Zweig hängt: `branch` ist der Index in `GarlandPlan.branches`.
struct GarlandBauble: Equatable {
    var branch: Int
    var pattern: Int   // 0 bis 4, passend zu tb-bauble-<n+1>
    var thread: Double // Fadenlänge in Einheiten der Vorlage
    var x: Double      // Fadenanfang in Koordinaten des Zweigs oder Büschels
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
    /// Durchhang am Dock in Birnenhöhen: Tanne und klassisch.
    static let dockSag = 0.3
    static let dockClassicSag = 0.45
    /// Zweiggröße und Ansatzpunkt-Skalierung der schmalen Girlande am Dock.
    static let dockBranchScale = 0.45
    static let dockAnchorScale = 0.73
    /// Tiefe der Girlande unter dem Kabel für die Fenstergröße: Menüleiste je 24 pt Birnenhöhe, Dock fest.
    static let depthPer24 = 60.0
    static let dockDepth = 24.0
    static let bowScale = 0.6

    // "Tanne bunt" (Art/TanneBunt): Maße des Zielbilds, 0,3 pt je Einheit der Vorlage bei Mittelstellung
    static let tbUnit = 0.3
    /// Birnenhöhe, bei der das Zielbild entstand (Menüleiste von 30 pt, Mittelstellung): dort gilt 0,3 pt je Einheit, sonst im Verhältnis.
    static let tbRefBulbH = 30.0
    /// Bogentiefe in Birnenhöhen und Tiefe der Girlande unter dem Kabel je 24 pt Birnenhöhe (Zielbild: Bogen etwa 25 pt, Kugeln bis etwa 50 pt darunter).
    static let tbSag = 0.6
    static let tbDepthPer24 = 40.0
    /// Birnenabstand gegenüber dem Standard (Zielbild: etwa 30 pt, Bögen von 150 pt mit fünf Birnen).
    static let tbSpacingFactor = 30.0 / 58.5
    static let tbAnchorUnits = 70.0
    static let tbBaubleUnits = 170.0
    /// Büschelgröße am Dock in pt je Einheit (Birnen sind am Dock so groß wie bei der klassischen Dock-Kette, das Grün gut sichtbar).
    static let tbDockScale = 0.45
    static let tbRotation = 22.0
    static let tbBaubleSizes: [(w: Double, h: Double, hangX: Double, hangY: Double)] = [(80, 89, 40, 0), (88, 111, 44, 14), (76, 85, 38, 0), (88, 111, 44, 14), (80, 89, 40, 0)]

    /// Dock-Kette: Bei Symbolgröße 64 pt und Mittelstellung ist jedes Element halb so groß wie bei der Menüleisten-Kette desselben Bildschirms (`barHeight`).
    /// Die Kette skaliert linear mit der Symbolgröße, der Regler wirkt relativ dazu, nie unter 6 pt.
    static func dockBulbHeight(tile: Double, bulbLevel: Int, barHeight: Double = 24, kind: ChainStyleKind = .firGold) -> Double {
        if kind == .firColor { return max(8, tile * 0.25 * Levels.value(Levels.bulbSize, bulbLevel)) }   // Tanne bunt: Maße von 1.2.1
        return max(6, 0.5 * max(barHeight, 22) * tile / 64 * Levels.value(Levels.bulbSize, bulbLevel))
    }
    /// Birnenhöhe, auf die die Dock-Büschel und -Zweige bezogen sind (Symbolgröße 73 pt bei Mittelstellung).
    static let dockRefBulbH = 73.0 * 0.25
    /// Wachstum der Birnen und des Grüns über einem vergrößerten Symbol: Symbolgröße mit Vergrößerung geteilt durch Ruhegröße (`lift` ist die Anhebung der Oberkante).
    /// Größtes Wachstum der Dock-Kette (largesize durch tilesize), höchstens 2,5: Sprites und Fenster werden darauf ausgelegt.
    static func dockMaxGrow(large: Double, tile: Double) -> Double { min(max(large / max(tile, 1), 1), 2.5) }
    static func dockMagnification(lift: Double, tile: Double) -> Double { 1 + max(lift, 0) / max(tile, 1) }

    /// Durchhang-Faktor am Dock: bei "genau am Dock" wirkt er nur halb so stark wie an der Menüleiste, bei "durchgehend" voll.
    static func dockSagFactor(level: Int, continuous: Bool) -> Double {
        let f = Levels.value(Levels.sag, level)
        return continuous ? f : 1 + (f - 1) / 2
    }

    /// Durchhang am Dock bei "genau am Dock". Stufen 1 bis 3: nie tiefer als die Mittelstellung, solange diese das obere Viertel der Symbole (Birne plus
    /// Durchhang) schon überschreitet, sonst höchstens bis zum Viertel (unverändert). Stufen 4 und 5 (`level` 3 und 4): Kabeltiefe plus halbe Birne höchstens
    /// ein Drittel der Symbolhöhe, damit sie bei der Standard-Birnengröße sichtbar tiefer sind als die Mittelstellung.
    static func dockExactSag(requested: Double, midSag: Double, bulbH: Double, tile: Double, level: Int = 2) -> Double {
        if level >= 3 { return min(requested, max(midSag, tile / 3 - bulbH / 2)) }
        let quarterBudget = max(0, tile / 4 - bulbH)
        return min(requested, max(midSag, quarterBudget))
    }

    /// Durchhang-Mittelstellung am Dock: Tanne wie an der Menüleiste (gleiche Stildefinition), klassisch wie bisher.
    static func dockMidSag(_ k: ChainStyleKind, bulbH: Double, look: Look = .lavish) -> Double { bulbH * LookProfile.make(k, look, dock: true).sag }

    /// "Tanne bunt" an der Menüleiste: eine Größenstufe kleiner als der Regler (Mittelstellung = Stufe 2 mit Faktor 0,85), damit Tabs und Titel lesbar bleiben.
    static let tbSizeFactor = 0.85
    static func menuBarBulbHeight(_ k: ChainStyleKind, barHeight: Double, level: Int) -> Double {
        ChainLayout.bulbHeight(menuBarHeight: barHeight, level: level) * (k == .firColor ? tbSizeFactor : 1)
    }

    static func sag(_ k: ChainStyleKind) -> Double { k == .firColor ? tbSag : sag }
    static func depthPer24(_ k: ChainStyleKind) -> Double { k == .firColor ? tbDepthPer24 : depthPer24 * hangLength }
    /// Ausdehnung der Zweig-Sprites links und rechts vom Ansatzpunkt in pt der Leinwand (aus den Bildern gemessen), ungespiegelt.
    static func extent(layer: BranchLayer, sprite n: Int) -> (left: Double, right: Double) {
        if layer == .cluster { return (65, 65) }
        let maxX: [BranchLayer: [Double]] = [.back: [98, 101.5, 102.5, 104], .mid: [92, 95.5, 96, 97], .hang: [87, 86, 87.5], .front: [80.5, 82, 85.5]]
        let minX: [BranchLayer: [Double]] = [.back: [39.5, 39.5, 39.5, 39.5], .mid: [39.5, 39.5, 39.5, 39.5], .hang: [33.5, 35, 15], .front: [39.5, 39.5, 39.5]]
        let i = min(max(n, 1), maxX[layer]!.count) - 1
        return (max(0, 40 - minX[layer]![i]), max(0, maxX[layer]![i] - 40))
    }

    static let spriteCounts: [BranchLayer: Int] = [.back: 4, .mid: 4, .hang: 3, .front: 3, .cluster: 1]

    static func anchorSpacing(scale s: Double) -> Double { 22 * s / max(density, 0.1) }

    /// Lage im Bogen: 0 und 1 sind die Aufhängepunkte, 0,5 die tiefste Stelle.
    static func arcT(_ u: Double, _ arcLength: Double) -> Double { let t = (u / max(arcLength, 1)).truncatingRemainder(dividingBy: 1); return t < 0 ? t + 1 : t }

    /// Stabile Platzierung: gleiche Eingaben ergeben immer denselben Plan.
    static func plan(length: Double, arcLength: Double, arcCount: Int, scale s: Double, style: ChainStyleKind, dock: Bool, bulbPositions: [Double] = [],
                     profile: LookProfile? = nil, dockTile: Double = 58) -> GarlandPlan {
        guard style.isFir, length > 0 else { return GarlandPlan() }
        let prof = profile ?? LookProfile.make(style, .lavish, dock: dock)
        if style == .firColor { return planBunt(length: length, arcLength: arcLength, arcCount: arcCount, scale: s, dock: dock, bulbPositions: bulbPositions, prof: prof, dockTile: dockTile) }
        var plan = GarlandPlan()
        let n = max(1, Int(length / anchorSpacing(scale: s)))
        let step = length / Double(n)
        func pick(_ layer: BranchLayer, _ k: Int, _ salt: Int) -> Int { 1 + Int(stableRandom(k, salt, 11) * Double(spriteCounts[layer]!)) % spriteCounts[layer]! }
        func rot(_ k: Int, _ salt: Int, _ range: Double) -> Double { (stableRandom(k, salt, 12) * 2 - 1) * range }
        let flat = prof.flatten   // Zweige zum Kabel hin drehen (gespiegelte in Gegenrichtung), Länge und Nadeln bleiben
        for k in 0..<n {
            let u = (Double(k) + 0.5) * step
            let m1 = k % 2 == 1, m2 = k % 2 == 0, m4 = stableRandom(k, 4, 16) < 0.5
            plan.branches.append(GarlandBranch(layer: .back, sprite: pick(.back, k, 1), u: u, mirrored: m1, rotation: rot(k, 1, 12) + (m1 ? -flat : flat)))
            if stableRandom(k, 2, 13) < 0.75 {
                plan.branches.append(GarlandBranch(layer: .mid, sprite: pick(.mid, k, 2), u: u + step * 0.3, mirrored: m2, rotation: rot(k, 2, 12) + (m2 ? -flat : flat)))
            }
            let t = arcT(u, arcLength)
            let hangHere: Bool
            switch prof.hang {
            case .none: hangHere = false
            case .edges: hangHere = (t < 0.2 || t > 0.8) && stableRandom(k, 3, 18) < 0.5
            case .regular: hangHere = (k + 2) % 5 == 0
            }
            if hangHere {
                plan.branches.append(GarlandBranch(layer: .hang, sprite: pick(.hang, k, 3), u: u, mirrored: stableRandom(k, 3, 14) < 0.5, rotation: rot(k, 3, 8)))
            }
            if stableRandom(k, 4, 15) < 0.22 {
                plan.branches.append(GarlandBranch(layer: .front, sprite: pick(.front, k, 4), u: u - step * 0.2, mirrored: m4, rotation: rot(k, 4, 10) + (m4 ? -flat : flat)))
            }
        }
        if style == .firGold {
            for a in 0..<max(arcCount, 1) {
                switch prof.cones {
                case .none, .perArc: break
                case .hookEveryOtherArc: if a % 2 == 0 { plan.cones.append((Double(a) + 0.12 + 0.08 * stableRandom(a, 5, 17)) * arcLength) }
                case .scattered: plan.cones.append((Double(a) + 0.2 + 0.6 * stableRandom(a, 5, 17)) * arcLength)
                }
            }
            if prof.bows { for a in 0...max(arcCount, 1) { plan.bows.append(Double(a) * arcLength) } }
        }
        return plan
    }

    /// "Tanne bunt": Büschel dicht entlang des Strangs, Kugeln an Goldfäden aus den Büscheln, zwei Zapfen je Bogen. Am Dock nur kleine Büschel.
    private static func planBunt(length: Double, arcLength: Double, arcCount: Int, scale s: Double, dock: Bool, bulbPositions: [Double], prof: LookProfile, dockTile: Double) -> GarlandPlan {
        var plan = GarlandPlan()
        let unit = tbUnit * s
        let n = max(1, Int(length / (tbAnchorUnits * (dock ? tbDockScale * s : unit))))
        let step = length / Double(n)
        for k in 0..<n {
            plan.branches.append(GarlandBranch(layer: .cluster, sprite: 1, u: (Double(k) + 0.5) * step, mirrored: stableRandom(k, 1, 21) < 0.5,
                                               rotation: (stableRandom(k, 2, 22) * 2 - 1) * tbRotation, scale: 1.1 + 0.15 * stableRandom(k, 3, 23)))
        }
        if prof.baubles != .none {
            let small = prof.baubles == .dockSmall
            let every = small ? 1.5 * dockTile : tbBaubleUnits * unit * (prof.baubles == .edgeHalf ? 2 : 1)
            var u = every * 0.5, i = 0
            while u < length {
                let pattern = small ? [0, 2, 4][plan.baubles.count % 3] : plan.baubles.count % 5   // kleine Kugel nur mit den Mustern ohne Schleifchen
                let sz = tbBaubleSizes[pattern]
                let half = sz.w * unit / 2 + 2
                let clear = 6 * unit + 2   // der Faden endet nie an einer Birne
                let home = min(max(Int(u / step), 0), n - 1)
                for d in (prof.baubles == .full ? [0, 1, -1, 2, -2] : [0, 1, -1, 2, -2, 3, -3]) {
                    let c = home + d
                    guard c >= 0, c < n else { continue }
                    let bu = plan.branches[c].u
                    let t = arcT(bu, arcLength)
                    if prof.baubles == .edgeHalf, t >= 0.3, t <= 0.7 { continue }   // nie in der Bogenmitte
                    if small, t >= 0.35, t <= 0.65 { continue }
                    guard bu > half, bu < length - half, bulbPositions.allSatisfy({ abs($0 - bu) > clear }) else { continue }
                    let r = stableRandom(i, 4, 24)
                    let thread = small ? 21 + 13 * r : (prof.baubles == .edgeHalf ? (i % 2 == 0 ? 15 + 10 * r : 25 - 10 * r) : (i % 2 == 0 ? 45 + 20 * r : 65 - 20 * r))
                    plan.baubles.append(GarlandBauble(branch: c, pattern: pattern, thread: thread, x: 65, y: 52, u: bu))
                    break
                }
                u += every; i += 1
            }
        }
        if case .perArc(let per) = prof.cones, per > 0 {
            for a in 0..<max(arcCount, 1) {
                plan.cones.append((Double(a) + 0.25 + 0.1 * stableRandom(a, 5, 25)) * arcLength)
                if per > 1 { plan.cones.append((Double(a) + 0.65 + 0.1 * stableRandom(a, 6, 26)) * arcLength) }
            }
        }
        return plan
    }
}
