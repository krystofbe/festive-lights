#if DIRECT
import AppKit
import Sparkle
import Combine

/// Updates der Direkt-Variante über Sparkle 2. Prüft einmal täglich (Info.plist: `SUScheduledCheckInterval`), ohne Systemprofil und ohne
/// Zusatzparameter im Feed-Request (`SUEnableSystemProfiling` ist aus). Beim ersten Start gibt es keinen eigenen Dialog, Sparkle fragt beim zweiten Start.
final class UpdateController: ObservableObject {
    private let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var observation: AnyCancellable?

    /// Der Schalter in Allgemein folgt auch der Antwort aus Sparkles eigener Abfrage beim zweiten Start.
    init() {
        observation = controller.updater.publisher(for: \.automaticallyChecksForUpdates).dropFirst().sink { [weak self] _ in self?.objectWillChange.send() }
    }

    var automatic: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue; objectWillChange.send() }
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }
}
#endif
