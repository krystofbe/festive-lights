import Foundation
import Combine

enum ColorMode: String, CaseIterable { case multicolor, warm }
enum DisplayLayer: String, CaseIterable { case above, desktop }
/// Bildschirme (ab 1.1): Lichter und Schnee auf allen oder nur auf dem Hauptbildschirm.
enum DisplayScope: String, CaseIterable { case all, mainOnly }
/// Sparmodus: automatisch (Stromsparmodus, Akku unter 20 %), immer oder nie.
enum PowerMode: String, CaseIterable { case automatic, always, off }

/// Der Sparmodus greift gerade (Anzeige im Einstellungsfenster). Eigenes Objekt, nicht Teil von `Settings`: Änderungen von `Settings` lösen `apply()`
/// aus, und `apply()` schreibt diesen Status, das darf nie eine Schleife bilden. Veröffentlicht wird nur bei echter Änderung.
final class PowerStatus: ObservableObject {
    static let shared = PowerStatus()
    @Published private(set) var active = false
    func update(_ v: Bool) { if active != v { active = v } }
}

/// Alle gespeicherten Einstellungen. Änderungen werden sofort in UserDefaults geschrieben,
/// Änderungen von außen (zum Beispiel `defaults write`) werden live übernommen.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard
    private var loading = false

    @Published var lightsEnabled = true { didSet { write("lightsEnabled", lightsEnabled) } }
    @Published var chainStyle = ChainStyleKind.firColor { didSet { write("chainStyle", chainStyle.rawValue) } }
    @Published var colorMode = ColorMode.multicolor { didSet { write("colorMode", colorMode.rawValue) } }
    @Published var pattern = LightPattern.twinkle { didSet { write("pattern", pattern.rawValue) } }
    @Published var lightsTempo = 2 { didSet { write("lightsTempo", lightsTempo) } }
    @Published var bulbSize = 2 { didSet { write("bulbSize", bulbSize) } }
    @Published var spacing = 2 { didSet { write("spacing", spacing) } }
    @Published var lightsLayer = DisplayLayer.above { didSet { write("lightsLayer", lightsLayer.rawValue) } }
    @Published var dockLights = true { didSet { write("dockLights", dockLights) } }
    @Published var dockStyle = ChainStyleKind.firColor { didSet { write("dockStyle", dockStyle.rawValue) } }
    @Published var dockColorMode = ColorMode.multicolor { didSet { write("dockColorMode", dockColorMode.rawValue) } }
    @Published var dockPattern = LightPattern.twinkle { didSet { write("dockPattern", dockPattern.rawValue) } }
    @Published var dockTempo = 2 { didSet { write("dockTempo", dockTempo) } }
    @Published var dockBulbSize = 2 { didSet { write("dockBulbSize", dockBulbSize) } }
    @Published var dockSpacing = 2 { didSet { write("dockSpacing", dockSpacing) } }
    @Published var dockLayer = DisplayLayer.above { didSet { write("dockLayer", dockLayer.rawValue) } }
    @Published var dockShape = DockShape.exact { didSet { write("dockShape", dockShape.rawValue) } }

    @Published var snowEnabled = true { didSet { write("snowEnabled", snowEnabled) } }
    @Published var snowAmount = 2 { didSet { write("snowAmount", snowAmount) } }
    @Published var flakeSize = 2 { didSet { write("flakeSize", flakeSize) } }
    @Published var snowSpeed = 2 { didSet { write("snowSpeed", snowSpeed) } }
    @Published var wind = Wind.off { didSet { write("wind", wind.rawValue) } }
    @Published var snowAvoid = 2 { didSet { write("snowAvoid", snowAvoid) } }
    @Published var snowLayer = DisplayLayer.above { didSet { write("snowLayer", snowLayer.rawValue) } }
    @Published var settleSnow = true { didSet { write("settleSnow", settleSnow) } }

    @Published var displays = DisplayScope.all { didSet { write("displays", displays.rawValue) } }
    @Published var powerMode = PowerMode.automatic { didSet { write("powerMode", powerMode.rawValue) } }
    @Published var paused = false { didSet { write("paused", paused) } }
    @Published var welcomeShown = false { didSet { write("welcomeShown", welcomeShown) } }

    private init() {
        // Startargumente (zum Beispiel -chainStyle) gelten höchstens einmal beim Start, danach ist die Argument-Domain leer
        let args = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        #if DEBUG
        adopt(args)
        // Entwicklerschalter (zum Beispiel -debugIgnoreLock, keine Einstellungen) bleiben für die Debug-Auslöser lesbar
        UserDefaults.standard.setVolatileDomain(args.filter { !Settings.keys.contains($0.key) }, forName: UserDefaults.argumentDomain)
        #else
        UserDefaults.standard.setVolatileDomain([:], forName: UserDefaults.argumentDomain)
        #endif
        Settings.migrate(d)
        load()
        observer = DefaultsObserver(keys: Settings.keys) { [weak self] in
            DispatchQueue.main.async { if let self, !self.loading { self.load() } }
        }
    }

    private var observer: DefaultsObserver?
    static let keys = ["lightsEnabled", "chainStyle", "colorMode", "pattern", "lightsTempo", "bulbSize", "spacing", "lightsLayer", "dockLights", "dockStyle", "dockColorMode", "dockPattern", "dockTempo", "dockBulbSize", "dockSpacing", "dockLayer", "dockShape",
                       "snowEnabled", "snowAmount", "flakeSize", "snowSpeed", "wind", "snowAvoid", "snowLayer", "settleSnow",
                       "powerMode", "displays", "paused", "welcomeShown"]

    private func level(_ key: String, _ def: Int) -> Int {
        d.object(forKey: key) == nil ? def : min(max(d.integer(forKey: key), 0), 4)
    }
    private func bool(_ key: String, _ def: Bool) -> Bool { d.object(forKey: key) == nil ? def : d.bool(forKey: key) }
    private func raw<T: RawRepresentable>(_ key: String, _ def: T) -> T where T.RawValue == String {
        d.string(forKey: key).flatMap(T.init(rawValue:)) ?? def
    }
    private func set<T: Equatable>(_ p: ReferenceWritableKeyPath<Settings, T>, _ v: T) { if self[keyPath: p] != v { self[keyPath: p] = v } }

    /// Einmalig beim ersten Start mit getrennten Ketten: Die bisher gemeinsamen Werte gelten für beide, ein gespeicherter Dock-Stil
    /// "sameAsBar" wird zum Stil der Menüleiste.
    static func migrate(_ d: UserDefaults) {
        // "Immer Energie sparen" an wird zu "Immer", aus zu "Automatisch"
        if d.object(forKey: "powerMode") == nil, let old = d.object(forKey: "alwaysSaveEnergy") as? Bool {
            d.set(old ? PowerMode.always.rawValue : PowerMode.automatic.rawValue, forKey: "powerMode")
            d.removeObject(forKey: "alwaysSaveEnergy")
        }
        guard d.object(forKey: "dockMigrated") == nil else { return }
        for (bar, dock) in [("colorMode", "dockColorMode"), ("pattern", "dockPattern"), ("lightsTempo", "dockTempo"), ("bulbSize", "dockBulbSize"),
                            ("spacing", "dockSpacing"), ("lightsLayer", "dockLayer")] {
            if let v = d.object(forKey: bar) { d.set(v, forKey: dock) }
        }
        if let old = d.string(forKey: "dockStyle"), ChainStyleKind(rawValue: old) != nil {
            // eigener Dock-Stil bleibt
        } else if let v = d.object(forKey: "chainStyle") { d.set(v, forKey: "dockStyle") } else { d.removeObject(forKey: "dockStyle") }
        d.set(true, forKey: "dockMigrated")
    }

    /// Übernimmt Startargumente einmalig als gespeicherte Werte. Später hat die Oberfläche immer Vorrang.
    func adopt(_ args: [String: Any]) {
        for k in Settings.keys { if let v = args[k] { d.set(v, forKey: k) } }
    }

    func load() {
        loading = true
        defer { loading = false }
        set(\.lightsEnabled, bool("lightsEnabled", true))
        set(\.chainStyle, raw("chainStyle", .firColor))
        set(\.colorMode, raw("colorMode", .multicolor))
        set(\.pattern, raw("pattern", .twinkle))
        set(\.lightsTempo, level("lightsTempo", 2))
        set(\.bulbSize, level("bulbSize", 2))
        set(\.spacing, level("spacing", 2))
        set(\.lightsLayer, raw("lightsLayer", .above))
        set(\.dockLights, bool("dockLights", true))
        set(\.dockStyle, raw("dockStyle", .firColor))
        set(\.dockColorMode, raw("dockColorMode", .multicolor))
        set(\.dockPattern, raw("dockPattern", .twinkle))
        set(\.dockTempo, level("dockTempo", 2))
        set(\.dockBulbSize, level("dockBulbSize", 2))
        set(\.dockSpacing, level("dockSpacing", 2))
        set(\.dockLayer, raw("dockLayer", .above))
        set(\.dockShape, raw("dockShape", .exact))
        set(\.snowEnabled, bool("snowEnabled", true))
        set(\.snowAmount, level("snowAmount", 2))
        set(\.flakeSize, level("flakeSize", 2))
        set(\.snowSpeed, level("snowSpeed", 2))
        set(\.wind, raw("wind", .off))
        set(\.snowAvoid, level("snowAvoid", 2))
        set(\.snowLayer, raw("snowLayer", .above))
        set(\.settleSnow, bool("settleSnow", true))
        set(\.powerMode, raw("powerMode", .automatic))
        set(\.displays, raw("displays", .all))
        set(\.paused, bool("paused", false))
        set(\.welcomeShown, bool("welcomeShown", false))
    }

    /// Setzt alle Werte aus SPEC §3 zurück. Unverändert bleiben "schon gezeigt"-Flags und die Pause. "Beim Anmelden starten" und die
    /// Berechtigung liegen außerhalb dieser Klasse und sind nicht betroffen. Wirkt sofort, weil jeder Wert veröffentlicht wird.
    func resetToDefaults() {
        lightsEnabled = true; chainStyle = .firColor; colorMode = .multicolor; pattern = .twinkle
        lightsTempo = 2; bulbSize = 2; spacing = 2; lightsLayer = .above
        dockLights = true; dockStyle = .firColor; dockColorMode = .multicolor; dockPattern = .twinkle
        dockTempo = 2; dockBulbSize = 2; dockSpacing = 2; dockLayer = .above; dockShape = .exact
        snowEnabled = true; snowAmount = 2; flakeSize = 2; snowSpeed = 2; wind = .off; snowAvoid = 2; snowLayer = .above; settleSnow = true
        powerMode = .automatic; displays = .all
    }

    /// Schreibt nur den geänderten Schlüssel. Beim Laden von außen wird nichts zurückgeschrieben.
    private func write(_ key: String, _ value: Any) {
        guard !loading else { return }
        d.set(value, forKey: key)
    }
}

/// Meldet Änderungen an UserDefaults, auch von außen (zum Beispiel `defaults write`).
final class DefaultsObserver: NSObject {
    private let keys: [String]
    private let onChange: () -> Void

    init(keys: [String], onChange: @escaping () -> Void) {
        self.keys = keys
        self.onChange = onChange
        super.init()
        keys.forEach { UserDefaults.standard.addObserver(self, forKeyPath: $0, options: [], context: nil) }
    }

    deinit { keys.forEach { UserDefaults.standard.removeObserver(self, forKeyPath: $0) } }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        onChange()
    }
}
