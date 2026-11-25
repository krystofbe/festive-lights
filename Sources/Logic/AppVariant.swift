/// Standard ist die App-Store-Fassung: Sandbox, ohne Bedienungshilfen (AX). Der AX-Code (DockTracker, Berechtigung, zweites Popover) steht hinter dem
/// Compile-Schalter `DIRECT` im Repo, wird aber nicht gebaut und nicht ausgeliefert.
enum AppVariant {
    #if DIRECT
    static let isStore = false
    #else
    static let isStore = true
    #endif

    /// "Schnee bleibt auf Fenstern liegen" braucht mit AX die Berechtigung, in der Store-Fassung läuft es über die Fensterliste ohne.
    static func settleAllowed(accessibilityGranted: Bool, isStore: Bool = AppVariant.isStore) -> Bool { isStore || accessibilityGranted }
}
