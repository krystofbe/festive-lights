import SwiftUI
import ServiceManagement

final class PermissionModel: ObservableObject {
    @Published var granted = Permission.granted
    private var timer: Timer?

    func start() {
        refresh()
        timer?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() { timer?.invalidate(); timer = nil }
    func refresh() { let g = Permission.granted; if g != granted { granted = g } }
}

final class LoginModel: ObservableObject {
    @Published var enabled = SMAppService.mainApp.status == .enabled

    func refresh() { enabled = SMAppService.mainApp.status == .enabled }

    func set(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {}
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
                Text(low).font(.caption).foregroundStyle(.secondary).frame(width: 52, alignment: .trailing)
                Slider(value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }), in: 0...4, step: 1)
                    .frame(width: 130)
                    .accessibilityLabel(Text(title))
                    .accessibilityValue(Text("\(value + 1) / 5"))
                Text(high).font(.caption).foregroundStyle(.secondary).frame(width: 52, alignment: .leading)
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

struct SettingsView: View {
    @ObservedObject var s: Settings
    @ObservedObject var perm: PermissionModel
    @ObservedObject var login: LoginModel
    @State private var confirmReset = false

    var body: some View {
        TabView {
            general.tabItem { Label("General", systemImage: "gearshape") }
            menuBar.tabItem { Label("Menu bar", systemImage: "menubar.rectangle") }
            dock.tabItem { Label("Dock", systemImage: "dock.rectangle") }
            snow.tabItem { Label("Snow", systemImage: "snowflake") }
        }
        .frame(width: 470, height: 480)
        .onAppear { perm.start() }
        .onDisappear { perm.stop() }
    }

    private var menuBar: some View {
        SettingsPane(title: "Lights on the menu bar", isOn: $s.lightsEnabled) {
            chainControls(style: $s.chainStyle, colors: $s.colorMode, pattern: $s.pattern, tempo: $s.lightsTempo, size: $s.bulbSize, spacing: $s.spacing, layer: $s.lightsLayer)
        }
    }

    private var dock: some View {
        SettingsPane(title: "Lights on the Dock", isOn: $s.dockLights) {
            chainControls(style: $s.dockStyle, colors: $s.dockColorMode, pattern: $s.dockPattern, tempo: $s.dockTempo, size: $s.dockBulbSize, spacing: $s.dockSpacing, layer: $s.dockLayer)
            let side = ["left", "right"].contains(CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String ?? "bottom")
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
            Text("Classic").tag(ChainStyleKind.classic)
            Text("Fir, colorful").tag(ChainStyleKind.firColor)
            Text("Fir, warm gold").tag(ChainStyleKind.firGold)
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
            LevelSlider(title: "Avoid pointer", value: $s.snowAvoid, low: "Little", high: "Much")
            LabeledContent("Wind") {
                Picker("Wind", selection: $s.wind) {
                    Text("Off").tag(Wind.off)
                    Text("Blowing left").tag(Wind.left)
                    Text("Blowing right").tag(Wind.right)
                }.pickerStyle(.segmented).labelsHidden().frame(width: 335)
            }
            layerPicker($s.snowLayer)
            Toggle("Snow stays on windows", isOn: $s.settleSnow)
                .disabled(!perm.granted)
        }
    }

    private var general: some View {
        Form {
            Toggle("Start at login", isOn: Binding(get: { login.enabled }, set: { login.set($0) }))
            Picker(selection: $s.powerMode) {
                Text("Automatic").tag(PowerMode.automatic)
                Text("Always").tag(PowerMode.always)
                Text("Off").tag(PowerMode.off)
            } label: {
                Text(LocalizedStringKey(s.powerActive ? "Low Power Mode (active now)" : "Low Power Mode"))
            }
            .pickerStyle(.segmented)
            Text(LocalizedStringKey(s.powerMode == .automatic ? "power.automatic" : s.powerMode == .always ? "power.always" : "power.off"))
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
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

struct WelcomeView: View {
    let startStorm: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            Text("Happy holidays! ❄️ Fancy a snowstorm?").font(.headline).multilineTextAlignment(.center)
            Button("Start snowstorm", action: startStorm).buttonStyle(.borderedProminent)
        }
        .padding(16).frame(width: 250)
    }
}

struct PermissionPromptView: View {
    let open: () -> Void
    var body: some View {
        VStack(spacing: 10) {
            Text("Lights on the Dock too, and snow that stays on windows?").font(.headline).multilineTextAlignment(.center)
            Text("For this FestiveLights sees where the Dock and your windows are. No contents, no input.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Open System Settings", action: open).buttonStyle(.borderedProminent)
        }
        .padding(16).frame(width: 280)
    }
}
