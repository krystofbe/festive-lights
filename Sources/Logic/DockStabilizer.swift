import CoreGraphics
import Foundation

/// Übernimmt einen neuen Dock-Rahmen erst, wenn er sich `settle` Sekunden nicht mehr geändert hat.
struct DockFrameStabilizer {
    var settle = 0.15
    var tolerance: CGFloat = 0.5
    private(set) var committed: CGRect?
    private var candidate: CGRect?
    private var since = 0.0
    private var started = false

    /// Gibt den neuen stabilen Rahmen zurück, sobald er feststeht. nil-Rahmen heißt: Dock nicht sichtbar.
    /// Rückgabe ist doppelt optional: `.some(nil)` meldet "jetzt unsichtbar".
    mutating func feed(time t: Double, frame: CGRect?) -> CGRect?? {
        if !started || !Self.same(frame, candidate, tolerance) {
            started = true
            candidate = frame
            since = t
        }
        guard t - since >= settle else { return nil }
        if hasCommitted && Self.same(candidate, committed, tolerance) { return nil }
        hasCommitted = true
        committed = candidate
        return .some(candidate)
    }

    private var hasCommitted = false

    private static func same(_ a: CGRect?, _ b: CGRect?, _ tol: CGFloat) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (a?, b?):
            return abs(a.minX - b.minX) <= tol && abs(a.minY - b.minY) <= tol
                && abs(a.width - b.width) <= tol && abs(a.height - b.height) <= tol
        default: return false
        }
    }
}
