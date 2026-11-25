import CoreGraphics
import Foundation

/// Schneeschicht auf einer Fensterkante als Höhenprofil.
struct SnowPile {
    static let maxHeight: Float = 12
    static let columnWidth: Double = 4
    private(set) var columns: [Float]

    init(width: Double) {
        columns = Array(repeating: 0, count: max(2, Int(ceil(width / SnowPile.columnWidth))))
    }

    var width: Double { Double(columns.count) * SnowPile.columnWidth }
    var meanHeight: Float { columns.reduce(0, +) / Float(columns.count) }
    var fill: Float { meanHeight / SnowPile.maxHeight }
    var isEmpty: Bool { columns.allSatisfy { $0 < 0.05 } }

    /// Eine Flocke landet bei x: weicher Hügel, wird zum Maximum hin langsamer.
    mutating func deposit(at x: Double, amount: Float) {
        let c = x / SnowPile.columnWidth
        let radius = 4
        for i in max(0, Int(c) - radius)...min(columns.count - 1, Int(c) + radius) {
            let d = (Double(i) + 0.5 - c) / 2.2
            let k = Float(exp(-d * d))
            let room = max(0, 1 - columns[i] / SnowPile.maxHeight)
            columns[i] = min(SnowPile.maxHeight, columns[i] + amount * k * room)
        }
    }

    /// Entfernt einen Anteil des vorhandenen Schnees und gibt die entfernte Höhensumme zurück.
    @discardableResult
    mutating func remove(fraction: Float) -> Float {
        var removed: Float = 0
        for i in columns.indices { removed += columns[i] * fraction; columns[i] *= 1 - fraction }
        return removed
    }

    /// Nimmt nur im Bereich x0...x1 einen Anteil weg (Abrutschen an einer Ecke).
    @discardableResult
    mutating func remove(fraction: Float, from x0: Double, to x1: Double) -> Float {
        var removed: Float = 0
        let lo = max(0, Int(x0 / SnowPile.columnWidth)), hi = min(columns.count - 1, Int(x1 / SnowPile.columnWidth))
        guard lo <= hi else { return 0 }
        for i in lo...hi { removed += columns[i] * fraction; columns[i] *= 1 - fraction }
        return removed
    }

    mutating func clear() { for i in columns.indices { columns[i] = 0 } }

    /// Passt das Profil einer geänderten Fensterbreite an.
    mutating func resize(width newWidth: Double) {
        let n = max(2, Int(ceil(newWidth / SnowPile.columnWidth)))
        guard n != columns.count else { return }
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let src = Double(i) * Double(columns.count) / Double(n)
            out[i] = columns[min(columns.count - 1, Int(src))]
        }
        columns = out
    }

    /// Höhe an der Stelle x (linear interpoliert).
    func height(at x: Double) -> Float {
        let c = x / SnowPile.columnWidth - 0.5
        let i = Int(floor(c))
        let f = Float(c - Double(i))
        let a = columns[min(max(i, 0), columns.count - 1)]
        let b = columns[min(max(i + 1, 0), columns.count - 1)]
        return a + (b - a) * f
    }
}

enum WindowEdges {
    /// Sichtbare x-Abschnitte der Oberkante von `window`. `above` sind die Fenster davor.
    static func visibleSegments(of window: CGRect, above: [CGRect]) -> [ClosedRange<Double>] {
        var segs: [ClosedRange<Double>] = [Double(window.minX)...Double(window.maxX)]
        for o in above where o.minY <= window.minY + 0.5 && o.maxY > window.minY + 0.5 {
            let cut = Double(o.minX)...Double(o.maxX)
            segs = segs.flatMap { s -> [ClosedRange<Double>] in
                guard s.overlaps(cut) else { return [s] }
                var r: [ClosedRange<Double>] = []
                if s.lowerBound < cut.lowerBound { r.append(s.lowerBound...cut.lowerBound) }
                if s.upperBound > cut.upperBound { r.append(cut.upperBound...s.upperBound) }
                return r
            }
        }
        return segs.filter { $0.upperBound - $0.lowerBound > 6 }
    }
}
