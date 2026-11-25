import Foundation

enum LightPattern: String, CaseIterable {
    case steady, twinkle, chase
}

/// Zeitplan der Birnen: liefert pro Birne die Helligkeit 0 (gedimmt) bis 1 (voll).
enum PatternSchedule {
    static func brightness(index: Int, count: Int, time: Double, pattern: LightPattern, tempo: Double) -> Double {
        switch pattern {
        case .steady: return 1
        case .twinkle: return twinkle(index: index, time: time * tempo)
        case .chase: return chase(index: index, count: count, time: time * tempo)
        }
    }

    /// Länge einer Phase in Sekunden. In geraden Phasen dürfen nur Birnen mit gerader Nummer dimmen, in ungeraden nur die ungeraden.
    /// Benachbarte Birnen haben unterschiedliche Parität und dimmen deshalb nie gleichzeitig.
    static let twinklePhase = 6.0
    /// Wahrscheinlichkeit, dass eine Birne in ihrer Phase dimmt. Ergibt etwa 6 % gleichzeitig gedimmte Birnen.
    static let twinkleChance = 0.5

    /// Jede Birne dimmt höchstens einmal pro eigener Phase für 1,5 bis 3 s, Aus- und Aufglimmen je bis 0,8 s weich.
    static func twinkle(index: Int, time t: Double) -> Double {
        let phase = Int(floor(t / twinklePhase))
        guard (phase + index) % 2 == 0, stableRandom(index, phase, 21) < twinkleChance else { return 1 }
        let d = 1.5 + 1.5 * stableRandom(index, phase, 22)
        let start = Double(phase) * twinklePhase + stableRandom(index, phase, 23) * (twinklePhase - d)
        let u = t - start
        guard u > 0, u < d else { return 1 }
        let fade = min(0.8, d / 2.2)
        let depth = u < fade ? u / fade : (u > d - fade ? (d - u) / fade : 1)
        let s = depth * depth * (3 - 2 * depth)
        return 1 - s
    }

    /// Heller Abschnitt wandert von links nach rechts, Rest gedimmt.
    static func chase(index: Int, count: Int, time t: Double) -> Double {
        guard count > 0 else { return 1 }
        let width = max(3.0, Double(count) * 0.16)
        let speed = max(3.0, Double(count) / 9.0)
        let travel = Double(count) + width * 2
        let head = (t * speed).truncatingRemainder(dividingBy: travel) - width
        let rel = (Double(index) - head) / width
        guard rel > -0.25, rel < 1.25 else { return 0 }
        let x = rel < 0 ? 1 + rel / 0.25 : (rel > 1 ? 1 - (rel - 1) / 0.25 : 1)
        return x * x * (3 - 2 * x)
    }
}
