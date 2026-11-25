import Foundation

/// Die Simulation rechnet mit Ursprung links oben (y nach unten, wie CGWindowList).
/// Core-Animation-Layer in den Overlay-Fenstern haben den Ursprung links unten.
enum ScreenCoords {
    static func layerY(topDown y: Double, height: Double) -> Double { height - y }

}
