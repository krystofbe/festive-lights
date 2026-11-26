import Foundation
import Combine

enum OnbStep: Int, CaseIterable {
    case welcome, menuBar, dock, snow, access, done

    /// Der Freigabe-Schritt gibt es nur in der Direkt-Variante.
    static var all: [OnbStep] { allCases.filter { $0 != .access || !AppVariant.isStore } }
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
