import AppKit
import ApplicationServices

struct DockGeometry: Equatable {
    var screenID: CGDirectDisplayID
    var edge: DockEdge
    var rect: CGRect        // Symbolleiste des Docks, Cocoa-Koordinaten
    var edgeLine: Double    // Innenkante des Docks: y bei unten, x bei links oder rechts
    var continuous = false  // durchgehende Kette über die volle Bildschirmbreite statt genau am Dock
}

enum Permission {
    static var granted: Bool { AXIsProcessTrusted() }

    static func request() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Beobachtet Position und Größe des Docks über die Bedienungshilfen-Schnittstelle.
final class DockTracker {
    var onChange: ((DockGeometry?) -> Void)?
    /// Vergrößerte Symbole: Spannen entlang der Kette in absoluten Cocoa-Koordinaten (x bei unten, y bei seitlichem Dock).
    var onSpans: (([DockProfile.Span], DockEdge) -> Void)?
    private var restItems: [CGRect] = []
    private var magTimer: Timer?
    private var spansActive = false
    private var started = false
    private var inZone = false
    private var autohide = false
    private var magnificationOn = false
    private var tile = 64.0
    private var reading = false
    private var polling = false
    private let axQueue = DispatchQueue(label: "ms.blckbox.FestiveLights.dockax", qos: .userInteractive)
    #if DEBUG
    var debugItems = ""
    #endif
    private var timer: Timer?
    private var stabilizer = DockFrameStabilizer()
    private var burstUntil = 0.0
    private(set) var current: DockGeometry?
    private var observers: [NSObjectProtocol] = []

    func start() {
        guard timer == nil, !started else { return }
        started = true
        burst()
        let nc = NSWorkspace.shared.notificationCenter
        for n in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(nc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in self?.burst() })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.burst() })
        observers.append(DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.dock.prefchanged"), object: nil, queue: .main) { [weak self] _ in self?.burst() })
    }

    func stop(reportNil: Bool = true) {
        started = false
        timer?.invalidate(); timer = nil
        observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0); DistributedNotificationCenter.default().removeObserver($0) }
        observers = []
        stabilizer = DockFrameStabilizer()
        if current != nil { current = nil; if reportNil { onChange?(nil) } }
    }

    func burst() {
        guard started else { return }
        burstUntil = CACurrentMediaTime() + 2.5
        autohide = (CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) as? Bool) ?? false
        magnificationOn = Self.magnification
        tile = (CFPreferencesCopyAppValue("tilesize" as CFString, "com.apple.dock" as CFString) as? Double) ?? 64
        schedule(1.0 / 30)
    }

    private func schedule(_ interval: Double) {
        if let t = timer, abs(t.timeInterval - interval) < 0.001 { return }
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.poll() }
        t.tolerance = interval * 0.2
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Eine Abfrage der Bedienungshilfen auf eigener Queue (höchstens eine zugleich), der Haupt-Thread wartet nie auf das Dock.
    private func poll() {
        let now = CACurrentMediaTime()
        if now > burstUntil { timer?.invalidate(); timer = nil }   // Ruhezustand: keine laufende Abfrage, nur Ereignisse
        startMagnificationIfNeeded()
        // Vergrößerung beim Überfahren ignorieren: Zeiger im Dock-Bereich friert den Rahmen ein.
        if magnificationOn, let c = current, c.rect.insetBy(dx: -40, dy: -40).contains(NSEvent.mouseLocation) { return }
        guard !polling else { return }
        polling = true
        let primary = Double(NSScreen.screens.first?.frame.height ?? 0)
        axQueue.async { [weak self] in
            let trusted = Permission.granted
            let raw = trusted ? Self.readRect() : nil
            let rest = raw == nil ? [] : (Self.readItems(primaryHeight: primary) ?? [])
            DispatchQueue.main.async { self?.handlePolled(raw, rest) }
        }
    }

    private func handlePolled(_ raw: CGRect?, _ rest: [CGRect]) {
        polling = false
        guard started else { return }
        let geo = raw.flatMap { Self.geometry(forCGRect: $0) }
        guard let result = stabilizer.feed(time: CACurrentMediaTime(), frame: geo?.rect) else { return }
        current = result == nil ? nil : geo
        restItems = current == nil ? [] : rest
        onChange?(current)
    }

    /// Während der Zeiger über dem Dock ist (Vergrößerung an): Symbolrahmen lesen, sonst nichts tun. Die Abfrage läuft auf einer eigenen
    /// Queue (höchstens eine zugleich), der Haupt-Thread wartet nie auf das Dock. Bei der ersten Störung bricht sie ab.
    private func pollMagnification() {
        guard magnificationOn, current != nil else { stopMagnification(); return }
        let near = current!.rect.insetBy(dx: -140, dy: -140).contains(NSEvent.mouseLocation)
        if !near && !spansActive { stopMagnification(); return }
        guard !reading else { return }
        reading = true
        let primary = Double(NSScreen.screens.first?.frame.height ?? 0)
        axQueue.async { [weak self] in
            let items = Self.readItems(primaryHeight: primary)
            DispatchQueue.main.async { self?.applyItems(items) }
        }
    }

    private func applyItems(_ items: [CGRect]?) {
        reading = false
        guard magnificationOn, let c = current else { stopMagnification(); return }
        let near = c.rect.insetBy(dx: -140, dy: -140).contains(NSEvent.mouseLocation)
        guard let items, items.count == restItems.count, !items.isEmpty else { if !near && !spansActive { stopMagnification() }; return }
        var spans: [DockProfile.Span] = []
        for (r, rest) in zip(items, restItems) {
            let lift = DockProfile.lift(edge: c.edge, current: r, rest: rest, tile: tile, barLine: c.edgeLine)
            spans.append(c.edge == .bottom ? DockProfile.Span(a: Double(r.minX), b: Double(r.maxX), lift: lift)
                                           : DockProfile.Span(a: Double(r.minY), b: Double(r.maxY), lift: lift))
        }
        spansActive = spans.contains { $0.lift > 0.3 }
        #if DEBUG
        if let i = spans.indices.max(by: { spans[$0].lift < spans[$1].lift }) { debugItems = "cur=\(items[i]) rest=\(restItems[i]) lift=\(spans[i].lift) edgeLine=\(c.edgeLine) listRect=\(c.rect)" }
        #endif
        onSpans?(spans, c.edge)
        if !near && !spansActive { onSpans?([], c.edge); stopMagnification() }
    }

    private func startMagnificationIfNeeded() {
        guard magnificationOn, magTimer == nil, let c = current, c.rect.insetBy(dx: -140, dy: -140).contains(NSEvent.mouseLocation) else { return }
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.pollMagnification() }
        RunLoop.main.add(t, forMode: .common)
        magTimer = t
    }

    func pointerMoved() {
        guard started else { return }
        startMagnificationIfNeeded()
        // Auto-Hide: Dock fährt ein, wenn der Zeiger an die Kante kommt, und aus, wenn er die Zone verlässt
        let m = NSEvent.mouseLocation
        if let c = current {
            let inside = c.rect.insetBy(dx: -20, dy: -20).contains(m)
            if inside != inZone { inZone = inside; if autohide { burst() } }
        } else if autohide, let f = NSScreen.screens.first?.frame, m.y < f.minY + 3 || m.x < f.minX + 3 || m.x > f.maxX - 3 { burst() }
    }

    private func stopMagnification() { magTimer?.invalidate(); magTimer = nil; spansActive = false }

    private static var magnification: Bool {
        (CFPreferencesCopyAppValue("magnification" as CFString, "com.apple.dock" as CFString) as? Bool) ?? false
    }

    /// Rahmen aller Dock-Symbole (Cocoa-Koordinaten), bei Vergrößerung die aktuell vergrößerten.
    static func readItems(primaryHeight: Double) -> [CGRect]? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let el = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(el, 0.05)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &ref) == .success, let kids = ref as? [AXUIElement] else { return nil }
        for k in kids {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(k, kAXRoleAttribute as CFString, &role)
            guard (role as? String) == "AXList" else { continue }
            var cref: CFTypeRef?
            guard AXUIElementCopyAttributeValue(k, kAXChildrenAttribute as CFString, &cref) == .success, let items = cref as? [AXUIElement] else { return nil }
            var out: [CGRect] = []
            for it in items {
                var fv: CFTypeRef?
                guard AXUIElementCopyAttributeValue(it, "AXFrame" as CFString, &fv) == .success else { return nil }   // erste Störung: Abbruch
                var r = CGRect.zero
                AXValueGetValue(fv as! AXValue, .cgRect, &r)
                out.append(CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height))
            }
            return out
        }
        return nil
    }

    /// Rahmen der Symbolleiste des Docks in Koordinaten oben links, nur Bedienungshilfen (auch abseits des Haupt-Threads erlaubt).
    static func readRect() -> CGRect? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let el = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(el, 0.05)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &ref) == .success, let kids = ref as? [AXUIElement] else { return nil }
        for k in kids {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(k, kAXRoleAttribute as CFString, &role)
            guard (role as? String) == "AXList" else { continue }
            var pv: CFTypeRef?, sv: CFTypeRef?
            guard AXUIElementCopyAttributeValue(k, kAXPositionAttribute as CFString, &pv) == .success,
                  AXUIElementCopyAttributeValue(k, kAXSizeAttribute as CFString, &sv) == .success else { return nil }
            var pos = CGPoint.zero, size = CGSize.zero
            AXValueGetValue(pv as! AXValue, .cgPoint, &pos)
            AXValueGetValue(sv as! AXValue, .cgSize, &size)
            guard size.width > 20, size.height > 20 else { continue }
            return CGRect(origin: pos, size: size)
        }
        return nil
    }

    static func geometry(forCGRect cg: CGRect) -> DockGeometry? {
        guard let primary = NSScreen.screens.first else { return nil }
        let rect = CGRect(x: cg.minX, y: primary.frame.height - cg.maxY, width: cg.width, height: cg.height)
        guard let screen = NSScreen.screens.max(by: { $0.frame.intersection(rect).area < $1.frame.intersection(rect).area }) else { return nil }
        let visible = screen.frame.intersection(rect).area / max(rect.area, 1)
        guard visible > 0.9 else { return nil }
        let orientation = CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String ?? "bottom"
        let autohide = (CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) as? Bool) ?? false
        let vf = screen.visibleFrame, f = screen.frame
        let edge: DockEdge = orientation == "left" ? .left : orientation == "right" ? .right : .bottom
        let line: Double
        switch edge {
        case .bottom: line = autohide || vf.minY - f.minY < 2 ? rect.maxY + 6 : vf.minY
        case .left: line = autohide || vf.minX - f.minX < 2 ? rect.maxX + 6 : vf.minX
        case .right: line = autohide || f.maxX - vf.maxX < 2 ? rect.minX - 6 : vf.maxX
        }
        return DockGeometry(screenID: screen.displayID, edge: edge, rect: rect, edgeLine: line)
    }
}

extension CGRect {
    var area: CGFloat { isNull || isEmpty ? 0 : width * height }
}
