import AppKit

/// Durchklickbares, unsichtbares Fenster für Lichter oder Schnee.
final class OverlayWindow: NSWindow {
    let rootLayer = CALayer()

    /// Ketten liegen auf der gleichen Ebene eine Stufe über dem Schnee, damit sie nie hinter den Flocken liegen.
    private let aboveSnow: Bool

    init(frame: NSRect, aboveSnow: Bool = false) {
        self.aboveSnow = aboveSnow
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        sharingType = .none
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugCapture") { sharingType = .readOnly }
        #endif
        animationBehavior = .none
        canHide = false
        isExcludedFromWindowsMenu = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
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

    private var currentLayer: DisplayLayer?

    func setLayer(_ layer: DisplayLayer) {
        guard layer != currentLayer else { return }
        currentLayer = layer
        level = NSWindow.Level(rawValue: OverlayLevel.raw(layer, aboveSnow: aboveSnow, mainMenu: Int(CGWindowLevelForKey(.mainMenuWindow)), desktop: Int(CGWindowLevelForKey(.desktopWindow))))
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
