import AppKit

struct TrackedWindow {
    var id: Int
    var frame: CGRect       // globale Koordinaten, y nach unten
    var above: [CGRect]
}

/// Liest die Fensterliste (nur Geometrie, keine Berechtigung nötig).
enum WindowTracker {
    static func poll(menuBarBottom: (CGRect) -> Double) -> [TrackedWindow] {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        let screens = NSScreen.screens.map { CGRect(origin: $0.cgOrigin, size: $0.frame.size) }
        var occluders: [CGRect] = []
        var out: [TrackedWindow] = []
        for w in info {
            guard let layer = w[kCGWindowLayer as String] as? Int, layer >= 0, layer < 24,
                  let pid = w[kCGWindowOwnerPID as String] as? Int32, pid != me,
                  let bd = w[kCGWindowBounds as String] as? NSDictionary,
                  let r = CGRect(dictionaryRepresentation: bd),
                  (w[kCGWindowAlpha as String] as? Double ?? 1) > 0.1, r.width >= 40, r.height >= 20,
                  (w[kCGWindowOwnerName as String] as? String) != "Dock" else { continue }
            if layer == 0, let id = w[kCGWindowNumber as String] as? Int, r.width >= 140, r.height >= 80 {
                let fullscreen = screens.contains { $0.insetBy(dx: -2, dy: -2).contains(r) || (abs($0.width - r.width) < 2 && abs($0.height - r.height) < 2) }
                if !fullscreen, r.minY > menuBarBottom(r) + 3 { out.append(TrackedWindow(id: id, frame: r, above: occluders)) }
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
    }

    private(set) var entries: [Int: Entry] = [:]
    /// Wunsch nach herabfallendem Schnee: Punkt in globalen y-nach-unten-Koordinaten.
    var debris: [(x: Double, y: Double, count: Int)] = []
    var active = false
    private(set) var meltStart: Double?
    private var lastWindowPoll = 0.0

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

    func update(windows: [TrackedWindow], mouseDown: Bool, time: Double) {
        let seen = Set(windows.map(\.id))
        for id in entries.keys where !seen.contains(id) {
            entries[id]!.missing += 1
            if entries[id]!.missing >= 3 {
                if active { fall(entries[id]!, fraction: 1) }
                entries[id] = nil
            }
        }
        for w in windows {
            var e = entries[w.id] ?? Entry(pile: SnowPile(width: Double(w.frame.width)), frame: w.frame, above: w.above, segments: [])
            e.missing = 0
            e.moving = false
            let moved = hypot(w.frame.minX - e.frame.minX, w.frame.minY - e.frame.minY)
            if abs(w.frame.width - e.frame.width) > 0.5 { e.pile.resize(width: Double(w.frame.width)); e.version += 1 }
            if moved > 0.5 || w.frame != e.frame {
                e.version += 1
                e.moving = moved > 0.5
                if moved > 2, active, e.pile.fill > 0.04 { fall(e, fraction: 0, scatter: min(5, Int(moved / 8) + 1)) }
                if mouseDown, moved > 0.5, active {
                    let steps = e.detector.feed(time: time, position: w.frame.origin)
                    for _ in 0..<steps {
                        let removed = e.pile.remove(fraction: 1.0 / 3.0)
                        fall(e, fraction: 0, scatter: min(40, Int(removed / 3) + 4))
                        e.version += 1
                    }
                }
            }
            if !mouseDown { e.detector.reset() }
            let segs = WindowEdges.visibleSegments(of: w.frame, above: w.above)
            if segs != e.segments { e.segments = segs; e.version += 1 }
            e.frame = w.frame
            e.above = w.above
            entries[w.id] = e
        }
    }

    private func fall(_ e: Entry, fraction: Double, scatter: Int = 0) {
        let n = scatter > 0 ? scatter : min(160, Int(Double(e.pile.columns.reduce(0, +)) / 2.5) + 6)
        for _ in 0..<n {
            guard let seg = e.segments.randomElement() else { return }
            let x = Double.random(in: seg)
            let h = Double(e.pile.height(at: x - Double(e.frame.minX)))
            debris.append((x, Double(e.frame.minY) - h * Double.random(in: 0.3...1), 1))
        }
    }

    func deposit(id: Int, x: Double, amount: Float) {
        guard entries[id] != nil else { return }
        entries[id]!.pile.deposit(at: x, amount: amount)
        entries[id]!.version += 1
    }

    func clear() { entries.removeAll(); debris.removeAll() }
}
