#if DIRECT
import AppKit
import Sparkle

/// Updates der Direkt-Variante über Sparkle 2. Prüft einmal täglich (Info.plist: `SUScheduledCheckInterval`), ohne Systemprofil und ohne
/// Zusatzparameter im Feed-Request (`SUEnableSystemProfiling` ist aus). Beim ersten Start gibt es keinen eigenen Dialog, Sparkle fragt beim zweiten Start.
final class UpdateController: ObservableObject {
    private let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    var automatic: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue; objectWillChange.send() }
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }
}
#endif
