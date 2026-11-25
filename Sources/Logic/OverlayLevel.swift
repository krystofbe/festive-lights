/// Fensterebene der Overlays. Auf der gleichen Ebene liegt die Kette (mit Girlande, Zapfen, Schleifen, Kugeln) eine Stufe über dem Schnee.
enum OverlayLevel {
    static func raw(_ layer: DisplayLayer, aboveSnow: Bool, mainMenu: Int, desktop: Int) -> Int {
        switch layer {
        case .above: return mainMenu - (aboveSnow ? 1 : 2)
        case .desktop: return desktop + (aboveSnow ? 2 : 1)
        }
    }
}
