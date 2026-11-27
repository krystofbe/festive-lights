import AppKit

/// Echte Kettenausschnitte für die Einführung: Die Kette wird vom eigenen Renderer gezeichnet (im gewählten Stil und Auftritt) und einmal in ein Bild
/// gerendert. Ergebnisse werden zwischengespeichert, zur Laufzeit ändert sich danach nichts mehr.
enum ChainPreview {
    private static var cache: [String: NSImage] = [:]

    /// `dock`: Kette auf einem nachgebauten Dock-Streifen, sonst unter einer Menüleiste. Größe in pt, gerendert mit 2 Pixeln je pt.
    static func image(kind: ChainStyleKind, look: Look, dock: Bool, size: CGSize) -> NSImage {
        let key = "\(kind.rawValue)|\(look.rawValue)|\(dock)|\(Int(size.width))x\(Int(size.height))"
        if let i = cache[key] { return i }
        let img = render(kind: kind, look: look, dock: dock, size: size)
        cache[key] = img
        return img
    }

    private static func spec(kind: ChainStyleKind, look: Look, dock: Bool, length: Double) -> ChainSpec {
        if !dock {
            let p = LookProfile.make(kind, look, dock: false), h = Garland.menuBarBulbHeight(kind, barHeight: 33, level: 2)
            return ChainSpec(p0: CGPoint(x: 0, y: 300), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1), length: length, bulbH: h, sag: h * p.sag, liftSign: -1, isMenuBar: true, liftMax: 0,
                             spacing: Garland.menuBarSpacing(kind, look: look, barHeight: 33), garlandDepth: kind.isFir ? Garland.depthPer24(kind) * h / 24 : 0, look: look)
        }
        let tile = 58.0, h = Garland.dockBulbHeight(tile: tile, bulbLevel: 2, barHeight: 37, kind: kind)
        let mid = Garland.dockMidSag(kind, bulbH: h, look: look)
        let sag = Garland.dockExactSag(requested: mid, midSag: mid, bulbH: h, tile: tile, level: 2)
        let depth = kind == .firColor ? Garland.dockDepth * h / Garland.dockRefBulbH : (kind.isFir ? Garland.depthPer24(kind) * h / 24 : 0)
        return ChainSpec(p0: CGPoint(x: 0, y: 300), uDir: CGVector(dx: 1, dy: 0), hang: CGVector(dx: 0, dy: -1), length: length, bulbH: h, sag: sag, liftSign: -1, isMenuBar: false, liftMax: 110,
                         spacing: ChainLayout.spacing(bulbHeight: h, level: 2) * LookProfile.make(kind, look, dock: true).spacingK, garlandDepth: depth, dockTile: tile, look: look, dockMaxGrow: 1)
    }

    private static func render(kind: ChainStyleKind, look: Look, dock: Bool, size: CGSize) -> NSImage {
        let scale = 2, w = Int(size.width) * scale, h = Int(size.height) * scale
        let ctx = Art.context(w, h)
        ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        let lineY = size.height - (dock ? 30 : 16)   // Aufhängelinie von unten gemessen
        func fill(_ hex: Int, _ r: CGRect) {
            ctx.setFillColor(CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)); ctx.fill(r)
        }
        if dock {
            fill(0xEFE8D8, CGRect(x: 0, y: lineY, width: size.width, height: size.height - lineY))
            fill(0x4A5A4C, CGRect(x: 0, y: 0, width: size.width, height: lineY))
            // nachgebaute Symbole unter der Kette
            for (i, c) in [0xE9604F, 0x5B8FD1, 0x4C9A6A, 0xF2B33D].enumerated() {
                let r = CGRect(x: 12 + CGFloat(i) * 40, y: 6, width: 32, height: 32)
                ctx.setFillColor(CGColor(srgbRed: CGFloat((c >> 16) & 255) / 255, green: CGFloat((c >> 8) & 255) / 255, blue: CGFloat(c & 255) / 255, alpha: 1))
                ctx.addPath(CGPath(roundedRect: r, cornerWidth: 7, cornerHeight: 7, transform: nil)); ctx.fillPath()
            }
        } else {
            fill(0xEAD5AE, CGRect(x: 0, y: lineY, width: size.width, height: size.height - lineY))
            fill(0xF3EEE2, CGRect(x: 0, y: 0, width: size.width, height: lineY))
        }
        let r = ChainRenderer()
        let sp = spec(kind: kind, look: look, dock: dock, length: Double(size.width) + 200)
        r.configure(spec: sp, style: ChainStyle(warm: false, pattern: .steady, tempo: 1, dark: dock, reduceMotion: false, kind: kind), scale: CGFloat(scale))
        r.prepareOffscreen()   // nie ein Fenster auf den Bildschirm bringen
        defer { r.discardWindow() }
        for i in 0..<120 { _ = r.update(time: 20 + Double(i) * 0.016, dt: 0.016, pointer: nil) }   // Federn einschwingen lassen
        let fr = r.window.frame
        ctx.saveGState()
        ctx.clip(to: CGRect(origin: .zero, size: size))
        // Spezifikationsposition (u = 100, Linie bei y = 300) auf die Bildposition (0, lineY) schieben
        ctx.translateBy(x: fr.minX - 100, y: lineY - (300 - fr.minY))
        r.window.rootLayer.render(in: ctx)
        ctx.restoreGState()
        return NSImage(cgImage: ctx.makeImage()!, size: size)
    }
}
