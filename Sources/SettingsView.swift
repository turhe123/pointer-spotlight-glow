import AppKit
import Carbon
import ServiceManagement
import SwiftUI

/// Tabbed Settings window: one tab per effect plus General (hotkeys, login, capture, permission).
struct SettingsView: View {
    var body: some View {
        TabView {
            HighlightTab().tabItem { Label("Highlight", systemImage: "circle.fill") }
            RipplesTab().tabItem { Label("Click Ripples", systemImage: "dot.radiowaves.left.and.right") }
            SpotlightTab().tabItem { Label("Spotlight", systemImage: "light.max") }
            GeneralTab().tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 560, height: 380)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}

/// Binding that bridges a hex string setting to a SwiftUI `Color` for `ColorPicker`.
private func colorBinding(_ store: SettingsStore, _ keyPath: WritableKeyPath<EffectSettings, String>) -> Binding<Color> {
    Binding(get: { Color(hex: store.s[keyPath: keyPath]) },
            set: { store.s[keyPath: keyPath] = $0.hexString })
}

/// Labeled slider row with a formatted value readout.
private struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var format: (Double) -> String = { String(format: "%.0f", $0) }

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: $value, in: range)
                Text(format(value)).monospacedDigit().frame(width: 52, alignment: .trailing)
            }
        }
    }
}

private let percent: (Double) -> String = { "\(Int(($0 * 100).rounded()))%" }
private let seconds: (Double) -> String = { String(format: "%.2fs", $0) }

/// Effect tab layout: a form on the left and the live preview square on the right.
private struct EffectTab<Controls: View>: View {
    let kind: PreviewSquare.Kind
    @ViewBuilder let controls: Controls

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Form { controls }.formStyle(.grouped)
            VStack {
                PreviewSquare(kind: kind)
                Text("Live preview").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.top, 20).padding(.trailing, 16)
        }
    }
}

private struct HighlightTab: View {
    @Bindable private var store = SettingsStore.shared
    var body: some View {
        EffectTab(kind: .highlight) {
            Toggle("Show pointer highlight", isOn: $store.s.highlightOn)
            ColorPicker("Color", selection: colorBinding(store, \.highlightColor), supportsOpacity: false)
            SliderRow(title: "Opacity", value: $store.s.highlightOpacity, range: 0.05...1, format: percent)
            SliderRow(title: "Size", value: $store.s.highlightSize, range: 20...200)
            SliderRow(title: "Fade", value: $store.s.highlightFade, range: 0...1.5, format: seconds)
        }
    }
}

private struct RipplesTab: View {
    @Bindable private var store = SettingsStore.shared
    private let model = PointerModel.shared
    var body: some View {
        EffectTab(kind: .ripples) {
            Toggle("Show click ripples", isOn: $store.s.ripplesOn)
            if !model.clickPermission {
                PermissionNote()
            }
            ColorPicker("Left click", selection: colorBinding(store, \.leftClickColor), supportsOpacity: false)
            ColorPicker("Right click", selection: colorBinding(store, \.rightClickColor), supportsOpacity: false)
            SliderRow(title: "Opacity", value: $store.s.rippleOpacity, range: 0.1...1, format: percent)
            SliderRow(title: "Size", value: $store.s.rippleSize, range: 20...160)
            SliderRow(title: "Duration", value: $store.s.rippleDuration, range: 0.2...2, format: seconds)
        }
    }
}

private struct SpotlightTab: View {
    @Bindable private var store = SettingsStore.shared
    var body: some View {
        EffectTab(kind: .spotlight) {
            Toggle("Spotlight mode", isOn: $store.s.spotlightOn)
            SliderRow(title: "Dimming", value: $store.s.spotlightDim, range: 0.1...0.95, format: percent)
            SliderRow(title: "Radius", value: $store.s.spotlightRadius, range: 40...500)
            SliderRow(title: "Fade", value: $store.s.spotlightFade, range: 0...1.5, format: seconds)
            Text("While the spotlight is on, press [ and ] or hold ⌥ and scroll to change its radius.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// Explains why click ripples are unavailable and links to the relevant privacy pane.
private struct PermissionNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Click ripples need Input Monitoring permission", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("The highlight and spotlight keep working without it. Enable PointerSpotlightGlow in System Settings › Privacy & Security › Input Monitoring.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Request Access") { Permissions.request() }
                Button("Open System Settings") { Permissions.openSystemSettings() }
            }
        }
    }
}

private struct GeneralTab: View {
    @Bindable private var store = SettingsStore.shared
    private let model = PointerModel.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Hotkeys") {
                LabeledContent("Toggle all effects") { HotKeyRecorder(hotKey: $store.s.toggleAllKey) }
                LabeledContent("Toggle spotlight") { HotKeyRecorder(hotKey: $store.s.spotlightKey) }
            }
            Section("Behavior") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Hide effects from screen recordings", isOn: $store.s.excludeFromCapture)
                Text("Off by default so viewers of your recording or share see the effects.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Permission") {
                if model.clickPermission {
                    Label("Input Monitoring granted — click ripples active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    PermissionNote()
                }
            }
            HStack {
                Button("Support / Donate ❤️") { openDonationPage() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Could not update login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

/// Button that records the next modifier+key combination pressed as a global hotkey.
struct HotKeyRecorder: View {
    @Binding var hotKey: HotKey
    @State private var monitor: Any?

    var body: some View {
        Button(monitor == nil ? hotKey.display : "Type shortcut… (esc cancels)") {
            monitor == nil ? startRecording() : stopRecording()
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) { stopRecording(); return nil }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard !flags.isDisjoint(with: [.command, .option, .control]) else { NSSound.beep(); return nil }
            var carbon: UInt32 = 0, symbols = ""
            if flags.contains(.control) { carbon |= UInt32(controlKey); symbols += "⌃" }
            if flags.contains(.option) { carbon |= UInt32(optionKey); symbols += "⌥" }
            if flags.contains(.shift) { carbon |= UInt32(shiftKey); symbols += "⇧" }
            if flags.contains(.command) { carbon |= UInt32(cmdKey); symbols += "⌘" }
            let key = event.charactersIgnoringModifiers?.uppercased() ?? "?"
            hotKey = HotKey(keyCode: UInt32(event.keyCode), modifiers: carbon, display: symbols + key)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

/// Animated sample of one effect over a fake desktop, driven by the current settings.
struct PreviewSquare: View {
    enum Kind { case highlight, ripples, spotlight }
    let kind: Kind
    private let store = SettingsStore.shared

    var body: some View {
        let s = store.s
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let rect = CGRect(origin: .zero, size: size)
                ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: [.indigo, .teal]),
                                                           startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
                for row in 0..<6 {
                    let y = 20 + Double(row) * 24
                    ctx.fill(Path(roundedRect: CGRect(x: 16, y: y, width: size.width - 32 - Double(row % 3) * 30, height: 8),
                                  cornerRadius: 4), with: .color(.white.opacity(0.6)))
                }
                let center = CGPoint(x: size.width / 2 + cos(t * 0.8) * 30, y: size.height / 2 + sin(t * 0.8) * 30)
                // Scale real-world pixel sizes down so they fit the small square.
                var scaled = s
                scaled.highlightSize *= 0.5; scaled.rippleSize *= 0.5; scaled.spotlightRadius *= 0.3
                switch kind {
                case .highlight:
                    EffectRenderer.highlight(&ctx, center: center, s: scaled)
                case .ripples:
                    let cycle = max(0.2, Motion.scaled(s.rippleDuration)) + 0.4
                    let phase = t.truncatingRemainder(dividingBy: cycle * 2)
                    let isRight = phase >= cycle
                    let progress = phase.truncatingRemainder(dividingBy: cycle) / (cycle - 0.4)
                    if progress < 1 { EffectRenderer.ripple(&ctx, center: center, progress: progress, isRight: isRight, s: scaled) }
                    if progress < 0.3 { EffectRenderer.press(&ctx, center: center, isRight: isRight, s: scaled) }
                case .spotlight:
                    EffectRenderer.spotlight(&ctx, size: size, center: center, s: scaled)
                }
                if let cursor = ctx.resolveSymbol(id: 0) { ctx.draw(cursor, at: CGPoint(x: center.x + 4, y: center.y + 7)) }
            } symbols: {
                Image(systemName: "cursorarrow").font(.system(size: 16)).foregroundStyle(.white).tag(0)
            }
        }
        .frame(width: 180, height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
    }
}
