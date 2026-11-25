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

    @Published var lightsEnabled = true { didSet { save() } }
    @Published var chainStyle = ChainStyleKind.classic { didSet { save() } }
    @Published var colorMode = ColorMode.multicolor { didSet { save() } }
    @Published var pattern = LightPattern.twinkle { didSet { save() } }
    @Published var lightsTempo = 2 { didSet { save() } }
    @Published var bulbSize = 2 { didSet { save() } }
    @Published var spacing = 2 { didSet { save() } }
    @Published var lightsLayer = DisplayLayer.above { didSet { save() } }
    @Published var dockLights = true { didSet { save() } }
    @Published var dockStyle = DockStyle.sameAsBar { didSet { save() } }

    @Published var snowEnabled = true { didSet { save() } }
    @Published var snowAmount = 2 { didSet { save() } }
    @Published var flakeSize = 2 { didSet { save() } }
    @Published var snowSpeed = 2 { didSet { save() } }
    @Published var wind = Wind.off { didSet { save() } }
    @Published var snowAvoid = 2 { didSet { save() } }
    @Published var snowLayer = DisplayLayer.above { didSet { save() } }
    @Published var settleSnow = true { didSet { save() } }

    @Published var alwaysSaveEnergy = false { didSet { save() } }
    @Published var paused = false { didSet { save() } }
    @Published var welcomeShown = false { didSet { save() } }
    @Published var permissionPromptShown = false { didSet { save() } }

    private init() {
        load()
        observer = DefaultsObserver(keys: Settings.keys) { [weak self] in
            DispatchQueue.main.async { if let self, !self.loading { self.load() } }
        }
    }

    private var observer: DefaultsObserver?
    static let keys = ["lightsEnabled", "chainStyle", "colorMode", "pattern", "lightsTempo", "bulbSize", "spacing", "lightsLayer", "dockLights", "dockStyle",
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

    private func save() {
        guard !loading else { return }
        loading = true
        defer { DispatchQueue.main.async { [self] in loading = false } }
        d.set(lightsEnabled, forKey: "lightsEnabled")
        // Ein Startargument (-chainStyle ...) soll die gespeicherte Einstellung nicht überschreiben
        if !CommandLine.arguments.contains("-chainStyle") { d.set(chainStyle.rawValue, forKey: "chainStyle") }
        d.set(colorMode.rawValue, forKey: "colorMode")
        d.set(pattern.rawValue, forKey: "pattern")
        d.set(lightsTempo, forKey: "lightsTempo")
        d.set(bulbSize, forKey: "bulbSize")
        d.set(spacing, forKey: "spacing")
        d.set(lightsLayer.rawValue, forKey: "lightsLayer")
        d.set(dockLights, forKey: "dockLights")
        d.set(dockStyle.rawValue, forKey: "dockStyle")
        d.set(snowEnabled, forKey: "snowEnabled")
        d.set(snowAmount, forKey: "snowAmount")
        d.set(flakeSize, forKey: "flakeSize")
        d.set(snowSpeed, forKey: "snowSpeed")
        d.set(wind.rawValue, forKey: "wind")
        d.set(snowAvoid, forKey: "snowAvoid")
        d.set(snowLayer.rawValue, forKey: "snowLayer")
        d.set(settleSnow, forKey: "settleSnow")
        d.set(alwaysSaveEnergy, forKey: "alwaysSaveEnergy")
        d.set(paused, forKey: "paused")
        d.set(welcomeShown, forKey: "welcomeShown")
        d.set(permissionPromptShown, forKey: "permissionPromptShown")
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
