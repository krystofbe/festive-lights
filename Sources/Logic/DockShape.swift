import CoreGraphics
import Foundation

/// Form der Dock-Kette: "genau am Dock" (Standard, mit oder ohne Berechtigung) oder "durchgehend" über die volle Bildschirmbreite.
enum DockShape: String, CaseIterable {
    case continuous, exact
}

/// Ergebnis der Dock-Ermittlung: Dock sichtbar mit Geometrie, ausgeblendet (Auto-Hide) oder nicht ermittelbar (unplausibel, anderes macOS).
enum ExactState: Equatable { case visible, hidden, unavailable }

/// Was tatsächlich gezeichnet wird.
enum DockForm: Equatable {
    case exact, hidden, continuous

    /// "Genau am Dock" nur bei sichtbarem Dock. Ausgeblendet verschwindet die Kette mit dem Dock. Liefert die Ermittlung kein
    /// plausibles Ergebnis, fällt die Kette sanft auf "durchgehend" zurück, statt falsch zu liegen.
    static func resolve(choice: DockShape, exact: ExactState) -> DockForm {
        guard choice == .exact else { return .continuous }
        switch exact {
        case .visible: return .exact
        case .hidden: return .hidden
        case .unavailable: return .continuous
        }
    }
}

/// Woher die Dock-Geometrie kommt: mit Berechtigung der genauere Weg über die Bedienungshilfen, sonst der Treffer-Test.
enum DockSource: Equatable {
    case accessibility, probe

    static func choose(permission: Bool) -> DockSource { permission ? .accessibility : .probe }
}

struct ScreenInfo: Equatable {
    var frame: CGRect
    var visible: CGRect
}

/// Lage der durchgehenden Dock-Kette aus öffentlichen Größen: Dock-Oberkante aus dem freien Bildschirmbereich ohne Dock.
enum ContinuousDock {
    struct Placement: Equatable {
        var screenIndex: Int
        var edge: DockEdge
        var edgeLine: Double     // y bei unten, x bei links oder rechts (Cocoa-Koordinaten)
        var thickness: Double    // Dicke des Docks, 0 bei ausgeblendetem Dock
    }

    static func edge(orientation: String?) -> DockEdge {
        orientation == "left" ? .left : orientation == "right" ? .right : .bottom
    }

    /// Der Bildschirm mit der größten Dock-Dicke trägt die Kette. Ist das Dock ausgeblendet (überall Dicke 0), liegt sie am Rand des Hauptbildschirms.
    static func placement(screens: [ScreenInfo], orientation: String?) -> Placement? {
        guard !screens.isEmpty else { return nil }
        let e = edge(orientation: orientation)
        func thickness(_ s: ScreenInfo) -> Double {
            switch e {
            case .bottom: return Double(s.visible.minY - s.frame.minY)
            case .left: return Double(s.visible.minX - s.frame.minX)
            case .right: return Double(s.frame.maxX - s.visible.maxX)
            }
        }
        func line(_ s: ScreenInfo, visible: Bool) -> Double {
            switch e {
            case .bottom: return Double(visible ? s.visible.minY : s.frame.minY)
            case .left: return Double(visible ? s.visible.minX : s.frame.minX)
            case .right: return Double(visible ? s.visible.maxX : s.frame.maxX)
            }
        }
        if let i = screens.indices.max(by: { thickness(screens[$0]) < thickness(screens[$1]) }), thickness(screens[i]) > 1 {
            return Placement(screenIndex: i, edge: e, edgeLine: line(screens[i], visible: true), thickness: thickness(screens[i]))
        }
        return Placement(screenIndex: 0, edge: e, edgeLine: line(screens[0], visible: false), thickness: 0)
    }
}

/// Energiesparen: Einstellung, Stromsparmodus oder Akku unter 20 % ohne Netzteil.
enum PowerPolicy {
    static func energySaving(alwaysSave: Bool, lowPowerMode: Bool, onBattery: Bool, batteryFraction: Double?) -> Bool {
        if alwaysSave || lowPowerMode { return true }
        guard onBattery, let f = batteryFraction else { return false }
        return f < 0.2
    }
}

/// Zustände, die ein Neuzeichnen der Oberfläche nach sich ziehen, wenn sie sich ändern (Sperre, "Bewegung reduzieren", Energiesparen).
struct RuntimeState: Equatable {
    var suspended = false
    var reduceMotion = false
    var energySaving = false
}
