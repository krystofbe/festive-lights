import CoreGraphics
import Foundation

/// Rechenlogik für mehrere Bildschirme (F4a), ohne AppKit: Anordnung, bündige Oberkanten, Auswahl, Begrüßung.
struct ScreenGeom: Equatable {
    var id: Int
    var frame: CGRect          // Cocoa-Koordinaten
    var scale: Double          // Retina-Faktor
    var menuBarHeight: Double  // 0: keine Menüleiste auf diesem Bildschirm
}

/// Lage eines Bildschirms in einer durchgehenden Girlande: `offset` ist der Abstand seines linken Rands vom Anfang der Girlande, `total` deren Länge.
struct StripPlacement: Equatable {
    var offset: Double
    var total: Double
}

enum ScreenLayout {
    static let flushTolerance = 2.0   // pt

    /// Bildschirme mit Menüleiste, die nebeneinander liegen (Kanten berühren sich) und deren Oberkanten bündig sind, bilden eine Girlande.
    /// Die Reihenfolge ist von links nach rechts. Alle anderen stehen für sich (offset 0, total = Breite).
    static func strips(_ screens: [ScreenGeom]) -> [Int: StripPlacement] {
        let bars = screens.filter { $0.menuBarHeight > 0 }.sorted { $0.frame.minX < $1.frame.minX }
        var out: [Int: StripPlacement] = [:]
        var i = 0
        while i < bars.count {
            var group = [bars[i]]
            var j = i + 1
            while j < bars.count, let last = group.last, adjacent(last, bars[j]) { group.append(bars[j]); j += 1 }
            let total = group.reduce(0) { $0 + Double($1.frame.width) }
            var off = 0.0
            for g in group { out[g.id] = StripPlacement(offset: off, total: total); off += Double(g.frame.width) }
            i = j
        }
        return out
    }

    private static func adjacent(_ a: ScreenGeom, _ b: ScreenGeom) -> Bool {
        abs(a.frame.maxX - b.frame.minX) <= flushTolerance && abs(a.frame.maxY - b.frame.maxY) <= flushTolerance
            && abs(a.menuBarHeight - b.menuBarHeight) <= flushTolerance
    }

    /// Lichter und Schnee auf diesem Bildschirm? "Nur Hauptbildschirm" zeigt sie nur auf dem Bildschirm mit der Hauptmenüleiste.
    static func showsEffects(isMain: Bool, mainOnly: Bool) -> Bool { !mainOnly || isMain }

    /// Ein Bildschirm hat nur dann eine Kette, wenn er eine Menüleiste hat (bei "Monitore verwenden verschiedene Spaces" jeder, sonst nur der Hauptbildschirm).
    static func hasChain(menuBarHeight: Double) -> Bool { menuBarHeight > 1 }

    struct Diff: Equatable {
        var added: [Int] = []       // neu angesteckt: Birnen gehen nacheinander an (F4a 7)
        var recreated: [Int] = []   // Rahmen oder Retina-Faktor geändert: neu aufbauen, ohne Begrüßung
        var removed: [Int] = []     // abgesteckt: sauber abbauen
    }

    /// Vergleich des bekannten mit dem neuen Zustand. Beim App-Start ist `known` leer und `isStart` gesetzt: Alle Bildschirme werden begrüßt (F1).
    static func diff(known: [Int: ScreenGeom], current: [ScreenGeom]) -> Diff {
        var d = Diff()
        let ids = Set(current.map(\.id))
        for s in current {
            if let k = known[s.id] { if k.frame != s.frame || k.scale != s.scale { d.recreated.append(s.id) } } else { d.added.append(s.id) }
        }
        d.removed = known.keys.filter { !ids.contains($0) }.sorted()
        return d
    }
}
