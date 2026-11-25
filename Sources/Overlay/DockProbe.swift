import AppKit
import os

/// Dock-Geometrie ohne Bedienungshilfen über den Treffer-Test des Fensterservers (`NSWindow.windowNumber(at:belowWindowWithWindowNumber:)`).
///
/// Threading: Alle Treffer-Tests laufen auf eigenen seriellen Queues (nie auf dem Haupt-Thread), der Haupt-Thread bekommt nur fertige
/// Ergebnisse. Ob `windowNumber(at:belowWindowWithWindowNumber:)` abseits des Haupt-Threads zugesichert ist, steht in der Apple-Dokumentation
/// nicht. Das ist ein bewusst akzeptiertes Restrisiko: Der Aufruf fragt nur den Fensterserver ab und ändert keinen Zustand. Er wurde im
/// Dauertest (mehrere zehntausend Aufrufe, parallel zu Fensteränderungen) ohne Auffälligkeiten genutzt, siehe DECISIONS.md.
///
/// Ruhezustand: Es läuft nichts. Gemessen wird nur bei Ereignissen (App gestartet oder beendet, Space-Wechsel, Dock- oder Bildschirm-
/// einstellungen, Zeiger an der Dock-Kante bei Auto-Hide) und während der Vergrößerung, solange der Zeiger über dem Dock ist.
/// Hängt der Fensterserver, wacht ein Watchdog auf dem Haupt-Thread: Die Kette bleibt stehen, Hänger werden aufgegeben.
final class DockProbe {
    enum Result { case visible(DockGeometry), hidden, unavailable }

    var onResult: ((Result) -> Void)?
    var onSpans: (([DockProfile.Span], DockEdge) -> Void)?

    private struct Snapshot {
        var screens: [ScreenInfo]
        var primaryHeight: Double
        var orientation: String
        var autohide: Bool
        var tile: Double
        var large: Double
        var magnification: Bool
    }

    private struct Placed {
        var screenIndex: Int
        var edge: DockEdge
        var frame: CGRect
        var bar: DockProbeLogic.Bar
    }

    private struct Measured {
        var placed: Placed?
        var plausible: Bool
    }

    private let measureQueue = DispatchQueue(label: "ms.blckbox.FestiveLights.dockprobe.measure", qos: .userInteractive)
    private let loopQueue = DispatchQueue(label: "ms.blckbox.FestiveLights.dockprobe.loop", qos: .userInteractive)
    private let signposter = OSSignposter(subsystem: "ms.blckbox.FestiveLights", category: "dock")

    // nur Haupt-Thread
    private var observers: [NSObjectProtocol] = []
    private var burstTimer: Timer?
    private var watchdog: Timer?
    private var burstStart = 0.0
    private var burstUntil = 0.0
    private var measuring = false
    private var measureStarted = 0.0
    private var generation = 0
    private var loopRunning = false
    private var machine = DockStateMachine()
    private var placed: Placed?
    private var snapshot: Snapshot?
    private var lastGeo: DockGeometry?
    private var running = false
    private var pointerInside = false

    // zwischen den Threads
    private let stopLoop = OSAllocatedUnfairLock(initialState: false)
    private let heartbeat = OSAllocatedUnfairLock(initialState: 0.0)
    private let slot = OSAllocatedUnfairLock<(spans: [DockProfile.Span], edge: DockEdge)?>(initialState: nil)

    // Messwerte für Tests und Abnahme: Haupt-Thread (ms je Bild) und Hintergrund (ms je Messung)
    private(set) var mainMsMax = 0.0, mainMsSum = 0.0, mainFrames = 0
    private(set) var probeMsMax = 0.0, probeMsSum = 0.0, probeRuns = 0
    var statsLine: String {
        String(format: "main avg=%.3f max=%.3f frames=%d | probe avg=%.2f max=%.2f runs=%d", mainFrames > 0 ? mainMsSum / Double(mainFrames) : 0, mainMsMax, mainFrames,
               probeRuns > 0 ? probeMsSum / Double(probeRuns) : 0, probeMsMax, probeRuns)
    }

    func start() {
        guard !running else { return }
        running = true
        machine.reset()
        let nc = NSWorkspace.shared.notificationCenter
        for n in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(nc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in self?.burst() })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.burst() })
        observers.append(DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.dock.prefchanged"), object: nil, queue: .main) { [weak self] _ in self?.burst() })
        burst()
    }

    func stop() {
        guard running else { return }
        running = false
        burstTimer?.invalidate(); burstTimer = nil
        watchdog?.invalidate(); watchdog = nil
        stopLoop.withLock { $0 = true }
        generation += 1
        measuring = false
        loopRunning = false
        observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0); DistributedNotificationCenter.default().removeObserver($0) }
        observers = []
    }

    /// Nach einem Ereignis häufig messen, bis das Dock seinen Endzustand erreicht hat (längstens 6 s).
    func burst() {
        guard running else { return }
        let now = CACurrentMediaTime()
        if burstTimer == nil { burstStart = now; snapshot = takeSnapshot() }   // Einstellungen einmal je Burst lesen
        burstUntil = now + 1.5
        measureNow()
        guard burstTimer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            let t = CACurrentMediaTime()
            // solange der Zustand sich noch ändert (späte Dock-Animation), weitermessen
            if t > self.burstUntil, self.machine.isSettling, t - self.burstStart < 6 { self.burstUntil = t + 0.3 }
            if t > self.burstUntil { self.burstTimer?.invalidate(); self.burstTimer = nil; return }
            self.measureNow()
        }
        RunLoop.main.add(t, forMode: .common)
        burstTimer = t
        startWatchdog()
    }

    // MARK: Zeiger

    /// Bei jedem Mausereignis: billige Entscheidung ohne Nebenwirkung, sonst nichts.
    func pointerMoved() {
        guard running, let s = snapshot else { return }
        let zone = placed.map { p in
            DockPointerLogic.barZone(a: p.bar.a, length: p.bar.b - p.bar.a, thick: p.bar.thick, grow: max(s.large - s.tile, 0) + 8, edge: p.edge, screen: p.frame)
        }
        let strip = Self.edgeStrip(screen: (placed?.frame ?? s.screens.first?.frame), orientation: s.orientation)
        let (action, inside) = DockPointerLogic.react(pointer: NSEvent.mouseLocation, barZone: zone, edgeStrip: strip, autohide: s.autohide,
                                                      magnification: s.magnification, loopRunning: loopRunning, wasInside: pointerInside)
        pointerInside = inside
        if action.startMagnificationLoop, let p = placed { startLoop(p, s) }
        if action.burst { burst() }
    }

    private static func edgeStrip(screen: CGRect?, orientation: String) -> CGRect? {
        guard let f = screen else { return nil }
        switch ContinuousDock.edge(orientation: orientation) {
        case .bottom: return CGRect(x: f.minX, y: f.minY, width: f.width, height: 3)
        case .left: return CGRect(x: f.minX, y: f.minY, width: 3, height: f.height)
        case .right: return CGRect(x: f.maxX - 3, y: f.minY, width: 3, height: f.height)
        }
    }

    // MARK: Watchdog

    private func startWatchdog() {
        guard watchdog == nil else { return }
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = CACurrentMediaTime()
            if self.measuring, now - self.measureStarted > 0.3 { self.generation += 1; self.measuring = false }   // Hänger aufgeben
            if self.loopRunning, now - self.heartbeat.withLock({ $0 }) > 0.5 {
                self.stopLoop.withLock { $0 = true }
                self.loopRunning = false
            }
            if !self.measuring && !self.loopRunning && self.burstTimer == nil { self.watchdog?.invalidate(); self.watchdog = nil }
        }
        RunLoop.main.add(t, forMode: .common)
        watchdog = t
    }

    // MARK: Messen im Ruhezustand

    private func takeSnapshot() -> Snapshot {
        func pref<T>(_ k: String) -> T? { CFPreferencesCopyAppValue(k as CFString, "com.apple.dock" as CFString) as? T }
        return Snapshot(screens: NSScreen.screens.map { ScreenInfo(frame: $0.frame, visible: $0.visibleFrame) },
                        primaryHeight: Double(NSScreen.screens.first?.frame.height ?? 0),
                        orientation: pref("orientation") ?? "bottom",
                        autohide: pref("autohide") ?? false,
                        tile: pref("tilesize") ?? 64,
                        large: pref("largesize") ?? 128,
                        magnification: pref("magnification") ?? false)
    }

    private func measureNow() {
        guard running, !measuring, let snap = snapshot else { return }
        measuring = true
        measureStarted = CACurrentMediaTime()
        startWatchdog()
        let gen = generation
        measureQueue.async { [weak self] in
            let t0 = CACurrentMediaTime()
            let m = Self.measure(snap)
            let ms = (CACurrentMediaTime() - t0) * 1000
            DispatchQueue.main.async {
                guard let self, gen == self.generation else { return }   // veraltete Ergebnisse nach Hänger oder Stopp verwerfen
                self.measuring = false
                self.probeMsMax = max(self.probeMsMax, ms); self.probeMsSum += ms; self.probeRuns += 1
                self.handle(m, snap)
            }
        }
    }

    private static func hit(_ ids: Set<Int>, _ frame: CGRect, _ edge: DockEdge, _ u: Double, _ d: Double) -> Bool {
        let p: NSPoint
        switch edge {
        case .bottom: p = NSPoint(x: frame.minX + u, y: frame.minY + d)
        case .left: p = NSPoint(x: frame.minX + d, y: frame.minY + u)
        case .right: p = NSPoint(x: frame.maxX - 1 - d, y: frame.minY + u)
        }
        return ids.contains(NSWindow.windowNumber(at: p, belowWindowWithWindowNumber: 0))
    }

    private static func dockWindowIDs() -> Set<Int> {
        var ids = Set<Int>()
        for w in CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        where (w[kCGWindowOwnerName as String] as? String) == "Dock" && (w[kCGWindowLayer as String] as? Int) == Int(CGWindowLevelForKey(.dockWindow)) {
            if let n = w[kCGWindowNumber as String] as? Int { ids.insert(n) }
        }
        return ids
    }

    /// Hintergrund: Leiste suchen und auf Plausibilität prüfen.
    private static func measure(_ s: Snapshot) -> Measured {
        let ids = dockWindowIDs()
        guard !ids.isEmpty else { return Measured(placed: nil, plausible: false) }
        let edge = ContinuousDock.edge(orientation: s.orientation)
        for (i, sc) in s.screens.enumerated() {
            let f = sc.frame
            let len = edge == .bottom ? Double(f.width) : Double(f.height)
            if let bar = DockProbeLogic.findBar(length: len, hit: { hit(ids, f, edge, $0, $1) }) {
                let t: Double
                switch edge {
                case .bottom: t = Double(sc.visible.minY - sc.frame.minY)
                case .left: t = Double(sc.visible.minX - sc.frame.minX)
                case .right: t = Double(sc.frame.maxX - sc.visible.maxX)
                }
                let ok = DockProbeLogic.isPlausible(bar, tile: s.tile, screenLength: len, expectedThickness: s.autohide || t <= 1 ? nil : t)
                return Measured(placed: Placed(screenIndex: i, edge: edge, frame: f, bar: bar), plausible: ok)
            }
        }
        return Measured(placed: nil, plausible: false)
    }

    private func handle(_ m: Measured, _ s: Snapshot) {
        guard running else { return }
        let obs: DockObservation
        if let p = m.placed, m.plausible {
            placed = p
            let f = p.frame, b = p.bar
            let o = p.edge == .bottom ? Double(f.minX) : Double(f.minY)
            let a = o + b.a, e = o + b.b, icon = max(b.thick - 6, 10)
            let id = NSScreen.screens.first { $0.frame == f }?.displayID ?? 0
            switch p.edge {
            case .bottom: lastGeo = DockGeometry(screenID: id, edge: .bottom, rect: CGRect(x: a, y: f.minY, width: e - a, height: icon), edgeLine: Double(f.minY) + b.thick)
            case .left: lastGeo = DockGeometry(screenID: id, edge: .left, rect: CGRect(x: f.minX, y: a, width: icon, height: e - a), edgeLine: Double(f.minX) + b.thick)
            case .right: lastGeo = DockGeometry(screenID: id, edge: .right, rect: CGRect(x: f.maxX - icon, y: a, width: icon, height: e - a), edgeLine: Double(f.maxX) - b.thick)
            }
            obs = .visible(lastGeo!.rect)
        } else {
            placed = nil
            obs = m.placed == nil && s.autohide ? .hidden : .unavailable
        }
        guard let emitted = machine.observe(obs, time: CACurrentMediaTime()) else { return }
        switch emitted {
        case .visible: if let g = lastGeo { onResult?(.visible(g)) }
        case .hidden: onResult?(.hidden)
        case .unavailable: onResult?(.unavailable)
        }
    }

    // MARK: Vergrößerung

    /// Nur der jeweils letzte Stand wird geliefert: Die Schleife schreibt in einen Slot, der Haupt-Thread holt ihn ab.
    private func deliverLatest() {
        guard let v = slot.withLock({ let x = $0; $0 = nil; return x }) else { return }
        let st = CACurrentMediaTime()
        let sp = signposter.beginInterval("applySpans")
        onSpans?(v.spans, v.edge)
        signposter.endInterval("applySpans", sp)
        let d = (CACurrentMediaTime() - st) * 1000
        mainMsMax = max(mainMsMax, d); mainMsSum += d; mainFrames += 1
    }

    private func startLoop(_ p: Placed, _ s: Snapshot) {
        loopRunning = true
        stopLoop.withLock { $0 = false }
        heartbeat.withLock { $0 = CACurrentMediaTime() }
        startWatchdog()
        loopQueue.async { [weak self] in
            let ids = Self.dockWindowIDs()
            let f = p.frame, edge = p.edge
            let zone = DockPointerLogic.barZone(a: p.bar.a, length: p.bar.b - p.bar.a, thick: p.bar.thick, grow: max(s.large - s.tile, 0) + 8, edge: edge, screen: p.frame)
            var lingerUntil = 0.0, lastU = 0.0
            while true {
                let t0 = CACurrentMediaTime()
                guard let me = self, !me.stopLoop.withLock({ $0 }) else { break }
                me.heartbeat.withLock { $0 = t0 }
                // Zeiger über CGEvent (thread-sicher, Ursprung oben links) nach Cocoa umrechnen
                let loc = CGEvent(source: nil)?.location ?? .zero
                let m = CGPoint(x: loc.x, y: s.primaryHeight - loc.y)
                let inside = zone.contains(m)
                if inside { lingerUntil = t0 + 0.8; lastU = edge == .bottom ? Double(m.x - f.minX) : Double(m.y - f.minY) } else if t0 > lingerUntil { break }
                let spans = DockProbeLogic.profile(bar: p.bar, pointerU: lastU, reach: (s.large - s.tile) * 3 + 80, maxExtra: s.large - s.tile + 24) { DockProbe.hit(ids, f, edge, $0, $1) }
                let o = edge == .bottom ? Double(f.minX) : Double(f.minY)
                let abs = spans.map { DockProfile.Span(a: $0.a + o, b: $0.b + o, lift: $0.lift) }
                let ms = (CACurrentMediaTime() - t0) * 1000
                let had = me.slot.withLock { cur -> Bool in let h = cur != nil; cur = (abs, edge); return h }
                if !had { DispatchQueue.main.async { me.probeMsMax = max(me.probeMsMax, ms); me.probeMsSum += ms; me.probeRuns += 1; me.deliverLatest() } }
                let elapsed = CACurrentMediaTime() - t0
                if elapsed < 1.0 / 90 { usleep(UInt32((1.0 / 90 - elapsed) * 1_000_000)) }
            }
            DispatchQueue.main.async {
                guard let me = self else { return }
                me.loopRunning = false
                me.slot.withLock { $0 = nil }
                me.onSpans?([], edge)
            }
        }
    }
}
