import Foundation
import Combine

/// Ab 1.3 drei Schritte: Kette aussuchen, wo es leuchten soll (in der Direkt-Variante mit optionaler Freigabe), Frohe Festtage.
enum OnbStep: Int, CaseIterable {
    case pick, glow, finish
    static var all: [OnbStep] { allCases }
}

final class OnboardingModel: ObservableObject {
    @Published var index = 0
    let steps = OnbStep.all
    var step: OnbStep { steps[index] }
    var isLast: Bool { index == steps.count - 1 }
    func next() { if !isLast { index += 1 } }
    func back() { if index > 0 { index -= 1 } }
}

/// Wirkung der Stilwahl: gilt sofort für Menüleiste und Dock.
func applyOnboardingStyle(_ kind: ChainStyleKind, to s: Settings) { s.chainStyle = kind; s.dockStyle = kind }

/// Solange Einführung oder Einstellungsfenster offen ist, hat die App ein Dock-Symbol und taucht in Befehl-Tab auf (SPEC §6 Punkt 2a), sonst ist sie ein
/// reines Menüleisten-Programm. Gezählt wird, welche dieser Fenster offen sind.
struct WindowPolicyTracker {
    private(set) var open = Set<String>()
    var wantsRegular: Bool { !open.isEmpty }
    /// Gibt zurück, ob sich die gewünschte Richtlinie geändert hat.
    @discardableResult mutating func opened(_ id: String) -> Bool { let was = wantsRegular; open.insert(id); return was != wantsRegular }
    @discardableResult mutating func closed(_ id: String) -> Bool { let was = wantsRegular; open.remove(id); return was != wantsRegular }
}
