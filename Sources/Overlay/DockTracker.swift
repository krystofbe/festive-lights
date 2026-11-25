import AppKit
import ApplicationServices

enum DockEdge { case bottom, left, right }

struct DockGeometry: Equatable {
    var screenID: CGDirectDisplayID
    var edge: DockEdge
    var rect: CGRect        // Symbolleiste des Docks, Cocoa-Koordinaten
    var edgeLine: Double    // Innenkante des Docks: y bei unten, x bei links oder rechts
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
    private var timer: Timer?
    private var stabilizer = DockFrameStabilizer()
    private var burstUntil = 0.0
    private(set) var current: DockGeometry?
    private var observers: [NSObjectProtocol] = []

    func start() {
        stop()
        schedule(0.2)
        let nc = NSWorkspace.shared.notificationCenter
        for n in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(nc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in self?.burst() })
        }
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.burst() })
        observers.append(DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.dock.prefchanged"), object: nil, queue: .main) { [weak self] _ in self?.burst() })
    }

    func stop() {
        timer?.invalidate(); timer = nil
        observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0); DistributedNotificationCenter.default().removeObserver($0) }
        observers = []
        stabilizer = DockFrameStabilizer()
        if current != nil { current = nil; onChange?(nil) }
    }

    func burst() {
        burstUntil = CACurrentMediaTime() + 2.5
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

    private func poll() {
        let now = CACurrentMediaTime()
        if now > burstUntil { schedule(0.2) }
        let geo = Permission.granted ? Self.read() : nil
        // Vergrößerung beim Überfahren ignorieren: Zeiger im Dock-Bereich friert den Rahmen ein.
        if Self.magnification, let c = current, c.rect.insetBy(dx: -40, dy: -40).contains(NSEvent.mouseLocation) { return }
        guard let result = stabilizer.feed(time: now, frame: geo?.rect) else { return }
        current = result == nil ? nil : geo
        onChange?(current)
    }

    private static var magnification: Bool {
        (CFPreferencesCopyAppValue("magnification" as CFString, "com.apple.dock" as CFString) as? Bool) ?? false
    }

    static func read() -> DockGeometry? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let el = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(el, 0.15)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &ref) == .success, let kids = ref as? [AXUIElement] else { return nil }
        for k in kids {
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(k, kAXRoleAttribute as CFString, &role)
            guard (role as? String) == "AXList" else { continue }
            var pv: CFTypeRef?, sv: CFTypeRef?
            guard AXUIElementCopyAttributeValue(k, kAXPositionAttribute as CFString, &pv) == .success,
                  AXUIElementCopyAttributeValue(k, kAXSizeAttribute as CFString, &sv) == .success else { continue }
            var pos = CGPoint.zero, size = CGSize.zero
            AXValueGetValue(pv as! AXValue, .cgPoint, &pos)
            AXValueGetValue(sv as! AXValue, .cgSize, &size)
            guard size.width > 20, size.height > 20 else { continue }
            return geometry(forCGRect: CGRect(origin: pos, size: size))
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
