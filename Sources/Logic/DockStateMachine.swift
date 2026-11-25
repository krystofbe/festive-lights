import CoreGraphics
import Foundation

/// Was die Dock-Ermittlung in einem Messschritt gesehen hat.
enum DockObservation: Equatable {
    case visible(CGRect)   // Leiste gefunden und plausibel
    case hidden            // nichts getroffen und Auto-Hide an
    case unavailable       // nichts getroffen ohne Auto-Hide, oder unplausibel
}

/// Entprellt die Messschritte: Ein Zustand wird erst gemeldet, wenn er `settle` Sekunden unverändert blieb (ein Rahmen gilt als gleich
/// innerhalb der Toleranz). Ein einzelner schlechter Schritt führt so nie zum Rückfall auf "durchgehend", und nach einem Rückfall
/// wird derselbe Rahmen wie vorher wieder gemeldet.
struct DockStateMachine {
    var settle = 0.15
    var settleUnavailable = 0.35   // Rückfall mit Hysterese
    var tolerance: CGFloat = 0.5
    private(set) var committed: DockObservation?
    private var candidate: DockObservation?
    private var since = 0.0

    /// Unfertig: Der Kandidat unterscheidet sich vom gemeldeten Zustand (der Burst soll weitermessen).
    var isSettling: Bool { candidate != nil && !Self.same(candidate, committed, tolerance) }

    /// Liefert den neuen Zustand, sobald er feststeht.
    mutating func observe(_ obs: DockObservation, time t: Double) -> DockObservation? {
        if !Self.same(candidate, obs, tolerance) { candidate = obs; since = t }
        let need: Double
        if case .unavailable = obs { need = settleUnavailable } else { need = settle }
        guard t - since >= need, !Self.same(candidate, committed, tolerance) else { return nil }
        committed = candidate
        return committed
    }

    mutating func reset() { self = DockStateMachine(settle: settle, settleUnavailable: settleUnavailable, tolerance: tolerance) }

    private static func same(_ a: DockObservation?, _ b: DockObservation?, _ tol: CGFloat) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case (.hidden?, .hidden?), (.unavailable?, .unavailable?): return true
        case let (.visible(x)?, .visible(y)?):
            return abs(x.minX - y.minX) <= tol && abs(x.minY - y.minY) <= tol && abs(x.width - y.width) <= tol && abs(x.height - y.height) <= tol
        default: return false
        }
    }
}

/// Entscheidungen bei Zeigerbewegungen, ohne Seiteneffekte.
enum DockPointerLogic {
    struct Action: Equatable {
        var startMagnificationLoop = false
        var burst = false
    }

    /// `barZone`: Leiste plus tatsächliche Vergrößerungshöhe. `edgeStrip`: Streifen an der Bildschirmkante des Docks.
    /// `placed`: Leiste bekannt (sichtbar). `wasInside`: Zeiger war beim letzten Ereignis in `barZone`.
    static func react(pointer: CGPoint, barZone: CGRect?, edgeStrip: CGRect?, autohide: Bool, magnification: Bool, loopRunning: Bool, wasInside: Bool) -> (Action, inside: Bool) {
        var a = Action()
        let inside = barZone?.contains(pointer) ?? false
        if inside && magnification && !loopRunning { a.startMagnificationLoop = true }
        if inside != wasInside && autohide { a.burst = true }
        // Auto-Hide: Zeiger an der Dock-Kante lässt das Dock erscheinen, auch wenn gerade keine Leiste bekannt ist
        if autohide, !inside, let s = edgeStrip, s.contains(pointer) { a.burst = true }
        return (a, inside)
    }

    /// Zone, in der der Zeiger das Dock verändert: Leiste mit kleinem Rand und der Höhe, um die Symbole höchstens wachsen.
    static func barZone(a: Double, length: Double, thick: Double, grow: Double, edge: DockEdge, screen: CGRect, margin: Double = 8) -> CGRect {
        let depth = thick + grow + margin
        switch edge {
        case .bottom: return CGRect(x: Double(screen.minX) + a - margin, y: Double(screen.minY), width: length + 2 * margin, height: depth)
        case .left: return CGRect(x: Double(screen.minX), y: Double(screen.minY) + a - margin, width: depth, height: length + 2 * margin)
        case .right: return CGRect(x: Double(screen.maxX) - depth, y: Double(screen.minY) + a - margin, width: depth, height: length + 2 * margin)
        }
    }
}
