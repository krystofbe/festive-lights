import SwiftUI
import AppKit
import CoreText

/// Farben und Schriften der Einführung (SPEC §6 Punkt 5), unabhängig vom System-Erscheinungsbild.
/// "Bewegung reduzieren" live beobachten.
final class ReduceMotionMonitor: ObservableObject {
    @Published var on = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    private var token: NSObjectProtocol?
    init() {
        token = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let v = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            if v != self.on { self.on = v }
        }
    }
    deinit { if let t = token { NSWorkspace.shared.notificationCenter.removeObserver(t) } }
}

/// Schalter im Stil von macOS (runder Knopf), weinrot wenn an, neutrales Grau wenn aus, als ganze Karte bedienbar.
struct OnbCardToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label
                Spacer(minLength: 8)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule().fill(configuration.isOn ? OnbStyle.wine : Color(hex: 0xA9A397)).frame(width: 42, height: 24)
                    Circle().fill(Color.white).frame(width: 20, height: 20).shadow(color: .black.opacity(0.25), radius: 1, y: 1).padding(.horizontal, 2)
                }
                .animation(.easeInOut(duration: 0.15), value: configuration.isOn)
            }
            .padding(.horizontal, 16).frame(minHeight: 44)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xEADFCB), lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(Text(LocalizedStringKey(configuration.isOn ? "onb.on" : "Off")))
    }
}

enum OnbStyle {
    static let cream = Color(hex: 0xFFFAF0), snow = Color(hex: 0xF3EAD8), flake = Color(hex: 0x9CC3DD)
    static let red = Color(hex: 0xD8432F), wine = Color(hex: 0x86241A), ink = Color(hex: 0x2B363F), muted = Color(hex: 0x5D6A72), dotOff = Color(hex: 0xE7DCCB)

    static func title(_ size: CGFloat = 30) -> Font { .custom("MountainsofChristmas-Bold", size: size) }
    static func body(_ size: CGFloat = 13.5) -> Font { .custom("Poppins-Regular", size: size) }
    static func medium(_ size: CGFloat = 14) -> Font { .custom("Poppins-Medium", size: size) }
    static func strong(_ size: CGFloat = 14) -> Font { .custom("Poppins-SemiBold", size: size) }

    /// Eingebettete Schriften für diesen Prozess registrieren (einmal).
    static let registerFonts: Void = {
        for name in ["MountainsofChristmas-Bold", "Poppins-Regular", "Poppins-Medium", "Poppins-SemiBold"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
        }
    }()
}

/// Der erste Klick auf ein inaktives Fenster löst gleich die Aktion aus.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

extension Color {
    init(hex: Int) { self.init(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255) }
}

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel
    @ObservedObject var s: Settings
    @ObservedObject var login: LoginModel
    #if DIRECT
    @ObservedObject var perm: PermissionModel
    #endif
    var close: () -> Void
    var pulse: () -> Void

    static let size = CGSize(width: 560, height: 540)
    private static let green = Color(hex: 0x34C759)

    init(model: OnboardingModel, s: Settings, login: LoginModel, close: @escaping () -> Void, pulse: @escaping () -> Void = {}) {
        _ = OnbStyle.registerFonts
        self.model = model; self.s = s; self.login = login; self.close = close; self.pulse = pulse
        #if DIRECT
        self.perm = PermissionModel()
        #endif
    }

    var body: some View {
        ZStack {
            OnbStyle.cream
            SnowDots(count: model.step == .finish ? 40 : 9).accessibilityHidden(true).allowsHitTesting(false).zIndex(0)
            VStack(spacing: 0) {
                Image(nsImage: NSImage(named: "garland-header") ?? NSImage()).resizable().frame(width: 560, height: 96).accessibilityHidden(true).allowsHitTesting(false)
                Spacer(minLength: 0)
            }
            VStack {
                Spacer()
                ZStack(alignment: .bottom) {
                    Ellipse().fill(OnbStyle.snow).frame(width: 720, height: 90).offset(y: 48).frame(width: 560, height: 100, alignment: .bottom)
                    HStack { tree; Spacer(); tree.scaleEffect(x: -1) }.padding(.horizontal, 12)
                }
                .frame(height: 100, alignment: .bottom)
            }
            .accessibilityHidden(true).allowsHitTesting(false)
            VStack(spacing: 0) {
                if model.step == .pick { lookUpHint.padding(.top, 100) } else { Spacer().frame(height: 104) }
                VStack(spacing: 10) { content }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                dots.frame(height: 12)
                Spacer().frame(height: 14)
                buttons.frame(height: 44)
                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 40)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Button(action: close) { EmptyView() }.keyboardShortcut(.cancelAction).opacity(0).accessibilityHidden(true))
        .environment(\.colorScheme, .light)
        .clipped()
        .onChange(of: model.step) { _, new in if new == .finish { pulse() } }
        #if DIRECT
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in perm.refresh() }
        #endif
    }

    private var tree: some View { Image(nsImage: NSImage(named: "tree") ?? NSImage()).resizable().frame(width: 56, height: 76) }

    private var lookUpHint: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.up").font(.system(size: 11, weight: .bold))
            Text("onb.up").font(OnbStyle.strong(12))
        }
        .foregroundColor(OnbStyle.red).padding(.horizontal, 12).padding(.vertical, 4)
        .background(Capsule().fill(Color.white)).shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        .accessibilityHidden(true)
    }

    private var dots: some View {
        HStack(spacing: 10) {
            ForEach(0..<model.steps.count, id: \.self) { i in
                Capsule().fill(i == model.index ? OnbStyle.red : OnbStyle.dotOff).frame(width: i == model.index ? 22 : 9, height: 9)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onb.progress"))
        .accessibilityValue(Text("\(model.index + 1) / \(model.steps.count)"))
    }

    private var buttons: some View {
        HStack {
            if model.index > 0 { textButton("onb.back") { model.back() } }
            Spacer()
            Button(action: { model.isLast ? close() : model.next() }) {
                Text(LocalizedStringKey(model.isLast ? "onb.go" : "onb.next"))
                    .font(OnbStyle.strong(15)).foregroundColor(.white).padding(.horizontal, 30).padding(.vertical, 10)
                    .background(Capsule().fill(OnbStyle.wine))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 56)   // zwischen den Bäumchen
    }

    private func textButton(_ key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(LocalizedStringKey(key)).font(OnbStyle.strong(14)).foregroundColor(OnbStyle.muted).padding(.horizontal, 10).padding(.vertical, 8).contentShape(Rectangle()) }
            .buttonStyle(.plain)
    }

    private func heading(_ key: String, _ sub: String?) -> some View {
        VStack(spacing: 4) {
            // Die Schrift hat Überhänge: Rand rundherum, damit nichts abgeschnitten wird
            Text(LocalizedStringKey(key)).font(OnbStyle.title(30)).foregroundColor(OnbStyle.red).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                .padding(.horizontal, 14).padding(.vertical, 2)
                .accessibilityAddTraits(.isHeader)
            if let sub {
                Text(LocalizedStringKey(sub)).font(OnbStyle.body()).foregroundColor(OnbStyle.muted).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 360)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .pick: pick
        case .glow: glow
        case .finish: finish
        }
    }

    // MARK: Schritt 1, Kette aussuchen

    private var pick: some View {
        VStack(spacing: 10) {
            heading("onb.pick.title", "onb.pick.sub")
            HStack(spacing: 12) {
                styleCard(.firColor, "Fir, colorful")
                styleCard(.firGold, "Fir, warm gold")
                styleCard(.classic, "Classic")
            }
            VStack(spacing: 6) {
                Text("onb.look.label").font(OnbStyle.strong(11)).tracking(1.2).foregroundColor(OnbStyle.muted)
                HStack(spacing: 0) {
                    ForEach(Look.allCases, id: \.self) { l in lookSegment(l) }
                }
                .padding(3).background(RoundedRectangle(cornerRadius: 11).fill(Color(hex: 0xEAE4D8)))
                .frame(width: 372)
                Text(LocalizedStringKey(lookExplanation)).font(OnbStyle.body(13)).foregroundColor(OnbStyle.muted)
                    .accessibilityLabel(Text(LocalizedStringKey(lookExplanation)))
            }
        }
    }

    private var lookExplanation: String { ["onb.look.subtle", "onb.look.festive", "onb.look.lavish"][s.look.rawValue] }

    private func lookSegment(_ l: Look) -> some View {
        let sel = s.look == l
        return Button { s.look = l; s.dockLook = l } label: {
            Text(LocalizedStringKey(["Subtle", "Festive", "Lavish"][l.rawValue])).font(OnbStyle.strong(13.5)).foregroundColor(sel ? OnbStyle.ink : OnbStyle.muted)
                .frame(maxWidth: .infinity).frame(height: 30)
                .background(RoundedRectangle(cornerRadius: 9).fill(sel ? Color.white : Color.clear).shadow(color: .black.opacity(sel ? 0.1 : 0), radius: 2, y: 1))
                .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(sel ? [.isButton, .isSelected] : .isButton)
    }

    private func styleCard(_ kind: ChainStyleKind, _ name: String) -> some View {
        let sel = s.chainStyle == kind
        return Button(action: { applyOnboardingStyle(kind, to: s) }) {
            VStack(spacing: 0) {
                Image(nsImage: ChainPreview.image(kind: kind, look: s.look, dock: false, size: CGSize(width: 150, height: 84))).resizable().frame(width: 150, height: 84)
                Text(LocalizedStringKey(name)).font(OnbStyle.strong(14)).foregroundColor(OnbStyle.ink).frame(width: 150, height: 36)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(sel ? OnbStyle.red : Color(hex: 0xEADFCB), lineWidth: sel ? 3 : 1))
            .overlay(alignment: .topTrailing) {
                if sel {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                        .frame(width: 24, height: 24).background(Circle().fill(OnbStyle.red)).offset(x: 8, y: -8)
                }
            }
            .shadow(color: .black.opacity(sel ? 0.15 : 0.07), radius: sel ? 8 : 4, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(name)))
        .accessibilityAddTraits(sel ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Schritt 2, wo soll's leuchten

    private var glow: some View {
        VStack(spacing: 10) {
            heading("onb.where.title", "onb.where.sub")
            HStack(spacing: 12) {
                glowTile("Menu bar", on: $s.lightsEnabled) { AnyView(Image(nsImage: ChainPreview.image(kind: s.chainStyle, look: s.look, dock: false, size: CGSize(width: 150, height: 76))).resizable().frame(width: 150, height: 76)) }
                glowTile("Dock", on: $s.dockLights) { AnyView(Image(nsImage: ChainPreview.image(kind: s.dockStyle, look: s.dockLook, dock: true, size: CGSize(width: 150, height: 76))).resizable().frame(width: 150, height: 76)) }
                glowTile("Snow", on: $s.snowEnabled) { AnyView(snowPreview) }
            }
            #if DIRECT
            accessRow
            #endif
        }
    }

    private var snowPreview: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x7FA9DA), Color(hex: 0xDCE9F5)], startPoint: .top, endPoint: .bottom)
            SnowDots(count: 14, color: .white, opacity: 0.9)
        }
        .frame(width: 150, height: 76)
    }

    private func glowTile(_ name: String, on: Binding<Bool>, preview: () -> AnyView) -> some View {
        let isOn = on.wrappedValue
        return Button { on.wrappedValue.toggle() } label: {
            VStack(spacing: 0) {
                preview().opacity(isOn ? 1 : 0.35).frame(width: 150, height: 76).clipped()
                Text(LocalizedStringKey(name)).font(OnbStyle.strong(14)).foregroundColor(OnbStyle.ink).frame(height: 24)
                HStack(spacing: 6) {
                    ZStack(alignment: isOn ? .trailing : .leading) {
                        Capsule().fill(isOn ? Self.green : Color(hex: 0xA9A397)).frame(width: 36, height: 21)
                        Circle().fill(Color.white).frame(width: 17, height: 17).shadow(color: .black.opacity(0.25), radius: 1, y: 1).padding(.horizontal, 2)
                    }
                    .animation(.easeInOut(duration: 0.15), value: isOn)
                    Text(LocalizedStringKey(isOn ? "onb.on" : "onb.off")).font(OnbStyle.strong(13)).foregroundColor(isOn ? Color(hex: 0x1F8A3B) : OnbStyle.muted)
                }
                .frame(height: 34)
            }
            .frame(width: 150)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isOn ? Self.green : Color(hex: 0xEADFCB), lineWidth: isOn ? 3 : 1))
            .shadow(color: .black.opacity(0.07), radius: 4, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(name)))
        .accessibilityValue(Text(LocalizedStringKey(isOn ? "onb.on" : "onb.off")))
        .accessibilityAddTraits(.isToggle)
    }

    #if DIRECT
    private var accessRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("onb.access.row").font(OnbStyle.strong(13.5)).foregroundColor(OnbStyle.ink)
                Text("onb.access.sub").font(OnbStyle.body(12.5)).foregroundColor(OnbStyle.muted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if perm.granted {
                Label(LocalizedStringKey("Permission granted"), systemImage: "checkmark.circle.fill").font(OnbStyle.body(12.5)).foregroundColor(Color(hex: 0x2E7D4F))
            } else {
                Button { Permission.request(); Permission.openSystemSettings() } label: {
                    Text("onb.access.button").font(OnbStyle.strong(13)).foregroundColor(OnbStyle.ink).padding(.horizontal, 14).padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Color.white)).overlay(RoundedRectangle(cornerRadius: 9).stroke(Color(hex: 0xD9CDB8), lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .frame(width: 480)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundColor(Color(hex: 0xC9BDA6)))
        .opacity(s.dockLights ? 1 : 0.5)   // matt, wenn das Dock aus ist
    }
    #endif

    // MARK: Schritt 3, Frohe Festtage

    private var finish: some View {
        VStack(spacing: 10) {
            Image(nsImage: ChainPreview.image(kind: s.chainStyle, look: s.look, dock: false, size: CGSize(width: 440, height: 84))).resizable().frame(width: 440, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xEADFCB), lineWidth: 1))
                .accessibilityHidden(true)
            heading("onb.finish.title", nil)
            HStack(spacing: 14) {
                Image(nsImage: MenubarIcon.image(frame: 0, animated: false)).renderingMode(.template).foregroundColor(OnbStyle.ink)
                    .frame(width: 40, height: 34).background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xEDE4D2))).overlay(RoundedRectangle(cornerRadius: 8).stroke(OnbStyle.red.opacity(0.8), lineWidth: 1.5))
                    .accessibilityHidden(true)
                Text("onb.finish.hint").font(OnbStyle.body(13.5)).foregroundColor(OnbStyle.ink).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16).padding(.vertical, 10).frame(width: 420)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xEADFCB), lineWidth: 1))
            onbSwitch("Start at login", isOn: Binding(get: { login.enabled }, set: { login.set($0) }), width: 300)
        }
    }

    private func onbSwitch(_ title: String, isOn: Binding<Bool>, width: CGFloat = 300) -> some View {
        Toggle(isOn: isOn) { Text(LocalizedStringKey(title)).font(OnbStyle.medium(14)).foregroundColor(OnbStyle.ink) }
            .toggleStyle(OnbCardToggleStyle())
            .frame(width: width)
    }
}

struct SnowDots: View {
    var count = 9
    var color = OnbStyle.flake
    var opacity = 0.65
    @ObservedObject private var power = PowerStatus.shared
    @StateObject private var motion = ReduceMotionMonitor()

    var body: some View {
        let still = power.active || motion.on
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: still)) { ctx in
            Canvas { gc, size in
                let t = still ? 0 : ctx.date.timeIntervalSinceReferenceDate
                for i in 0..<count {
                    let x = stableRandom(i, 1, 2) * size.width
                    let r = 1.5 + stableRandom(i, 2, 2) * 1.5
                    let speed = 6 + stableRandom(i, 3, 2) * 8
                    let y = (stableRandom(i, 4, 2) * size.height + t * speed).truncatingRemainder(dividingBy: size.height)
                    gc.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(color.opacity(opacity)))
                }
            }
        }
    }
}

final class OnboardingController: NSObject, NSWindowDelegate {
    /// Beim Schließen die Ansicht freigeben, damit nichts (Zeitgeber, Schneepunkte) im Hintergrund weiterläuft.
    func windowWillClose(_ notification: Notification) {
        let w = window
        window = nil
        DispatchQueue.main.async { w?.contentView = nil }
    }


    private var window: NSWindow?
    private let model = OnboardingModel()
    private let settings: Settings
    private let login: LoginModel
    private let pulse: () -> Void
    var isShown: Bool { window?.isVisible ?? false }

    init(settings: Settings, login: LoginModel, pulse: @escaping () -> Void) { self.settings = settings; self.login = login; self.pulse = pulse }

    func show() {
        if let w = window, w.isVisible {   // schon offen: nur nach vorn holen
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        login.refresh()
        if window == nil {
            let view = OnboardingView(model: model, s: settings, login: login, close: { [weak self] in self?.window?.close() }, pulse: pulse)
            let host = FirstMouseHostingView(rootView: view)
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: OnboardingView.size.width, height: OnboardingView.size.height), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.contentView = host
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.isMovableByWindowBackground = false   // sonst wird ein Klick mit leichter Mausbewegung zum Fensterzug und der Schalter reagiert nicht
            w.appearance = NSAppearance(named: .aqua)
            w.backgroundColor = NSColor(srgbRed: 1, green: 0.98, blue: 0.94, alpha: 1)
            w.isReleasedWhenClosed = false
            w.title = String(localized: "onb.window")
            w.delegate = self
            window = w
        }
        model.index = 0
        if let w = window, let v = NSScreen.screens.first?.visibleFrame { w.setFrameOrigin(WindowPlacement.centeredOrigin(size: w.frame.size, visible: v)) }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

#if DEBUG
/// Rendert jeden Schritt der Einführung ohne Bildschirm in PNG-Dateien (`--render-onboarding <Ordner>`, Sprache über `-AppleLanguages "(de)"`).
enum OnboardingSnapshot {
    static func run(dir: String) {
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let lang = Locale.preferredLanguages.first?.prefix(2) ?? "en"
        let variant = AppVariant.isStore ? "store" : "direct"
        let model = OnboardingModel()
        let view = OnboardingView(model: model, s: Settings.shared, login: LoginModel(), close: {})
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: OnboardingView.size)
        let w = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        w.appearance = NSAppearance(named: .aqua)
        w.contentView = host
        func shot(_ i: Int, _ suffix: String) {
            model.index = i
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(variant)-\(lang)-\(i + 1)-\(model.steps[i])\(suffix).png"))
        }
        let st = Settings.shared
        let old = (st.lightsEnabled, st.dockLights, st.snowEnabled, st.chainStyle, st.dockStyle, st.look, st.dockLook)
        st.lightsEnabled = true; st.dockLights = true; st.snowEnabled = true
        st.chainStyle = .firColor; st.dockStyle = .firColor; st.look = .festive; st.dockLook = .festive
        for i in 0..<model.steps.count { shot(i, "") }
        st.lightsEnabled = true; st.dockLights = false; st.snowEnabled = false   // Kacheln teils aus
        shot(1, "-aus")
        st.chainStyle = .firGold; st.dockStyle = .firGold; st.look = .subtle; st.dockLook = .subtle
        shot(0, "-gold-dezent")
        (st.lightsEnabled, st.dockLights, st.snowEnabled, st.chainStyle, st.dockStyle, st.look, st.dockLook) = old
        // Die Vorschauen dürfen kein sichtbares Fenster hinterlassen
        let visible = NSApp.windows.filter { $0.isVisible }
        if !visible.isEmpty { FileHandle.standardError.write("FEHLER: \(visible.count) sichtbare Fenster nach dem Rendern der Vorschauen\n".data(using: .utf8)!); exit(3) }
    }
}
#endif
