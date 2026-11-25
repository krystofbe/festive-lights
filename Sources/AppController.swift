import AppKit
import Combine
import IOKit.ps

final class AppController: NSObject {
    let settings = Settings.shared
    private var overlays: [CGDirectDisplayID: ScreenOverlay] = [:]
    private var status: StatusController!
    #if DIRECT
    private let dockTracker = DockTracker()
    private var accessibilityRunner: DockSourceRunner { dockTracker }
    #else
    private let accessibilityRunner: DockSourceRunner = NullRunner()
    #endif
    private let dockProbe = DockProbe()
    private lazy var dockSources = DockSourceCoordinator(accessibility: accessibilityRunner, probe: dockProbe)
    /// nil: noch nicht ermittelt, dann zeigt die Dock-Kette nichts (statt kurz in der falschen Form).
    private var exactResult: DockProbe.Result?
    private var bag = Set<AnyCancellable>()
    private var snowStarted = false
    private var snowRampStart: Double?
    private var suspended = false
    private var screensAsleep = false
    private var locked = false
    #if DIRECT
    private var permission = Permission.granted
    private let permissionModel = PermissionModel()
    #else
    private var permission = false
    #endif
    private var reduceMotion = false
    // nur bei echter Änderung veröffentlichen: apply() läuft beim Einblenden des Schnees bildweise, jede Veröffentlichung layoutet das Einstellungsfenster neu
    private var energySaving = false { didSet { PowerStatus.shared.update(energySaving) } }
    private var dark = true
    private var dockGeometry: DockGeometry?
    private var settingsWindow: NSWindow?
    private var monitors: [Any] = []
    private var timers: [Timer] = []
    private let loginModel = LoginModel()
    private let settingsNav = SettingsNav()
    private lazy var onboarding = OnboardingController(settings: settings, login: loginModel, startStorm: { [weak self] in self?.startStorm() })
    func showOnboarding() { onboarding.show() }
    #if DIRECT
    private let updates = UpdateController()
    func checkForUpdates() { updates.checkForUpdates() }
    #endif
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
        dn.addObserver(self, selector: #selector(debugStorm), name: NSNotification.Name("ms.blackbox.festivelights.debug.storm"), object: nil)
        dn.addObserver(self, selector: #selector(debugShake(_:)), name: NSNotification.Name("ms.blackbox.festivelights.debug.shake"), object: nil)
        dn.addObserver(self, selector: #selector(debugHit(_:)), name: NSNotification.Name("ms.blackbox.festivelights.debug.hit"), object: nil)
        dn.addObserver(self, selector: #selector(debugWelcome), name: NSNotification.Name("ms.blackbox.festivelights.debug.welcome"), object: nil)
        dn.addObserver(self, selector: #selector(debugSwipe(_:)), name: NSNotification.Name("ms.blackbox.festivelights.debug.swipe"), object: nil)
        #endif
        dn.addObserver(self, selector: #selector(dockPrefsChanged), name: NSNotification.Name("com.apple.dock.prefchanged"), object: nil)
        dn.addObserver(self, selector: #selector(showSettingsRequested), name: NSNotification.Name("ms.blackbox.festivelights.showSettings"), object: nil)

        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            let p = NSEvent.mouseLocation
            Engine.shared.pointerEvent(p, time: ProcessInfo.processInfo.systemUptime)
            self?.overlays.values.forEach { $0.pointerMoved(p) }
            #if DIRECT
            self?.dockTracker.pointerMoved()
            #endif
            self?.dockProbe.pointerMoved()
        } as Any)

        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { _ in Engine.shared.requestBurst() } as Any)
        for n in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didHideApplicationNotification, NSWorkspace.didTerminateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            ws.addObserver(forName: n, object: nil, queue: .main) { _ in Engine.shared.requestBurst() }
        }
        #if DIRECT
        dockTracker.onSpans = { [weak self] spans, edge in self?.overlays.values.forEach { $0.setDockSpans(spans, edge: edge) } }
        #endif
        dockProbe.onSpans = { [weak self] spans, edge in self?.overlays.values.forEach { $0.setDockSpans(spans, edge: edge) } }
        dockProbe.onResult = { [weak self] r in
            #if DEBUG
            let l = "\(Date().timeIntervalSince1970) probe \(r)\n"
            if let h = FileHandle(forWritingAtPath: NSHomeDirectory() + "/festivelights-test/dock.log") { h.seekToEndOfFile(); h.write(l.data(using: .utf8)!); h.closeFile() }
            else { try? l.write(toFile: NSHomeDirectory() + "/festivelights-test/dock.log", atomically: true, encoding: .utf8) }
            #endif
            self?.exactResult = r; self?.scheduleApply()
        }
        #if DIRECT
        dockTracker.onChange = { [weak self] g in
            #if DEBUG
            let l = "\(Date().timeIntervalSince1970) \(String(describing: g?.rect)) edge=\(String(describing: g?.edge))\n"
            if let h = FileHandle(forWritingAtPath: NSHomeDirectory() + "/festivelights-test/dock.log") { h.seekToEndOfFile(); h.write(l.data(using: .utf8)!); h.closeFile() }
            else { try? l.write(toFile: NSHomeDirectory() + "/festivelights-test/dock.log", atomically: true, encoding: .utf8) }
            #endif
            let hidden = (CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) as? Bool) ?? false
            self?.dockGeometry = g
            if let g { self?.exactResult = .visible(g) } else { self?.exactResult = hidden ? .hidden : .unavailable }
            self?.scheduleApply()
        }
        #endif
        updateDockTracking()

        // Berechtigung und Energie regelmäßig prüfen (Entzug binnen 5 s)
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.poll() }
        t.tolerance = 0.2
        RunLoop.main.add(t, forMode: .common)
        timers.append(t)

        apply()
        // Erster Start: nach 3 s Schnee, dazu das Willkommens-Popover (nur als gezeigt markiert, wenn es wirklich erschien)
        after(3) { [weak self] in
            guard let self else { return }
            self.snowStarted = true
            self.snowRampStart = CACurrentMediaTime()
            self.apply()
        }
        // Einführung: einmalig beim allerersten Start, nach 1,5 s
        after(1.5) { [weak self] in
            guard let self, !self.settings.welcomeShown else { return }
            self.settings.welcomeShown = true
            self.onboarding.show()
        }
    }

    private func after(_ s: Double, _ f: @escaping () -> Void) {
        let t = Timer(timeInterval: s, repeats: false) { _ in f() }
        RunLoop.main.add(t, forMode: .common)
    }

    private func poll() {
        #if DEBUG
        let line = "probe[\(dockProbe.statsLine)] mag[\(debugAX)] flakes=\(overlays.values.map { $0.snow.aliveCount }) trusted=\(permission) dock=\(String(describing: dockGeometry))  suspended=\(suspended) energy=\(energySaving) reduce=\(reduceMotion) stir[events=\(Engine.shared.debugEvents) maxSpeed=\(Int(Engine.shared.debugMaxSpeed)) stirred=\(Engine.shared.debugStirred) pileCalls=\(PileStore.shared.debugStirCalls) hits=\(PileStore.shared.debugStirHits) edges=\(PileStore.shared.debugEdges)] piles=\(PileStore.shared.entries.count) fills=\(PileStore.shared.entries.values.map { String(format: "%.2f", $0.pile.fill) }) \(status.debugAppearance)\n"
        try? line.write(toFile: NSHomeDirectory() + "/festivelights-test/state.txt", atomically: true, encoding: .utf8)
        #endif
        #if DIRECT
        let p = Permission.granted
        if p != permission { permission = p; updateDockTracking(); scheduleApply() }
        permissionModel.refresh()
        #endif
        let before = runtimeState
        refreshSystem()
        if runtimeState != before { scheduleApply() }
        status.updateIcon()
    }

    private var runtimeState: RuntimeState { RuntimeState(suspended: suspended, reduceMotion: reduceMotion, energySaving: energySaving, dark: dark) }

    #if DEBUG
    private var debugAX: String {
        #if DIRECT
        return dockTracker.debugItems
        #else
        return "n/a"
        #endif
    }
    #endif

    private func updateDockTracking() {
        let wanted = settings.dockLights && settings.dockShape == .exact && !settings.paused && !suspended
        dockSources.update(wanted: wanted, permission: permission)
        if !wanted { exactResult = nil }   // nach Pause oder Sperre kein alter Rahmen
    }

    @objc private func dockPrefsChanged() { DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.scheduleApply() } }
    @objc private func screensChanged() { reconcileScreens(); scheduleApply() }
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
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugReduceMotion") { reduceMotion = true }
        #endif
        energySaving = computeEnergySaving()
        dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        locked = (CGSessionCopyCurrentDictionary() as? [String: Any])?["CGSSessionScreenIsLocked"] as? Bool ?? false
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugIgnoreLock") { locked = false }
        #endif
        suspended = screensAsleep || locked
        var anim = !reduceMotion && !suspended
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugNoIcon") { anim = false }
        #endif
        if anim != animating { animating = anim; status?.setAnimating(anim) }
    }

    private func computeEnergySaving() -> Bool {
        var onBattery = false
        var fraction: Double?
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(), let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for ps in list {
                guard let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                      (d[kIOPSPowerSourceStateKey] as? String) == kIOPSBatteryPowerValue,
                      let cur = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
                onBattery = true
                fraction = Double(cur) / Double(max)
            }
        }
        return PowerPolicy.energySaving(mode: settings.powerMode, lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                                        onBattery: onBattery, batteryFraction: fraction)
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
        energySaving = computeEnergySaving()
        let now = CACurrentMediaTime()
        let stormOn = Engine.shared.storm != nil && !reduceMotion
        if reduceMotion, Engine.shared.storm != nil { Engine.shared.storm = nil }
        let live = !s.paused && !suspended
        let lightsOn = s.lightsEnabled && live
        let snowOn = ((s.snowEnabled && snowStarted) || stormOn) && live
        let settle = snowOn && s.settleSnow && AppVariant.settleAllowed(accessibilityGranted: permission) && s.snowLayer == .above
        updateDockTracking()
        var st = AppState()
        st.lightsOn = lightsOn
        // Dock-Kette: genau am Dock (mit Berechtigung über die Bedienungshilfen, sonst per Treffer-Test), bei Auto-Hide mit dem Dock
        // verschwindend, bei unplausiblem Ergebnis sanft zurück auf durchgehend
        var dockGeo: DockGeometry?
        if s.dockLights, s.dockShape == .continuous || exactResult != nil {
            let state: ExactState
            switch exactResult { case .visible?: state = .visible; case .hidden?: state = .hidden; default: state = .unavailable }
            switch DockForm.resolve(choice: s.dockShape, exact: state) {
            case .exact: if case .visible(let g)? = exactResult { dockGeo = g }
            case .hidden: dockGeo = nil
            case .continuous: dockGeo = continuousDockGeometry()
            }
        }
        st.dockLightsOn = live && dockGeo != nil
        st.snowOn = snowOn
        st.settle = settle
        st.lightsLayer = s.lightsLayer
        st.snowLayer = s.snowLayer
        st.warm = s.colorMode == .warm
        st.kind = s.chainStyle
        st.dockKind = s.dockStyle
        st.dockLayer = s.dockLayer
        st.dockWarm = s.dockColorMode == .warm
        st.dockPattern = s.dockPattern
        st.dockTempo = Levels.value(Levels.tempo, s.dockTempo)
        st.dockBulbLevel = s.dockBulbSize
        st.dockSpacingLevel = s.dockSpacing
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
        st.dock = dockGeo
        st.snowRampStart = snowRampStart
        Engine.shared.settleActive = settle
        Engine.shared.reduceMotion = reduceMotion
        PileStore.shared.setActive(settle, time: now)
        if !settle && PileStore.shared.isIdle { PileStore.shared.clear() }
        overlays.values.forEach { $0.apply(st) }
    }

    /// Durchgehende Dock-Kette aus öffentlichen Größen (visibleFrame und Dock-Ausrichtung), ohne Berechtigung.
    private func continuousDockGeometry() -> DockGeometry? {
        let screens = NSScreen.screens
        let orientation = CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String
        guard let p = ContinuousDock.placement(screens: screens.map { ScreenInfo(frame: $0.frame, visible: $0.visibleFrame) }, orientation: orientation) else { return nil }
        let s = screens[p.screenIndex].frame
        let t = p.thickness
        let rect: CGRect
        switch p.edge {
        case .bottom: rect = CGRect(x: s.minX, y: s.minY, width: s.width, height: t)
        case .left: rect = CGRect(x: s.minX, y: s.minY, width: t, height: s.height)
        case .right: rect = CGRect(x: s.maxX - t, y: s.minY, width: t, height: s.height)
        }
        return DockGeometry(screenID: screens[p.screenIndex].displayID, edge: p.edge, rect: rect, edgeLine: p.edgeLine, continuous: true)
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

    #if DEBUG
    @objc private func debugStorm() { toggleStorm() }
    @objc private func debugWelcome() { showOnboarding() }

    /// Entwicklerhilfe: welche App liegt an einem Punkt (Durchklick-Prüfung)? Objekt "x,y;x,y;..." in globalen Koordinaten oben links.
    @objc private func debugHit(_ n: Notification) {
        var out = ""
        for part in (n.object as? String ?? "").split(separator: ";") {
            let v = part.split(separator: ",").compactMap { Double($0) }
            guard v.count == 2 else { continue }
            var el: AXUIElement?
            AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(v[0]), Float(v[1]), &el)
            var pid: pid_t = 0
            if let el { AXUIElementGetPid(el, &pid) }
            let name = NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?"
            out += "\(Int(v[0])),\(Int(v[1])) -> \(name)\n"
        }
        try? out.write(toFile: NSHomeDirectory() + "/festivelights-test/hit.txt", atomically: true, encoding: .utf8)
    }

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
    #endif

    @objc private func showSettingsRequested() { showSettings() }

    func showSettings() {
        if settingsWindow == nil {
            #if DIRECT
            let host = NSHostingController(rootView: SettingsView(s: settings, perm: permissionModel, updates: updates, login: loginModel, nav: settingsNav))
            #else
            let host = NSHostingController(rootView: SettingsView(s: settings, login: loginModel, nav: settingsNav))
            #endif
            let w = NSWindow(contentViewController: host)
            w.title = String(localized: "settings.title")
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            if let v = NSScreen.screens.first?.visibleFrame { w.setFrameTopLeftPoint(NSPoint(x: v.midX - 235, y: v.maxY - 200)) }
            settingsWindow = w
        }
        if settingsWindow?.isVisible != true { settingsNav.tab = .general }
        #if DIRECT
        permissionModel.refresh()
        #endif
        loginModel.refresh()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

import SwiftUI
