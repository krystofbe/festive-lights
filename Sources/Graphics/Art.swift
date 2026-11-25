import AppKit

/// Zugriff auf die PDF-Ebenen aus Art/ und Rendern in Bitmaps.
enum Art {
    static let palette: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
        (0xED, 0x45, 0x3D), (0xFA, 0xBD, 0x33), (0x45, 0xC7, 0x6B), (0x40, 0x99, 0xF2), (0xA8, 0x66, 0xED),
    ].map { ($0.0 / 255, $0.1 / 255, $0.2 / 255) }
    static let warmWhite: (r: CGFloat, g: CGFloat, b: CGFloat) = (0xFF / 255, 0xE7 / 255, 0xB8 / 255)

    static let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
    private static var pages: [String: CGPDFPage] = [:]

    static func page(_ name: String) -> CGPDFPage? {
        if let p = pages[name] { return p }
        guard let url = Bundle.main.url(forResource: name, withExtension: "pdf"),
              let doc = CGPDFDocument(url as CFURL), let p = doc.page(at: 1) else { return nil }
        pages[name] = p
        return p
    }

    static func context(_ w: Int, _ h: Int) -> CGContext {
        CGContext(data: nil, width: max(w, 1), height: max(h, 1), bitsPerComponent: 8, bytesPerRow: 0, space: srgb,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    }

    /// Zeichnet die Seite so, dass sie die Fläche (w x h) füllt.
    static func draw(_ name: String, in ctx: CGContext, width w: CGFloat, height h: CGFloat) {
        guard let p = page(name) else { return }
        let box = p.getBoxRect(.mediaBox)
        ctx.saveGState()
        ctx.scaleBy(x: w / box.width, y: h / box.height)
        ctx.translateBy(x: -box.minX, y: -box.minY)
        ctx.drawPDFPage(p)
        ctx.restoreGState()
    }

    /// Die Ebene als Maske verwendet und einfarbig gefüllt.
    static func tinted(_ name: String, color: CGColor, width w: Int, height h: Int) -> CGImage? {
        let c = context(w, h)
        draw(name, in: c, width: CGFloat(w), height: CGFloat(h))
        c.setBlendMode(.sourceIn)
        c.setFillColor(color)
        c.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return c.makeImage()
    }
}

typealias RGB = (r: CGFloat, g: CGFloat, b: CGFloat)

func cgColor(_ c: RGB, alpha: CGFloat = 1, mix: RGB? = nil, amount: CGFloat = 0) -> CGColor {
    let m = mix ?? (0, 0, 0)
    return CGColor(colorSpace: Art.srgb, components: [
        c.r + (m.r - c.r) * amount, c.g + (m.g - c.g) * amount, c.b + (m.b - c.b) * amount, alpha,
    ])!
}

/// Birnen aus den vier PDF-Ebenen, eingefärbt, gedimmt oder leuchtend.
enum BulbSprites {
    struct Key: Hashable { var color: Int; var lit: Bool; var dark: Bool; var px: Int }
    private static var cache: [Key: CGImage] = [:]
    private static var glowCache: [Key: CGImage] = [:]

    static func color(_ index: Int, warm: Bool) -> RGB { warm ? Art.warmWhite : Art.palette[index % Art.palette.count] }

    static func image(color index: Int, warm: Bool, lit: Bool, dark: Bool, pixelHeight px: Int) -> CGImage {
        let key = Key(color: warm ? -1 : index % Art.palette.count, lit: lit, dark: dark, px: px)
        if let i = cache[key] { return i }
        let rgb = color(index, warm: warm)
        let w = Int((Double(px) * 0.6).rounded()), h = px
        let ctx = Art.context(w, h)
        let full = CGRect(x: 0, y: 0, width: w, height: h)
        let deep: RGB = (0.12, 0.12, 0.14)
        let bodyColor = lit ? cgColor(rgb) : cgColor(rgb, mix: deep, amount: 0.78)
        let lineColor = lit ? cgColor(rgb, amount: 0.45) : cgColor(rgb, mix: deep, amount: 0.9)
        func layer(_ name: String, _ color: CGColor) {
            if let img = Art.tinted(name, color: color, width: w, height: h) { ctx.draw(img, in: full) }
        }
        layer("bulb-body", bodyColor)
        if lit {
            Art.draw("bulb-highlight", in: ctx, width: CGFloat(w), height: CGFloat(h))
        } else {
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            ctx.setAlpha(0.3)
            Art.draw("bulb-highlight", in: ctx, width: CGFloat(w), height: CGFloat(h))
            ctx.endTransparencyLayer()
        }
        layer("bulb-outline", lineColor)
        if dark, let edge = Art.tinted("bulb-socket", color: CGColor(gray: 0.82, alpha: 0.75), width: w, height: h) {
            let r = max(0.6, CGFloat(h) / 60)
            for k in 0..<8 {
                let a = CGFloat(k) * .pi / 4
                ctx.draw(edge, in: full.offsetBy(dx: cos(a) * r, dy: sin(a) * r))
            }
        }
        layer("bulb-socket", CGColor(gray: 0.16, alpha: 1))
        let img = ctx.makeImage()!
        cache[key] = img
        return img
    }

    /// Weicher runder Schein in der Birnenfarbe, läuft nach außen aus.
    static func glow(color index: Int, warm: Bool, pixels px: Int) -> CGImage {
        let key = Key(color: warm ? -1 : index % Art.palette.count, lit: true, dark: false, px: px)
        if let i = glowCache[key] { return i }
        let rgb = color(index, warm: warm)
        let ctx = Art.context(px, px)
        let stops: [CGFloat] = [0, 0.35, 0.7, 1]
        let alphas: [CGFloat] = [0.75, 0.45, 0.14, 0]
        var comps: [CGFloat] = []
        for a in alphas { comps += [rgb.r, rgb.g, rgb.b, a] }
        let g = CGGradient(colorSpace: Art.srgb, colorComponents: comps, locations: stops, count: 4)!
        let c = CGPoint(x: CGFloat(px) / 2, y: CGFloat(px) / 2)
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: CGFloat(px) / 2, options: [])
        let img = ctx.makeImage()!
        glowCache[key] = img
        return img
    }
}

enum SnowSprites {
    static let size = 64

    /// Weiche runde Flocke: weißer Kern, leichter Schein, dezenter dunkler Schatten. Kern ist 1/2.4 der Breite.
    static let soft: CGImage = {
        let px = size
        let ctx = Art.context(px, px)
        let c = CGPoint(x: CGFloat(px) / 2, y: CGFloat(px) / 2 + 1.5)
        let core = CGFloat(px) / 2.4 / 2
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 6, color: CGColor(gray: 0, alpha: 0.75))
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: c.x - core, y: c.y - core, width: core * 2, height: core * 2))
        ctx.restoreGState()
        let g = CGGradient(colorSpace: Art.srgb, colorComponents: [1, 1, 1, 0.55, 1, 1, 1, 0.22, 1, 1, 1, 0],
                           locations: [0.35, 0.6, 1], count: 3)!
        ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: CGFloat(px) / 2, options: [])
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: c.x - core, y: c.y - core, width: core * 2, height: core * 2))
        return ctx.makeImage()!
    }()

    /// Kristallflocke aus snowflake-crystal.pdf, weiß mit Schatten. Kristall füllt 1/1.5 der Breite.
    static let crystal: CGImage = {
        let px = size
        let ctx = Art.context(px, px)
        let inner = Int(Double(px) / 1.5)
        if let img = Art.tinted("snowflake-crystal", color: CGColor(gray: 1, alpha: 1), width: inner, height: inner) {
            let r = CGRect(x: (px - inner) / 2, y: (px - inner) / 2 + 1, width: inner, height: inner)
            ctx.setShadow(offset: CGSize(width: 0, height: -1.5), blur: 3.5, color: CGColor(gray: 0, alpha: 0.55))
            ctx.draw(img, in: r)
        }
        return ctx.makeImage()!
    }()
}

enum MenubarIcon {
    static let frameCount = 36
    private static var cache: [Int: NSImage] = [:]

    /// Eine Animationsphase 0...1. Die drei Birnen glimmen nacheinander heller und dunkler.
    static func image(frame: Int, dark: Bool, animated: Bool) -> NSImage {
        let f = animated ? frame % frameCount : -1
        // Helligkeit je Birne in drei Stufen. Gleiche Stufen ergeben dasselbe Bild, dann wird nichts neu gezeichnet.
        var levels: [CGFloat] = [1, 1, 1]
        if f >= 0 {
            for b in 0..<3 {
                let phase = Double(f) / Double(frameCount) - Double(b) / 3.0
                let p = phase - floor(phase)
                let pulse = p < 0.5 ? sin(p * 2 * .pi) : 0
                levels[b] = pulse > 0.8 ? 1.0 : (pulse > 0.3 ? 0.8 : 0.62)
            }
        }
        let key = (levels.map { Int($0 * 100) }.reduce(0) { $0 * 1000 + $1 }) * 2 + (dark ? 1 : 0)
        if let i = cache[key] { return i }
        let suffix = dark ? "dark" : "light"
        let ctx = Art.context(36, 36)
        ctx.scaleBy(x: 2, y: 2)
        Art.draw("menubar-cable-\(suffix)", in: ctx, width: 18, height: 18)
        for b in 0..<3 {
            let alpha = levels[b]
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            ctx.setAlpha(alpha)
            Art.draw("menubar-bulb\(b + 1)-\(suffix)", in: ctx, width: 18, height: 18)
            ctx.endTransparencyLayer()
        }
        let img = NSImage(cgImage: ctx.makeImage()!, size: NSSize(width: 18, height: 18))
        img.isTemplate = false
        cache[key] = img
        return img
    }
}
