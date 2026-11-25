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

struct SettingsView: View {
    @ObservedObject var s: Settings
    @ObservedObject var perm: PermissionModel
    @ObservedObject var login: LoginModel

    var body: some View {
        TabView {
            lights.tabItem { Label("Lights", systemImage: "lightbulb") }
            snow.tabItem { Label("Snow", systemImage: "snowflake") }
            general.tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 470, height: 400)
        .onAppear { perm.start() }
        .onDisappear { perm.stop() }
    }

    private var lights: some View {
        Form {
            Picker("Style", selection: $s.chainStyle) {
                Text("Classic").tag(ChainStyleKind.classic)
                Text("Fir, colorful").tag(ChainStyleKind.firColor)
                Text("Fir, warm gold").tag(ChainStyleKind.firGold)
            }.pickerStyle(.segmented)
            if s.chainStyle == .classic || (s.dockLights && s.dockStyle.resolve(bar: s.chainStyle) == .classic) {
                Picker("Colors", selection: $s.colorMode) {
                    Text("Multicolor").tag(ColorMode.multicolor)
                    Text("Warm white").tag(ColorMode.warm)
                }.pickerStyle(.segmented)
            }
            Picker("Pattern", selection: $s.pattern) {
                Text("Steady").tag(LightPattern.steady)
                Text("Twinkle").tag(LightPattern.twinkle)
                Text("Chase").tag(LightPattern.chase)
            }.pickerStyle(.segmented)
            LevelSlider(title: "Speed", value: $s.lightsTempo, low: "Slow", high: "Fast")
            LevelSlider(title: "Bulb size", value: $s.bulbSize, low: "Small", high: "Large")
            LevelSlider(title: "Spacing", value: $s.spacing, low: "Tight", high: "Wide")
            Picker("Layer", selection: $s.lightsLayer) {
                Text("Above all windows").tag(DisplayLayer.above)
                Text("Desktop only").tag(DisplayLayer.desktop)
            }
            Toggle("Lights on the Dock", isOn: $s.dockLights)
                .disabled(!perm.granted)
            Picker("Dock style", selection: $s.dockStyle) {
                Text("Like menu bar").tag(DockStyle.sameAsBar)
                Text("Classic").tag(DockStyle.classic)
                Text("Fir, colorful").tag(DockStyle.firColor)
                Text("Fir, warm gold").tag(DockStyle.firGold)
            }
            .disabled(!perm.granted || !s.dockLights)
            if !perm.granted {
                Text("Permission needed, see General.").font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var snow: some View {
        Form {
            LevelSlider(title: "Amount", value: $s.snowAmount, low: "Light", high: "Heavy")
            LevelSlider(title: "Flake size", value: $s.flakeSize, low: "Small", high: "Large")
            LevelSlider(title: "Speed", value: $s.snowSpeed, low: "Slow", high: "Fast")
            LevelSlider(title: "Avoid pointer", value: $s.snowAvoid, low: "Little", high: "Much")
            Picker("Wind", selection: $s.wind) {
                Text("Off").tag(Wind.off)
                Text("Blowing left").tag(Wind.left)
                Text("Blowing right").tag(Wind.right)
            }
            Picker("Layer", selection: $s.snowLayer) {
                Text("Above all windows").tag(DisplayLayer.above)
                Text("Desktop only").tag(DisplayLayer.desktop)
            }
            Toggle("Snow stays on windows", isOn: $s.settleSnow)
                .disabled(!perm.granted)
        }
        .formStyle(.grouped)
    }

    private var general: some View {
        Form {
            Toggle("Start at login", isOn: Binding(get: { login.enabled }, set: { login.set($0) }))
            Toggle("Always save energy", isOn: $s.alwaysSaveEnergy)
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
