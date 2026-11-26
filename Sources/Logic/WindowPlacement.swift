import CoreGraphics
import Foundation

/// Fensterposition (Cocoa-Koordinaten, Ursprung unten links): erste Platzierung und Wiederherstellung einer gemerkten Position.
enum WindowPlacement {
    static let minGapBelowMenuBar = 120.0

    /// Erstes Öffnen des Einstellungsfensters: horizontal mittig im freien Bereich des Bildschirms mit der Menüleiste, vertikal im oberen Drittel,
    /// aber mindestens 120 pt unter der Menüleiste (`visible.maxY` ist deren Unterkante). Das Fenster bleibt ganz im freien Bereich, soweit es passt.
    static func initialOrigin(size: CGSize, visible: CGRect) -> CGPoint {
        let gap = max(minGapBelowMenuBar, (visible.height - size.height) / 3)
        let x = visible.midX - size.width / 2
        let y = visible.maxY - gap - size.height
        return clamp(CGPoint(x: x, y: y), size: size, visible: visible)
    }

    /// Mittig im freien Bereich (Einführung).
    static func centeredOrigin(size: CGSize, visible: CGRect) -> CGPoint {
        clamp(CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2), size: size, visible: visible)
    }

    /// Gemerkte Position, wenn die Titelleiste (oberer Streifen, mindestens 60 x 24 pt) auf einem vorhandenen Bildschirm sichtbar ist, sonst nil.
    static func restoredOrigin(saved: CGPoint?, size: CGSize, screens visibleFrames: [CGRect]) -> CGPoint? {
        guard let p = saved else { return nil }
        let strip = CGRect(x: p.x, y: p.y + size.height - 24, width: size.width, height: 24)
        for v in visibleFrames {
            let hit = strip.intersection(v)
            if !hit.isNull, hit.width >= 60, hit.height >= 24 { return p }
        }
        return nil
    }

    private static func clamp(_ p: CGPoint, size: CGSize, visible: CGRect) -> CGPoint {
        // zu großes Fenster: oben bündig, links bündig
        let maxX = visible.maxX - size.width, maxY = visible.maxY - size.height
        return CGPoint(x: max(visible.minX, min(p.x, maxX)) , y: max(visible.minY, min(p.y, maxY)))
    }
}

/// Einmalig: Fensterpositionen, die eine Version vor 1.0.2 gespeichert hat (eigener Schlüssel und AppKits automatische Frame-Werte), werden verworfen,
/// damit das Einstellungsfenster nach einem Update mittig öffnet. Danach gemerkte Positionen bleiben.
enum WindowPositionMigration {
    static let doneKey = "windowPositionMigrated102"
    static let originKey = "settingsWindowOrigin"

    static func run(_ d: UserDefaults) {
        guard d.object(forKey: doneKey) == nil else { return }
        d.removeObject(forKey: originKey)
        for k in d.dictionaryRepresentation().keys where k.hasPrefix("NSWindow Frame") { d.removeObject(forKey: k) }
        d.set(true, forKey: doneKey)
    }
}
