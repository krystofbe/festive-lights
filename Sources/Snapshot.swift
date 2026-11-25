#if DEBUG
import AppKit

/// Entwicklungswerkzeug: rendert Lichter und Schnee ohne Bildschirm in PNG-Dateien (`--render-snapshots <Ordner>`).
enum Snapshot {
    static func write(_ layer: CALayer, size: CGSize, background: CGColor, flipped: Bool = false, to path: String) {
        let scale = 2
        let ctx = Art.context(Int(size.width) * scale, Int(size.height) * scale)
        ctx.setFillColor(background)
        ctx.fill(CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
        ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        if flipped { ctx.translateBy(x: 0, y: size.height); ctx.scaleBy(x: 1, y: -1) }
        layer.render(in: ctx)
        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    static func run(dir: String) {
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        guard let screen = NSScreen.screens.first else { return }
        let f = screen.frame
        let dark = CGColor(srgbRed: 0.09, green: 0.1, blue: 0.125, alpha: 1)
        let light = CGColor(srgbRed: 0.95, green: 0.95, blue: 0.96, alpha: 1)
        let bar = MenuBar.info(for: screen) ?? MenuBar.Info(height: 24, bottomY: Double(f.maxY) - 24, dynamic: false)
        let h = ChainLayout.bulbHeight(menuBarHeight: bar.height, level: 2)

        func spec() -> ChainSpec {
            ChainSpec(p0: CGPoint(x: f.minX, y: bar.bottomY), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1), length: Double(f.width),
                      bulbH: h, sag: h, liftSign: -1, liftToTop: true, liftMax: 0, spacing: ChainLayout.spacing(bulbHeight: h, level: 2))
        }
        for isDark in [true, false] {
            let r = ChainRenderer()
            r.configure(spec: spec(), style: ChainStyle(warm: false, pattern: .steady, tempo: 1, dark: isDark, reduceMotion: false), scale: 2, levelsKey: 0)
            r.setVisible(true, layer: .above, intro: nil)
            r.window.rootLayer.opacity = 1
            r.update(time: 20, dt: 0.016, pointer: nil)
            write(r.window.rootLayer, size: r.window.frame.size, background: isDark ? dark : light, to: "\(dir)/chain-\(isDark ? "dark" : "light").png")
        }
        // Tannen-Stile
        for kind in [ChainStyleKind.firColor, .firGold] {
            for isDark in [true, false] {
                let fh = ChainLayout.bulbHeight(menuBarHeight: bar.height, level: 2)
                let fspec = ChainSpec(p0: CGPoint(x: f.minX, y: bar.bottomY), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1), length: Double(f.width),
                                      bulbH: fh, sag: fh * 0.3, liftSign: -1, liftToTop: true, liftMax: 0, spacing: ChainLayout.spacing(bulbHeight: fh, level: 2),
                                      garlandDepth: 150 * (fh / 24))
                let fr = ChainRenderer()
                fr.configure(spec: fspec, style: ChainStyle(warm: false, pattern: .steady, tempo: 1, dark: isDark, reduceMotion: false, kind: kind), scale: 2, levelsKey: 0)
                fr.setVisible(true, layer: .above, intro: nil); fr.window.rootLayer.opacity = 1
                fr.update(time: 20, dt: 0.016, pointer: nil)
                write(fr.window.rootLayer, size: fr.window.frame.size, background: isDark ? dark : light, to: "\(dir)/\(kind.rawValue)-\(isDark ? "dark" : "light").png")
                if kind == .firGold && isDark {
                    let p = CGPoint(x: f.width * 0.5, y: bar.bottomY - fh * 1.6)
                    for i in 0..<40 { fr.update(time: 20 + Double(i) / 60, dt: 1.0 / 60, pointer: p) }
                    write(fr.window.rootLayer, size: fr.window.frame.size, background: dark, to: "\(dir)/\(kind.rawValue)-dodge.png")
                }
            }
        }
        // Funkeln und Ausweichen
        let r = ChainRenderer()
        r.configure(spec: spec(), style: ChainStyle(warm: false, pattern: .twinkle, tempo: 1, dark: true, reduceMotion: false), scale: 2, levelsKey: 0)
        r.setVisible(true, layer: .above, intro: nil)
        r.window.rootLayer.opacity = 1
        let ptr = CGPoint(x: f.width * 0.5, y: bar.bottomY - h * 1.6)
        for i in 0..<40 { r.update(time: 20 + Double(i) / 60, dt: 1.0 / 60, pointer: ptr) }
        write(r.window.rootLayer, size: r.window.frame.size, background: dark, to: "\(dir)/chain-dodge.png")
        for i in 0..<12 { r.update(time: 21 + Double(i) / 60, dt: 1.0 / 60, pointer: nil) }
        write(r.window.rootLayer, size: r.window.frame.size, background: dark, to: "\(dir)/chain-release.png")

        // Dock links
        let dl = ChainRenderer()
        let dspec = ChainSpec(p0: CGPoint(x: 90, y: 700), uDir: CGVector(dx: 0, dy: -1), hang: CGVector(dx: 1, dy: 0), length: 500, bulbH: 16, sag: 16,
                              liftSign: 1, liftToTop: false, liftMax: 28, spacing: 31)
        dl.configure(spec: dspec, style: ChainStyle(warm: false, pattern: .steady, tempo: 1, dark: true, reduceMotion: false), scale: 2, levelsKey: 0)
        dl.setVisible(true, layer: .above, intro: nil); dl.window.rootLayer.opacity = 1
        dl.update(time: 20, dt: 0.016, pointer: nil)
        write(dl.window.rootLayer, size: dl.window.frame.size, background: dark, to: "\(dir)/chain-dock-left.png")
        let db = ChainRenderer()
        let bspec = ChainSpec(p0: CGPoint(x: 400, y: 90), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1), length: 700, bulbH: 14, sag: 14,
                              liftSign: -1, liftToTop: false, liftMax: 25, spacing: 27)
        db.configure(spec: bspec, style: ChainStyle(warm: true, pattern: .steady, tempo: 1, dark: false, reduceMotion: false), scale: 2, levelsKey: 0)
        db.setVisible(true, layer: .above, intro: nil); db.window.rootLayer.opacity = 1
        db.update(time: 20, dt: 0.016, pointer: nil)
        write(db.window.rootLayer, size: db.window.frame.size, background: light, to: "\(dir)/chain-dock-bottom-warm.png")

        // Schnee, danach mit Schneeschicht auf einem Fenster
        let field = SnowField(screen: screen)
        var cfg = SnowConfig(); cfg.settle = true
        field.configure(cfg)
        let store = PileStore.shared
        store.setActive(true, time: 0)
        let win = CGRect(x: 500, y: 300, width: 700, height: 400)
        store.update(windows: [TrackedWindow(id: 1, frame: win, above: [])], mouseDown: false, time: 0)
        for _ in 0..<4000 { store.deposit(id: 1, x: Double.random(in: 0...700), amount: 2.0) }
        for i in 0..<400 {
            _ = field.tick(time: Double(i) / 60, dt: 1.0 / 60, pointerGlobal: CGPoint(x: 1500, y: 600), stormFactor: 0, targets: [], store: store)
        }
        write(field.window.rootLayer, size: f.size, background: dark, to: "\(dir)/snow-dark.png")
        write(field.window.rootLayer, size: f.size, background: light, to: "\(dir)/snow-light.png")
        print("aliveCount", field.aliveCount)
    }
}
#endif
