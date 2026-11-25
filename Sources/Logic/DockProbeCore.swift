import CoreGraphics
import Foundation
import os

struct DockGeometry: Equatable {
    var screenID: CGDirectDisplayID
    var edge: DockEdge
    var rect: CGRect        // Symbolleiste des Docks, Cocoa-Koordinaten
    var edgeLine: Double    // Innenkante des Docks: y bei unten, x bei links oder rechts
    var continuous = false  // durchgehende Kette über die volle Bildschirmbreite statt genau am Dock
}

/// Zustand und Entscheidungen des Treffer-Test-Wegs ohne Fensterserver, Queues und Uhr. Die Uhr kommt immer als Parameter.
enum DockProbeCore {
    struct Snapshot: Equatable {
        var screens: [ScreenInfo]
        var primaryHeight: Double
        var orientation: String
        var autohide: Bool
        var tile: Double
        var large: Double
        var magnification: Bool
    }

    struct Placed: Equatable {
        var screenIndex: Int
        var edge: DockEdge
        var frame: CGRect
        var bar: DockProbeLogic.Bar
    }

    struct Measured: Equatable {
        var placed: Placed?
        var plausible: Bool
    }

    /// Leiste suchen und auf Plausibilität prüfen. `hit(frame, edge, u, d)` ist der Treffer-Test des Fensterservers.
    static func measure(_ s: Snapshot, dockWindowsPresent: Bool, hit: (CGRect, DockEdge, Double, Double) -> Bool) -> Measured {
        guard dockWindowsPresent else { return Measured(placed: nil, plausible: false) }
        let edge = ContinuousDock.edge(orientation: s.orientation)
        for (i, sc) in s.screens.enumerated() {
            let f = sc.frame
            let len = edge == .bottom ? Double(f.width) : Double(f.height)
            if let bar = DockProbeLogic.findBar(length: len, hit: { hit(f, edge, $0, $1) }) {
                let t: Double
                switch edge {
                case .bottom: t = Double(sc.visible.minY - sc.frame.minY)
                case .left: t = Double(sc.visible.minX - sc.frame.minX)
                case .right: t = Double(sc.frame.maxX - sc.visible.maxX)
                }
                let ok = DockProbeLogic.isPlausible(bar, tile: s.tile, screenLength: len, expectedThickness: s.autohide || t <= 1 ? nil : t)
                return Measured(placed: Placed(screenIndex: i, edge: edge, frame: f, bar: bar), plausible: ok)
            }
        }
        return Measured(placed: nil, plausible: false)
    }

    /// Messergebnis in Beobachtung und Geometrie übersetzen (die Dicke der Birnenleiste ist die Trefferdicke minus 6 pt).
    static func evaluate(_ m: Measured, _ s: Snapshot, screenID: (CGRect) -> CGDirectDisplayID) -> (obs: DockObservation, geometry: DockGeometry?) {
        guard let p = m.placed, m.plausible else { return (m.placed == nil && s.autohide ? .hidden : .unavailable, nil) }
        let f = p.frame, b = p.bar
        let o = p.edge == .bottom ? Double(f.minX) : Double(f.minY)
        let a = o + b.a, e = o + b.b, icon = max(b.thick - 6, 10)
        let id = screenID(f)
        let g: DockGeometry
        switch p.edge {
        case .bottom: g = DockGeometry(screenID: id, edge: .bottom, rect: CGRect(x: a, y: f.minY, width: e - a, height: icon), edgeLine: Double(f.minY) + b.thick)
        case .left: g = DockGeometry(screenID: id, edge: .left, rect: CGRect(x: f.minX, y: a, width: icon, height: e - a), edgeLine: Double(f.minX) + b.thick)
        case .right: g = DockGeometry(screenID: id, edge: .right, rect: CGRect(x: f.maxX - icon, y: a, width: icon, height: e - a), edgeLine: Double(f.maxX) - b.thick)
        }
        return (.visible(g.rect), g)
    }

    /// Kantenstreifen aller Bildschirme an der Dock-Seite (bei Auto-Hide kann das Dock auf jedem erscheinen), der unter dem Zeiger zuerst.
    static func edgeStrips(screens: [CGRect], orientation: String) -> [CGRect] {
        screens.map { f in
            switch ContinuousDock.edge(orientation: orientation) {
            case .bottom: return CGRect(x: f.minX, y: f.minY, width: f.width, height: 3)
            case .left: return CGRect(x: f.minX, y: f.minY, width: 3, height: f.height)
            case .right: return CGRect(x: f.maxX - 3, y: f.minY, width: 3, height: f.height)
            }
        }
    }

    static func edgeStrip(at pointer: CGPoint, screens: [CGRect], orientation: String) -> CGRect? {
        let all = edgeStrips(screens: screens, orientation: orientation)
        return all.first { $0.insetBy(dx: -0.5, dy: -0.5).contains(pointer) } ?? all.first
    }
}

/// Bücher der Messungen (Haupt-Thread). Eine laufende plus höchstens eine wartende Messung, Hänger werden per Generation verworfen.
struct ProbeScheduler {
    static let hangLimit = 0.3
    private(set) var generation = 0
    private(set) var measuring = false
    private(set) var pending = 0

    /// Generation der neuen Messung, nil wenn schon eine läuft oder zu viele warten.
    mutating func begin() -> Int? {
        guard !measuring, pending < 2 else { return nil }
        measuring = true; pending += 1
        return generation
    }

    /// Ergebnis (oder Verwurf) einer Messung. true, wenn es noch gilt.
    mutating func finish(_ gen: Int) -> Bool {
        pending = max(pending - 1, 0)
        guard gen == generation else { return false }
        measuring = false
        return true
    }

    /// `startedAt`: Beginn der Messung auf der Queue (nil: wartet noch). Gibt true zurück, wenn ein Hänger aufgegeben wurde.
    mutating func watchdog(now: Double, startedAt: Double?) -> Bool {
        guard measuring, let s = startedAt, now - s > Self.hangLimit else { return false }
        generation += 1; measuring = false
        return true
    }

    mutating func stop() { generation += 1; measuring = false }
}

/// Wann die Dock-Einstellungen neu gelesen werden: bei jedem Ereignis sofort und danach alle 0,4 s, solange der Zustand noch nicht
/// feststeht (AppKit zieht `visibleFrame` womöglich später nach).
struct SnapshotPolicy {
    static let followUp = 0.4
    private var again: Double?

    mutating func event(now: Double) { again = now + Self.followUp }
    mutating func reset() { again = nil }

    /// true, wenn jetzt nachgelesen werden soll. `keepGoing`: danach in 0,4 s erneut (Zustand unfertig oder unplausibel).
    mutating func due(now: Double, keepGoing: Bool = false) -> Bool {
        guard let a = again, now >= a else { return false }
        again = keepGoing ? now + Self.followUp : nil
        return true
    }
}

/// Ablauf eines Bursts (Haupt-Thread, Uhr als Parameter): wann gelesen, gemessen und beendet wird.
struct BurstPlanner {
    struct Plan: Equatable { var retake: Bool; var measure: Bool; var startTimer: Bool }
    struct Tick: Equatable { var retake: Bool; var ended: Bool }
    static let maxLength = 6.0

    private(set) var active = false
    private var start = 0.0
    private var until = 0.0
    private var policy = SnapshotPolicy()

    /// `event`: Dock-, Bildschirm- oder App-Ereignis (liest neu und misst sofort). Zeigerbewegungen messen nur beim Start eines Bursts.
    mutating func request(now: Double, duration: Double, event: Bool, haveSnapshot: Bool) -> Plan {
        let fresh = !active
        if fresh { active = true; start = now }
        if event { policy.event(now: now) }
        until = max(until, now + duration)
        return Plan(retake: event || !haveSnapshot, measure: event || fresh, startTimer: fresh)
    }

    /// Ein Takt des Timers. `settling`: Zustand noch nicht gemeldet. `unavailable`: letzte Messung unplausibel oder nichts gefunden.
    mutating func tick(now: Double, settling: Bool, unavailable: Bool) -> Tick {
        let retake = policy.due(now: now, keepGoing: settling || unavailable)
        if now > until, settling, now - start < Self.maxLength { until = now + 0.3 }
        if now > until { active = false; return Tick(retake: retake, ended: true) }
        return Tick(retake: retake, ended: false)
    }

    mutating func reset() { self = BurstPlanner() }
}

/// Eine Vergrößerungsschleife je Marke: Eine ältere Schleife erkennt an der Marke, dass sie abgelöst wurde, und rührt nichts mehr an.
final class LoopGate: @unchecked Sendable {
    private let token = OSAllocatedUnfairLock(initialState: 0)
    func start() -> Int { token.withLock { $0 += 1; return $0 } }
    func cancel() { token.withLock { $0 += 1 } }
    func isCurrent(_ t: Int) -> Bool { token.withLock { $0 == t } }
}

/// Welcher Weg die Dock-Geometrie liefert und was beim Wechsel angehalten wird.
protocol DockSourceRunner: AnyObject {
    func begin()
    func end()        // anhalten und Ergebnis melden
    func endQuiet()   // anhalten ohne Meldung (Quellwechsel, Pause)
}

final class DockSourceCoordinator {
    private let accessibility: DockSourceRunner
    private let probe: DockSourceRunner
    init(accessibility: DockSourceRunner, probe: DockSourceRunner) { self.accessibility = accessibility; self.probe = probe }

    func update(wanted: Bool, permission: Bool) {
        switch (wanted, DockSource.choose(permission: permission)) {
        case (true, .accessibility): probe.endQuiet(); accessibility.begin()
        case (true, .probe): accessibility.endQuiet(); probe.begin()
        case (false, _): accessibility.endQuiet(); probe.endQuiet()
        }
    }
}

/// Platzhalter für den Weg über die Bedienungshilfen in der App-Store-Fassung (dort nicht einkompiliert, der Treffer-Test-Weg liefert alles).
final class NullRunner: DockSourceRunner {
    func begin() {}
    func end() {}
    func endQuiet() {}
}
