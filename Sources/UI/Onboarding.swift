import SwiftUI
import AppKit
import CoreText

/// Farben und Schriften der Einführung (SPEC §6 Punkt 5), unabhängig vom System-Erscheinungsbild.
enum OnbStyle {
    static let cream = Color(hex: 0xFFFAF0), snow = Color(hex: 0xF3EAD8), flake = Color(hex: 0x9CC3DD)
    static let red = Color(hex: 0xD8432F), wine = Color(hex: 0x86241A), ink = Color(hex: 0x2B363F), muted = Color(hex: 0x5D6A72), dotOff = Color(hex: 0xE7DCCB)

    static func title(_ size: CGFloat = 30) -> Font { .custom("MountainsofChristmas-Bold", size: size) }
    static func body(_ size: CGFloat = 13.5) -> Font { .custom("Poppins-Regular", size: size) }
    static func strong(_ size: CGFloat = 14) -> Font { .custom("Poppins-SemiBold", size: size) }

    /// Eingebettete Schriften für diesen Prozess registrieren (einmal).
    static let registerFonts: Void = {
        for name in ["MountainsofChristmas-Bold", "Poppins-Regular", "Poppins-Medium", "Poppins-SemiBold"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
        }
    }()
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
    var startStorm: () -> Void

    init(model: OnboardingModel, s: Settings, login: LoginModel, close: @escaping () -> Void, startStorm: @escaping () -> Void) {
        _ = OnbStyle.registerFonts
        self.model = model; self.s = s; self.login = login; self.close = close; self.startStorm = startStorm
        #if DIRECT
        self.perm = PermissionModel()
        #endif
    }

    var body: some View {
        ZStack {
            OnbStyle.cream
            SnowDots().accessibilityHidden(true).zIndex(0)
            VStack(spacing: 0) {
                Image(nsImage: NSImage(named: "garland-header") ?? NSImage()).resizable().frame(width: 560, height: 96).accessibilityHidden(true)
                Spacer(minLength: 0)
            }
            VStack {
                Spacer()
                ZStack(alignment: .bottom) {
                    Ellipse().fill(OnbStyle.snow).frame(width: 720, height: 90).offset(y: 48).frame(width: 560, height: 100, alignment: .bottom)
                    HStack {
                        tree
                        Spacer()
                        tree.scaleEffect(x: -1)
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: 100, alignment: .bottom)
            }
            .accessibilityHidden(true)
            VStack(spacing: 0) {
                Spacer().frame(height: 108)
                // Inhalt im freien Raum zentriert, Punkte und Buttonzeile darunter an fester Stelle
                VStack(spacing: 6) { content }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                dots.frame(height: 12)
                Spacer().frame(height: 16)
                buttons.frame(height: 44)
                Spacer().frame(height: 26)
            }
            .padding(.horizontal, 40)
        }
        .frame(width: 560, height: 440)
        .background(Button(action: close) { EmptyView() }.keyboardShortcut(.cancelAction).opacity(0).accessibilityHidden(true))
        .environment(\.colorScheme, .light)
        .clipped()
    }

    private var tree: some View {
        Image(nsImage: NSImage(named: "tree") ?? NSImage()).resizable().frame(width: 56, height: 76)
    }

    private var dots: some View {
        HStack(spacing: 10) {
            ForEach(0..<model.steps.count, id: \.self) { i in
                Circle().fill(i == model.index ? OnbStyle.red : OnbStyle.dotOff).frame(width: 9, height: 9)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onb.progress"))
        .accessibilityValue(Text("\(model.index + 1) / \(model.steps.count)"))
    }

    private var buttons: some View {
        HStack {
            if model.index > 0 { textButton("onb.back") { model.back() } }
            if !model.isLast { textButton("onb.skip") { close() } }
            Spacer()
            Button(action: { model.isLast ? close() : model.next() }) {
                Text(LocalizedStringKey(model.isLast ? "onb.go" : "onb.next"))
                    .font(OnbStyle.strong(15)).foregroundColor(.white).padding(.horizontal, 30).padding(.vertical, 10)
                    .background(Capsule().fill(OnbStyle.wine))
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 56)   // zwischen den Bäumchen
    }

    private func textButton(_ key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(LocalizedStringKey(key)).font(OnbStyle.strong(14)).foregroundColor(OnbStyle.muted).padding(.horizontal, 10).padding(.vertical, 8) }
            .buttonStyle(.plain)
    }

    private func heading(_ key: String, _ body: String) -> some View {
        VStack(spacing: 6) {
            Text(LocalizedStringKey(key)).font(OnbStyle.title()).foregroundColor(OnbStyle.red).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Text(LocalizedStringKey(body)).font(OnbStyle.body()).foregroundColor(OnbStyle.muted).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 440)
        }
    }

    @ViewBuilder private var content: some View {
        switch model.step {
        case .welcome:
            heading("onb.welcome.title", "onb.welcome.body")
            HStack(spacing: 14) {
                card(.firColor, "Fir, colorful", "style-firColor")
                card(.firGold, "Fir, warm gold", "style-firGold")
                card(.classic, "Classic", "style-classic")
            }
            .padding(.top, 8)
        case .reach:
            illustrationMenuBar
            heading("onb.reach.title", "onb.reach.body")
        case .snow:
            illustrationWindow
            heading("onb.snow.title", "onb.snow.body")
            Button(action: startStorm) {
                Text("onb.storm").font(OnbStyle.strong(13)).foregroundColor(OnbStyle.wine).padding(.horizontal, 18).padding(.vertical, 7)
                    .background(Capsule().fill(Color(hex: 0xF6E2DA)))
            }.buttonStyle(.plain)
        case .access:
            #if DIRECT
            Image(systemName: "dock.rectangle").font(.system(size: 40)).foregroundColor(OnbStyle.red).accessibilityHidden(true)
            heading("onb.access.title", "onb.access.body")
            HStack(spacing: 14) {
                Button(action: { Permission.request(); Permission.openSystemSettings() }) {
                    Text("Open System Settings").font(OnbStyle.strong(13)).foregroundColor(OnbStyle.wine).padding(.horizontal, 18).padding(.vertical, 7)
                        .background(Capsule().fill(Color(hex: 0xF6E2DA)))
                }.buttonStyle(.plain)
                Label(LocalizedStringKey(perm.granted ? "Permission granted" : "Permission not granted"), systemImage: perm.granted ? "checkmark.circle.fill" : "circle")
                    .font(OnbStyle.body(13)).foregroundColor(perm.granted ? Color(hex: 0x2E7D4F) : OnbStyle.muted)
            }
            .onAppear { perm.refresh() }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in perm.refresh() }
            #endif
        case .done:
            Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundColor(OnbStyle.red).accessibilityHidden(true)
            heading("onb.done.title", "onb.done.body")
            Toggle(isOn: Binding(get: { login.enabled }, set: { login.set($0) })) {
                Text("Start at login").font(OnbStyle.body(14)).foregroundColor(OnbStyle.ink)
            }
            .toggleStyle(.switch).tint(OnbStyle.red).fixedSize()
        }
    }

    private func card(_ kind: ChainStyleKind, _ name: String, _ image: String) -> some View {
        let selected = s.chainStyle == kind
        return Button(action: { applyOnboardingStyle(kind, to: s) }) {
            VStack(spacing: 0) {
                Image(nsImage: NSImage(named: image) ?? NSImage()).resizable().scaledToFill().frame(width: 144, height: 56).clipped()
                Text(LocalizedStringKey(name)).font(OnbStyle.strong(14)).foregroundColor(OnbStyle.ink).frame(width: 144, height: 38)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? OnbStyle.red : Color.clear, lineWidth: 3))
            .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(name)))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var illustrationMenuBar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(OnbStyle.ink).frame(width: 300, height: 26)
            HStack(spacing: 14) {
                Circle().fill(Color.white.opacity(0.5)).frame(width: 9, height: 9)
                Capsule().fill(Color.white.opacity(0.5)).frame(width: 40, height: 6)
                Spacer()
                ZStack {
                    Circle().stroke(OnbStyle.red, lineWidth: 2).frame(width: 24, height: 24)
                    Image(nsImage: MenubarIcon.image(frame: 0, animated: false)).renderingMode(.template).foregroundColor(.white)
                }
                Circle().fill(Color.white.opacity(0.5)).frame(width: 9, height: 9)
            }
            .padding(.horizontal, 12).frame(width: 300)
        }
        .accessibilityHidden(true)
    }

    private var illustrationWindow: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 8).fill(Color(hex: 0xDCE6EC)).frame(width: 150, height: 56).offset(y: 8)
                .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
            HStack(spacing: 4) { ForEach(0..<3) { _ in Circle().fill(Color.white.opacity(0.9)).frame(width: 7, height: 7) } }
                .frame(width: 150, alignment: .leading).padding(.leading, 12).offset(y: 24)
            // Schneeschicht auf der Oberkante, wie die echte Schicht der App
            ZStack {
                Capsule().fill(Color.white).frame(width: 156, height: 9)
                Circle().fill(Color.white).frame(width: 18, height: 18).offset(x: -40, y: -3)
                Circle().fill(Color.white).frame(width: 24, height: 24).offset(x: 6, y: -5)
                Circle().fill(Color.white).frame(width: 15, height: 15).offset(x: 48, y: -2)
            }
            .shadow(color: OnbStyle.flake.opacity(0.5), radius: 1, y: 1).offset(y: 6)
            Group {
                Circle().frame(width: 4, height: 4).offset(x: -50, y: -4)
                Circle().frame(width: 3, height: 3).offset(x: -12, y: -14)
                Circle().frame(width: 5, height: 5).offset(x: 34, y: -8)
                Circle().frame(width: 3, height: 3).offset(x: 62, y: -16)
            }
            .foregroundColor(OnbStyle.flake)
        }
        .frame(width: 170, height: 70)
        .scaleEffect(0.8).frame(height: 54)
        .accessibilityHidden(true)
    }
}

/// Ruhig fallende hellblaue Punkte, im Sparmodus oder bei "Bewegung reduzieren" statisch.
struct SnowDots: View {
    var body: some View {
        let still = PowerStatus.shared.active || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        TimelineView(.animation(minimumInterval: still ? nil : 1.0 / 20)) { ctx in
            Canvas { gc, size in
                let t = still ? 0 : ctx.date.timeIntervalSinceReferenceDate
                for i in 0..<9 {
                    let x = stableRandom(i, 1, 2) * size.width
                    let r = 1.5 + stableRandom(i, 2, 2) * 1.5
                    let speed = 6 + stableRandom(i, 3, 2) * 8
                    let y = (stableRandom(i, 4, 2) * size.height + t * speed).truncatingRemainder(dividingBy: size.height)
                    gc.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(OnbStyle.flake.opacity(0.65)))
                }
            }
        }
    }
}

final class OnboardingController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let model = OnboardingModel()
    private let settings: Settings
    private let login: LoginModel
    private let startStorm: () -> Void
    var isShown: Bool { window?.isVisible ?? false }

    init(settings: Settings, login: LoginModel, startStorm: @escaping () -> Void) { self.settings = settings; self.login = login; self.startStorm = startStorm }

    func show() {
        if window == nil {
            let view = OnboardingView(model: model, s: settings, login: login, close: { [weak self] in self?.window?.close() }, startStorm: startStorm)
            let host = NSHostingView(rootView: view)
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 440), styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.contentView = host
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.isMovableByWindowBackground = true
            w.appearance = NSAppearance(named: .aqua)
            w.backgroundColor = NSColor(srgbRed: 1, green: 0.98, blue: 0.94, alpha: 1)
            w.isReleasedWhenClosed = false
            w.title = String(localized: "onb.window")
            w.delegate = self
            window = w
        }
        model.index = 0
        window?.center()
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
        let view = OnboardingView(model: model, s: Settings.shared, login: LoginModel(), close: {}, startStorm: {})
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 560, height: 440)
        let w = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        w.appearance = NSAppearance(named: .aqua)
        w.contentView = host
        for i in 0..<model.steps.count {
            model.index = i
            host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/\(variant)-\(lang)-\(i + 1)-\(model.steps[i]).png"))
        }
    }
}
#endif
