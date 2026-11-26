import CoreGraphics
import Foundation

struct WindowLite: Equatable {
    var layer: Int
    var pid: Int
    var bounds: CGRect   // CG-Koordinaten (Ursprung oben links)
    var alpha = 1.0
    var regular = true   // normale App mit Dock-Symbol (Hintergrund- und Overlay-Apps zählen nicht)
}

/// Erkennt Vollbild-Bildschirme ohne Bildschirmaufnahme-Berechtigung und ohne Bedienungshilfen: Auf einem Bildschirm mit Vollbild-App füllen normale
/// Fenster (Ebene 0) fremder Prozesse den ganzen Bildschirm einschließlich des Menüleistenbereichs, ein Fenster oder bei Split View mehrere ohne Lücke.
/// NSScreen.visibleFrame ändert sich dabei für diesen Prozess nicht zuverlässig und taugt nicht als Signal.
/// Bekannte Grenze: Bei automatisch ausgeblendeter Menüleiste kann ein maximiertes Fenster den ganzen Bildschirm füllen und wird dann wie Vollbild behandelt.
enum FullScreenDetect {
    static let tolerance = 1.5
    static let splitGap = 8.0   // Spalt zwischen den Fenstern einer Split View
    static let minAlpha = 0.5   // unsichtbare Vollflächen-Fenster zählen nicht

    /// Ebene des Dock-Fensters. Liegt es über dem ganzen Bildschirm, ist dort eine Vollbild-App aktiv.
    static let dockLayer = -2147483622

    /// `notchTop`: Höhe des Kerbenbands je Bildschirm (safeAreaInsets.top). Auf Bildschirmen mit Kerbe liegt das Vollbild-Fenster erst darunter, die Form
    /// "unter dem Kerbenband" gilt aber nur, wenn zugleich ein Dock-Fenster den ganzen Bildschirm deckt (sonst wäre es ein maximiertes Fenster).
    static func fullScreenIDs(screens: [(id: Int, cgRect: CGRect)], windows: [WindowLite], ownPID: Int, notchTop: [Int: Double] = [:]) -> Set<Int> {
        let candidates = windows.filter { $0.layer == 0 && $0.pid != ownPID && $0.alpha >= minAlpha && $0.regular }
        var out = Set<Int>()
        for s in screens {
            let here = candidates.filter { $0.bounds.intersects(s.cgRect.insetBy(dx: tolerance, dy: tolerance)) }
            if here.contains(where: { matches($0.bounds, s.cgRect) }) || covers(here.map(\.bounds), s.cgRect) { out.insert(s.id); continue }
            guard let n = notchTop[s.id], n > 0, windows.contains(where: { $0.layer == dockLayer && matches($0.bounds, s.cgRect) }) else { continue }
            let below = CGRect(x: s.cgRect.minX, y: s.cgRect.minY + n, width: s.cgRect.width, height: s.cgRect.height - n)
            if here.contains(where: { matches($0.bounds, below) }) || covers(here.map(\.bounds), below) { out.insert(s.id) }
        }
        return out
    }

    private static func matches(_ b: CGRect, _ r: CGRect) -> Bool {
        abs(b.minX - r.minX) <= tolerance && abs(b.minY - r.minY) <= tolerance && abs(b.width - r.width) <= tolerance && abs(b.height - r.height) <= tolerance
    }

    /// Vereinigung der Fenster deckt den Bildschirm lückenlos (bis auf den Spalt der Split View). Mindestens zwei Fenster, jedes reicht bis zum oberen Rand.
    private static func covers(_ rects: [CGRect], _ screen: CGRect) -> Bool {
        guard rects.count >= 2 else { return false }
        let r = rects.map { $0.insetBy(dx: -splitGap / 2, dy: 0).intersection(screen) }.filter { !$0.isNull && $0.width > 1 && $0.height > 1 }
        guard r.count >= 2, r.allSatisfy({ abs($0.minY - screen.minY) <= tolerance && abs($0.maxY - screen.maxY) <= tolerance }) else { return false }
        let sorted = r.sorted { $0.minX < $1.minX }
        var reach = screen.minX
        for w in sorted {
            if w.minX > reach + tolerance { return false }
            reach = max(reach, w.maxX)
        }
        return reach >= screen.maxX - tolerance && sorted.first!.minX <= screen.minX + tolerance
    }
}

/// Das Dock gilt als ausgeblendet, wenn es automatisch ausgeblendet ist oder auf einem Bildschirm eine Vollbild-App läuft (macOS blendet es dort aus,
/// bis der Zeiger an den Rand fährt). Dann ist die Dock-Kette nur sichtbar, solange das Dock erscheint, und fällt nie auf "durchgehend" zurück.
enum DockHiding {
    static func effectiveAutohide(autohidePref: Bool, fullScreenActive: Bool) -> Bool { autohidePref || fullScreenActive }
}
