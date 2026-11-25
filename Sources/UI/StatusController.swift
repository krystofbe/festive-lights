import AppKit
import SwiftUI

/// Menüleisten-Symbol, Menü und die beiden Popovers.
final class StatusController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var timer: Timer?
    private var frame = 0
    private var shown: (Int, Bool)?
    private let app: AppController

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

    #if DEBUG
    var debugAppearance: String {
        "frame=\(item.button?.window?.frame ?? .zero) screens=\(NSScreen.screens.map(\.frame)) btn=\(item.button?.effectiveAppearance.name.rawValue ?? "-") win=\(item.button?.window?.effectiveAppearance.name.rawValue ?? "-") app=\(NSApp.effectiveAppearance.name.rawValue)"
    }
    #endif

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
        add("menu.dock", #selector(toggleDock), on: s.dockLights)
        add("menu.snow", #selector(toggleSnow), on: s.snowEnabled)
        add("menu.storm", #selector(storm), on: app.stormRunning, enabled: !app.reduceMotionActive)
        menu.addItem(.separator())
        #if DIRECT
        add("menu.updates", #selector(checkUpdates))
        #endif
        add("menu.welcome", #selector(openWelcome))
        add("menu.settings", #selector(openSettings), key: ",")
        add("menu.quit", #selector(quit), key: "q")
    }

    #if DIRECT
    @objc private func checkUpdates() { app.checkForUpdates() }
    #endif
    @objc private func openWelcome() { app.showOnboarding() }
    @objc private func pause() { Settings.shared.paused.toggle() }
    @objc private func toggleLights() { Settings.shared.lightsEnabled.toggle() }
    @objc private func toggleDock() { Settings.shared.dockLights.toggle() }
    @objc private func toggleSnow() { Settings.shared.snowEnabled.toggle() }
    @objc private func storm() { app.toggleStorm() }
    @objc private func openSettings() { app.showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }
}
