import AppKit
import SwiftUI

/// Menüleisten-Symbol, Menü und die beiden Popovers.
final class StatusController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var timer: Timer?
    private var frame = 0
    private var shown: (Int, Bool)?
    private let app: AppController
    private var popover: NSPanel?
    private var closeTimer: Timer?
    private var outsideMonitor: Any?

    init(app: AppController) {
        self.app = app
        super.init()
        item.button?.image = MenubarIcon.image(frame: 0, animated: false)
        item.button?.setAccessibilityLabel("FestiveLights")
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        rebuild(menu)
        updateIcon()
    }

    func setAnimating(_ on: Bool) {
        timer?.invalidate(); timer = nil
        shown = nil
        if on {
            let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.frame = (self.frame + 1) % MenubarIcon.frameCount
                self.updateIcon()
            }
            t.tolerance = 0.05
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
        updateIcon()
    }

    var debugAppearance: String {
        "frame=\(item.button?.window?.frame ?? .zero) screens=\(NSScreen.screens.map(\.frame)) btn=\(item.button?.effectiveAppearance.name.rawValue ?? "-") win=\(item.button?.window?.effectiveAppearance.name.rawValue ?? "-") app=\(NSApp.effectiveAppearance.name.rawValue)"
    }

    func updateIcon() {
        guard let button = item.button else { return }
        let animated = timer != nil
        let img = MenubarIcon.image(frame: animated ? frame : 0, animated: animated)
        if button.image !== img { button.image = img }
    }

    func menuNeedsUpdate(_ menu: NSMenu) { rebuild(menu) }

    private func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        let s = Settings.shared
        func add(_ key: String, _ sel: Selector, on: Bool = false, enabled: Bool = true, key k: String = "") {
            let m = NSMenuItem(title: String(localized: String.LocalizationValue(key)), action: sel, keyEquivalent: k)
            m.target = self
            m.state = on ? .on : .off
            m.isEnabled = enabled
            menu.addItem(m)
        }
        add("menu.pause", #selector(pause), on: s.paused)
        menu.addItem(.separator())
        add("menu.lights", #selector(toggleLights), on: s.lightsEnabled)
        if Permission.granted {
            add("menu.dock", #selector(toggleDock), on: s.dockLights)
        } else {
            add("menu.dock.needs", #selector(openPermission))
        }
        add("menu.snow", #selector(toggleSnow), on: s.snowEnabled)
        add("menu.storm", #selector(storm), on: app.stormRunning, enabled: !app.reduceMotionActive)
        menu.addItem(.separator())
        add("menu.settings", #selector(openSettings), key: ",")
        add("menu.quit", #selector(quit), key: "q")
    }

    @objc private func pause() { Settings.shared.paused.toggle() }
    @objc private func toggleLights() { Settings.shared.lightsEnabled.toggle() }
    @objc private func toggleDock() { Settings.shared.dockLights.toggle() }
    @objc private func toggleSnow() { Settings.shared.snowEnabled.toggle() }
    @objc private func storm() { app.toggleStorm() }
    @objc private func openSettings() { app.showSettings() }
    @objc private func openPermission() { Permission.request(); Permission.openSystemSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    /// Zeigt ein Popover unter dem Symbol, ohne den Fokus zu nehmen. Schließt nach `seconds` oder bei Klick daneben.
    /// Eigenes Panel statt NSPopover: NSPopover saß auf macOS 26 etwa 230 pt zu tief.
    func showPopover(_ content: some View, seconds: Double) {
        guard let button = item.button, let win = button.window, win.isVisible,
              let screen = NSScreen.screens.first(where: { $0.frame.intersects(win.frame) }) else { return }
        closePopover()
        let host = NSHostingView(rootView: content)
        let size = host.fittingSize
        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .popover
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true
        host.frame = effect.bounds
        host.autoresizingMask = [.width, .height]
        effect.addSubview(host)
        let panel = PopoverPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.contentView = effect
        var x = win.frame.midX - size.width / 2
        x = min(max(x, screen.frame.minX + 8), screen.frame.maxX - size.width - 8)
        panel.setFrameOrigin(NSPoint(x: x, y: win.frame.minY - size.height - 6))
        panel.orderFrontRegardless()
        popover = panel
        closeTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in self?.closePopover() }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.closePopover() }
    }

    func closePopover() {
        closeTimer?.invalidate(); closeTimer = nil
        if let m = outsideMonitor { NSEvent.removeMonitor(m); outsideMonitor = nil }
        popover?.orderOut(nil); popover = nil
    }

    func showWelcome() {
        showPopover(WelcomeView { [weak self] in self?.closePopover(); self?.app.startStorm() }, seconds: 20)
    }

    func showPermissionPrompt() {
        showPopover(PermissionPromptView { [weak self] in
            self?.closePopover(); Permission.request(); Permission.openSystemSettings()
        }, seconds: 45)
    }
}

final class PopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
