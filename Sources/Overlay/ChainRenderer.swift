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
        var chainKey = ""
        var slot = 0
        var bauble: CALayer?
        var baubleSway = Spring()
    }

    private(set) var spec: ChainSpec?
    private var branches: [Piece] = [], cones: [Piece] = [], bows: [Piece] = []
    private var branchChains: [String: BeadChain] = [:]
    private var style = ChainStyle()
    private var layout = ChainLayout(length: 10, spacing: 40)
    private var bulbs: [Bulb] = []
    private var beads = BeadChain(rest: [0], length: 1, minGap: 1, halfGap: 1)
    private var coneBeads = BeadChain(rest: [0], length: 1, minGap: 1, halfGap: 1)
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
        beads = BeadChain(rest: layout.bulbPositions, length: sp.length, minGap: max(1.5 * w, 6), halfGap: sp.spacing)
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
        coneBeads = BeadChain(rest: [0], length: 1, minGap: 1, halfGap: 1)
        branchChains = [:]
        guard style.kind.isFir else { return }
        let fs = sp.bulbH / 24
        let dock = sp.isDock
        let plan = Garland.plan(length: sp.length, arcLength: layout.arcLength, arcCount: layout.arcCount, scale: dock ? 0.73 : fs, style: style.kind, dock: dock, bulbPositions: layout.bulbPositions)
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
        let sortedIdx = plan.branches.indices.sorted { order(plan.branches[$0].layer) != order(plan.branches[$1].layer) ? order(plan.branches[$0].layer) < order(plan.branches[$1].layer) : $0 < $1 }
        for br in sortedIdx.map({ plan.branches[$0] }) {
            if !frontStart && br.layer == .front { frontStart = true; content.addSublayer(cable) }
            let hang = br.layer == .hang
            let k = dock ? 0.2 : (hang ? Garland.hangScale * Garland.hangLength : Garland.branchScale) * fs
            let z: CGFloat = br.layer == .back ? 0 : (br.layer == .front ? 3 : 1)
            branches.append(piece(FirSprites.branch(br.layer, br.sprite), size: FirSprites.branchCanvas, anchor: FirSprites.branchAnchor, z: z,
                                  u: br.u, rotationDeg: br.rotation, mirrored: br.mirrored, scale: k))
        }
        if !frontStart { content.addSublayer(cable) }
        // Zweig-Ansatzpunkte rutschen wie die Birnen am Kabel, die Nadelspitzen dürfen nicht in die Lücke ragen
        var perLayer: [String: [(piece: Piece, e: (left: Double, right: Double))]] = [:]
        for (piece, br) in zip(branches, sortedIdx.map({ plan.branches[$0] })) {
            let k = dock ? 0.2 : (br.layer == .hang ? Garland.hangScale * Garland.hangLength : Garland.branchScale) * fs
            let e = Garland.extent(layer: br.layer, sprite: br.sprite)
            let m = br.mirrored ? (left: e.right, right: e.left) : e
            piece.chainKey = br.layer.rawValue
            perLayer[br.layer.rawValue, default: []].append((piece, (m.left * k * 1.2, m.right * k * 1.2)))
        }
        for (key, list) in perLayer {
            for (i, item) in list.enumerated() { item.piece.slot = i }
            branchChains[key] = BeadChain(rest: list.map { $0.piece.u }, length: sp.length, minGap: 8, halfGap: sp.spacing, extents: list.map { $0.e })
        }
        bulbs.forEach { content.addSublayer($0.container) }
        // Kugeln hängen als Kind ihres Zweigs an der Stelle mit Nadeln nahe der Spitze und folgen ihm beim Rutschen und Biegen
        var pieceOfPlan: [Int: Piece] = [:]
        for (slot, planIdx) in sortedIdx.enumerated() { pieceOfPlan[planIdx] = branches[slot] }
        let bpxk = max(8, Int((FirSprites.baubleSize.height * fs * Garland.baubleScale * scale).rounded()))
        for bb in plan.baubles {
            guard let piece = pieceOfPlan[bb.branch] else { continue }
            let kb = fs * Garland.baubleScale
            let l = CALayer()
            l.contents = FirSprites.pdfImage(bb.gold ? "bauble-gold" : "bauble-red", size: FirSprites.baubleSize, pixelHeight: bpxk)
            l.contentsScale = scale
            l.bounds = CGRect(x: 0, y: 0, width: FirSprites.baubleSize.width * kb, height: FirSprites.baubleSize.height * kb)
            l.anchorPoint = CGPoint(x: FirSprites.baubleAnchor.x / FirSprites.baubleSize.width, y: 1 - FirSprites.baubleAnchor.y / FirSprites.baubleSize.height)
            let kBranch = piece.container.bounds.width / FirSprites.branchCanvas.width
            l.position = CGPoint(x: bb.x * kBranch, y: (FirSprites.branchCanvas.height - bb.y) * kBranch)
            piece.container.addSublayer(l)
            piece.bauble = l
        }
        let px = max(8, Int((FirSprites.coneSize.height * fs * Garland.coneScale * scale).rounded()))
        for u in plan.cones {
            let p = piece(FirSprites.pdfImage("pinecone", size: FirSprites.coneSize, pixelHeight: px), size: FirSprites.coneSize, anchor: FirSprites.coneAnchor,
                          z: 5, u: u, rotationDeg: ChainLayout.tilt(index: Int(u)) * 0.5, mirrored: false, scale: fs * Garland.coneScale)
            p.container.contentsScale = scale
            p.swings = true
            cones.append(p)
        }
        coneBeads = BeadChain(rest: plan.cones, length: sp.length, minGap: max(1.4 * FirSprites.coneSize.width * fs * Garland.coneScale, 8), halfGap: sp.spacing)
        let bpx = max(8, Int((FirSprites.bowSize.height * fs * Garland.bowScale * scale).rounded()))
        for u in plan.bows {
            let p = piece(FirSprites.pdfImage("bow", size: FirSprites.bowSize, pixelHeight: bpx), size: FirSprites.bowSize, anchor: FirSprites.bowAnchor,
                          z: 6, u: u, rotationDeg: 0, mirrored: false, scale: fs * Garland.bowScale)
            p.container.contentsScale = scale
            bows.append(p)
        }
    }

    private var dockLift: [Double] = []

    /// Anhebung der Kette über den vergrößerten Dock-Symbolen an Stützstellen im Abstand `du` (leer: keine).
    func setDockLift(_ l: [Double]) {
        guard l != dockLift else { return }
        dockLift = l
        cableDirty = true
        cableDirtyForGarland = true
        lastMotion = true
    }

    var stepU: Double { du }

    private func liftAt(_ u: Double) -> Double {
        guard dockLift.count > 1 else { return 0 }
        let f = max(0, u) / du
        let i = min(Int(f), dockLift.count - 2)
        let t = min(max(f - Double(i), 0), 1)
        return dockLift[i] * (1 - t) + dockLift[i + 1] * t
    }

    private func cableV(_ sp: ChainSpec, _ u: Double) -> Double {
        sp.sag * layout.sagFactor(at: min(max(u, 0), sp.length - 0.001)) + sp.liftSign * liftAt(u)
    }

    /// Zweige, Zapfen und Schleifen sitzen am Kabel. Zweige biegen sich vom Zeiger weg, Zapfen rutschen wie die Birnen.
    /// Gibt zurück, ob noch etwas schwingt.
    private func updateGarland(_ sp: ChainSpec, dt: Double, reduce: Bool, origin: CGPoint, pointerU: Double?, strength k: Double) -> Bool {
        var moving = false
        let baseAngle = atan2(Double(sp.hang.dy), Double(sp.hang.dx)) + .pi / 2
        for (j, c) in cones.enumerated() where j < coneBeads.pos.count { c.u = coneBeads.pos[j] }
        for b in branches { if let c = branchChains[b.chainKey], b.slot < c.pos.count { b.u = c.pos[b.slot] } }
        let first = branches.count, second = first + cones.count
        for (idx, piece) in (branches + cones + bows).enumerated() {
            let u = piece.u
            let v = cableV(sp, u)
            let g = sp.point(u: u, v: v)
            piece.container.position = CGPoint(x: g.x - origin.x, y: g.y - origin.y)
            let v2 = cableV(sp, u + 3), v1 = cableV(sp, u - 3)
            let theta = atan2(v2 - v1, 6)
            var target = piece.rotation + 0.5 * theta * sp.cross
            if idx < first {
                // Zweige biegen sich leicht in Rutschrichtung und federn beim Zurückrutschen nach
                let vel = branchChains[piece.chainKey].map { piece.slot < $0.vel.count ? $0.vel[piece.slot] : 0 } ?? 0
                target += -sp.cross * min(max(vel / 700, -0.5), 0.5)
            }
            if idx >= first && idx < second {
                let i = idx - first
                let vel = i < coneBeads.vel.count ? coneBeads.vel[i] : 0
                target += -sp.cross * min(max(vel / 900, -0.6), 0.6)
            }
            if reduce { piece.sway = Spring(value: target, velocity: 0) }
            else if piece.swings || idx < first {
                if abs(piece.sway.value - target) > 0.0008 || abs(piece.sway.velocity) > 0.003 {
                    piece.sway.step(target: target, dt: dt, params: idx < first ? Spring.branch : Spring.sway)
                    moving = true
                    if abs(piece.sway.value - target) < 0.0008 && abs(piece.sway.velocity) < 0.003 { piece.sway = Spring(value: target, velocity: 0) }
                }
            } else { piece.sway = Spring(value: target, velocity: 0) }
            piece.container.transform = CATransform3DScale(CATransform3DMakeRotation(baseAngle + piece.sway.value, 0, 0, 1), piece.mirrored ? -1 : 1, 1, 1)
            if let bl = piece.bauble {
                // Die Kugel hängt senkrecht an ihrem Faden und pendelt nach, wenn der Zweig rutscht
                let vel = branchChains[piece.chainKey].map { piece.slot < $0.vel.count ? $0.vel[piece.slot] : 0 } ?? 0
                let target = -sp.cross * min(max(vel / 900, -0.6), 0.6)
                if reduce { piece.baubleSway = Spring(value: target, velocity: 0) }
                else if abs(piece.baubleSway.value - target) > 0.0008 || abs(piece.baubleSway.velocity) > 0.003 {
                    piece.baubleSway.step(target: target, dt: dt, params: Spring.sway)
                    moving = true
                }
                let m: Double = piece.mirrored ? -1 : 1
                bl.transform = CATransform3DMakeRotation(m * (piece.baubleSway.value - (baseAngle + piece.sway.value)), 0, 0, 1)
            }
        }
        return moving
    }

    /// 0: nichts zu tun, 1: nur Muster (niedrige Bildrate genügt), 2: Bewegung (volle Bildrate).
    @discardableResult
    func update(time: Double, dt: Double, pointer: CGPoint?) -> Int {
        guard let sp = spec, !bulbs.isEmpty, wantVisible || window.rootLayer.presentation()?.opacity ?? 0 > 0.01 else { return 0 }
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

        // Zeiger: Nähe zum Kabel bestimmt die Stärke, die Lücke sitzt am Fußpunkt des Zeigers
        var k = 0.0
        var pu: Double?
        if let p = pointer, !reduce {
            let rel = CGPoint(x: p.x - sp.p0.x, y: p.y - sp.p0.y)
            let u0 = Double(rel.x * sp.uDir.dx + rel.y * sp.uDir.dy)
            let pv = Double(rel.x * sp.hang.dx + rel.y * sp.hang.dy)
            let inBar = sp.liftToTop && pv < -1
            if !inBar, u0 > -80, u0 < sp.length + 80, abs(pv) < 200 {
                var dmin = Double.infinity
                let lo = max(0, Int((u0 - 70) / du)), hi = min(Int(sp.length / du), Int((u0 + 70) / du) + 1)
                if lo <= hi {
                    for i in lo...hi {
                        let u = Double(i) * du
                        let v = cableV(sp, u)
                        dmin = min(dmin, Dodge.distance(from: CGPoint(x: u0, y: pv), toSegment: CGPoint(x: u, y: v), CGPoint(x: u, y: v + 0.6 * sp.bulbH)))
                    }
                }
                k = Dodge.liftWeight(distance: dmin)
                if k > 0 { pu = u0 }
            }
        }
        var branchesSettled = true
        for (key, c) in branchChains where !c.isSettled() { _ = key; branchesSettled = false; break }
        if reduce { beads.snapToRest(); coneBeads.snapToRest(); for key in branchChains.keys { branchChains[key]!.snapToRest() } }
        else if k > 0 || !beads.isSettled() || !coneBeads.isSettled() || !branchesSettled {
            beads.step(dt: dt, pointer: pu, strength: k)
            coneBeads.step(dt: dt, pointer: pu, strength: k)
            for key in branchChains.keys { branchChains[key]!.step(dt: dt, pointer: pu, strength: k) }
        }
        var moving = k > 0 || !beads.isSettled() || !coneBeads.isSettled() || branchChains.values.contains { !$0.isSettled() }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let origin = window.frame.origin
        func local(_ g: CGPoint) -> CGPoint { CGPoint(x: g.x - origin.x, y: g.y - origin.y) }

        if cableDirty {
            let path = CGMutablePath()
            let n = Int(sp.length / du) + 1
            for i in 0...n {
                let u = min(Double(i) * du, sp.length)
                let pt = local(sp.point(u: u, v: cableV(sp, u)))
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            cable.path = path
            cableDirty = false
        }

        // Birnen: Position entlang des Kabels aus der Perlenkette, Neigung aus der Geschwindigkeit
        let intro = introStart.map { time - $0 } ?? 10
        let n = bulbs.count
        var swayActive = false
        let baseAngle = atan2(Double(sp.hang.dy), Double(sp.hang.dx)) + .pi / 2
        for (i, b) in bulbs.enumerated() {
            let u = beads.pos[i]
            b.container.position = local(sp.point(u: u, v: cableV(sp, u)))
            let theta = atan2(cableV(sp, u + 3) - cableV(sp, u - 3), 6)
            let tilt = ChainLayout.tilt(index: i) * .pi / 180
            let target = tilt + 0.5 * theta * sp.cross - sp.cross * min(max(beads.vel[i] / 900, -0.6), 0.6)
            var angle = target
            if !reduce {
                if abs(b.sway.value - target) > 0.0008 || abs(b.sway.velocity) > 0.003 {
                    b.sway.step(target: target, dt: dt, params: Spring.sway)
                    swayActive = true
                    if abs(b.sway.value - target) < 0.0008 && abs(b.sway.velocity) < 0.003 { b.sway = Spring(value: target, velocity: 0) }
                }
                angle = b.sway.value
            } else { b.sway = Spring(value: target, velocity: 0) }
            b.container.transform = CATransform3DMakeRotation(baseAngle + angle, 0, 0, 1)

            var bright = PatternSchedule.brightness(index: i, count: n, time: time, pattern: reduce ? .steady : style.pattern, tempo: style.tempo)
            if intro < 1.8 {
                let s = min(max((intro - Double(i) / Double(n) * 1.2) / 0.3, 0), 1)
                bright = min(bright, s * s * (3 - 2 * s))
            }
            b.lit.opacity = Float(bright)
            b.glow.opacity = Float(bright * 0.9)
        }
        if moving || swayActive || cableDirtyForGarland || garlandSwaying {
            garlandSwaying = updateGarland(sp, dt: dt, reduce: reduce, origin: origin, pointerU: pu, strength: k)
            if garlandSwaying { swayActive = true }
        }
        cableDirtyForGarland = false
        CATransaction.commit()
        moving = moving || swayActive
        lastMotion = moving || intro < 1.8
        if lastMotion { return 2 }
        return (style.pattern != .steady && !reduce) ? 1 : 0
    }
}
