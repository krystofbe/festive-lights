import AppKit
import QuartzCore

struct AppState: Equatable {
    var lightsOn = false, dockLightsOn = false, snowOn = false, settle = false
    var lightsLayer = DisplayLayer.above, snowLayer = DisplayLayer.above, dockLayer = DisplayLayer.above
    var warm = false, dockWarm = false
    var kind = ChainStyleKind.classic
    var dockKind = ChainStyleKind.classic
    var pattern = LightPattern.twinkle, dockPattern = LightPattern.twinkle
    var tempo = 1.0, dockTempo = 1.0
    var bulbLevel = 2, spacingLevel = 2, dockBulbLevel = 2, dockSpacingLevel = 2
    var amount = 80.0, sizeMult = 1.0, speedMult = 1.0
    var wind = Wind.off
    var avoid = 80.0
    var reduceMotion = false, energySaving = false, dark = true, suspended = false
    var dock: DockGeometry?
    var snowRampStart: Double?
    var mainOnly = false
    var sagLevel = 2, dockSagLevel = 2
    var fullScreenIDs: Set<CGDirectDisplayID> = []   // Bildschirme mit Vollbild-App
    var showInFullScreen = false
}

enum MenuBar {
    struct Info { var height: Double; var bottomY: Double; var dynamic: Bool }

    /// Menüleiste dieses Bildschirms: sichtbar, automatisch ausgeblendet oder nicht vorhanden.
    static func info(for screen: NSScreen) -> Info? {
        let inset = Double(screen.frame.maxY - screen.visibleFrame.maxY)
        if inset > 1 { return Info(height: inset, bottomY: Double(screen.frame.maxY) - inset, dynamic: false) }
        guard UserDefaults.standard.bool(forKey: "_HIHideMenuBar") else { return nil }
        // Ohne "verschiedene Spaces" hat nur der Hauptbildschirm eine Menüleiste
        guard NSScreen.screensHaveSeparateSpaces || screen.displayID == NSScreen.screens.first?.displayID else { return nil }
        let nominal = Double(NSStatusBar.system.thickness)
        var shown = 0.0
        if let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
            for w in list {
                guard (w[kCGWindowLayer as String] as? Int) == 24, (w[kCGWindowOwnerName as String] as? String) == "Window Server",
                      let bd = w[kCGWindowBounds as String] as? NSDictionary, let r = CGRect(dictionaryRepresentation: bd),
                      r.height > 10, r.height < 80, r.width > screen.frame.width * 0.5,
                      r.intersects(CGRect(origin: screen.cgOrigin, size: screen.frame.size)) else { continue }
                let local = Double(r.maxY - screen.cgOrigin.y)
                if local > 0 { shown = max(shown, min(local, nominal)) }
            }
        }
        return Info(height: nominal, bottomY: Double(screen.frame.maxY) - shown, dynamic: true)
    }
}

/// Alles, was zu einem Bildschirm gehört: Lichter, Dock-Lichter und Schnee mit eigener Bildschleife.
final class ScreenOverlay {
    private(set) var screen: NSScreen
    let menubar = ChainRenderer()
    let dock = ChainRenderer()
    let snow: SnowField
    private var link: CADisplayLink?
    private var state = AppState()
    private var lastTick: Double?
    private var rateMode = -1
    private var barShown = false
    private var lastBarPoll = 0.0
    private var lastBar: MenuBar.Info?
    private var observers: [NSObjectProtocol] = []
    private var barDynamic = false
    private var dockContinuous: Bool?
    private var dockSwitchUntil = 0.0

    /// Lage in einer durchgehenden Girlande über mehrere Bildschirme (nil: Kette für sich).
    var strip: StripPlacement?
    /// Begrüßung beim ersten Einschalten (App-Start und neu angesteckte Bildschirme, nicht nach Auflösungswechsel oder Aufwachen).
    private let greet: Bool
    var isMain: Bool { screen.displayID == NSScreen.screens.first?.displayID }
    /// Vollbild-App auf diesem Bildschirm und nicht gewünscht: Lichter, Dock-Kette und Schnee ausblenden, die anderen Bildschirme leuchten weiter.
    private var fullScreenHidden: Bool { state.fullScreenIDs.contains(screen.displayID) && !state.showInFullScreen }
    private var effectsOn: Bool { ScreenLayout.showsEffects(isMain: isMain, mainOnly: state.mainOnly) && !fullScreenHidden }

    init(screen: NSScreen, greet: Bool = true) {
        self.screen = screen
        self.greet = greet
        snow = SnowField(screen: screen)
        Engine.shared.fields.append(snow)
        link = screen.displayLink(target: self, selector: #selector(tick(_:)))
        link?.add(to: .main, forMode: .common)
        link?.isPaused = true
        // In Vollbild-Spaces und bei voll verdeckten Overlays wird nichts simuliert oder gezeichnet
        for w in [menubar.window, dock.window, snow.window] {
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: w, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.occluded = !self.anyOverlayVisible()
                if !self.occluded { self.wake() }
            })
        }
    }

    private var occluded = false

    #if DEBUG
    /// Diagnose je Bildschirm für mehrere Monitore: Rahmen, Menüleiste, Fenster und Zustand der Bildschleife.
    var debugInfo: String {
        let bar = MenuBar.info(for: screen)
        func w(_ x: NSWindow) -> String { "vis=\(x.isVisible) occ=\(x.occlusionState.contains(.visible)) lvl=\(x.level.rawValue) fr=\(NSStringFromRect(x.frame))" }
        return "screen[\(screen.displayID) fr=\(NSStringFromRect(screen.frame)) vis=\(NSStringFromRect(screen.visibleFrame)) scale=\(screen.backingScaleFactor) bar=\(bar.map { "\($0.height)@\($0.bottomY)" } ?? "nil") occluded=\(occluded) paused=\(link?.isPaused ?? true) lightsOn=\(state.lightsOn) snowOn=\(state.snowOn) menubar{\(w(menubar.window))} snow{\(w(snow.window))}]"
    }
    #endif

    private func anyOverlayVisible() -> Bool {
        [menubar.window, dock.window, snow.window].contains { $0.isVisible && $0.occlusionState.contains(.visible) }
    }

    deinit { teardown() }

    func teardown() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }; observers = []
        link?.invalidate(); link = nil
        Engine.shared.fields.removeAll { $0 === snow }
        menubar.setVisible(false, layer: .above, intro: nil)
        dock.setVisible(false, layer: .above, intro: nil)
        snow.tearDown()
        menubar.window.orderOut(nil); dock.window.orderOut(nil)
    }

    /// Vergrößerte Dock-Symbole: absolute Spannen in Cocoa-Koordinaten, hier in u-Koordinaten der Dock-Kette umgerechnet.
    func setDockSpans(_ spans: [DockProfile.Span], edge: DockEdge) {
        guard let sp = dock.spec, dock.isShown, !(state.dock?.continuous ?? false) else { return }
        let u: [DockProfile.Span] = spans.map { s in
            edge == .bottom ? DockProfile.Span(a: s.a - Double(sp.p0.x), b: s.b - Double(sp.p0.x), lift: s.lift)
                            : DockProfile.Span(a: Double(sp.p0.y) - s.b, b: Double(sp.p0.y) - s.a, lift: s.lift)
        }
        let count = Int(sp.length / dock.stepU) + 2
        dock.setDockLift(spans.isEmpty ? [] : DockProfile.samples(spans: u, du: dock.stepU, count: count))
        wake()
    }

    func wake() { if link?.isPaused == true { lastTick = nil; link?.isPaused = false } }

    func pointerMoved(_ p: CGPoint) {
        guard link?.isPaused == true, !occluded else { return }
        let near = [menubar, dock].contains { $0.isShown && $0.window.frame.insetBy(dx: -90, dy: -90).contains(p) }
        if near { wake() }
    }

    func apply(_ st: AppState) {
        state = st
        if st.suspended {
            menubar.setVisible(false, layer: st.lightsLayer, intro: nil)
            dock.setVisible(false, layer: st.dockLayer, intro: nil)
            snow.setVisible(false)
            link?.isPaused = true
            return
        }
        configureChains()
        snow.configure(SnowConfig(enabled: st.snowOn && effectsOn, amount: st.amount, sizeMult: st.sizeMult, speedMult: st.speedMult, wind: st.wind,
                                  avoidRadius: st.avoid, reduceMotion: st.reduceMotion, energySaving: st.energySaving,
                                  settle: st.settle && effectsOn, layer: st.snowLayer, rampStart: st.snowRampStart, piles: effectsOn))
        if fullScreenHidden { snow.setVisible(false) } else if (st.snowOn && effectsOn) || !snow.isEmpty { snow.setVisible(true) }
        wake()
    }

    private func style(_ kind: ChainStyleKind, warm: Bool, pattern: LightPattern, tempo: Double) -> ChainStyle {
        ChainStyle(warm: warm, pattern: pattern, tempo: tempo * (state.energySaving ? 0.7 : 1),
                   dark: state.dark, reduceMotion: state.reduceMotion, kind: kind)
    }

    private func configureChains() {
        let st = state
        let scale = screen.backingScaleFactor
        let fir = st.kind.isFir
        let dockFir = st.dockKind.isFir
        if let bar = MenuBar.info(for: screen) {
            barDynamic = bar.dynamic
            lastBar = bar
            barShown = bar.dynamic && abs(bar.bottomY - Double(screen.frame.maxY)) > 0.5
            let h = ChainLayout.bulbHeight(menuBarHeight: bar.height, level: st.bulbLevel)
            let spec = ChainSpec(p0: CGPoint(x: screen.frame.minX, y: bar.bottomY), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1),
                                 length: Double(screen.frame.width), bulbH: h, sag: (fir ? h * Garland.sag(st.kind) : h) * Levels.value(Levels.sag, st.sagLevel), liftSign: -1, isMenuBar: true, liftMax: 0,
                                 spacing: ChainLayout.spacing(bulbHeight: h, level: st.spacingLevel) * (st.kind == .firColor ? Garland.tbSpacingFactor : 1),
                                 garlandDepth: fir ? Garland.depthPer24(st.kind) * (h / 24) : 0,
                                 stripOffset: strip?.offset ?? 0, stripTotal: strip?.total ?? 0)
            menubar.configure(spec: spec, style: style(st.kind, warm: st.warm, pattern: st.pattern, tempo: st.tempo), scale: scale)
            menubar.setVisible(st.lightsOn && effectsOn, layer: st.lightsLayer, intro: greet ? CACurrentMediaTime() : nil)
        } else {
            barDynamic = false
            menubar.setVisible(false, layer: st.lightsLayer, intro: nil)
        }
        if st.dockLightsOn, !fullScreenHidden, let d = st.dock, d.screenID == screen.displayID {
            // Formwechsel (zum Beispiel Berechtigung entzogen): sanft aus- und in der neuen Form wieder einblenden
            let now = CACurrentMediaTime()
            if now < dockSwitchUntil { return }
            if dock.isShown, let prev = dockContinuous, prev != d.continuous {
                dockSwitchUntil = now + 0.35
                dockContinuous = nil
                dock.setVisible(false, layer: st.dockLayer, intro: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) { [weak self] in self?.configureChains() }
                return
            }
            dockContinuous = d.continuous
            // Dock-Kette nach der Symbolgröße: Mittelstellung = ein Viertel der Symbolhöhe, der Regler wirkt relativ dazu
            let tile = (CFPreferencesCopyAppValue("tilesize" as CFString, "com.apple.dock" as CFString) as? Double) ?? 64
            let h = Garland.dockBulbHeight(tile: tile, bulbLevel: st.dockBulbLevel)
            let magnify = (CFPreferencesCopyAppValue("magnification" as CFString, "com.apple.dock" as CFString) as? Bool) ?? false
            let large = (CFPreferencesCopyAppValue("largesize" as CFString, "com.apple.dock" as CFString) as? Double) ?? 128
            let grow = magnify ? Garland.dockMaxGrow(large: large, tile: tile) : 1
            let pad = d.continuous ? 0.0 : 6.0
            var spec: ChainSpec
            let sp = ChainLayout.spacing(bulbHeight: h, level: st.dockSpacingLevel)
            let dockSagMid = dockFir ? h * Garland.dockSag : h * Garland.dockClassicSag
            let dockSagRequested = dockSagMid * Garland.dockSagFactor(level: st.dockSagLevel, continuous: d.continuous)
            let dockSagValue = d.continuous ? dockSagRequested : Garland.dockExactSag(requested: dockSagRequested, midSag: dockSagMid, bulbH: h, tile: tile, level: st.dockSagLevel)
            switch d.edge {
            case .bottom:
                spec = ChainSpec(p0: CGPoint(x: d.rect.minX - pad, y: d.edgeLine), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1),
                                 length: Double(d.rect.width) + 2 * pad, bulbH: h, sag: dockSagValue, liftSign: -1, isMenuBar: false, liftMax: 110, spacing: sp, garlandDepth: dockFir ? Garland.dockDepth * h / Garland.dockRefBulbH : 0, dockTile: tile, dockMaxGrow: grow)
            case .left:
                spec = ChainSpec(p0: CGPoint(x: d.edgeLine, y: d.rect.maxY + pad), uDir: CGVector(dx: 0, dy: -1), hang: CGVector(dx: 1, dy: 0),
                                 length: Double(d.rect.height) + 2 * pad, bulbH: h, sag: dockSagValue, liftSign: 1, isMenuBar: false, liftMax: 110, spacing: sp, garlandDepth: dockFir ? Garland.dockDepth * h / Garland.dockRefBulbH : 0, dockTile: tile, dockMaxGrow: grow)
            case .right:
                spec = ChainSpec(p0: CGPoint(x: d.edgeLine, y: d.rect.maxY + pad), uDir: CGVector(dx: 0, dy: -1), hang: CGVector(dx: -1, dy: 0),
                                 length: Double(d.rect.height) + 2 * pad, bulbH: h, sag: dockSagValue, liftSign: 1, isMenuBar: false, liftMax: 110, spacing: sp, garlandDepth: dockFir ? Garland.dockDepth * h / Garland.dockRefBulbH : 0, dockTile: tile, dockMaxGrow: grow)
            }
            dock.configure(spec: spec, style: style(st.dockKind, warm: st.dockWarm, pattern: st.dockPattern, tempo: st.dockTempo), scale: scale)
            dock.setVisible(true, layer: st.dockLayer, intro: nil)
        } else {
            dockContinuous = nil
            dock.setVisible(false, layer: st.dockLayer, intro: nil)
        }
    }

    @objc private func tick(_ l: CADisplayLink) {
        // Nichts sichtbar (Vollbild-App, ganz verdeckt): Bildschleife anhalten, die Benachrichtigung über die Sichtbarkeit weckt sie wieder
        if !anyOverlayVisible() { occluded = true; l.isPaused = true; return }
        occluded = false
        let now = l.timestamp
        let dt = min(max(now - (lastTick ?? now - 1.0 / 60), 0.001), 0.05)
        lastTick = now
        let engine = Engine.shared
        engine.sharedTick(now: now)
        let mouse = NSEvent.mouseLocation
        // Automatisch ausgeblendete Menüleiste: Position nur abfragen, wenn der Zeiger am oberen Rand ist oder die Leiste gerade fährt, höchstens 10 Mal pro Sekunde
        var barBusy = false
        if barDynamic {
            let atTop = mouse.y >= screen.frame.maxY - 6 && screen.frame.contains(mouse)
            if (atTop || barShown) && now - lastBarPoll >= 0.1 { lastBarPoll = now; configureChains() }
            barBusy = atTop || barShown
        }

        let pointer: CGPoint? = screen.frame.insetBy(dx: -100, dy: -100).contains(mouse) ? mouse : nil   // auch knapp außerhalb: Ausweichen an der Kante zwischen Bildschirmen
        var level = max(menubar.update(time: now, dt: dt, pointer: pointer), dock.update(time: now, dt: dt, pointer: pointer))
        let chainMoving = level >= 2
        var snowBusy = false
        if (state.snowOn || !snow.isEmpty) && !fullScreenHidden {
            snowBusy = snow.tick(time: now, dt: dt, pointerGlobal: mouse, stormFactor: engine.stormFactor(now), targets: engine.targets(for: screen), store: PileStore.shared)
            if !state.snowOn && snow.isEmpty { snow.setVisible(false); snowBusy = false }
        }
        let snowOnly = snowBusy && !chainMoving && Engine.shared.stirStrength == 0 && !Engine.shared.air.isActive
        if snowBusy { level = max(level, 2) }
        if barBusy { level = max(level, 1) }
        // Rate nach Bedarf: Zeigerinteraktion und Federn bis 120 Hz, reiner Schneefall höchstens 60 Hz, Muster 30 Hz
        let mode = state.energySaving ? 0 : (level >= 2 && !snowOnly ? 2 : (snowBusy || level >= 2 ? 1 : 0))
        if rateMode != mode {
            rateMode = mode
            l.preferredFrameRateRange = mode == 2 ? CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
                : mode == 1 ? CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60) : CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
        }
        if level == 0 { l.isPaused = true }
    }
}
