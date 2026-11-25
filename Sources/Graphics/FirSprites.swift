import AppKit

/// Grafiken der Tannen-Stile aus Art/Tanne: Zweige, Mini-Birnen, Zapfen, Schleife.
enum FirSprites {
    static let branchCanvas = CGSize(width: 150, height: 175)
    static let branchAnchor = CGPoint(x: 40, y: 12)
    static let bulbSize = CGSize(width: 8, height: 28)
    static let coneSize = CGSize(width: 24, height: 40), coneAnchor = CGPoint(x: 12, y: 6)
    static let baubleSize = CGSize(width: 16, height: 26), baubleAnchor = CGPoint(x: 8, y: 2.5)
    static let bowSize = CGSize(width: 40, height: 34), bowAnchor = CGPoint(x: 20, y: 12)

    private static var pngs: [String: CGImage] = [:]
    private static var bulbCache: [String: CGImage] = [:]
    private static var glowCache: [String: CGImage] = [:]
    private static var pdfCache: [String: CGImage] = [:]

    static func rgb(_ hex: Int) -> RGB { (CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255) }

    /// Birnenfarbe und Scheinfarbe je Stil und laufender Nummer.
    static func colors(_ kind: ChainStyleKind, index: Int) -> (bulb: RGB, glow: RGB) {
        switch kind {
        case .firGold: return (rgb(0xFFC766), rgb(0xFFB547))
        default:
            let bulbs = [0xD42A2E, 0xF2B33D, 0xFFEFC4, 0xF2B33D], glows = [0xFF5238, 0xFFB547, 0xFFE0A0, 0xFFB547]
            let i = index % 4
            return (rgb(bulbs[i]), rgb(glows[i]))
        }
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
        let key = "\(kind.rawValue)|\(kind == .firGold ? 0 : index % 4)|\(lit)|\(px)"
        if let i = bulbCache[key] { return i }
        let c = colors(kind, index: index).bulb
        let w = max(2, Int((Double(px) * 8 / 28).rounded())), h = px
        let ctx = Art.context(w, h)
        let full = CGRect(x: 0, y: 0, width: w, height: h)
        let deep: RGB = (0.1, 0.12, 0.1)
        func layer(_ name: String, _ color: CGColor) {
            if let img = Art.tinted(name, color: color, width: w, height: h) { ctx.draw(img, in: full) }
        }
        // Glasröhre mit rundem Boden statt der spitzen Form aus minibulb-glass.pdf (Praxistest: zu spitz). Maße wie in der PDF.
        let sx = CGFloat(w) / 8, sy = CGFloat(h) / 28
        func pt(_ x: Double, _ yTop: Double) -> CGPoint { CGPoint(x: CGFloat(x) * sx, y: (28 - CGFloat(yTop)) * sy) }
        let radius = 2.575
        let path = CGMutablePath()
        path.move(to: pt(1.4, 8.5))
        path.addLine(to: pt(1.4, 27 - radius))
        path.addArc(center: pt(3.975, 27 - radius), radius: CGFloat(radius) * sx, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
        path.addLine(to: pt(6.55, 8.5))
        path.closeSubpath()
        ctx.addPath(path)
        ctx.setFillColor(lit ? cgColor(c) : cgColor(c, mix: deep, amount: 0.78))
        ctx.fillPath()
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setAlpha(lit ? 0.5 : 0.12)
        Art.draw("minibulb-shine", in: ctx, width: CGFloat(w), height: CGFloat(h))
        ctx.endTransparencyLayer()
        ctx.restoreGState()
        ctx.addPath(path)
        ctx.setStrokeColor(lit ? cgColor(c, amount: 0.45) : cgColor(c, mix: deep, amount: 0.9))
        ctx.setLineWidth(max(0.5 * sx, 0.8))
        ctx.strokePath()
        Art.draw("minibulb-socket", in: ctx, width: CGFloat(w), height: CGFloat(h))
        let img = ctx.makeImage()!
        bulbCache[key] = img
        return img
    }

    static func glow(kind: ChainStyleKind, index: Int, pixels px: Int) -> CGImage {
        let key = "\(kind.rawValue)|\(kind == .firGold ? 0 : index % 4)|\(px)"
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
