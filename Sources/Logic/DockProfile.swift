import Foundation

/// Form der Dock-Kette bei eingeschalteter Vergrößerung: Die Kette liegt auf der Oberkante der vergrößerten Symbole.
enum DockProfile {
    /// Ein Symbol des Docks entlang der Kette: von `a` bis `b` (u-Koordinaten), um `lift` pt über seine Ruhehöhe gewachsen.
    struct Span: Equatable { var a: Double; var b: Double; var lift: Double }

    /// Abfall der Hüllkurve neben einem Symbol in pt Höhe je pt Breite.
    static let slope = 1.2

    /// Obere Hüllkurve: Über jedem Symbol mindestens dessen Anhebung, daneben sanft abfallend. Nie negativ.
    static func envelope(spans: [Span], at u: Double) -> Double {
        var best = 0.0
        for s in spans where s.lift > 0 {
            let d = u < s.a ? s.a - u : (u > s.b ? u - s.b : 0)
            best = max(best, s.lift - slope * d)
        }
        return best
    }

    /// Anhebung an `count` Stützstellen im Abstand `du`.
    static func samples(spans: [Span], du: Double, count: Int) -> [Double] {
        (0..<count).map { envelope(spans: spans, at: Double($0) * du) }
    }

    /// Sichtbare Symbolgröße aus der Größe des Eintrags (Bedienungshilfen): Der Eintrag enthält Rand, der mit der Vergrößerung
    /// langsamer wächst als das Symbol. Am Testrechner gemessen: Eintrag 77 pt breit entspricht Symbol 64 pt, Eintrag 99,9 pt entspricht 78 pt.
    static func visibleSize(tile: Double, current: CGRect, rest: CGRect) -> Double {
        tile * pow(max(Double(current.width / max(rest.width, 1)), 1), 0.75)
    }

    /// Wie weit die sichtbare Oberkante (bei seitlichem Dock: Innenkante) des vergrößerten Symbols über der Dock-Linie `barLine` liegt.
    /// Unten: obere Kante, links: rechte Kante, rechts: linke Kante. Nie negativ.
    static func lift(edge: DockEdge, current r: CGRect, rest: CGRect, tile: Double, barLine: Double) -> Double {
        let vis = visibleSize(tile: tile, current: r, rest: rest)
        switch edge {
        case .bottom: return max(0, Double(r.maxY) - (Double(r.height) - vis) / 2 - barLine)
        case .left: return max(0, Double(r.maxX) - (Double(r.width) - vis) / 2 - barLine)
        case .right: return max(0, barLine - (Double(r.minX) + (Double(r.width) - vis) / 2))
        }
    }
}

enum DockEdge { case bottom, left, right }
