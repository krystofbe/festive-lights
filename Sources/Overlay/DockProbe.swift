import AppKit
import os

/// Dock-Geometrie ohne Bedienungshilfen über den Treffer-Test des Fensterservers (`NSWindow.windowNumber(at:belowWindowWithWindowNumber:)`).
/// Alle Abfragen laufen auf einer eigenen Queue. Der Haupt-Thread bekommt nur fertige Ergebnisse, hängt also nie am Fensterserver.
/// Im Ruhezustand läuft nichts: Es wird nur bei Ereignissen gemessen (App gestartet oder beendet, Dock- oder Bildschirmeinstellungen,
/// Zeiger an der Dock-Kante bei Auto-Hide) und während der Vergrößerung, solange der Zeiger über dem Dock ist.
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

    private let queue = DispatchQueue(label: "ms.blckbox.FestiveLights.dockprobe", qos: .userInteractive)
    private let signposter = OSSignposter(subsystem: "ms.blckbox.FestiveLights", category: "dock")
    private var observers: [NSObjectProtocol] = []
    private var burstTimer: Timer?
    private var burstUntil = 0.0
    private var measuring = false
    private var loopRunning = false
    private var stopLoop = false
    private var stabilizer = DockFrameStabilizer()
    private var placed: Placed?
    private var snapshot: Snapshot?
    private var running = false
    private var pointerInZone = false

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
        let nc = NSWorkspace.shared.notificationCenter
        for n in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
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
        stopLoop = true
        observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0); DistributedNotificationCenter.default().removeObserver($0) }
        observers = []
        stabilizer = DockFrameStabilizer()
    }

    /// Nach einem Ereignis kurz häufig messen, bis das Dock seine neue Größe erreicht hat.
    func burst() {
        guard running else { return }
        burstUntil = CACurrentMediaTime() + 1.5
        measureNow()
        guard burstTimer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            guard let self else { return }
            if CACurrentMediaTime() > self.burstUntil { self.burstTimer?.invalidate(); self.burstTimer = nil; return }
            self.measureNow()
        }
        RunLoop.main.add(t, forMode: .common)
        burstTimer = t
    }

    // MARK: Zeiger

    /// Bei jedem Mausereignis: billige Prüfung, sonst nichts.
    func pointerMoved() {
        guard running, let p = placed, let s = snapshot else { return }
        let m = NSEvent.mouseLocation
        let zone = Self.zone(p, large: s.large).insetBy(dx: -4, dy: -4)
        let inside = zone.contains(m)
        if inside && s.magnification && !loopRunning { startLoop(p, s) }
        if inside != pointerInZone {
            pointerInZone = inside
            if s.autohide { burst() }   // Dock fährt ein oder aus
        }
        // Auto-Hide: Zeiger an der Dock-Kante des Bildschirms lässt das Dock erscheinen
        if s.autohide, !inside, let f = Self.edgeStrip(screens: s.screens, orientation: s.orientation), f.contains(m) { burst() }
    }

    private static func zone(_ p: Placed, large: Double) -> CGRect {
        let f = p.frame, r = large * 1.7 + 20
        switch p.edge {
        case .bottom: return CGRect(x: f.minX + p.bar.a - r, y: f.minY, width: p.bar.b - p.bar.a + 2 * r, height: p.bar.thick + r)
        case .left: return CGRect(x: f.minX, y: f.minY + p.bar.a - r, width: p.bar.thick + r, height: p.bar.b - p.bar.a + 2 * r)
        case .right: return CGRect(x: f.maxX - p.bar.thick - r, y: f.minY + p.bar.a - r, width: p.bar.thick + r, height: p.bar.b - p.bar.a + 2 * r)
        }
    }

    private static func edgeStrip(screens: [ScreenInfo], orientation: String) -> CGRect? {
        guard let f = screens.first?.frame else { return nil }
        switch ContinuousDock.edge(orientation: orientation) {
        case .bottom: return CGRect(x: f.minX, y: f.minY, width: f.width, height: 3)
        case .left: return CGRect(x: f.minX, y: f.minY, width: 3, height: f.height)
        case .right: return CGRect(x: f.maxX - 3, y: f.minY, width: 3, height: f.height)
        }
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
        guard running, !measuring else { return }
        measuring = true
        let snap = takeSnapshot()
        snapshot = snap
        queue.async { [weak self] in
            let t0 = CACurrentMediaTime()
            let found = Self.measure(snap)
            let ms = (CACurrentMediaTime() - t0) * 1000
            DispatchQueue.main.async {
                guard let self else { return }
                self.measuring = false
                self.probeMsMax = max(self.probeMsMax, ms); self.probeMsSum += ms; self.probeRuns += 1
                self.handle(found, snap)
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

    /// Hintergrund: Leiste suchen. nil: nichts getroffen.
    private static func measure(_ s: Snapshot) -> Placed? {
        let ids = dockWindowIDs()
        guard !ids.isEmpty else { return nil }
        let edge = ContinuousDock.edge(orientation: s.orientation)
        for (i, sc) in s.screens.enumerated() {
            let f = sc.frame
            let len = edge == .bottom ? Double(f.width) : Double(f.height)
            if let bar = DockProbeLogic.findBar(length: len, hit: { hit(ids, f, edge, $0, $1) }) {
                return Placed(screenIndex: i, edge: edge, frame: f, bar: bar)
            }
        }
        return nil
    }

    private func expectedThickness(_ p: Placed, _ s: Snapshot) -> Double? {
        let sc = s.screens[p.screenIndex]
        let t: Double
        switch p.edge {
        case .bottom: t = Double(sc.visible.minY - sc.frame.minY)
        case .left: t = Double(sc.visible.minX - sc.frame.minX)
        case .right: t = Double(sc.frame.maxX - sc.visible.maxX)
        }
        return t > 1 ? t : nil
    }

    private func handle(_ found: Placed?, _ s: Snapshot) {
        guard running else { return }
        guard let p = found else {
            placed = nil
            // Nichts getroffen: bei Auto-Hide ist das Dock ausgeblendet, sonst nicht ermittelbar
            if let c = stabilizer.feed(time: CACurrentMediaTime(), frame: nil), c == nil {
                onResult?(s.autohide ? .hidden : .unavailable)
            }
            return
        }
        let screenLen = p.edge == .bottom ? Double(p.frame.width) : Double(p.frame.height)
        guard DockProbeLogic.isPlausible(p.bar, tile: s.tile, screenLength: screenLen, expectedThickness: s.autohide ? nil : expectedThickness(p, s)) else {
            placed = nil
            onResult?(.unavailable)
            return
        }
        placed = p
        let f = p.frame, b = p.bar
        let o = p.edge == .bottom ? Double(f.minX) : Double(f.minY)
        let a = o + b.a, e = o + b.b, icon = max(b.thick - 6, 10)
        let geo: DockGeometry
        switch p.edge {
        case .bottom:
            geo = DockGeometry(screenID: Self.displayID(s.screens[p.screenIndex].frame), edge: .bottom, rect: CGRect(x: a, y: f.minY, width: e - a, height: icon), edgeLine: Double(f.minY) + b.thick)
        case .left:
            geo = DockGeometry(screenID: Self.displayID(f), edge: .left, rect: CGRect(x: f.minX, y: a, width: icon, height: e - a), edgeLine: Double(f.minX) + b.thick)
        case .right:
            geo = DockGeometry(screenID: Self.displayID(f), edge: .right, rect: CGRect(x: f.maxX - icon, y: a, width: icon, height: e - a), edgeLine: Double(f.maxX) - b.thick)
        }
        if let c = stabilizer.feed(time: CACurrentMediaTime(), frame: geo.rect), c != nil { onResult?(.visible(geo)) }
    }

    private static func displayID(_ frame: CGRect) -> CGDirectDisplayID {
        NSScreen.screens.first { $0.frame == frame }?.displayID ?? 0
    }

    // MARK: Vergrößerung

    private func startLoop(_ p: Placed, _ s: Snapshot) {
        loopRunning = true
        stopLoop = false
        queue.async { [weak self] in
            let ids = Self.dockWindowIDs()
            let f = p.frame
            let edge = p.edge
            var lingerUntil = 0.0
            var lastU = 0.0
            while true {
                let t0 = CACurrentMediaTime()
                if self?.stopLoop ?? true { break }
                // Zeiger über CGEvent (thread-sicher, Ursprung oben links) nach Cocoa umrechnen
                let loc = CGEvent(source: nil)?.location ?? .zero
                let m = CGPoint(x: loc.x, y: s.primaryHeight - loc.y)
                let (mu, md): (Double, Double)
                switch edge {
                case .bottom: (mu, md) = (Double(m.x - f.minX), Double(m.y - f.minY))
                case .left: (mu, md) = (Double(m.y - f.minY), Double(m.x - f.minX))
                case .right: (mu, md) = (Double(m.y - f.minY), Double(f.maxX - m.x))
                }
                let r = s.large * 1.7 + 20
                let inside = mu > p.bar.a - r && mu < p.bar.b + r && md < p.bar.thick + r && md > -4
                if inside { lingerUntil = t0 + 0.8; lastU = mu } else if t0 > lingerUntil { break }
                let spans = DockProbeLogic.profile(bar: p.bar, pointerU: lastU, reach: s.large * 2.6, maxExtra: s.large * 1.4 + 20) { DockProbe.hit(ids, f, edge, $0, $1) }
                let o = edge == .bottom ? Double(f.minX) : Double(f.minY)
                let abs: [DockProfile.Span] = spans.map { sp in
                    edge == .bottom ? DockProfile.Span(a: sp.a + o, b: sp.b + o, lift: sp.lift) : DockProfile.Span(a: sp.a + o, b: sp.b + o, lift: sp.lift)
                }
                let ms = (CACurrentMediaTime() - t0) * 1000
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.probeMsMax = max(self.probeMsMax, ms); self.probeMsSum += ms; self.probeRuns += 1
                    let st = CACurrentMediaTime()
                    let sp = self.signposter.beginInterval("applySpans")
                    self.onSpans?(abs, edge)
                    self.signposter.endInterval("applySpans", sp)
                    let d = (CACurrentMediaTime() - st) * 1000
                    self.mainMsMax = max(self.mainMsMax, d); self.mainMsSum += d; self.mainFrames += 1
                }
                let elapsed = CACurrentMediaTime() - t0
                if elapsed < 1.0 / 90 { usleep(UInt32((1.0 / 90 - elapsed) * 1_000_000)) }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.loopRunning = false
                self.onSpans?([], edge)
            }
        }
    }
}
