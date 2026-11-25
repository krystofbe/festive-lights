import AppKit
import Combine
import IOKit.ps

final class AppController: NSObject {
    let settings = Settings.shared
    private var overlays: [CGDirectDisplayID: ScreenOverlay] = [:]
    private var status: StatusController!
    private let dockTracker = DockTracker()
    private var bag = Set<AnyCancellable>()
    private var snowStarted = false
    private var snowRampStart: Double?
    private var suspended = false
    private var screensAsleep = false
    private var locked = false
    private var permission = Permission.granted
    private var reduceMotion = false
    private var energySaving = false
    private var dark = true
    private var dockGeometry: DockGeometry?
    private var settingsWindow: NSWindow?
    private var monitors: [Any] = []
    private var timers: [Timer] = []
    private let permissionModel = PermissionModel()
    private let loginModel = LoginModel()
    private var applyScheduled = false
    private var animating = false

    var stormRunning: Bool { Engine.shared.storm.map { !$0.isStopping(at: CACurrentMediaTime()) } ?? false }

    func start() {
        let engine = Engine.shared
        engine.onStormEnded = { [weak self] in self?.apply() }
        status = StatusController(app: self)
        refreshSystem()
        reconcileScreens()

        settings.objectWillChange.sink { [weak self] _ in self?.scheduleApply() }.store(in: &bag)

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(sleepChanged), name: NSWorkspace.willSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(sleepChanged), name: NSWorkspace.didWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(sleepChanged), name: NSWorkspace.screensDidSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(sleepChanged), name: NSWorkspace.screensDidWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(systemChanged), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        nc.addObserver(self, selector: #selector(systemChanged), name: NSNotification.Name.NSProcessInfoPowerStateDidChange, object: nil)
        let dn = DistributedNotificationCenter.default()
        dn.addObserver(self, selector: #selector(lockChanged(_:)), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        dn.addObserver(self, selector: #selector(lockChanged(_:)), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
        dn.addObserver(self, selector: #selector(systemChanged), name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
        #if DEBUG
        dn.addObserver(self, selector: #selector(debugStorm), name: NSNotification.Name("ms.blckbox.FestiveLights.debug.storm"), object: nil)
        dn.addObserver(self, selector: #selector(debugShake(_:)), name: NSNotification.Name("ms.blckbox.FestiveLights.debug.shake"), object: nil)
        dn.addObserver(self, selector: #selector(debugSwipe(_:)), name: NSNotification.Name("ms.blckbox.FestiveLights.debug.swipe"), object: nil)
        #endif
        dn.addObserver(self, selector: #selector(showSettingsRequested), name: NSNotification.Name("ms.blckbox.FestiveLights.showSettings"), object: nil)

        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            let p = NSEvent.mouseLocation
            self?.overlays.values.forEach { $0.pointerMoved(p) }
        } as Any)

        dockTracker.onChange = { [weak self] g in self?.dockGeometry = g; self?.scheduleApply() }
        updateDockTracking()

        // Berechtigung und Energie regelmäßig prüfen (Entzug binnen 5 s)
        let t = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.poll() }
        t.tolerance = 0.5
        RunLoop.main.add(t, forMode: .common)
        timers.append(t)

        apply()
        // Erster Start: nach 3 s Schnee, dazu das Willkommens-Popover
        after(3) { [weak self] in
            guard let self else { return }
            self.snowStarted = true
            self.snowRampStart = CACurrentMediaTime()
            self.apply()
            if !self.settings.welcomeShown {
                self.settings.welcomeShown = true
                self.status.showWelcome()
                if !self.settings.permissionPromptShown && !Permission.granted {
                    self.after(62) { [weak self] in
                        guard let self, !self.settings.permissionPromptShown, !Permission.granted else { return }
                        self.settings.permissionPromptShown = true
                        self.status.showPermissionPrompt()
                    }
                }
            }
        }
    }

    private func after(_ s: Double, _ f: @escaping () -> Void) {
        let t = Timer(timeInterval: s, repeats: false) { _ in f() }
        RunLoop.main.add(t, forMode: .common)
    }

    private func poll() {
        #if DEBUG
        let line = "trusted=\(Permission.granted) dock=\(String(describing: dockGeometry)) raw=\(String(describing: DockTracker.read())) suspended=\(suspended) energy=\(energySaving) reduce=\(reduceMotion) piles=\(PileStore.shared.entries.count) fills=\(PileStore.shared.entries.values.map { String(format: "%.2f", $0.pile.fill) }) \(status.debugAppearance)\n"
        try? line.write(toFile: NSHomeDirectory() + "/festivelights-test/state.txt", atomically: true, encoding: .utf8)
        #endif
        let p = Permission.granted
        if p != permission { permission = p; updateDockTracking(); scheduleApply() }
        permissionModel.refresh()
        let wasSuspended = suspended
        refreshSystem()
        if suspended != wasSuspended { scheduleApply() }
        let e = computeEnergySaving()
        if e != energySaving { energySaving = e; scheduleApply() }
        status.updateIcon()
    }

    private func updateDockTracking() {
        if permission && settings.dockLights { dockTracker.start() } else { dockTracker.stop() }
    }

    @objc private func screensChanged() { reconcileScreens(); dockTracker.burst(); scheduleApply() }
    @objc private func systemChanged() { refreshSystem(); scheduleApply() }
    @objc private func sleepChanged(_ n: Notification) {
        let asleep = n.name == NSWorkspace.willSleepNotification || n.name == NSWorkspace.screensDidSleepNotification
        screensAsleep = asleep
        refreshSystem(); scheduleApply()
    }
    @objc private func lockChanged(_ n: Notification) {
        locked = n.name.rawValue == "com.apple.screenIsLocked"
        refreshSystem(); scheduleApply()
    }

    private func refreshSystem() {
        reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        energySaving = computeEnergySaving()
        dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        locked = (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugIgnoreLock") { locked = false }
        #endif
        suspended = screensAsleep || locked
        let anim = !reduceMotion && !suspended
        if anim != animating { animating = anim; status?.setAnimating(anim) }
    }

    private func computeEnergySaving() -> Bool {
        if settings.alwaysSaveEnergy || ProcessInfo.processInfo.isLowPowerModeEnabled { return true }
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return false }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  (d[kIOPSPowerSourceStateKey] as? String) == kIOPSBatteryPowerValue,
                  let cur = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            if Double(cur) / Double(max) < 0.2 { return true }
        }
        return false
    }

    private func reconcileScreens() {
        let screens = NSScreen.screens
        var keep: Set<CGDirectDisplayID> = []
        for s in screens {
            let id = s.displayID
            keep.insert(id)
            if let o = overlays[id], o.screen.frame == s.frame, o.screen.backingScaleFactor == s.backingScaleFactor { continue }
            overlays[id]?.teardown()
            overlays[id] = ScreenOverlay(screen: s)
        }
        for id in overlays.keys where !keep.contains(id) { overlays[id]?.teardown(); overlays[id] = nil }
    }

    private func scheduleApply() {
        guard !applyScheduled else { return }
        applyScheduled = true
        DispatchQueue.main.async { [self] in applyScheduled = false; apply() }
    }

    func apply() {
        let s = settings
        let now = CACurrentMediaTime()
        let stormOn = Engine.shared.storm != nil && !reduceMotion
        if reduceMotion, Engine.shared.storm != nil { Engine.shared.storm = nil }
        let live = !s.paused && !suspended
        let lightsOn = s.lightsEnabled && live
        let snowOn = ((s.snowEnabled && snowStarted) || stormOn) && live
        let settle = snowOn && s.settleSnow && permission && s.snowLayer == .above
        updateDockTracking()
        var st = AppState()
        st.lightsOn = lightsOn
        st.dockLightsOn = lightsOn && s.dockLights && permission && dockGeometry != nil
        st.snowOn = snowOn
        st.settle = settle
        st.lightsLayer = s.lightsLayer
        st.snowLayer = s.snowLayer
        st.warm = s.colorMode == .warm
        st.pattern = s.pattern
        st.tempo = Levels.value(Levels.tempo, s.lightsTempo)
        st.bulbLevel = s.bulbSize
        st.spacingLevel = s.spacing
        st.amount = Levels.value(Levels.snowAmount, s.snowAmount)
        st.sizeMult = Levels.value(Levels.flakeSize, s.flakeSize)
        st.speedMult = Levels.value(Levels.snowSpeed, s.snowSpeed)
        st.wind = s.wind
        st.avoid = Levels.value(Levels.snowAvoid, s.snowAvoid)
        st.reduceMotion = reduceMotion
        st.energySaving = energySaving
        st.dark = dark
        st.suspended = suspended
        st.dock = dockGeometry
        st.snowRampStart = snowRampStart
        Engine.shared.settleActive = settle
        PileStore.shared.setActive(settle, time: now)
        if !settle && PileStore.shared.isIdle { PileStore.shared.clear() }
        overlays.values.forEach { $0.apply(st) }
    }

    func startStorm() {
        guard !reduceMotion else { return }
        Engine.shared.storm = StormEnvelope(start: CACurrentMediaTime())
        apply()
    }

    func toggleStorm() {
        guard !reduceMotion else { return }
        let now = CACurrentMediaTime()
        if var s = Engine.shared.storm, !s.isStopping(at: now) {
            s.stopRequested = now
            Engine.shared.storm = s
        } else {
            Engine.shared.storm = StormEnvelope(start: now)
        }
        apply()
    }

    var reduceMotionActive: Bool { reduceMotion }

    @objc private func debugStorm() { toggleStorm() }

    /// Entwicklerhilfe: schüttelt ein Fenster per echten Mausereignissen. Objekt "x,y,Wechsel,Ausschlag,Intervall".
    @objc private func debugShake(_ n: Notification) {
        let v = (n.object as? String ?? "").split(separator: ",").compactMap { Double($0) }
        guard v.count >= 5 else { return }
        DispatchQueue.global().async {
            func post(_ t: CGEventType, _ x: Double, _ y: Double) {
                CGEvent(mouseEventSource: nil, mouseType: t, mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)?.post(tap: .cghidEventTap)
            }
            var x = v[0]
            post(.mouseMoved, x, v[1]); usleep(200_000)
            post(.leftMouseDown, x, v[1]); usleep(100_000)
            var dir = 1.0
            let steps = 8
            var segs = Int(v[2]) + 1
            if segs % 2 == 1 { segs += 1 }
            for _ in 0..<segs {
                for _ in 0..<steps { x += dir * v[3] / Double(steps); post(.leftMouseDragged, x, v[1]); usleep(UInt32(v[4] * 1_000_000 / Double(steps))) }
                dir = -dir
            }
            post(.leftMouseUp, x, v[1])
        }
    }

    /// Entwicklerhilfe: bewegt den Zeiger schnell von A nach B. Objekt "x1,y1,x2,y2,Sekunden".
    @objc private func debugSwipe(_ n: Notification) {
        let v = (n.object as? String ?? "").split(separator: ",").compactMap { Double($0) }
        guard v.count >= 5 else { return }
        DispatchQueue.global().async {
            let steps = max(2, Int(v[4] * 120))
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: v[0] + (v[2] - v[0]) * t, y: v[1] + (v[3] - v[1]) * t), mouseButton: .left)?.post(tap: .cghidEventTap)
                usleep(UInt32(1_000_000 / 120))
            }
        }
    }
    @objc private func showSettingsRequested() { showSettings() }

    func showSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView: SettingsView(s: settings, perm: permissionModel, login: loginModel))
            let w = NSWindow(contentViewController: host)
            w.title = String(localized: "settings.title")
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 470, height: 340))
            if let v = NSScreen.screens.first?.visibleFrame { w.setFrameTopLeftPoint(NSPoint(x: v.midX - 235, y: v.maxY - 200)) }
            settingsWindow = w
        }
        permissionModel.refresh()
        loginModel.enabled = loginModel.enabled
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

import SwiftUI
