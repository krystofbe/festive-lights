import AppKit

/// Durchklickbares, unsichtbares Fenster für Lichter oder Schnee.
final class OverlayWindow: NSWindow {
    let rootLayer = CALayer()

    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        sharingType = .none
        animationBehavior = .none
        canHide = false
        isExcludedFromWindowsMenu = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .transient]
        let view = NSView(frame: NSRect(origin: .zero, size: frame.size))
        view.layer = rootLayer
        view.wantsLayer = true
        rootLayer.masksToBounds = true
        view.setAccessibilityElement(false)
        contentView = view
        setAccessibilityElement(false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func setLayer(_ layer: DisplayLayer) {
        switch layer {
        case .above: level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) - 1)
        case .desktop: level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        }
    }

    func place(_ frame: NSRect) {
        if self.frame != frame { setFrame(frame, display: false) }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }

    /// Ursprung des Bildschirms im globalen Koordinatensystem von CGWindowList (y nach unten).
    var cgOrigin: CGPoint {
        let primaryH = NSScreen.screens.first?.frame.height ?? frame.height
        return CGPoint(x: frame.minX, y: primaryH - frame.maxY)
    }
}
