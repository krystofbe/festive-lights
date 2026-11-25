import AppKit
import SwiftUI

/// Menüleisten-Symbol, Menü und die beiden Popovers.
final class StatusController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var timer: Timer?
    private var frame = 0
    private var shown: (Int, Bool)?
    private let app: AppController
    private var popover: NSPopover?
    private var closeTimer: Timer?
    private var outsideMonitor: Any?

    init(app: AppController) {
        self.app = app
        super.init()
        item.button?.image = MenubarIcon.image(frame: 0, dark: false, animated: false)
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
            let t = Timer(timeInterval: 1.0 / 8, repeats: true) { [weak self] _ in
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

    func updateIcon() {
        guard let button = item.button else { return }
        let dark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let animated = timer != nil
        let f = animated ? frame : 0
        if let s = shown, s.0 == f, s.1 == dark { return }
        shown = (f, dark)
        button.image = MenubarIcon.image(frame: f, dark: dark, animated: animated)
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

    /// Zeigt ein Popover am Symbol, ohne den Fokus zu nehmen. Schließt nach `seconds` oder bei Klick daneben.
    func showPopover(_ content: some View, seconds: Double) {
        guard let button = item.button, let win = button.window, win.isVisible,
              NSScreen.screens.contains(where: { $0.frame.intersects(win.frame) }) else { return }
        closePopover()
        let p = NSPopover()
        p.behavior = .applicationDefined
        p.animates = true
        let host = NSHostingController(rootView: content)
        p.contentViewController = host
        p.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover = p
        closeTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in self?.closePopover() }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.closePopover() }
    }

    func closePopover() {
        closeTimer?.invalidate(); closeTimer = nil
        if let m = outsideMonitor { NSEvent.removeMonitor(m); outsideMonitor = nil }
        popover?.close(); popover = nil
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
