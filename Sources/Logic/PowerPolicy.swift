import Foundation

/// Energiesparen: Einstellung, Stromsparmodus oder Akku unter 20 % ohne Netzteil.
enum PowerPolicy {
    static func energySaving(mode: PowerMode, lowPowerMode: Bool, onBattery: Bool, batteryFraction: Double?) -> Bool {
        switch mode {
        case .always: return true
        case .off: return false
        case .automatic: break
        }
        if lowPowerMode { return true }
        guard onBattery, let f = batteryFraction else { return false }
        return f < 0.2
    }
}

/// Zustände, die ein Neuzeichnen der Oberfläche nach sich ziehen, wenn sie sich ändern (Sperre, "Bewegung reduzieren", Energiesparen, Erscheinungsbild).
struct RuntimeState: Equatable {
    var suspended = false
    var reduceMotion = false
    var energySaving = false
    var dark = true
}
