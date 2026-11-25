import Foundation

/// Form der oberen Fensterecken, damit die Schneeschicht der sichtbaren Fensterform folgt.
enum WindowCorners {
    /// Empirisch gemessen: macOS 26 hat Ecken mit etwa 26 pt Radius, frühere Versionen etwa 10 pt.
    static func radius(forMajorVersion v: Int) -> Double { v >= 26 ? 26 : 10 }

    static var currentRadius: Double { radius(forMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion) }

    /// Wie weit die Fensterkante an Abstand d vom Seitenrand unter der Oberkante liegt (0 ab d >= r).
    static func edgeDrop(distanceFromSide d: Double, radius r: Double) -> Double {
        guard d < r, r > 0 else { return 0 }
        let dd = max(d, 0)
        return r - (r * r - (r - dd) * (r - dd)).squareRoot()
    }

    /// Dicke der Schicht 0...1: Null am Seitenrand, volle Dicke ab etwa 1,4 Radien.
    static func taper(distanceFromSide d: Double, radius r: Double) -> Double {
        let t = min(max(d / (r * 1.4), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
