import AppKit
import QuartzCore

struct AppState: Equatable {
    var lightsOn = false, dockLightsOn = false, snowOn = false, settle = false
    var lightsLayer = DisplayLayer.above, snowLayer = DisplayLayer.above
    var warm = false
    var kind = ChainStyleKind.classic
    var dockKind = ChainStyleKind.classic
    var pattern = LightPattern.twinkle
    var tempo = 1.0
    var bulbLevel = 2, spacingLevel = 2
    var amount = 80.0, sizeMult = 1.0, speedMult = 1.0
    var wind = Wind.off
    var avoid = 80.0
    var reduceMotion = false, energySaving = false, dark = true, suspended = false
    var dock: DockGeometry?
    var snowRampStart: Double?
}

enum MenuBar {
    struct Info { var height: Double; var bottomY: Double; var dynamic: Bool }

    /// Menüleiste dieses Bildschirms: sichtbar, automatisch ausgeblendet oder nicht vorhanden.
    static func info(for screen: NSScreen) -> Info? {
        let inset = Double(screen.frame.maxY - screen.visibleFrame.maxY)
        if inset > 1 { return Info(height: inset, bottomY: Double(screen.frame.maxY) - inset, dynamic: false) }
        guard UserDefaults.standard.bool(forKey: "_HIHideMenuBar") else { return nil }
        let nominal = Double(NSStatusBar.system.thickness)
        var shown = 0.0
        if let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] {
            for w in list {
                guard (w[kCGWindowLayer as String] as? Int) == 24, (w[kCGWindowOwnerName as String] as? String) == "Window Server",
                      let bd = w[kCGWindowBounds as String] as? NSDictionary, let r = CGRect(dictionaryRepresentation: bd),
                      r.height > 10, r.height < 80, r.width > screen.frame.width * 0.5 else { continue }
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
    private var barDynamic = false
    private var dockSpans: [DockProfile.Span] = []
    private var dockEdge = DockEdge.bottom

    init(screen: NSScreen) {
        self.screen = screen
        snow = SnowField(screen: screen)
        Engine.shared.fields.append(snow)
        link = screen.displayLink(target: self, selector: #selector(tick(_:)))
        link?.add(to: .main, forMode: .common)
        link?.isPaused = true
    }

    deinit { teardown() }

    func teardown() {
        link?.invalidate(); link = nil
        Engine.shared.fields.removeAll { $0 === snow }
        menubar.setVisible(false, layer: .above, intro: nil)
        dock.setVisible(false, layer: .above, intro: nil)
        snow.tearDown()
        menubar.window.orderOut(nil); dock.window.orderOut(nil)
    }

    func updateScreen(_ s: NSScreen) {
        screen = s
        snow.place(s)
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
        guard link?.isPaused == true else { return }
        let near = [menubar, dock].contains { $0.isShown && $0.window.frame.insetBy(dx: -90, dy: -90).contains(p) }
        if near { wake() }
    }

    func apply(_ st: AppState) {
        state = st
        if st.suspended {
            menubar.setVisible(false, layer: st.lightsLayer, intro: nil)
            dock.setVisible(false, layer: st.lightsLayer, intro: nil)
            snow.setVisible(false)
            link?.isPaused = true
            return
        }
        configureChains()
        snow.configure(SnowConfig(enabled: st.snowOn, amount: st.amount, sizeMult: st.sizeMult, speedMult: st.speedMult, wind: st.wind,
                                  avoidRadius: st.avoid, reduceMotion: st.reduceMotion, energySaving: st.energySaving,
                                  settle: st.settle, layer: st.snowLayer, rampStart: st.snowRampStart))
        if st.snowOn || !snow.isEmpty { snow.setVisible(true) }
        wake()
    }

    private func style(_ kind: ChainStyleKind) -> ChainStyle {
        ChainStyle(warm: state.warm, pattern: state.pattern, tempo: state.tempo * (state.energySaving ? 0.7 : 1),
                   dark: state.dark, reduceMotion: state.reduceMotion, kind: kind)
    }

    private func configureChains() {
        let st = state
        let scale = screen.backingScaleFactor
        let fir = st.kind.isFir
        let dockFir = st.dockKind.isFir
        if let bar = MenuBar.info(for: screen) {
            barDynamic = bar.dynamic
            let h = ChainLayout.bulbHeight(menuBarHeight: bar.height, level: st.bulbLevel)
            let spec = ChainSpec(p0: CGPoint(x: screen.frame.minX, y: bar.bottomY), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1),
                                 length: Double(screen.frame.width), bulbH: h, sag: fir ? h * Garland.sag : h, liftSign: -1, liftToTop: true, liftMax: 0,
                                 spacing: ChainLayout.spacing(bulbHeight: h, level: st.spacingLevel),
                                 garlandDepth: fir ? 60 * (h / 24) * Garland.hangLength : 0)
            menubar.configure(spec: spec, style: style(st.kind), scale: scale, levelsKey: 0)
            menubar.setVisible(st.lightsOn, layer: st.lightsLayer, intro: CACurrentMediaTime())
        } else {
            barDynamic = false
            menubar.setVisible(false, layer: st.lightsLayer, intro: nil)
        }
        if st.dockLightsOn, let d = st.dock, d.screenID == screen.displayID {
            let menuH = MenuBar.info(for: screen)?.height ?? Double(NSStatusBar.system.thickness)
            let h0 = ChainLayout.bulbHeight(menuBarHeight: menuH, level: st.bulbLevel)
            // durchgehend: Dicke des Docks (ausgeblendet: Standardmaß), genau am Dock: Höhe der Symbolleiste
            let thickness = Double(d.edge == .bottom ? d.rect.height : d.rect.width)
            let icon = d.continuous && thickness < 20 ? 90 : thickness
            // Birnengröße gilt auch am Dock: höchster Regler = ein Viertel der Symbolhöhe, darunter proportional
            let h = max(8, icon * 0.25 * Levels.value(Levels.bulbSize, st.bulbLevel) / 1.4)
            _ = h0
            let pad = d.continuous ? 0.0 : 6.0
            var spec: ChainSpec
            let sp = ChainLayout.spacing(bulbHeight: h, level: st.spacingLevel)
            switch d.edge {
            case .bottom:
                spec = ChainSpec(p0: CGPoint(x: d.rect.minX - pad, y: d.edgeLine), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1),
                                 length: Double(d.rect.width) + 2 * pad, bulbH: h, sag: dockFir ? h * 0.3 : h * 0.45, liftSign: -1, liftToTop: false, liftMax: 110, spacing: sp, garlandDepth: dockFir ? 24 : 0)
            case .left:
                spec = ChainSpec(p0: CGPoint(x: d.edgeLine, y: d.rect.maxY + pad), uDir: CGVector(dx: 0, dy: -1), hang: CGVector(dx: 1, dy: 0),
                                 length: Double(d.rect.height) + 2 * pad, bulbH: h, sag: dockFir ? h * 0.3 : h * 0.45, liftSign: 1, liftToTop: false, liftMax: 110, spacing: sp, garlandDepth: dockFir ? 24 : 0)
            case .right:
                spec = ChainSpec(p0: CGPoint(x: d.edgeLine, y: d.rect.maxY + pad), uDir: CGVector(dx: 0, dy: -1), hang: CGVector(dx: -1, dy: 0),
                                 length: Double(d.rect.height) + 2 * pad, bulbH: h, sag: dockFir ? h * 0.3 : h * 0.45, liftSign: 1, liftToTop: false, liftMax: 110, spacing: sp, garlandDepth: dockFir ? 24 : 0)
            }
            dock.configure(spec: spec, style: style(st.dockKind), scale: scale, levelsKey: 0)
            dock.setVisible(true, layer: st.lightsLayer, intro: nil)
        } else {
            dock.setVisible(false, layer: st.lightsLayer, intro: nil)
        }
    }

    @objc private func tick(_ l: CADisplayLink) {
        let now = l.timestamp
        let dt = min(max(now - (lastTick ?? now - 1.0 / 60), 0.001), 0.05)
        lastTick = now
        let engine = Engine.shared
        engine.sharedTick(now: now)
        if barDynamic { configureChains() }

        let mouse = NSEvent.mouseLocation
        let pointer: CGPoint? = screen.frame.contains(mouse) ? mouse : nil
        var level = max(menubar.update(time: now, dt: dt, pointer: pointer), dock.update(time: now, dt: dt, pointer: pointer))
        let chainMoving = level >= 2
        var snowBusy = false
        if state.snowOn || !snow.isEmpty {
            snowBusy = snow.tick(time: now, dt: dt, pointerGlobal: mouse, stormFactor: engine.stormFactor(now), targets: engine.targets(for: screen), store: PileStore.shared)
            if !state.snowOn && snow.isEmpty { snow.setVisible(false); snowBusy = false }
        }
        let snowOnly = snowBusy && !chainMoving && Engine.shared.stirStrength == 0 && !Engine.shared.air.isActive
        if snowBusy { level = max(level, 2) }
        if barDynamic { level = max(level, 1) }
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
