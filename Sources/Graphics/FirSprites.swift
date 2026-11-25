import AppKit

/// Grafiken der Tannen-Stile aus Art/Tanne: Zweige, Mini-Birnen, Zapfen, Schleife.
enum FirSprites {
    static let branchCanvas = CGSize(width: 150, height: 175)
    static let branchAnchor = CGPoint(x: 40, y: 12)
    static let bulbSize = CGSize(width: 10, height: 21)
    static let coneSize = CGSize(width: 24, height: 40), coneAnchor = CGPoint(x: 12, y: 6)
    // "Tanne bunt": Maße in Einheiten der Vorlage (Art/TanneBunt)
    static let clusterSize = CGSize(width: 130, height: 110), clusterAnchor = CGPoint(x: 65, y: 50)
    static let buntBulbSize = CGSize(width: 12, height: 22)
    static let buntConeSize = CGSize(width: 20, height: 28), buntConeAnchor = CGPoint(x: 10, y: 14)
    static let threadColor = CGColor(srgbRed: 0xD4 / 255, green: 0xAF / 255, blue: 0x37 / 255, alpha: 1)
    static let strandColor = CGColor(srgbRed: 0x2D / 255, green: 0x1E / 255, blue: 0x17 / 255, alpha: 1)
    static let buntCableColor = CGColor(srgbRed: 0x18 / 255, green: 0x22 / 255, blue: 0x1B / 255, alpha: 1)

    /// Birnengröße in pt bei Skalierung `fs` (Birnenhöhe geteilt durch 24).
    static func bulbSizePt(_ kind: ChainStyleKind, fs: Double) -> CGSize {
        kind == .firColor ? CGSize(width: buntBulbSize.width * Garland.tbUnit * fs, height: buntBulbSize.height * Garland.tbUnit * fs)
                          : CGSize(width: bulbSize.width * fs, height: bulbSize.height * fs)
    }

    /// Laufende Nummer der Farbe je Stil (Tanne bunt: Creme, Rot, Gelb, Tanne warmgold: eine Farbe).
    static func colorIndex(_ kind: ChainStyleKind, _ index: Int) -> Int { kind == .firColor ? index % 3 : 0 }
    static let bowSize = CGSize(width: 40, height: 34), bowAnchor = CGPoint(x: 20, y: 12)

    private static var pngs: [String: CGImage] = [:]
    private static var bulbCache: [String: CGImage] = [:]
    private static var glowCache: [String: CGImage] = [:]
    private static var pdfCache: [String: CGImage] = [:]

    static func rgb(_ hex: Int) -> RGB { (CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255) }

    /// Birnenfarbe und Scheinfarbe je Stil und laufender Nummer.
    static func colors(_ kind: ChainStyleKind, index: Int) -> (bulb: RGB, glow: RGB) {
        if kind == .firGold { return (rgb(0xFFC766), rgb(0xFFB547)) }
        let bulbs = [0xFFF3B0, 0xFF595E, 0xFFCA3A]
        let c = rgb(bulbs[colorIndex(kind, index)])
        return (c, c)
    }

    static func branch(_ layer: BranchLayer, _ n: Int) -> CGImage? {
        let name = "fir-\(layer.rawValue)-\(n)"
        if let i = pngs[name] { return i }
        guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        pngs[name] = img
        return img
    }

    /// PDF als Bild, Pixelhöhe `px`.
    static func pdfImage(_ name: String, size: CGSize, pixelHeight px: Int) -> CGImage? {
        let key = "\(name)|\(px)"
        if let i = pdfCache[key] { return i }
        let w = max(1, Int((Double(px) * Double(size.width / size.height)).rounded()))
        let ctx = Art.context(w, px)
        Art.draw(name, in: ctx, width: CGFloat(w), height: CGFloat(px))
        let img = ctx.makeImage()
        pdfCache[key] = img
        return img
    }

    static func bulb(kind: ChainStyleKind, index: Int, lit: Bool, pixelHeight px: Int) -> CGImage {
        let key = "\(kind.rawValue)|\(colorIndex(kind, index))|\(lit)|\(px)"
        if let i = bulbCache[key] { return i }
        let c = colors(kind, index: index).bulb
        let aspect = kind == .firColor ? 12.0 / 22 : 10.0 / 21
        let w = max(2, Int((Double(px) * aspect).rounded())), h = px
        let ctx = Art.context(w, h)
        let full = CGRect(x: 0, y: 0, width: w, height: h)
        let deep: RGB = (0.1, 0.12, 0.1)
        func layer(_ name: String, _ color: CGColor) {
            if let img = Art.tinted(name, color: color, width: w, height: h) { ctx.draw(img, in: full) }
        }
        if kind == .firColor {
            // flacher Stil: Glas in der Birnenfarbe (gedimmt abgedunkelt), Fassung darüber
            if let img = Art.tinted("tb-bulb-glass", color: lit ? cgColor(c) : cgColor(c, mix: deep, amount: 0.78), width: w, height: h) { ctx.draw(img, in: full) }
            Art.draw("tb-bulb-socket", in: ctx, width: CGFloat(w), height: CGFloat(h))
            let img = ctx.makeImage()!
            bulbCache[key] = img
            return img
        }
        layer("minibulb-glass", lit ? cgColor(c) : cgColor(c, mix: deep, amount: 0.78))
        layer("minibulb-outline", lit ? cgColor(c, amount: 0.45) : cgColor(c, mix: deep, amount: 0.9))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setAlpha(lit ? 0.5 : 0.12)
        Art.draw("minibulb-shine", in: ctx, width: CGFloat(w), height: CGFloat(h))
        ctx.endTransparencyLayer()
        Art.draw("minibulb-socket", in: ctx, width: CGFloat(w), height: CGFloat(h))
        let img = ctx.makeImage()!
        bulbCache[key] = img
        return img
    }

    static func glow(kind: ChainStyleKind, index: Int, pixels px: Int) -> CGImage {
        let key = "\(kind.rawValue)|\(colorIndex(kind, index))|\(px)"
        if let i = glowCache[key] { return i }
        let g = colors(kind, index: index).glow
        let ctx = Art.context(px, px)
        var comps: [CGFloat] = []
        for a: CGFloat in [0.7, 0.4, 0.12, 0] { comps += [g.r, g.g, g.b, a] }
        let grad = CGGradient(colorSpace: Art.srgb, colorComponents: comps, locations: [0, 0.35, 0.7, 1], count: 4)!
        let c = CGPoint(x: CGFloat(px) / 2, y: CGFloat(px) / 2)
        ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0, endCenter: c, endRadius: CGFloat(px) / 2, options: [])
        let img = ctx.makeImage()!
        glowCache[key] = img
        return img
    }
}
