import AppKit

/// Gemeinsamer Zustand über alle Bildschirme: Schneesturm, Fensterliste, Schneeschichten.
final class Engine {
    static let shared = Engine()
    var fields: [SnowField] = []
    var storm: StormEnvelope?
    var onStormEnded: (() -> Void)?
    var settleActive = false
    private var lastPoll = 0.0
    private var lastShared = 0.0

    func stormFactor(_ now: Double) -> Double { storm?.factor(at: now) ?? 0 }

    func sharedTick(now: Double) {
        guard now - lastShared > 0.004 else { return }
        lastShared = now
        if let s = storm, s.isFinished(at: now) { storm = nil; onStormEnded?() }
        let store = PileStore.shared
        store.advanceMelt(time: now)
        let down = NSEvent.pressedMouseButtons & 1 != 0
        if settleActive, now - lastPoll >= (down ? 1.0 / 60 : 0.12) {
            lastPoll = now
            let bar = Double(NSStatusBar.system.thickness) + 2
            store.update(windows: WindowTracker.poll(menuBarBottom: { _ in bar }), mouseDown: down, time: now)
        }
        if !store.debris.isEmpty {
            for d in store.debris {
                for f in fields {
                    let r = f.cgFrame
                    if r.contains(CGPoint(x: d.x, y: d.y)) { f.spawnDebris(at: CGPoint(x: d.x - r.minX, y: d.y - r.minY), count: d.count) }
                }
            }
            store.debris.removeAll()
        }
    }

    func targets(for screen: NSScreen) -> [PileTarget] {
        guard settleActive else { return [] }
        let oy = Double(screen.cgOrigin.y)
        return PileStore.shared.entries.map { id, e in
            PileTarget(id: id, topY: Double(e.frame.minY) - oy, originX: Double(e.frame.minX), segments: e.segments)
        }
    }
}
