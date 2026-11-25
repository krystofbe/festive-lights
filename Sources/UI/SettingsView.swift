import SwiftUI
import ServiceManagement

#if DIRECT
final class PermissionModel: ObservableObject {
    @Published var granted = Permission.granted

    /// Aufgefrischt wird beim Öffnen und von `AppController.poll` (jede Sekunde), ein eigener Timer ist nicht nötig.
    func refresh() { let g = Permission.granted; if g != granted { granted = g } }
}
#endif

enum SettingsTab: Hashable { case general, menuBar, dock, snow }

/// Gewählter Tab: Beim Öffnen des Fensters wird er auf "Allgemein" zurückgesetzt.
final class SettingsNav: ObservableObject {
    @Published var tab = SettingsTab.general
}

final class LoginModel: ObservableObject {
    @Published var enabled = SMAppService.mainApp.status == .enabled

    func refresh() { enabled = SMAppService.mainApp.status == .enabled }

    func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {}
        // Verlangt macOS eine Freigabe, führt der Weg in die Systemeinstellungen (Anmeldeobjekte)
        if on, SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        enabled = SMAppService.mainApp.status == .enabled
    }
}

struct LevelSlider: View {
    let title: LocalizedStringKey
    @Binding var value: Int
    let low: LocalizedStringKey
    let high: LocalizedStringKey

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                Text(low).font(.caption).foregroundStyle(.secondary).frame(width: 52, alignment: .trailing).accessibilityHidden(true)
                Slider(value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }), in: 0...4, step: 1)
                    .frame(width: 130)
                    .accessibilityLabel(Text(title))
                    .accessibilityValue(Text("\(value + 1) / 5"))
                Text(high).font(.caption).foregroundStyle(.secondary).frame(width: 52, alignment: .leading).accessibilityHidden(true)
            }
        }
    }
}

/// Gemeinsamer Aufbau der Bereiche Menüleiste, Dock und Schnee: Schalter zuoberst in eigener Gruppe, darunter die Einstellungen (ausgegraut, wenn aus).
struct SettingsPane<Content: View>: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            Section { Toggle(title, isOn: $isOn) }
            Section { content }.disabled(!isOn)
        }
        .formStyle(.grouped)
    }
}

/// Sparmodus mit Live-Status: Der Status liegt in einem eigenen Objekt, damit seine Änderungen nur diese Zeilen betreffen.
struct PowerModeRows: View {
    @ObservedObject var s: Settings
    @ObservedObject var status: PowerStatus

    var body: some View {
        Picker(selection: $s.powerMode) {
            Text("Automatic").tag(PowerMode.automatic)
            Text("Always").tag(PowerMode.always)
            Text("Off").tag(PowerMode.off)
        } label: {
            Text(LocalizedStringKey(status.active ? "Low Power Mode (active now)" : "Low Power Mode"))
        }
        .pickerStyle(.segmented)
        Text(LocalizedStringKey(s.powerMode == .automatic ? "power.automatic" : s.powerMode == .always ? "power.always" : "power.off"))
            .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsView: View {
    @ObservedObject var s: Settings
    #if DIRECT
    @ObservedObject var perm: PermissionModel
    @ObservedObject var updates: UpdateController
    #endif
    @ObservedObject var login: LoginModel
    @ObservedObject var nav: SettingsNav
    @State private var confirmReset = false
    @State private var dockOnSide = SettingsView.dockIsOnSide()

    private static func dockIsOnSide() -> Bool {
        ["left", "right"].contains(CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String ?? "bottom")
    }

    var body: some View {
        TabView(selection: $nav.tab) {
            general.tabItem { Label("General", systemImage: "gearshape") }.tag(SettingsTab.general)
            menuBar.tabItem { Label("Menu bar", systemImage: "menubar.rectangle") }.tag(SettingsTab.menuBar)
            dock.tabItem { Label("Dock", systemImage: "dock.rectangle") }.tag(SettingsTab.dock)
            snow.tabItem { Label("Snow", systemImage: "snowflake") }.tag(SettingsTab.snow)
        }
        .frame(width: 470, height: 480)
        #if DIRECT
        .onAppear { perm.refresh() }
        #endif
        .onReceive(DistributedNotificationCenter.default().publisher(for: Notification.Name("com.apple.dock.prefchanged"))) { _ in dockOnSide = Self.dockIsOnSide() }
    }

    private var menuBar: some View {
        SettingsPane(title: "Lights on the menu bar", isOn: $s.lightsEnabled) {
            chainControls(style: $s.chainStyle, colors: $s.colorMode, pattern: $s.pattern, tempo: $s.lightsTempo, size: $s.bulbSize, spacing: $s.spacing, layer: $s.lightsLayer)
        }
    }

    private var dock: some View {
        SettingsPane(title: "Lights on the Dock", isOn: $s.dockLights) {
            chainControls(style: $s.dockStyle, colors: $s.dockColorMode, pattern: $s.dockPattern, tempo: $s.dockTempo, size: $s.dockBulbSize, spacing: $s.dockSpacing, layer: $s.dockLayer)
            let side = dockOnSide
            Picker("Length", selection: $s.dockShape) {
                Text(LocalizedStringKey(side ? "Dock height" : "Dock width")).tag(DockShape.exact)
                Text(LocalizedStringKey(side ? "Full height" : "Full width")).tag(DockShape.continuous)
            }.pickerStyle(.segmented)
        }
    }

    /// Gleicher Aufbau für Menüleiste und Dock, jede Kette mit eigenen Werten.
    @ViewBuilder
    private func chainControls(style: Binding<ChainStyleKind>, colors: Binding<ColorMode>, pattern: Binding<LightPattern>, tempo: Binding<Int>,
                               size: Binding<Int>, spacing: Binding<Int>, layer: Binding<DisplayLayer>) -> some View {
        Picker("Style", selection: style) {
            Text("Fir, colorful").tag(ChainStyleKind.firColor)
            Text("Fir, warm gold").tag(ChainStyleKind.firGold)
            Text("Classic").tag(ChainStyleKind.classic)
        }.pickerStyle(.segmented)
        if style.wrappedValue == .classic {
            Picker("Colors", selection: colors) {
                Text("Multicolor").tag(ColorMode.multicolor)
                Text("Warm white").tag(ColorMode.warm)
            }.pickerStyle(.segmented)
        }
        Picker("Pattern", selection: pattern) {
            Text("Steady").tag(LightPattern.steady)
            Text("Twinkle").tag(LightPattern.twinkle)
            Text("Chase").tag(LightPattern.chase)
        }.pickerStyle(.segmented)
        LevelSlider(title: "Speed", value: tempo, low: "Slow", high: "Fast")
        LevelSlider(title: "Size", value: size, low: "Small", high: "Large")
        LevelSlider(title: "Spacing", value: spacing, low: "Tight", high: "Wide")
        layerPicker(layer)
    }

    private func layerPicker(_ layer: Binding<DisplayLayer>) -> some View {
        LabeledContent("Layer") {
            Picker("Layer", selection: layer) {
                Text("Above all windows").tag(DisplayLayer.above)
                Text("Desktop only").tag(DisplayLayer.desktop)
            }.pickerStyle(.segmented).labelsHidden().frame(width: 335)
        }
    }

    private var snow: some View {
        SettingsPane(title: "Snow", isOn: $s.snowEnabled) {
            LevelSlider(title: "Amount", value: $s.snowAmount, low: "Light", high: "Heavy")
            LevelSlider(title: "Flake size", value: $s.flakeSize, low: "Small", high: "Large")
            LevelSlider(title: "Speed", value: $s.snowSpeed, low: "Slow", high: "Fast")
            LabeledContent("Wind") {
                Picker("Wind", selection: $s.wind) {
                    Text("Off").tag(Wind.off)
                    Text("Blowing left").tag(Wind.left)
                    Text("Blowing right").tag(Wind.right)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 335)
            }
            LevelSlider(title: "Avoid pointer", value: $s.snowAvoid, low: "Little", high: "Much")
            layerPicker($s.snowLayer)
            Toggle("Snow stays on windows", isOn: $s.settleSnow)
                #if DIRECT
                .disabled(!perm.granted)
                .accessibilityHint(Text(perm.granted ? "" : "settle.hint"))
                #endif
        }
    }

    private var general: some View {
        Form {
            Toggle("Start at login", isOn: Binding(get: { login.enabled }, set: { login.set($0) }))
            PowerModeRows(s: s, status: PowerStatus.shared)
            #if DIRECT
            Toggle("Automatically check for updates", isOn: Binding(get: { updates.automatic }, set: { updates.automatic = $0 }))
            #endif
            #if DIRECT
            Section("Permission") {
                HStack(spacing: 6) {
                    Image(systemName: perm.granted ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(perm.granted ? Color.green : Color.orange)
                        .accessibilityHidden(true)
                    Text(perm.granted ? "Permission granted" : "Permission not granted").fontWeight(.medium)
                }
                Text("With this permission FestiveLights sees where the Dock and your windows are, to hang lights on the Dock and let snow settle on windows. It sees no contents and no input.")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Open System Settings") { Permission.request(); Permission.openSystemSettings() }
            }
            #endif
            Section {
                Button("Reset to defaults", role: .destructive) { confirmReset = true }
                    .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmReset) {
                        Button("Reset", role: .destructive) { s.resetToDefaults() }
                        Button("Cancel", role: .cancel) {}
                    } message: { Text("Start at login and the permission stay as they are.") }
            }
        }
        .formStyle(.grouped)
    }
}
