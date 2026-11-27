import Foundation

/// "Auftritt" einer Kette (ab 1.3), je Kette ein eigener Wert. Grundsatz (SPEC Anhang A): Auftritt verkleinert nie. Zurückgenommen wird durch straffer spannen,
/// Behang nur nahe den Aufhängepunkten, kürzere Fäden, Teile abnehmen, bei warmgold flacher anbinden. Einzige kleinere Sorte: C7 bei klassisch Dezent.
enum Look: Int, CaseIterable {
    case subtle = 0, festive = 1, lavish = 2
}

enum HangMode: Equatable { case none, edges, regular }
enum ConeMode: Equatable { case none, perArc(Int), hookEveryOtherArc, scattered }
enum BaubleMode: Equatable { case none, edgeHalf, full, dockSmall }

/// Alle Werte einer Kette je Stil, Auftritt und Ort (Anhang A, Abschnitt 3). "Volle Pracht" ist der Stand von 1.2.2.
struct LookProfile: Equatable {
    var sag = 0.45                 // Durchhang in Birnenhöhen (Mittelstellung des Reglers)
    var spacingK = 1.0             // Birnenabstand gegenüber Volle Pracht (klassisch Dezent 1,5, Tanne bunt am Dock Dezent 2)
    var bulbScale = 1.0            // nur klassisch Dezent: kleinere Birnensorte C7
    var flatten = 0.0              // Grad, um die die Zweige der hinteren, mittleren und vorderen Schicht zum Kabel gedreht werden (warmgold)
    var hang = HangMode.regular
    var cones = ConeMode.scattered
    var bows = true
    var baubles = BaubleMode.none
    var miniBulb: Double? = nil    // Höhe (pt) der festen zweiten Birnensorte "Mini" (Dezent an der Menüleiste bei warmgold und klassisch)
    var perArc: Int? = nil         // Birnen je Bogen, wenn abweichend
    var noGreen = false            // warmgold Dezent an der Menüleiste: nur Kabel und Mini-Birnen
    var strandLift = 0.0           // pt, um die Strang und Büschel höher hängen (Dezent: 3) (Tanne bunt, Dezent, Menüleiste)

    static let miniDockHeight = 14.0   // Mini-Birne am Dock bei Symbolgröße 58, wächst linear mit der Symbolgröße, so gut sichtbar wie die Birnen von Tanne bunt am Dock
    static let miniHeight = 8.0   // feste zweite Birnensorte, etwas größer als die Birnen von Tanne bunt (6 pt)

    static func make(_ kind: ChainStyleKind, _ look: Look, dock: Bool) -> LookProfile {
        let i = look.rawValue
        var p = LookProfile()
        switch kind {
        case .firColor:
            p.bows = false; p.hang = .none
            if dock {
                p.sag = [0, 0.3, 0.3][i]; p.spacingK = [2, 1.5, 1.5][i]
                p.cones = [ConeMode.none, .none, .perArc(2)][i]
                p.baubles = [BaubleMode.none, .none, .dockSmall][i]
            } else {
                p.sag = [0.12, 0.4, 0.6][i]
                p.cones = [ConeMode.perArc(1), .perArc(2), .perArc(2)][i]
                p.baubles = [BaubleMode.none, .edgeHalf, .full][i]
                p.strandLift = [3, 0, 0][i]
            }
        case .firGold:
            p.sag = [0.12, 0.3, 0.45][i]; p.flatten = [30, 15, 0][i]
            p.hang = [HangMode.none, .edges, .regular][i]
            p.cones = [ConeMode.none, .hookEveryOtherArc, .scattered][i]
            p.bows = i > 0
            if !dock && i == 0 { p.miniBulb = LookProfile.miniHeight; p.noGreen = true; p.strandLift = 3; p.perArc = 8 }   // so dicht wie bei Tanne bunt Dezent (unregelmäßig: 60 % von 8 je Bogen)
        case .classic:
            p.sag = dock ? [0.1, 0.3, 0.45][i] : [0.1, 0.3, 1.0][i]
            p.bows = false; p.hang = .none; p.cones = .none
            if dock { if i == 0 { p.miniBulb = LookProfile.miniDockHeight; p.perArc = 3; p.spacingK = 1.7 } }   // Dock Dezent: Mini-Birnen in Dock-Größe, so dicht wie Tanne bunt Dezent am Dock
            else if i == 0 { p.miniBulb = LookProfile.miniHeight; p.perArc = 5 }     // an der Menüleiste Mini-Birnen, Abstand wie bei Tanne bunt
        }
        return p
    }
}

/// "Nur in Pausen": Schnee beginnt erst nach zwei Minuten ohne Eingabe.
enum SnowBreak {
    static let idleThreshold = 120.0
    static func allowsNewFlakes(onlyBreaks: Bool, idleSeconds: Double) -> Bool { !onlyBreaks || idleSeconds >= idleThreshold }
}

/// Vorderstes Fenster der aktiven App: das erste Fenster in der Liste (von vorn nach hinten), das der aktiven App gehört.
enum FrontWindow {
    static func pick(windows: [(id: Int, pid: Int32)], frontPID: Int32?) -> Int? {
        guard let frontPID else { return nil }
        return windows.first { $0.pid == frontPID }?.id
    }
}

/// Nachglimmen: Eine gedimmte oder ausgeschaltete Birne behält etwa 20 % ihres Farbscheins, der Übergang an/aus bleibt weich.
enum Ember {
    static let glowFloor = 0.2
    static func glowOpacity(bright: Double, base: Double) -> Double { base * (bright + glowFloor * (1 - bright)) }
}
