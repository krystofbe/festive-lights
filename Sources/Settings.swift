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
    @Published var colorMode = ColorMode.multicolor { didSet { save() } }
    @Published var pattern = LightPattern.twinkle { didSet { save() } }
    @Published var lightsTempo = 2 { didSet { save() } }
    @Published var bulbSize = 2 { didSet { save() } }
    @Published var spacing = 2 { didSet { save() } }
    @Published var lightsLayer = DisplayLayer.above { didSet { save() } }
    @Published var dockLights = true { didSet { save() } }

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
        NotificationCenter.default.addObserver(self, selector: #selector(defaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
    }

    @objc private func defaultsChanged() {
        DispatchQueue.main.async { [self] in if !loading { load() } }
    }

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
        set(\.colorMode, raw("colorMode", .multicolor))
        set(\.pattern, raw("pattern", .twinkle))
        set(\.lightsTempo, level("lightsTempo", 2))
        set(\.bulbSize, level("bulbSize", 2))
        set(\.spacing, level("spacing", 2))
        set(\.lightsLayer, raw("lightsLayer", .above))
        set(\.dockLights, bool("dockLights", true))
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
        d.set(colorMode.rawValue, forKey: "colorMode")
        d.set(pattern.rawValue, forKey: "pattern")
        d.set(lightsTempo, forKey: "lightsTempo")
        d.set(bulbSize, forKey: "bulbSize")
        d.set(spacing, forKey: "spacing")
        d.set(lightsLayer.rawValue, forKey: "lightsLayer")
        d.set(dockLights, forKey: "dockLights")
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
