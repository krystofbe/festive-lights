import Foundation

/// Verlauf des Schneesturms: baut sich in 2 s auf, endet nach 30 s oder auf Wunsch, klingt in 5 s ab.
struct StormEnvelope {
    static let rampUp = 2.0, duration = 30.0, rampDown = 5.0
    var start: Double
    var stopRequested: Double?

    private var naturalEnd: Double { start + StormEnvelope.duration }
    private var fadeStart: Double { min(naturalEnd, stopRequested ?? naturalEnd) }

    /// 0...1, Stärke des Sturms zum Zeitpunkt t.
    func factor(at t: Double) -> Double {
        guard t >= start else { return 0 }
        if t >= fadeStart {
            let up = min(1, (fadeStart - start) / StormEnvelope.rampUp)
            return max(0, up * (1 - (t - fadeStart) / StormEnvelope.rampDown))
        }
        let x = min(1, (t - start) / StormEnvelope.rampUp)
        return x * x * (3 - 2 * x)
    }

    func isFinished(at t: Double) -> Bool { t >= fadeStart + StormEnvelope.rampDown }
    func isStopping(at t: Double) -> Bool { t >= fadeStart }
}

enum Wind: String, CaseIterable { case off, left, right }

enum SnowPhysics {
    /// Horizontale Windgeschwindigkeit in pt/s für die vorderste Ebene. Böen nur bei Wind oder Sturm.
    static func windSpeed(mode: Wind, time t: Double, storm: Double, gusts: Bool = true) -> Double {
        let dir: Double = mode == .left ? -1 : 1
        let base = (mode == .off ? 0 : 38) * dir
        let stormBase = 150.0 * (mode == .left ? -1 : 1) * storm
        let windy = mode != .off || storm > 0
        guard windy else { return 0 }
        let gust = gusts ? max(0, sin(t * 0.43) * sin(t * 1.07 + 0.7)) : 0
        let strength = 0.6 + 1.1 * gust * (mode == .off ? storm : 1)
        return (base + stormBase) * strength
    }
}
