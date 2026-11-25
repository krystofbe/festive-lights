import AppKit

struct SnowConfig: Equatable {
    var enabled = true
    var amount = 80.0
    var sizeMult = 1.0
    var speedMult = 1.0
    var wind = Wind.off
    var avoidRadius = 80.0
    var reduceMotion = false
    var energySaving = false
    var settle = false
    var layer = DisplayLayer.above
    var rampStart: Double?
}

private struct Flake {
    var x = 0.0, y = 0.0, z = 0.0
    var speed = 0.0, phase = 0.0, freq = 0.0, amp = 0.0
    var size = 0.0, alpha = 0.0
    var crystal = false, rot = 0.0, rotSpeed = 0.0
    var fade = 0.0, fadeRate = 0.0
    var ttl = -1.0
    var vx = 0.0
    var slow = 1.0
    var drift = Stir.Drift()
    var layer = 0
    var dying = false, debris = false
    var grav = 72.0
    var pvx = 0.0, pushDir = 0.0
}

/// Schneefall auf einem Bildschirm. Koordinaten: Ursprung links oben, y nach unten.
final class SnowField {
    let window: OverlayWindow
    private let screenSize: CGSize
    private var flakes: [Flake] = []
    private var layers: [CALayer] = []
    private var free: [Int] = []
    private var piles: [Int: CAShapeLayer] = [:]
    private var pileVersion: [Int: Int] = [:]
    private var pileTime: [Int: Double] = [:]
    private let flakeHost = CALayer(), pileHost = CALayer()
    private var cfg = SnowConfig()
    private var scale: CGFloat = 2
    private var appliedSize = 1.0
    private var storm = 0.0
    private var pointerSmooth: CGPoint?
    private var wantVisible = false
    private let screen: NSScreen

    init(screen: NSScreen) {
        self.screen = screen
        screenSize = screen.frame.size
        window = OverlayWindow(frame: screen.frame)
        scale = screen.backingScaleFactor
        window.rootLayer.addSublayer(pileHost)
        window.rootLayer.addSublayer(flakeHost)
        pileHost.frame = CGRect(origin: .zero, size: screenSize)
        flakeHost.frame = CGRect(origin: .zero, size: screenSize)
    }

    var cgFrame: CGRect { CGRect(origin: screen.cgOrigin, size: screenSize) }

    func configure(_ c: SnowConfig) {
        cfg = c
        window.setLayer(c.layer)
        if c.sizeMult != appliedSize {
            appliedSize = c.sizeMult
            CATransaction.begin(); CATransaction.setDisableActions(true)
            for i in flakes.indices where !flakes[i].debris { resize(&flakes[i]) }
            CATransaction.commit()
        }
    }

    var aliveCount: Int { flakes.reduce(0) { $0 + ($1.dying || $1.debris ? 0 : 1) } }
    var isEmpty: Bool { flakes.isEmpty && piles.isEmpty }

    func setVisible(_ on: Bool) {
        guard on != wantVisible else { return }
        wantVisible = on
        if on { window.orderFrontRegardless() } else { window.orderOut(nil) }
    }

    private func baseSize(_ f: Flake) -> Double {
        f.crystal ? (11 + 6 * (f.z - 0.9) * 10 / 1) * appliedSize : (2.5 + 7 * f.z * f.z + 1.5 * f.z) * appliedSize
    }

    private func resize(_ f: inout Flake) {
        f.size = f.debris ? f.size : baseSize(f)
        let d = f.size * (f.crystal ? 1.5 : 2.4)
        layers[f.layer].bounds = CGRect(x: 0, y: 0, width: d, height: d)
    }

    private func newLayer() -> Int {
        if let i = free.popLast() { layers[i].isHidden = false; return i }
        let l = CALayer()
        l.contentsScale = scale
        l.magnificationFilter = .linear
        l.minificationFilter = .trilinear
        flakeHost.addSublayer(l)
        layers.append(l)
        return layers.count - 1
    }

    private func spawn(prefill: Bool) {
        var f = Flake()
        f.z = pow(Double.random(in: 0...1), 1.25)
        f.crystal = f.z > 0.9 && Double.random(in: 0...1) < 0.7
        f.x = Double.random(in: -30...(screenSize.width + 30))
        f.y = prefill ? Double.random(in: -10...screenSize.height) : -Double.random(in: 5...60)
        f.speed = 14 + 62 * f.z + Double.random(in: -5...5)
        f.phase = Double.random(in: 0...(2 * .pi))
        f.freq = Double.random(in: 0.5...1.4)
        f.amp = 5 + 14 * f.z * Double.random(in: 0.5...1)
        f.alpha = 0.3 + 0.65 * f.z
        f.rot = Double.random(in: 0...(2 * .pi))
        f.rotSpeed = Double.random(in: -0.6...0.6)
        f.fade = 0; f.fadeRate = 1.2
        f.layer = newLayer()
        resize(&f)
        let l = layers[f.layer]
        l.contents = f.crystal ? SnowSprites.crystal : SnowSprites.soft
        l.transform = CATransform3DIdentity
        l.opacity = 0
        flakes.append(f)
    }

    func spawnDebris(at p: CGPoint, count: Int, vx: Double = 0, vy: Double = .nan, gravity: Double = 72, big: Bool = false) {
        guard layers.count - free.count < 1100 else { return }
        for _ in 0..<count {
            var f = Flake()
            f.debris = true
            f.x = Double(p.x) + Double.random(in: -3...3); f.y = Double(p.y)
            f.size = (big ? Double.random(in: 3.5...6) : Double.random(in: 1.4...3.2)) * appliedSize
            f.grav = gravity
            f.speed = vy.isNaN ? Double.random(in: 25...200) : vy + Double.random(in: -30...30)
            f.vx = vx + Double.random(in: -22...22)
            f.alpha = Double.random(in: 0.6...1)
            f.ttl = gravity > 200 ? Double.random(in: 0.9...1.8) : Double.random(in: 0.7...2.2)
            f.fade = 1
            f.layer = newLayer()
            let d = f.size * 2.4
            layers[f.layer].bounds = CGRect(x: 0, y: 0, width: d, height: d)
            layers[f.layer].contents = SnowSprites.soft
            layers[f.layer].transform = CATransform3DIdentity
            layers[f.layer].opacity = Float(f.alpha)
            flakes.append(f)
        }
    }

    /// Gibt zurück, ob weitere Bilder nötig sind.
    func tick(time: Double, dt: Double, pointerGlobal: CGPoint, stormFactor: Double, targets: [PileTarget], store: PileStore) -> Bool {
        storm = stormFactor
        let reduce = cfg.reduceMotion
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        var ramp = 1.0
        if let r = cfg.rampStart { ramp = min(1, 0.3 + 0.7 * (time - r) / 25) }
        let wantCount = cfg.enabled ? cfg.amount * (cfg.energySaving ? 0.5 : 1) * (1 + 2 * stormFactor) * ramp : 0
        let target = Int(min(wantCount, 520).rounded())
        var alive = aliveCount
        if alive < target {
            let n = min(target - alive, Int(Double(target - alive) * dt * 2.5) + 1)
            let prefill = alive < Int(Double(target) * 0.9)
            for _ in 0..<n { spawn(prefill: prefill) }
            alive += n
        } else if alive > target {
            var extra = alive - target
            for i in flakes.indices.reversed() where extra > 0 && !flakes[i].dying && !flakes[i].debris {
                flakes[i].dying = true; flakes[i].fadeRate = 1 / 3; extra -= 1
            }
        }

        let speedMult = cfg.speedMult * (reduce ? 0.5 : 1) * (cfg.energySaving ? 0.8 : 1) * (1 + stormFactor)
        let windV = SnowPhysics.windSpeed(mode: cfg.wind, time: time, storm: stormFactor, gusts: !reduce)
        let swayOn = !reduce
        let W = screenSize.width, H = screenSize.height

        var pointer: CGPoint?
        let local = CGPoint(x: pointerGlobal.x - screen.frame.minX, y: screen.frame.height - (pointerGlobal.y - screen.frame.minY))
        let R = cfg.avoidRadius
        if local.x > -R, local.x < W + R, local.y > -R, local.y < H + R, R > 0 { pointer = local }
        if let p = pointer {
            let a = 1 - exp(-dt / 0.03)
            pointerSmooth = pointerSmooth.map { CGPoint(x: $0.x + (p.x - $0.x) * a, y: $0.y + (p.y - $0.y) * a) } ?? p
        } else { pointerSmooth = nil }

        let settleTargets = cfg.settle ? targets : []
        let air = Engine.shared.air
        let airOn = air.isActive
        let ox0 = Double(screen.cgOrigin.x), oy0 = Double(screen.cgOrigin.y)
        // bei schneller Fahrt übernimmt die Luftströmung, das Ausweichen blendet aus
        let dodge = 1 - Engine.shared.stirStrength
        #if DEBUG
        let log = Engine.shared.stirLog
        #endif
        let hitScale = pileHitAmount()
        var i = 0
        while i < flakes.count {
            var f = flakes[i]
            var remove = false
            let prevY = f.y
            if f.debris {
                f.ttl -= dt
                f.speed += f.grav * dt
                if airOn || !f.drift.isZero {
                    // feiner Pulverschnee folgt der Luft fast sofort
                    let s = airOn ? air.sample(x: ox0 + f.x, y: oy0 + f.y) : AirField.Sample()
                    let v = f.drift.step(air: s, sink: f.speed, tau: 0.08, dt: dt)
                    f.x += Double(v.dx) * dt; f.y += Double(v.dy) * dt
                } else { f.y += f.speed * dt }
                f.x += f.vx * dt
                let a = min(1, max(0, f.ttl / 0.5))
                layers[f.layer].opacity = Float(f.alpha * a)
                if f.ttl <= 0 || f.y > H + 10 { remove = true }
            } else {
                f.fade += (f.dying ? -1 : 1) * f.fadeRate * dt
                if f.fade >= 1 { f.fade = 1; f.fadeRate = f.dying ? f.fadeRate : 0 }
                if f.fade <= 0 { remove = true }
                let sway = swayOn ? sin(f.phase + time * f.freq) * f.amp : 0
                let sink = f.speed * speedMult * f.slow
                if airOn || !f.drift.isZero {
                    let s = airOn ? air.sample(x: ox0 + f.x + sway, y: oy0 + f.y) : AirField.Sample()
                    let v = f.drift.step(air: s, sink: sink, tau: Stir.relaxation(depth: f.z), dt: dt)
                    f.x += Double(v.dx) * dt; f.y += Double(v.dy) * dt
                    f.rot += f.drift.spin * dt
                    #if DEBUG
                    if let log, !f.drift.isZero {
                        log.write(String(format: "F,%.4f,%d,%.1f,%.1f,%.2f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f\n", time, f.layer, ox0 + f.x + sway, oy0 + f.y, f.z, sink,
                                         f.drift.vx, f.drift.vy + f.drift.lift, Double(v.dy), s.dx, Double(s.velocity.dy)).data(using: .utf8)!)
                    }
                    #endif
                } else { f.y += sink * dt }
                f.x += windV * (0.35 + 0.65 * f.z) * dt
                if f.crystal { f.rot += f.rotSpeed * dt * (reduce ? 0.5 : 1) }
                if f.y > H + f.size * 2 {
                    if f.dying { remove = true } else { f.y = -Double.random(in: 5...50); f.x = Double.random(in: -30...(W + 30)); f.drift = Stir.Drift() }
                }
                if f.x > W + 40 { f.x -= W + 80 } else if f.x < -40 { f.x += W + 80 }
                if !settleTargets.isEmpty, !f.dying, f.z > 0.12 {
                    let gx = ox0 + f.x
                    for t in settleTargets where prevY < t.topY && f.y >= t.topY {
                        if let s = t.segments.first(where: { $0.contains(gx) }), s.upperBound > s.lowerBound {
                            store.deposit(id: t.id, x: gx - t.originX, amount: hitScale)
                            f.dying = true; f.fadeRate = 9
                            break
                        }
                    }
                }
                if remove {
                    layers[f.layer].isHidden = true
                    free.append(f.layer)
                    flakes.swapAt(i, flakes.count - 1)
                    flakes.removeLast()
                    continue
                }
                let sx = f.x + sway, sy = f.y
                var tvx = 0.0, tslow = 1.0
                if let p = pointerSmooth {
                    let r = Dodge.push(flake: CGPoint(x: sx, y: sy), pointer: p, radius: R, prevDir: f.pushDir, side: f.phase < .pi ? 1 : -1)
                    f.pushDir = r.dir
                    tvx = r.vx * dodge; tslow = 1 - (1 - r.fallScale) * dodge
                } else { f.pushDir = 0 }
                // seitliche Geschwindigkeit läuft weich ein und aus, die Verschiebung der Flocke bleibt
                f.pvx += (tvx - f.pvx) * (1 - exp(-dt / 0.1))
                if abs(f.pvx) > 0.01 { f.x += f.pvx * dt } else { f.pvx = 0 }
                f.slow += (tslow - f.slow) * (1 - exp(-dt / 0.12))
                let l = layers[f.layer]
                l.position = CGPoint(x: sx, y: ScreenCoords.layerY(topDown: sy, height: H))
                if f.crystal { l.transform = CATransform3DMakeRotation(f.rot, 0, 0, 1) }
                l.opacity = Float(f.alpha * max(0, min(1, f.fade)))
                flakes[i] = f
                i += 1
                continue
            }
            let l = layers[f.layer]
            l.position = CGPoint(x: f.x, y: ScreenCoords.layerY(topDown: f.y, height: H))
            if remove {
                l.isHidden = true
                free.append(f.layer)
                flakes.swapAt(i, flakes.count - 1)
                flakes.removeLast()
                continue
            }
            flakes[i] = f
            i += 1
        }

        updatePiles(time: time, store: store)
        return !flakes.isEmpty || cfg.enabled || !piles.isEmpty
    }

    /// Höhe pro Flockentreffer, so kalibriert, dass bei Standardmenge nach etwa 5 Minuten die Schicht voll ist.
    private func pileHitAmount() -> Float {
        let area = Double(screenSize.width * screenSize.height)
        let standardFlux = 80.0 * 55.0 / area
        let refFlux = 80.0 * 55.0 / (1920.0 * 1080.0)
        return Float(2.76 * refFlux / standardFlux)
    }

    private func updatePiles(time: Double, store: PileStore) {
        let originX = Double(screen.cgOrigin.x), originY = Double(screen.cgOrigin.y)
        var seen = Set<Int>()
        let melt = store.melt
        for (id, e) in store.entries where cfg.settle || store.meltStart != nil {
            let frame = e.frame
            guard frame.maxX > originX, frame.minX < originX + screenSize.width,
                  frame.minY > originY - 20, frame.minY < originY + screenSize.height + 20, !e.pile.isEmpty else { continue }
            seen.insert(id)
            let layer: CAShapeLayer
            if let l = piles[id] { layer = l } else {
                layer = CAShapeLayer()
                layer.fillColor = CGColor(gray: 1, alpha: 0.97)
                layer.shadowColor = CGColor(gray: 0, alpha: 1)
                layer.shadowOpacity = 0.32
                layer.shadowRadius = 2.2
                layer.shadowOffset = .zero
                pileHost.addSublayer(layer)
                piles[id] = layer
            }
            let moved = pileVersion[id] != e.version
            let last = pileTime[id] ?? -1
            if layer.path == nil || (moved && (e.moving || time - last > 0.25)) {
                pileVersion[id] = e.version
                pileTime[id] = time
                layer.path = Self.path(entry: e, id: id, originX: originX, originY: originY, melt: melt, screenHeight: Double(screenSize.height))
            }
            layer.opacity = Float(1 - melt)
        }
        for id in piles.keys where !seen.contains(id) {
            piles[id]?.removeFromSuperlayer(); piles[id] = nil; pileVersion[id] = nil; pileTime[id] = nil
        }
    }

    static func path(entry e: PileStore.Entry, id: Int, originX: Double, originY: Double, melt: Double, screenHeight H: Double) -> CGPath {
        let path = CGMutablePath()
        let edgeY = Double(e.frame.minY) - originY
        let factor = 1 - melt
        let r = WindowCorners.currentRadius
        let left = Double(e.frame.minX), width = Double(e.frame.width)
        func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x - originX, y: ScreenCoords.layerY(topDown: y, height: H)) }
        for seg in e.segments {
            let x0 = seg.lowerBound, x1 = seg.upperBound
            let leftCorner = x0 <= left + 0.5, rightCorner = x1 >= left + width - 0.5
            var top: [CGPoint] = [], base: [CGPoint] = []
            var x = x0
            while true {
                let lx = x - left
                let dl = leftCorner ? lx : .infinity, dr = rightCorner ? width - lx : .infinity
                let d = min(dl, dr)
                let drop = WindowCorners.edgeDrop(distanceFromSide: d, radius: r)
                var taper = d.isFinite ? WindowCorners.taper(distanceFromSide: d, radius: r) : 1
                let cut = min(leftCorner ? .infinity : x - x0, rightCorner ? .infinity : x1 - x)
                if cut.isFinite { let t = min(1, cut / 14); taper = min(taper, (1 - (1 - t) * (1 - t)).squareRoot()) }
                let col = Int(max(0, lx) / SnowPile.columnWidth)
                let wave = 0.88 + 0.12 * sin(lx / 23 + Double(id % 7)) + 0.08 * sin(lx / 9 + Double(id % 5))
                let h = Double(e.pile.height(at: lx)) * wave * (0.9 + 0.2 * stableRandom(id, col, 5)) * taper * factor
                base.append(pt(x, edgeY + drop + 1.5))
                top.append(pt(x, edgeY + drop - h))
                if x >= x1 { break }
                x = min(x + 3, x1)
            }
            guard top.count > 1 else { continue }
            path.move(to: base[0])
            path.addLine(to: top[0])
            for k in 1..<top.count {
                let mid = CGPoint(x: (top[k - 1].x + top[k].x) / 2, y: (top[k - 1].y + top[k].y) / 2)
                path.addQuadCurve(to: mid, control: top[k - 1])
            }
            path.addLine(to: top[top.count - 1])
            for p in base.reversed() { path.addLine(to: p) }
            path.closeSubpath()
        }
        return path
    }

    func tearDown() { window.orderOut(nil) }
}

struct PileTarget {
    var id: Int
    var topY: Double       // lokal zum Bildschirm
    var originX: Double    // x des Fensters, global
    var segments: [ClosedRange<Double>]  // global
}
