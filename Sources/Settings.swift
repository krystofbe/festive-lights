import Foundation
import Combine

enum ColorMode: String, CaseIterable { case multicolor, warm }
enum DisplayLayer: String, CaseIterable { case above, desktop }

/// Alle gespeicherten Einstellungen. Änderungen werden sofort in UserDefaults geschrieben,
/// Änderungen von außen (zum Beispiel `defaults write`) werden live übernommen.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard
    private var loading = false

    @Published var lightsEnabled = true { didSet { write("lightsEnabled", lightsEnabled) } }
    @Published var chainStyle = ChainStyleKind.classic { didSet { write("chainStyle", chainStyle.rawValue) } }
    @Published var colorMode = ColorMode.multicolor { didSet { write("colorMode", colorMode.rawValue) } }
    @Published var pattern = LightPattern.twinkle { didSet { write("pattern", pattern.rawValue) } }
    @Published var lightsTempo = 2 { didSet { write("lightsTempo", lightsTempo) } }
    @Published var bulbSize = 2 { didSet { write("bulbSize", bulbSize) } }
    @Published var spacing = 2 { didSet { write("spacing", spacing) } }
    @Published var lightsLayer = DisplayLayer.above { didSet { write("lightsLayer", lightsLayer.rawValue) } }
    @Published var dockLights = true { didSet { write("dockLights", dockLights) } }
    @Published var dockStyle = DockStyle.sameAsBar { didSet { write("dockStyle", dockStyle.rawValue) } }
    @Published var dockShape = DockShape.exact { didSet { write("dockShape", dockShape.rawValue) } }

    @Published var snowEnabled = true { didSet { write("snowEnabled", snowEnabled) } }
    @Published var snowAmount = 2 { didSet { write("snowAmount", snowAmount) } }
    @Published var flakeSize = 2 { didSet { write("flakeSize", flakeSize) } }
    @Published var snowSpeed = 2 { didSet { write("snowSpeed", snowSpeed) } }
    @Published var wind = Wind.off { didSet { write("wind", wind.rawValue) } }
    @Published var snowAvoid = 2 { didSet { write("snowAvoid", snowAvoid) } }
    @Published var snowLayer = DisplayLayer.above { didSet { write("snowLayer", snowLayer.rawValue) } }
    @Published var settleSnow = true { didSet { write("settleSnow", settleSnow) } }

    @Published var alwaysSaveEnergy = false { didSet { write("alwaysSaveEnergy", alwaysSaveEnergy) } }
    @Published var paused = false { didSet { write("paused", paused) } }
    @Published var welcomeShown = false { didSet { write("welcomeShown", welcomeShown) } }
    @Published var permissionPromptShown = false { didSet { write("permissionPromptShown", permissionPromptShown) } }

    private init() {
        #if !DEBUG
        // Im Release wirken Startargumente (zum Beispiel -chainStyle) nicht, nur gespeicherte Einstellungen
        UserDefaults.standard.setVolatileDomain([:], forName: UserDefaults.argumentDomain)
        #endif
        load()
        observer = DefaultsObserver(keys: Settings.keys) { [weak self] in
            DispatchQueue.main.async { if let self, !self.loading { self.load() } }
        }
    }

    private var observer: DefaultsObserver?
    static let keys = ["lightsEnabled", "chainStyle", "colorMode", "pattern", "lightsTempo", "bulbSize", "spacing", "lightsLayer", "dockLights", "dockStyle", "dockShape",
                       "snowEnabled", "snowAmount", "flakeSize", "snowSpeed", "wind", "snowAvoid", "snowLayer", "settleSnow",
                       "alwaysSaveEnergy", "paused", "welcomeShown", "permissionPromptShown"]

    private func level(_ key: String, _ def: Int) -> Int {
        d.object(forKey: key) == nil ? def : min(max(d.integer(forKey: key), 0), 4)
    }
    private func bool(_ key: String, _ def: Bool) -> Bool { d.object(forKey: key) == nil ? def : d.bool(forKey: key) }
    private func raw<T: RawRepresentable>(_ key: String, _ def: T) -> T where T.RawValue == String {
        d.string(forKey: key).flatMap(T.init(rawValue:)) ?? def
    }
    private func set<T: Equatable>(_ p: ReferenceWritableKeyPath<Settings, T>, _ v: T) { if self[keyPath: p] != v { self[keyPath: p] = v } }

    private func load() {
        loading = true
        defer { loading = false }
        set(\.lightsEnabled, bool("lightsEnabled", true))
        set(\.chainStyle, raw("chainStyle", .classic))
        set(\.colorMode, raw("colorMode", .multicolor))
        set(\.pattern, raw("pattern", .twinkle))
        set(\.lightsTempo, level("lightsTempo", 2))
        set(\.bulbSize, level("bulbSize", 2))
        set(\.spacing, level("spacing", 2))
        set(\.lightsLayer, raw("lightsLayer", .above))
        set(\.dockLights, bool("dockLights", true))
        set(\.dockStyle, raw("dockStyle", .sameAsBar))
        set(\.dockShape, raw("dockShape", .exact))
        set(\.snowEnabled, bool("snowEnabled", true))
        set(\.snowAmount, level("snowAmount", 2))
        set(\.flakeSize, level("flakeSize", 2))
        set(\.snowSpeed, level("snowSpeed", 2))
        set(\.wind, raw("wind", .off))
        set(\.snowAvoid, level("snowAvoid", 2))
        set(\.snowLayer, raw("snowLayer", .above))
        set(\.settleSnow, bool("settleSnow", true))
        set(\.alwaysSaveEnergy, bool("alwaysSaveEnergy", false))
        set(\.paused, bool("paused", false))
        set(\.welcomeShown, bool("welcomeShown", false))
        set(\.permissionPromptShown, bool("permissionPromptShown", false))
    }

    /// Setzt alle Werte aus SPEC §3 zurück. Unverändert bleiben "schon gezeigt"-Flags und die Pause. "Beim Anmelden starten" und die
    /// Berechtigung liegen außerhalb dieser Klasse und sind nicht betroffen. Wirkt sofort, weil jeder Wert veröffentlicht wird.
    func resetToDefaults() {
        lightsEnabled = true; chainStyle = .classic; colorMode = .multicolor; pattern = .twinkle
        lightsTempo = 2; bulbSize = 2; spacing = 2; lightsLayer = .above
        dockLights = true; dockStyle = .sameAsBar; dockShape = .exact
        snowEnabled = true; snowAmount = 2; flakeSize = 2; snowSpeed = 2; wind = .off; snowAvoid = 2; snowLayer = .above; settleSnow = true
        alwaysSaveEnergy = false
    }

    /// Schreibt nur den geänderten Schlüssel. Beim Laden von außen wird nichts zurückgeschrieben.
    private func write(_ key: String, _ value: Any) {
        guard !loading else { return }
        #if DEBUG
        // Ein Startargument (-chainStyle ...) soll die gespeicherte Einstellung nicht überschreiben
        if key == "chainStyle", CommandLine.arguments.contains("-chainStyle") { return }
        #endif
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
