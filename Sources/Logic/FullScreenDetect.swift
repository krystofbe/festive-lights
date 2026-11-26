import CoreGraphics
import Foundation

struct WindowLite: Equatable {
    var layer: Int
    var pid: Int
    var bounds: CGRect   // CG-Koordinaten (Ursprung oben links)
}

/// Erkennt Vollbild-Bildschirme ohne Bildschirmaufnahme-Berechtigung und ohne Bedienungshilfen: Auf einem Bildschirm mit Vollbild-App füllt ein normales
/// Fenster (Ebene 0) eines anderen Prozesses den ganzen Bildschirm einschließlich des Menüleistenbereichs. NSScreen.visibleFrame ändert sich dabei
/// für diesen Prozess nicht zuverlässig und taugt nicht als Signal.
enum FullScreenDetect {
    static let tolerance = 1.5

    static func fullScreenIDs(screens: [(id: Int, cgRect: CGRect)], windows: [WindowLite], ownPID: Int) -> Set<Int> {
        var out = Set<Int>()
        for s in screens {
            for w in windows where w.layer == 0 && w.pid != ownPID {
                if abs(w.bounds.minX - s.cgRect.minX) <= tolerance, abs(w.bounds.minY - s.cgRect.minY) <= tolerance,
                   abs(w.bounds.width - s.cgRect.width) <= tolerance, abs(w.bounds.height - s.cgRect.height) <= tolerance { out.insert(s.id); break }
            }
        }
        return out
    }
}
