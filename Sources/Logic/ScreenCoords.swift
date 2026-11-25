import Foundation

/// Die Simulation rechnet mit Ursprung links oben (y nach unten, wie CGWindowList).
/// Core-Animation-Layer in den Overlay-Fenstern haben den Ursprung links unten.
enum ScreenCoords {
    static func layerY(topDown y: Double, height: Double) -> Double { height - y }

    /// Höhe eines Schneehügels über der Fensterkante, in Layer-Koordinaten (nach oben positiv).
    static func pileTopLayerY(edgeTopDown: Double, height h: Double, screenHeight: Double) -> Double {
        layerY(topDown: edgeTopDown, height: screenHeight) + h
    }

    /// Globales y von CGWindowList (oben) nach Cocoa (unten), bezogen auf die Höhe des Hauptbildschirms.
    static func cocoaY(fromCG y: Double, rectHeight: Double, primaryHeight: Double) -> Double {
        primaryHeight - y - rectHeight
    }
}
