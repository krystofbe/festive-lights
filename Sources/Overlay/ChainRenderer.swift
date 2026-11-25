import AppKit

struct ChainSpec: Equatable {
    var p0: CGPoint          // Kabelanfang, globale Cocoa-Koordinaten
    var uDir: CGVector       // Richtung entlang des Kabels
    var hang: CGVector       // Richtung, in die die Birnen hängen
    var length: Double
    var bulbH: Double
    var sag: Double
    var liftSign: Double     // -1: gegen die Hängerichtung heben, +1: in Hängerichtung
    var liftToTop: Bool      // Menüleiste: Abschnitt hebt sich bis unter die Leiste
    var liftMax: Double      // sonst: maximale Hubhöhe
    var spacing: Double
    var garlandDepth = 0.0   // Tiefe der Girlande unter dem Kabel, für die Fenstergröße
    var isDock: Bool { !liftToTop }

    func point(u: Double, v: Double) -> CGPoint {
        CGPoint(x: p0.x + uDir.dx * u + hang.dx * v, y: p0.y + uDir.dy * u + hang.dy * v)
    }

    var cross: Double { Double(uDir.dx * hang.dy - uDir.dy * hang.dx) }

    var windowFrame: NSRect {
        let glow = bulbH * 1.0
        let vMin = liftSign < 0 && !liftToTop ? -liftMax - 4 : -2
        let vMax = sag + max(bulbH, garlandDepth) + glow + (liftSign > 0 ? liftMax : 0)
        let pts = [point(u: -glow, v: vMin), point(u: length + glow, v: vMin), point(u: -glow, v: vMax), point(u: length + glow, v: vMax)]
        let xs = pts.map(\.x), ys = pts.map(\.y)
        return NSRect(x: xs.min()!.rounded(.down), y: ys.min()!.rounded(.down),
                      width: (xs.max()! - xs.min()!).rounded(.up) + 1, height: (ys.max()! - ys.min()!).rounded(.up) + 1)
    }
}

struct ChainStyle: Equatable {
    var warm = false
    var pattern = LightPattern.twinkle
    var tempo = 1.0
    var dark = true
    var reduceMotion = false
    var kind = ChainStyleKind.classic
}

final class ChainRenderer {
    let window = OverlayWindow(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
    private let cable = CAShapeLayer()
    private let content = CALayer()

    private final class Bulb {
        let container = CALayer(), dim = CALayer(), lit = CALayer(), glow = CALayer()
        var sway = Spring()
        init() {
            container.anchorPoint = CGPoint(x: 0.5, y: 1)
            [glow, dim, lit].forEach { container.addSublayer($0) }
            dim.contentsGravity = .resize; lit.contentsGravity = .resize; glow.contentsGravity = .resize
        }
    }

    /// Zweig, Zapfen oder Schleife der Tannengirlande.
    private final class Piece {
        let container = CALayer()
        var u = 0.0
        var rotation = 0.0       // Bogenmaß, fest
        var mirrored = false
        var sway = Spring()
        var swings = false
    }

    private(set) var spec: ChainSpec?
    private var branches: [Piece] = [], cones: [Piece] = [], bows: [Piece] = []
    private var style = ChainStyle()
    private var layout = ChainLayout(length: 10, spacing: 40)
    private var bulbs: [Bulb] = []
    private var lifts: [Spring] = []
    private var cableDirty = true
    private var cableDirtyForGarland = true
    private var garlandSwaying = false
    private var lastMotion = true
    private var lastPatternTime = 0.0
    private var builtKey = ""
    private var introStart: Double?
    private var wantVisible = false
    private var scale: CGFloat = 2
    private let du = 6.0

    init() {
        content.masksToBounds = false
        window.rootLayer.masksToBounds = true
        window.rootLayer.addSublayer(content)
        cable.fillColor = nil
        cable.lineWidth = 1.3
        cable.lineCap = .round
        content.addSublayer(cable)
        window.rootLayer.opacity = 0
    }

    var isShown: Bool { wantVisible }

    func setVisible(_ on: Bool, layer: DisplayLayer, intro now: Double?) {
        window.setLayer(layer)
        guard on != wantVisible else { return }
        wantVisible = on
        if on, introStart == nil, let now { introStart = now }
        if on { window.orderFrontRegardless() }
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, !self.wantVisible else { return }
            self.window.orderOut(nil)
        }
        window.rootLayer.opacity = on ? 1 : 0
        CATransaction.commit()
    }

    func configure(spec new: ChainSpec, style newStyle: ChainStyle, scale s: CGFloat, levelsKey: Int) {
        let geometryChanged = spec != new
        let needsRebuild = geometryChanged || style != newStyle || scale != s
        spec = new
        style = newStyle
        scale = s
        guard needsRebuild else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        window.place(new.windowFrame)
        content.frame = CGRect(origin: .zero, size: window.frame.size)
        cable.strokeColor = newStyle.kind.isFir ? CGColor(srgbRed: 0.1, green: 0.24, blue: 0.14, alpha: 0.95)
            : (newStyle.dark ? CGColor(gray: 0.8, alpha: 0.95) : CGColor(gray: 0.17, alpha: 0.95))
        cable.zPosition = 2
        let key = "\(new.length)|\(new.spacing)|\(new.bulbH)|\(newStyle.warm)|\(newStyle.dark)|\(s)|\(newStyle.kind.rawValue)|\(new.isDock)"
        if key != builtKey {
            builtKey = key
            rebuildBulbs(new)
            rebuildGarland(new)
        }
        if lifts.count != Int(new.length / du) + 2 { lifts = Array(repeating: Spring(), count: Int(new.length / du) + 2) }
        cableDirty = true
        cableDirtyForGarland = true
        CATransaction.commit()
    }

    private func rebuildBulbs(_ sp: ChainSpec) {
        layout = ChainLayout(length: sp.length, spacing: sp.spacing)
        bulbs.forEach { $0.container.removeFromSuperlayer() }
        bulbs = (0..<layout.bulbCount).map { _ in Bulb() }
        let fir = style.kind.isFir
        let fs = sp.bulbH / 24
        let h = fir ? FirSprites.bulbSize.height * fs : sp.bulbH
        let w = fir ? FirSprites.bulbSize.width * fs : h * 0.6
        let px = max(8, Int((h * scale).rounded()))
        let glowPx = max(16, Int((h * 2 * scale).rounded()))
        let glowCenter = fir ? 0.4 : 0.45
        for (i, b) in bulbs.enumerated() {
            b.container.bounds = CGRect(x: 0, y: 0, width: w, height: h)
            b.container.contentsScale = scale
            b.container.zPosition = 4
            b.dim.frame = b.container.bounds
            b.lit.frame = b.container.bounds
            b.glow.frame = CGRect(x: w / 2 - h, y: glowCenter * h - h, width: 2 * h, height: 2 * h)
            for l in [b.dim, b.lit, b.glow] { l.contentsScale = scale }
            if fir {
                b.dim.contents = FirSprites.bulb(kind: style.kind, index: i, lit: false, pixelHeight: px)
                b.lit.contents = FirSprites.bulb(kind: style.kind, index: i, lit: true, pixelHeight: px)
                b.glow.contents = FirSprites.glow(kind: style.kind, index: i, pixels: glowPx)
            } else {
                b.dim.contents = BulbSprites.image(color: i, warm: style.warm, lit: false, dark: style.dark, pixelHeight: px)
                b.lit.contents = BulbSprites.image(color: i, warm: style.warm, lit: true, dark: style.dark, pixelHeight: px)
                b.glow.contents = BulbSprites.glow(color: i, warm: style.warm, pixels: glowPx)
            }
            content.addSublayer(b.container)
        }
    }

    private func rebuildGarland(_ sp: ChainSpec) {
        (branches + cones + bows).forEach { $0.container.removeFromSuperlayer() }
        branches = []; cones = []; bows = []
        guard style.kind.isFir else { return }
        let fs = sp.bulbH / 24
        let dock = sp.isDock
        let plan = Garland.plan(length: sp.length, arcLength: layout.arcLength, arcCount: layout.arcCount, scale: dock ? 0.73 : fs, style: style.kind, dock: dock)
        func piece(_ img: CGImage?, size: CGSize, anchor: CGPoint, z: CGFloat, u: Double, rotationDeg: Double, mirrored: Bool, scale k: Double) -> Piece {
            let p = Piece()
            p.u = u; p.rotation = rotationDeg * .pi / 180; p.mirrored = mirrored
            let c = p.container
            c.contents = img
            c.contentsScale = 2
            c.minificationFilter = .trilinear
            c.magnificationFilter = .linear
            c.bounds = CGRect(x: 0, y: 0, width: size.width * k, height: size.height * k)
            c.anchorPoint = CGPoint(x: anchor.x / size.width, y: 1 - anchor.y / size.height)
            c.zPosition = z
            content.addSublayer(c)
            return p
        }
        // Reihenfolge von hinten nach vorn: hinten, Mitte und hängend, Kabel, vorn, Birnen, Zapfen, Schleifen
        func order(_ l: BranchLayer) -> Int { l == .back ? 0 : (l == .front ? 2 : 1) }
        var frontStart = false
        for br in plan.branches.sorted(by: { order($0.layer) < order($1.layer) }) {
            if !frontStart && br.layer == .front { frontStart = true; content.addSublayer(cable) }
            let hang = br.layer == .hang
            let k = dock ? 0.2 : (hang ? Garland.hangScale * Garland.hangLength : Garland.branchScale) * fs
            let z: CGFloat = br.layer == .back ? 0 : (br.layer == .front ? 3 : 1)
            branches.append(piece(FirSprites.branch(br.layer, br.sprite), size: FirSprites.branchCanvas, anchor: FirSprites.branchAnchor, z: z,
                                  u: br.u, rotationDeg: br.rotation, mirrored: br.mirrored, scale: k))
        }
        if !frontStart { content.addSublayer(cable) }
        bulbs.forEach { content.addSublayer($0.container) }
        let px = max(8, Int((FirSprites.coneSize.height * fs * Garland.coneScale * scale).rounded()))
        for u in plan.cones {
            let p = piece(FirSprites.pdfImage("pinecone", size: FirSprites.coneSize, pixelHeight: px), size: FirSprites.coneSize, anchor: FirSprites.coneAnchor,
                          z: 5, u: u, rotationDeg: ChainLayout.tilt(index: Int(u)) * 0.5, mirrored: false, scale: fs * Garland.coneScale)
            p.container.contentsScale = scale
            p.swings = true
            cones.append(p)
        }
        let bpx = max(8, Int((FirSprites.bowSize.height * fs * Garland.bowScale * scale).rounded()))
        for u in plan.bows {
            let p = piece(FirSprites.pdfImage("bow", size: FirSprites.bowSize, pixelHeight: bpx), size: FirSprites.bowSize, anchor: FirSprites.bowAnchor,
                          z: 6, u: u, rotationDeg: 0, mirrored: false, scale: fs * Garland.bowScale)
            p.container.contentsScale = scale
            bows.append(p)
        }
    }

    /// Zweige, Zapfen und Schleifen folgen dem Kabel. Gibt zurück, ob Zapfen noch pendeln.
    private func updateGarland(_ sp: ChainSpec, dt: Double, reduce: Bool, origin: CGPoint) -> Bool {
        var swaying = false
        let baseAngle = atan2(Double(sp.hang.dy), Double(sp.hang.dx)) + .pi / 2
        for piece in branches + cones + bows {
            let u = piece.u
            let w = liftAt(u)
            let v = vValue(sp, base: sp.sag * layout.sagFactor(at: min(max(u, 0), sp.length - 0.001)), w: w)
            let g = sp.point(u: u, v: v)
            piece.container.position = CGPoint(x: g.x - origin.x, y: g.y - origin.y)
            let v2 = vValue(sp, base: sp.sag * layout.sagFactor(at: min(u + 3, sp.length - 0.001)), w: liftAt(u + 3))
            let v1 = vValue(sp, base: sp.sag * layout.sagFactor(at: max(u - 3, 0)), w: liftAt(u - 3))
            let theta = atan2(v2 - v1, 6)
            let target = piece.rotation + 0.5 * theta * sp.cross
            var angle = target
            if piece.swings && !reduce {
                if abs(piece.sway.value - target) > 0.0008 || abs(piece.sway.velocity) > 0.003 {
                    piece.sway.step(target: target, dt: dt, params: Spring.sway)
                    swaying = true
                    if abs(piece.sway.value - target) < 0.0008 && abs(piece.sway.velocity) < 0.003 { piece.sway = Spring(value: target, velocity: 0) }
                }
                angle = piece.sway.value
            } else { piece.sway = Spring(value: target, velocity: 0) }
            piece.container.transform = CATransform3DScale(CATransform3DMakeRotation(baseAngle + angle, 0, 0, 1), piece.mirrored ? -1 : 1, 1, 1)
            piece.container.opacity = Float(Dodge.opacity(forWeight: w))
        }
        return swaying
    }

    private func sampleV(_ sp: ChainSpec, _ i: Int, base: Double) -> Double {
        let w = lifts[min(i, lifts.count - 1)].value
        return vValue(sp, base: base, w: w)
    }

    private func vValue(_ sp: ChainSpec, base: Double, w: Double) -> Double {
        if sp.liftToTop { return max(0.8, base * (1 - w)) }
        return base + sp.liftSign * w * sp.liftMax
    }

    private func liftAt(_ u: Double) -> Double {
        let f = max(0, u) / du
        let i = min(Int(f), lifts.count - 2)
        let t = min(max(f - Double(i), 0), 1)
        return lifts[i].value * (1 - t) + lifts[i + 1].value * t
    }

    /// 0: nichts zu tun, 1: nur Muster (niedrige Bildrate genügt), 2: Bewegung (volle Bildrate).
    @discardableResult
    func update(time: Double, dt: Double, pointer: CGPoint?) -> Int {
        guard let sp = spec, !bulbs.isEmpty, wantVisible || window.rootLayer.presentation()?.opacity ?? 0 > 0.01 else { return 0 }
        var active = false
        let reduce = style.reduceMotion

        // Schnellpfad: ohne Bewegung nur das Muster mit etwa 22 Bildern pro Sekunde, im Stillstand gar nichts
        let patternOn = style.pattern != .steady && !reduce
        let introRunning = introStart.map { time - $0 < 1.8 } ?? false
        let pointerNear = pointer.map { window.frame.insetBy(dx: -80, dy: -80).contains($0) } ?? false
        if !lastMotion && !cableDirty && !introRunning && !pointerNear {
            guard patternOn else { return 0 }
            if time - lastPatternTime < 0.045 { return 1 }
            lastPatternTime = time
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let n = bulbs.count
            for (i, b) in bulbs.enumerated() {
                let bright = PatternSchedule.brightness(index: i, count: n, time: time, pattern: style.pattern, tempo: style.tempo)
                b.lit.opacity = Float(bright)
                b.glow.opacity = Float(bright * 0.9)
            }
            CATransaction.commit()
            return 1
        }
        lastPatternTime = time

        // Zeigerabstand und Federn
        var target = [Double](repeating: 0, count: lifts.count)
        var anyTarget = false
        if let p = pointer, !reduce {
            let rel = CGPoint(x: p.x - sp.p0.x, y: p.y - sp.p0.y)
            let pu = Double(rel.x * sp.uDir.dx + rel.y * sp.uDir.dy)
            let pv = Double(rel.x * sp.hang.dx + rel.y * sp.hang.dy)
            let inBar = sp.liftToTop && pv < -1
            if !inBar, pu > -80, pu < sp.length + 80, abs(pv) < 200 {
                let lo = max(0, Int((pu - 70) / du)), hi = min(lifts.count - 1, Int((pu + 70) / du) + 1)
                if lo <= hi {
                    for i in lo...hi {
                        let u = Double(i) * du
                        let v = sp.sag * layout.sagFactor(at: min(u, sp.length - 0.001))
                        let d = Dodge.distance(from: CGPoint(x: pu, y: pv), toSegment: CGPoint(x: u, y: v), CGPoint(x: u, y: v + 0.6 * sp.bulbH))
                        target[i] = Dodge.liftWeight(distance: d)
                        if target[i] > 0 { anyTarget = true }
                    }
                }
            }
        }
        var springsActive = anyTarget
        for i in lifts.indices {
            if lifts[i].isSettled(target: target[i]) { lifts[i].value = target[i]; lifts[i].velocity = 0; continue }
            lifts[i].lift(target: target[i], dt: dt)
            springsActive = true
        }
        if reduce { for i in lifts.indices { lifts[i] = Spring() }; springsActive = cableDirty }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let origin = window.frame.origin
        func local(_ g: CGPoint) -> CGPoint { CGPoint(x: g.x - origin.x, y: g.y - origin.y) }

        if springsActive || cableDirty {
            let path = CGMutablePath()
            for i in 0..<lifts.count {
                let u = min(Double(i) * du, sp.length)
                let base = sp.sag * layout.sagFactor(at: min(u, sp.length - 0.001))
                let pt = local(sp.point(u: u, v: sampleV(sp, i, base: base)))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            cable.path = path
            cableDirty = false
        }

        // Birnen
        let intro = introStart.map { time - $0 } ?? 10
        let n = bulbs.count
        var swayActive = false
        for (i, b) in bulbs.enumerated() {
            let u = layout.bulbPositions[i]
            let base = sp.sag * layout.sagFactor(at: u)
            let w = liftAt(u)
            let v = vValue(sp, base: base, w: w)
            b.container.position = local(sp.point(u: u, v: v))

            let v2 = vValue(sp, base: sp.sag * layout.sagFactor(at: min(u + 3, sp.length - 0.001)), w: liftAt(u + 3))
            let v1 = vValue(sp, base: sp.sag * layout.sagFactor(at: max(u - 3, 0)), w: liftAt(u - 3))
            let theta = atan2(v2 - v1, 6)
            let baseAngle = atan2(Double(sp.hang.dy), Double(sp.hang.dx)) + .pi / 2
            let tilt = ChainLayout.tilt(index: i) * .pi / 180
            let targetAngle = tilt + 0.5 * theta * sp.cross
            var angle = targetAngle
            if !reduce {
                if !b.sway.isSettled(target: targetAngle, eps: 0.0008) || abs(b.sway.value - targetAngle) > 0.0008 {
                    b.sway.step(target: targetAngle, dt: dt, params: Spring.sway)
                    swayActive = true
                    if b.sway.isSettled(target: targetAngle, eps: 0.0008) { b.sway.value = targetAngle; b.sway.velocity = 0 }
                }
                angle = b.sway.value
            } else { b.sway = Spring(value: targetAngle, velocity: 0) }
            b.container.transform = CATransform3DMakeRotation(baseAngle + angle, 0, 0, 1)

            var bright = PatternSchedule.brightness(index: i, count: n, time: time, pattern: reduce ? .steady : style.pattern, tempo: style.tempo)
            if intro < 1.8 {
                let s = min(max((intro - Double(i) / Double(n) * 1.2) / 0.3, 0), 1)
                bright = min(bright, s * s * (3 - 2 * s))
                active = true
            }
            b.lit.opacity = Float(bright)
            b.glow.opacity = Float(bright * 0.9)
            b.container.opacity = Float(Dodge.opacity(forWeight: w))
        }
        if springsActive || cableDirtyForGarland || garlandSwaying {
            garlandSwaying = updateGarland(sp, dt: dt, reduce: reduce, origin: origin)
            if garlandSwaying { swayActive = true }
        }
        cableDirtyForGarland = false
        CATransaction.commit()
        if style.pattern != .steady && !reduce { active = true }
        lastMotion = springsActive || swayActive || intro < 1.8
        if lastMotion { return 2 }
        return active ? 1 : 0
    }
}
