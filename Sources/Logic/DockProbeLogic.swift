import Foundation

/// Dock-Geometrie ohne Bedienungshilfen: Der Fensterserver verrät über einen Treffer-Test, wo das Dock-Fenster getroffen wird.
/// Hier steht nur die Suchlogik. `hit(u, d)` fragt, ob an der Position `u` entlang der Kante und der Tiefe `d` von der Kante
/// (zum Bildschirm hin) das Dock getroffen wird.
enum DockProbeLogic {
    struct Bar: Equatable { var a: Double; var b: Double; var thick: Double }

    /// Trefferfläche ragt über das sichtbare Symbol hinaus (am Testrechner gemessen: etwa 8 pt).
    static let hitMargin = 8.0

    /// Grenze zwischen Treffer `inside` und Nicht-Treffer `outside` auf 1 pt genau. Rückgabe: letzter Treffer.
    static func boundary(inside: Double, outside: Double, _ test: (Double) -> Bool) -> Double {
        var i = inside, o = outside
        while abs(o - i) > 1 {
            let m = ((i + o) / 2).rounded()
            if m == i || m == o { break }
            if test(m) { i = m } else { o = m }
        }
        return i
    }

    /// Findet Anfang, Ende und Dicke der ruhenden Leiste. nil, wenn nichts getroffen wird (Dock ausgeblendet oder nicht erkennbar).
    /// Kosten: etwa `length / 24` Stichproben plus zwei Binärsuchen plus drei Dickenmessungen, einmalig bei Ereignissen.
    static func findBar(length: Double, hit: (Double, Double) -> Bool) -> Bar? {
        var first: Double?, last: Double?
        var u = 8.0
        while u < length {
            if hit(u, 2) { if first == nil { first = u }; last = u }
            u += 24
        }
        guard let f = first, let l = last else { return nil }
        let a = boundary(inside: f, outside: max(f - 24, -1)) { hit($0, 2) }
        let b = boundary(inside: l, outside: min(l + 24, length)) { hit($0, 2) } + 1
        // Dicke an drei Stellen, kleinster Wert: ein vergrößertes Symbol soll die Ruhedicke nicht verfälschen
        let thick = [a + 3, (a + b) / 2, b - 3].map { u0 in boundary(inside: 2, outside: 400) { hit(u0, $0) } + 1 }.min()!
        return Bar(a: a, b: b, thick: thick)
    }

    /// Plausibilitätsprüfung: bei Abweichung fällt die Kette auf "durchgehend" zurück.
    /// `expectedThickness`: Dicke aus dem freien Bildschirmbereich (visibleFrame), nil bei ausgeblendetem Dock.
    static func isPlausible(_ bar: Bar, tile: Double, screenLength: Double, expectedThickness: Double?) -> Bool {
        let length = bar.b - bar.a
        guard length >= tile * 1.5, length <= screenLength + 1 else { return false }
        guard bar.thick >= tile * 0.5, bar.thick <= tile * 3.5 else { return false }
        if let e = expectedThickness, e > 1, abs(bar.thick - e) > 14 { return false }
        return true
    }

    /// Anhebung der Symbole um die Zeigerposition: Spannen mit der Höhe, um die die Trefferfläche über die Ruheleiste ragt
    /// (minus Rand). Nur Stützstellen im Abstand `step` im Umkreis `reach` um den Zeiger, und nur dort eine Binärsuche, wo über der
    /// Leiste überhaupt etwas getroffen wird.
    static func profile(bar: Bar, pointerU: Double, step: Double = 20, reach: Double, maxExtra: Double, hit: (Double, Double) -> Bool) -> [DockProfile.Span] {
        var spans: [DockProfile.Span] = []
        var u = (max(bar.a, pointerU - reach) / step).rounded(.down) * step
        let end = min(bar.b, pointerU + reach)
        while u <= end {
            var lift = 0.0
            if hit(u, bar.thick + 1.5) {
                let top = boundary(inside: bar.thick + 1.5, outside: bar.thick + maxExtra) { hit(u, $0) } + 1
                lift = max(0, top - hitMargin - bar.thick)
            }
            spans.append(DockProfile.Span(a: u - step / 2, b: u + step / 2, lift: lift))
            u += step
        }
        return spans
    }
}
