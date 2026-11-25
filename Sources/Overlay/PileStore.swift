import AppKit

struct TrackedWindow {
    var id: Int
    var frame: CGRect       // globale Koordinaten, y nach unten
    var above: [CGRect]
}

/// Liest die Fensterliste (nur Geometrie, keine Berechtigung nötig).
enum WindowTracker {
    /// Menüleistenkante je Bildschirm in CG-Koordinaten (y nach unten), damit auch Zweitbildschirme über oder unter dem Hauptbildschirm stimmen.
    private struct ScreenBar { var rect: CGRect; var barBottom: Double }

    static func poll() -> [TrackedWindow] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        let screens = NSScreen.screens.map { s in
            ScreenBar(rect: CGRect(origin: s.cgOrigin, size: s.frame.size), barBottom: Double(s.cgOrigin.y) + Double(max(s.frame.maxY - s.visibleFrame.maxY, 0)))
        }
        var occluders: [CGRect] = []
        var out: [TrackedWindow] = []
        for w in info {
            guard let layer = w[kCGWindowLayer as String] as? Int, layer >= 0, layer < 24,
                  let pid = w[kCGWindowOwnerPID as String] as? Int32,
                  let bd = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: bd),
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.1, r.width >= 40, r.height >= 20,
                  (w[kCGWindowOwnerName as String] as? String) != "Dock" else { continue }
            if pid == me {
                // eigene normale Fenster (Einstellungen) verdecken Schnee anderer Fenster, bekommen aber selbst keinen
                if layer == 0 { occluders.append(r) }
                continue
            }
            if layer == 0, let id = w[kCGWindowNumber as String] as? Int, r.width >= 140, r.height >= 80 {
                let fullscreen = screens.contains { r.width >= $0.rect.width - 2 && r.height >= $0.rect.height - 2 }
                let home = screens.first { $0.rect.contains(CGPoint(x: r.midX, y: r.midY)) } ?? screens.first
                if !fullscreen, r.minY > (home?.barBottom ?? 26) + 3 { out.append(TrackedWindow(id: id, frame: r, above: occluders)) }
            }
            occluders.append(r)
        }
        return out
    }
}

/// Schneeschichten aller Fenster.
final class PileStore {
    static let shared = PileStore()

    struct Entry {
        var pile: SnowPile
        var frame: CGRect
        var above: [CGRect]
        var segments: [ClosedRange<Double>]
        var detector = ShakeDetector()
        var missing = 0
        var version = 0
        var moving = false
        var nextSlide = 0.0
    }

    private(set) var entries: [Int: Entry] = [:]
    /// Wunsch nach herabfallendem Schnee: Punkt in globalen y-nach-unten-Koordinaten.
    struct DebrisRequest { var x: Double; var y: Double; var count: Int; var vx = 0.0; var vy = Double.nan; var gravity = 72.0; var big = false }
    var debris: [DebrisRequest] = []
    var active = false
    #if DEBUG
    var debugStirCalls = 0, debugStirHits = 0, debugEdges: [Double] = []
    #endif
    private(set) var meltStart: Double?
    /// Zeitpunkt der letzten erkannten Fensterbewegung (steuert die Abfragerate beim Ziehen).
    private(set) var lastMoveTime = 0.0

    var melt: Double { meltFactor }
    private var meltFactor = 0.0

    func setActive(_ on: Bool, time: Double) {
        if on { meltStart = nil; meltFactor = 0 }
        else if active || !entries.isEmpty, meltStart == nil { meltStart = time }
        active = on
    }

    func advanceMelt(time: Double) {
        guard let s = meltStart else { return }
        meltFactor = min(1, (time - s) / 3)
        if meltFactor >= 1 { entries.removeAll(); meltStart = nil; meltFactor = 0 }
    }

    var isIdle: Bool { entries.isEmpty }

    /// `interval`: Abstand zur letzten Abfrage. Bei seltener Abfrage genügt ein fehlendes Fenster als Beweis, bei schneller sind es zwei Abfragen.
    func update(windows: [TrackedWindow], mouseDown: Bool, time: Double, interval: Double = 0.1) {
        let seen = Set(windows.map(\.id))
        for id in entries.keys where !seen.contains(id) {
            entries[id]!.missing += 1
            if entries[id]!.missing >= (interval > 0.3 ? 1 : 2) {
                if active { collapse(entries[id]!) }
                entries[id] = nil
            }
        }
        for w in windows {
            var e = entries[w.id] ?? Entry(pile: SnowPile(width: Double(w.frame.width)), frame: w.frame, above: w.above, segments: [], nextSlide: time + Double.random(in: 12...35))
            e.missing = 0
            e.moving = false
            let moved = hypot(w.frame.minX - e.frame.minX, w.frame.minY - e.frame.minY)
            if abs(w.frame.width - e.frame.width) > 0.5 { e.pile.resize(width: Double(w.frame.width)); e.version += 1 }
            if moved > 0.5 || w.frame != e.frame {
                e.version += 1
                e.moving = moved > 0.5
                if moved > 0.5 { lastMoveTime = time }
                if moved > 2, active, e.pile.fill > 0.04 { fall(e, scatter: min(5, Int(moved / 8) + 1)) }
                if mouseDown, moved > 0.5, active {
                    let steps = e.detector.feed(time: time, position: w.frame.origin)
                    for _ in 0..<steps {
                        let removed = e.pile.remove(fraction: 1.0 / 3.0)
                        fall(e, scatter: min(40, Int(removed / 3) + 4))
                        e.version += 1
                    }
                }
            }
            if !mouseDown { e.detector.reset() }
            let segs = WindowEdges.visibleSegments(of: w.frame, above: w.above)
            if segs != e.segments { e.segments = segs; e.version += 1 }
            if active, time >= e.nextSlide {
                e.nextSlide = time + Double.random(in: 15...45)
                slideCorner(&e)
            }
            e.frame = w.frame
            e.above = w.above
            entries[w.id] = e
        }
    }

    /// Fenster weg: Die Schicht bricht sofort in feine Flocken und einzelne Brocken auseinander, die aus der Form der Schicht
    /// beschleunigt nach unten fallen (unterschiedlich schnell, mit Schwerkraft), statt langsam zu rieseln.
    private func collapse(_ e: Entry) {
        guard !e.segments.isEmpty else { return }
        let total = e.pile.columns.reduce(0, +)
        let n = min(320, Int(Double(total) * 0.8) + 10)
        for i in 0..<n {
            guard let seg = e.segments.randomElement() else { return }
            let x = Double.random(in: seg)
            let h = Double(e.pile.height(at: x - Double(e.frame.minX)))
            let big = i % 8 == 0
            debris.append(DebrisRequest(x: x, y: Double(e.frame.minY) - h * Double.random(in: 0...1), count: 1,
                                        vx: Double.random(in: -25...25), vy: Double.random(in: 0...25),
                                        gravity: Double.random(in: 550...950), big: big))
        }
    }

    private func fall(_ e: Entry, scatter: Int = 0) {
        let n = scatter > 0 ? scatter : min(160, Int(Double(e.pile.columns.reduce(0, +)) / 2.5) + 6)
        for _ in 0..<n {
            guard let seg = e.segments.randomElement() else { return }
            let x = Double.random(in: seg)
            let h = Double(e.pile.height(at: x - Double(e.frame.minX)))
            debris.append(DebrisRequest(x: x, y: Double(e.frame.minY) - h * Double.random(in: 0.3...1), count: 1))
        }
    }

    /// An einer sichtbaren Ecke rutscht ein kleines Stück Schnee ab.
    private func slideCorner(_ e: inout Entry) {
        guard e.pile.fill > 0.3 else { return }
        let r = WindowCorners.currentRadius
        let width = Double(e.frame.width)
        let candidates: [(side: Bool, x: Double)] = [
            (true, Double(e.frame.minX)), (false, Double(e.frame.maxX)),
        ].filter { c in e.segments.contains { c.side ? $0.lowerBound <= Double(e.frame.minX) + 0.5 : $0.upperBound >= Double(e.frame.maxX) - 0.5 } }
        guard let c = candidates.randomElement() else { return }
        if c.side { e.pile.remove(fraction: 0.55, from: 0, to: r * 1.6) } else { e.pile.remove(fraction: 0.55, from: width - r * 1.6, to: width) }
        e.version += 1
        for _ in 0..<14 {
            let dx = Double.random(in: 0...(r * 1.4)) * (c.side ? 1 : -1)
            let drop = WindowCorners.edgeDrop(distanceFromSide: abs(dx), radius: r)
            debris.append(DebrisRequest(x: c.x + dx, y: Double(e.frame.minY) + drop - Double.random(in: 0...6), count: 1))
        }
    }

    /// Aufstöbern: schnelles Wischen über eine Schicht lässt eine Wolke aufstieben und hinterlässt eine Delle.
    /// Koordinaten global, y nach unten.
    func stir(from a: CGPoint, to b: CGPoint, velocity v: CGVector, strength: Double, time: Double) {
        #if DEBUG
        debugStirCalls += 1
        #endif
        guard active, strength > 0 else { return }
        #if DEBUG
        debugEdges = entries.values.map { Double($0.frame.minY) }
        #endif
        let samples = 12
        for (id, e) in entries {
            let edge = Double(e.frame.minY)
            var lastX = -1e9
            for k in 0...samples {
                let t = Double(k) / Double(samples)
                let x = Double(a.x + (b.x - a.x) * t), y = Double(a.y + (b.y - a.y) * t)
                guard y > edge - 18, y < edge + 8, abs(x - lastX) >= 14, e.segments.contains(where: { $0.contains(x) }) else { continue }
                let lx = x - Double(e.frame.minX)
                let h = Double(entries[id]!.pile.height(at: lx))
                guard h > 1.0 else { continue }
                lastX = x
                #if DEBUG
                debugStirHits += 1
                #endif
                entries[id]!.pile.remove(fraction: Float(0.4 + 0.3 * strength), from: lx - 14, to: lx + 14)
                entries[id]!.version += 1
                let n = Int(3 + 10 * strength)
                for _ in 0..<n {
                    debris.append(DebrisRequest(x: x + Double.random(in: -12...12), y: edge - h * Double.random(in: 0.2...1), count: 1,
                                                // nur ein kleiner Hüpfer aus der Schicht, mitgenommen wird die Wolke von der Luft (AirField)
                                                vx: Double.random(in: -15...15),
                                                vy: -Double.random(in: 5...28) * (0.5 + 0.5 * strength) * (v.dy < -200 ? 1 : 0.6)))
                }
            }
        }
    }

    func deposit(id: Int, x: Double, amount: Float) {
        guard entries[id] != nil else { return }
        entries[id]!.pile.deposit(at: x, amount: amount)
        entries[id]!.version += 1
    }

    func clear() { entries.removeAll(); debris.removeAll() }
}
