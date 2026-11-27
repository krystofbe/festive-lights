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

    private static var compareHolder: [ChainRenderer] = []

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
                      bulbH: h, sag: h, liftSign: -1, isMenuBar: true, liftMax: 0, spacing: ChainLayout.spacing(bulbHeight: h, level: 2))
        }
        for isDark in [true, false] {
            let r = ChainRenderer()
            r.configure(spec: spec(), style: ChainStyle(warm: false, pattern: .steady, tempo: 1, dark: isDark, reduceMotion: false), scale: 2)
            r.setVisible(true, layer: .above, intro: nil)
            r.window.rootLayer.opacity = 1
            r.update(time: 20, dt: 0.016, pointer: nil)
            write(r.window.rootLayer, size: r.window.frame.size, background: isDark ? dark : light, to: "\(dir)/chain-\(isDark ? "dark" : "light").png")
        }
        // Menüleisten-Symbol als Vorlage, hell und dunkel eingefärbt
        for (name, bg, fg) in [("menubar-light", light, CGColor(gray: 0.1, alpha: 1)), ("menubar-dark", CGColor(gray: 0.16, alpha: 1), CGColor(gray: 0.95, alpha: 1))] {
            let ctx = Art.context(18 * 8 * 4, 18 * 8)
            ctx.setFillColor(bg); ctx.fill(CGRect(x: 0, y: 0, width: ctx.width, height: ctx.height))
            for (i, frame) in [0, 4, 12, 20].enumerated() {
                let img = MenubarIcon.image(frame: frame, animated: true)
                guard let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
                let tint = Art.context(36, 36)
                tint.draw(cg, in: CGRect(x: 0, y: 0, width: 36, height: 36))
                tint.setBlendMode(.sourceIn); tint.setFillColor(fg); tint.fill(CGRect(x: 0, y: 0, width: 36, height: 36))
                ctx.interpolationQuality = .high
                ctx.draw(tint.makeImage()!, in: CGRect(x: i * 18 * 8, y: 0, width: 18 * 8, height: 18 * 8))
            }
            try? NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }
        // Tannen-Stile
        for kind in [ChainStyleKind.firColor, .firGold] {
            for isDark in [true, false] {
                let fh = ChainLayout.bulbHeight(menuBarHeight: bar.height, level: 2)
                let fspec = ChainSpec(p0: CGPoint(x: f.minX, y: bar.bottomY), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1), length: Double(f.width),
                                      bulbH: fh, sag: fh * Garland.sag(kind), liftSign: -1, isMenuBar: true, liftMax: 0, spacing: ChainLayout.spacing(bulbHeight: fh, level: 2) * (kind == .firColor ? Garland.tbSpacingFactor : 1),
                                      garlandDepth: Garland.depthPer24(kind) * (fh / 24))
                let fr = ChainRenderer()
                fr.configure(spec: fspec, style: ChainStyle(warm: false, pattern: .steady, tempo: 1, dark: isDark, reduceMotion: false, kind: kind), scale: 2)
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
        r.configure(spec: spec(), style: ChainStyle(warm: false, pattern: .twinkle, tempo: 1, dark: true, reduceMotion: false), scale: 2)
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
                              liftSign: 1, isMenuBar: false, liftMax: 28, spacing: 31)
        dl.configure(spec: dspec, style: ChainStyle(warm: false, pattern: .steady, tempo: 1, dark: true, reduceMotion: false), scale: 2)
        dl.setVisible(true, layer: .above, intro: nil); dl.window.rootLayer.opacity = 1
        dl.update(time: 20, dt: 0.016, pointer: nil)
        write(dl.window.rootLayer, size: dl.window.frame.size, background: dark, to: "\(dir)/chain-dock-left.png")
        let db = ChainRenderer()
        let bspec = ChainSpec(p0: CGPoint(x: 400, y: 90), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1), length: 700, bulbH: 14, sag: 14,
                              liftSign: -1, isMenuBar: false, liftMax: 25, spacing: 27)
        db.configure(spec: bspec, style: ChainStyle(warm: true, pattern: .steady, tempo: 1, dark: false, reduceMotion: false), scale: 2)
        db.setVisible(true, layer: .above, intro: nil); db.window.rootLayer.opacity = 1
        db.update(time: 20, dt: 0.016, pointer: nil)
        write(db.window.rootLayer, size: db.window.frame.size, background: light, to: "\(dir)/chain-dock-bottom-warm.png")

        // Vergleich je Stil im echten Größenverhältnis: Menüleiste dieses Macs und Dock unten (Symbolgröße 64) nebeneinander, gleicher Maßstab, dunkel
        for kind in [ChainStyleKind.firColor, .firGold, .classic] {
            let mh = Garland.menuBarBulbHeight(kind, barHeight: bar.height, level: 2), dh = Garland.dockBulbHeight(tile: 64, bulbLevel: 2, barHeight: bar.height, kind: kind)
            func render(_ sp: ChainSpec) -> CALayer {
                let r = ChainRenderer()
                r.configure(spec: sp, style: ChainStyle(warm: false, pattern: .steady, tempo: 1, dark: true, reduceMotion: false, kind: kind), scale: 2)
                r.setVisible(true, layer: .above, intro: nil); r.window.rootLayer.opacity = 1
                r.update(time: 20, dt: 0.016, pointer: nil)
                compareHolder.append(r)
                return r.window.rootLayer
            }
            let mspec = ChainSpec(p0: CGPoint(x: 40, y: 120), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1), length: 700, bulbH: mh, sag: kind.isFir ? mh * Garland.sag(kind) : mh, liftSign: -1, isMenuBar: true, liftMax: 0,
                                  spacing: ChainLayout.spacing(bulbHeight: mh, level: 2) * (kind == .firColor ? Garland.tbSpacingFactor : 1), garlandDepth: kind.isFir ? Garland.depthPer24(kind) * mh / 24 : 0)
            let dspec = ChainSpec(p0: CGPoint(x: 40, y: 120), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1), length: 700, bulbH: dh, sag: Garland.dockMidSag(kind, bulbH: dh), liftSign: -1, isMenuBar: false, liftMax: 110,
                                  spacing: ChainLayout.spacing(bulbHeight: dh, level: 2) * (kind == .firColor ? Garland.tbSpacingFactor : 1),
                                  garlandDepth: kind.isFir ? Garland.depthPer24(kind) * dh / 24 : 0, dockTile: 64, dockMaxGrow: 1)
            let ml = render(mspec), dl = render(dspec)
            let size = CGSize(width: ml.bounds.width + dl.bounds.width + 20, height: max(ml.bounds.height, dl.bounds.height))
            let sheet = CALayer(); sheet.bounds = CGRect(origin: .zero, size: size)
            ml.frame.origin = CGPoint(x: 0, y: size.height - ml.bounds.height); dl.frame.origin = CGPoint(x: ml.bounds.width + 20, y: size.height - dl.bounds.height)
            sheet.addSublayer(dl); sheet.addSublayer(ml)
            write(sheet, size: size, background: dark, to: "\(dir)/compare-\(kind.rawValue).png")
        }

        // Kontrollbilder für Vergleiche auf echten Bildschirmfotos: Menüleiste (Tanne bunt, Leistenhöhe 33) und Dock unten (Symbolgröße 58), mit Fensterrahmen
        func control(_ name: String, _ sp: ChainSpec, _ kind: ChainStyleKind, light: Bool) {
            let r = ChainRenderer()
            r.configure(spec: sp, style: ChainStyle(warm: false, pattern: .steady, tempo: 1, dark: !light, reduceMotion: false, kind: kind), scale: 2)
            r.setVisible(true, layer: .above, intro: nil); r.window.rootLayer.opacity = 1
            r.update(time: 20, dt: 0.016, pointer: nil)
            let fr = r.window.frame
            write(r.window.rootLayer, size: fr.size, background: CGColor(gray: 0, alpha: 0), to: "\(dir)/control-\(name).png")
            try? "\(fr.minX) \(fr.minY) \(fr.width) \(fr.height)".write(toFile: "\(dir)/control-\(name).txt", atomically: true, encoding: .utf8)
        }
        do {
            let k = ChainStyleKind.firColor
            let mh = Garland.menuBarBulbHeight(k, barHeight: 33, level: 2)
            control("menubar-bunt", ChainSpec(p0: CGPoint(x: 0, y: 77), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1), length: 1728, bulbH: mh, sag: mh * Garland.sag(k), liftSign: -1, isMenuBar: true, liftMax: 0,
                                              spacing: ChainLayout.spacing(bulbHeight: mh, level: 2) * Garland.tbSpacingFactor, garlandDepth: Garland.depthPer24(k) * mh / 24), k, light: true)
            let dh = Garland.dockBulbHeight(tile: 58, bulbLevel: 2, barHeight: 37, kind: k)
            control("dock-bunt", ChainSpec(p0: CGPoint(x: 41.5, y: 81), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1), length: 1643.5, bulbH: dh, sag: Garland.dockMidSag(k, bulbH: dh), liftSign: -1, isMenuBar: false, liftMax: 110,
                                           spacing: ChainLayout.spacing(bulbHeight: dh, level: 2), garlandDepth: Garland.dockDepth * dh / Garland.dockRefBulbH, dockTile: 58, dockMaxGrow: 1), k, light: false)
        }

        // Dock unten, Tanne warmgold
        let dg = ChainRenderer()
        dg.configure(spec: bspec, style: ChainStyle(warm: false, pattern: .steady, tempo: 1, dark: true, reduceMotion: false, kind: .firGold), scale: 2)
        dg.setVisible(true, layer: .above, intro: nil); dg.window.rootLayer.opacity = 1
        dg.update(time: 20, dt: 0.016, pointer: nil)
        write(dg.window.rootLayer, size: dg.window.frame.size, background: dark, to: "\(dir)/gold-dock.png")

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
