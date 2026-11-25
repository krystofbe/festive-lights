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

    /// Luftströmung um die Zeigerbahn, globale Koordinaten mit y nach unten (wie die Fensterliste).
    private(set) var air = AirField()
    /// Stärke des Aufstöberns im Moment, 0...1.
    private(set) var stirStrength = 0.0
    #if DEBUG
    /// Startargument `--stir-log <Datei>`: protokolliert Zeiger und aufgestöberte Flocken je Bild.
    let stirLog: FileHandle? = {
        guard let i = CommandLine.arguments.firstIndex(of: "--stir-log"), i + 1 < CommandLine.arguments.count else { return nil }
        let path = CommandLine.arguments[i + 1]
        FileManager.default.createFile(atPath: path, contents: nil)
        return FileHandle(forWritingAtPath: path)
    }()
    #endif

    func pointerEvent(_ p: CGPoint, time: Double) { tracker.feed(time: time, position: p); debugEvents += 1; debugMaxSpeed = max(debugMaxSpeed, hypot(tracker.velocity.dx, tracker.velocity.dy)) }
    private var lastShared = 0.0

    func stormFactor(_ now: Double) -> Double { storm?.factor(at: now) ?? 0 }

    func sharedTick(now: Double) {
        guard now - lastShared > 0.004 else { return }
        let dt = min(now - lastShared, 0.05)
        lastShared = now
        if let s = storm, s.isFinished(at: now) { storm = nil; onStormEnded?() }
        let store = PileStore.shared
        let pos = NSEvent.mouseLocation
        tracker.feed(time: ProcessInfo.processInfo.systemUptime, position: pos)
        let speed = tracker.speed(at: ProcessInfo.processInfo.systemUptime)
        stirStrength = reduceMotion ? 0 : Stir.strength(speed: speed)
        air.step(dt: dt)
        if stirStrength > 0, let primary = NSScreen.screens.first?.frame.height {
            let cg: (CGPoint) -> CGPoint = { CGPoint(x: $0.x, y: primary - $0.y) }
            let v = CGVector(dx: tracker.velocity.dx, dy: -tracker.velocity.dy)
            let from = cg(lastSweepPos ?? pos), to = cg(pos)
            let before = air.puffs.count
            air.feed(from: from, to: to, velocity: v)
            debugStirred += max(0, air.puffs.count - before)
            if NSEvent.pressedMouseButtons == 0 { store.stir(from: from, to: to, velocity: v, strength: stirStrength, time: now) }
        }
        #if DEBUG
        if let log = stirLog, air.isActive, let primary = NSScreen.screens.first?.frame.height {
            log.write(String(format: "P,%.4f,%.1f,%.1f,%.0f,%.0f,%.2f,%d\n", now, pos.x, primary - pos.y, tracker.velocity.dx, -tracker.velocity.dy, stirStrength, air.puffs.count).data(using: .utf8)!)
        }
        #endif
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
