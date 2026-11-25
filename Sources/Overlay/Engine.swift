import AppKit

/// Gemeinsamer Zustand über alle Bildschirme: Schneesturm, Fensterliste, Schneeschichten.
final class Engine {
    static let shared = Engine()
    var fields: [SnowField] = []
    var storm: StormEnvelope?
    var onStormEnded: (() -> Void)?
    var settleActive = false
    private var lastPoll = 0.0
    var reduceMotion = false
    var debugMaxSpeed = 0.0, debugStirred = 0, debugEvents = 0
    private var tracker = PointerVelocityTracker()
    private var lastSweepPos: CGPoint?

    struct Sweep { var from: CGPoint; var to: CGPoint; var velocity: CGVector; var strength: Double }
    /// Bewegungsbahn des Zeigers seit dem letzten Bild (globale Cocoa-Koordinaten), nur bei schneller Bewegung.
    private(set) var sweep: Sweep?

    func pointerEvent(_ p: CGPoint, time: Double) { tracker.feed(time: time, position: p); debugEvents += 1; debugMaxSpeed = max(debugMaxSpeed, hypot(tracker.velocity.dx, tracker.velocity.dy)) }
    private var lastShared = 0.0

    func stormFactor(_ now: Double) -> Double { storm?.factor(at: now) ?? 0 }

    func sharedTick(now: Double) {
        guard now - lastShared > 0.004 else { return }
        lastShared = now
        if let s = storm, s.isFinished(at: now) { storm = nil; onStormEnded?() }
        let store = PileStore.shared
        let pos = NSEvent.mouseLocation
        tracker.feed(time: ProcessInfo.processInfo.systemUptime, position: pos)
        let speed = tracker.speed(at: ProcessInfo.processInfo.systemUptime)
        let strength = reduceMotion ? 0 : Stir.strength(speed: speed)
        if strength > 0 {
            sweep = Sweep(from: lastSweepPos ?? pos, to: pos, velocity: tracker.velocity, strength: strength)
            if NSEvent.pressedMouseButtons == 0, let primary = NSScreen.screens.first?.frame.height {
                let cg: (CGPoint) -> CGPoint = { CGPoint(x: $0.x, y: primary - $0.y) }
                let v = tracker.velocity
                store.stir(from: cg(sweep!.from), to: cg(pos), velocity: CGVector(dx: v.dx, dy: -v.dy), strength: strength, time: now)
            }
        } else { sweep = nil }
        lastSweepPos = pos
        store.advanceMelt(time: now)
        let down = NSEvent.pressedMouseButtons & 1 != 0
        if settleActive, now - lastPoll >= (down ? 1.0 / 60 : 0.5) {
            lastPoll = now
            let bar = Double(NSStatusBar.system.thickness) + 2
            store.update(windows: WindowTracker.poll(menuBarBottom: { _ in bar }), mouseDown: down, time: now)
        }
        if !store.debris.isEmpty {
            for d in store.debris {
                for f in fields {
                    let r = f.cgFrame
                    if r.contains(CGPoint(x: d.x, y: d.y)) { f.spawnDebris(at: CGPoint(x: d.x - r.minX, y: d.y - r.minY), count: d.count, vx: d.vx, vy: d.vy) }
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
