import Foundation

/// "Auftritt" einer Kette (ab 1.3): bestimmt zusammen Tiefe, Schmuckmenge und Größe. Je Kette ein eigener Wert.
enum Look: Int, CaseIterable {
    case subtle = 0, festive = 1, lavish = 2

    /// Tiefengrenze unter der Menüleiste in pt, nil: keine zusätzliche Grenze.
    var menuDepth: Double? { [16, 30, nil][rawValue] }
    /// Tiefengrenze am Dock als Bruchteil der Symbolhöhe, nil: keine zusätzliche Grenze.
    var dockDepthFraction: Double? { [1.0 / 6, 1.0 / 4, nil][rawValue] }
    /// Anteil des Schmucks (Kugeln, Zapfen, Schleifen), der bleibt.
    var ornamentKeep: Double { [0, 0.5, 1][rawValue] }
    /// Größe der Kette gegenüber Volle Pracht.
    var sizeFactor: Double { [0.75, 0.9, 1][rawValue] }
    /// Hängende Zweige gibt es nur ab Festlich.
    var hasHangingBranches: Bool { self != .subtle }

    /// Gleichmäßig ausdünnen: behält etwa den Anteil `keep` der Elemente, verteilt über die ganze Länge.
    static func thin<T>(_ items: [T], keep: Double) -> [T] {
        if keep >= 1 { return items }
        if keep <= 0 { return [] }
        return items.enumerated().filter { Int(Double($0.offset + 1) * keep) > Int(Double($0.offset) * keep) }.map(\.element)
    }

    /// Verkleinerung (0,3 bis 1) von Girlande, Fäden und hängenden Zweigen, damit sie `limit` nicht überschreiten.
    static func garlandFit(natural: Double, limit: Double?) -> Double {
        guard let limit, natural > 0 else { return 1 }
        return min(1, max(0.3, limit / natural))
    }

    /// Flacherer Durchhang unter einer Tiefengrenze: höchstens die Hälfte der Grenze.
    static func sagCap(_ sag: Double, limit: Double?) -> Double { limit.map { min(sag, 0.5 * $0) } ?? sag }
}

/// "Nur in Pausen": Schnee beginnt erst nach zwei Minuten ohne Eingabe.
enum SnowBreak {
    static let idleThreshold = 120.0
    static func allowsNewFlakes(onlyBreaks: Bool, idleSeconds: Double) -> Bool { !onlyBreaks || idleSeconds >= idleThreshold }
}

/// Vorderstes Fenster der aktiven App: das erste Fenster in der Liste (von vorn nach hinten), das der aktiven App gehört.
enum FrontWindow {
    static func pick(windows: [(id: Int, pid: Int32)], frontPID: Int32?) -> Int? {
        guard let frontPID else { return nil }
        return windows.first { $0.pid == frontPID }?.id
    }
}
