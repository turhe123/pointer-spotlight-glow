import AppKit
import Carbon
import SwiftUI

/// Opens the project's donation page in the default browser.
func openDonationPage() {
    NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
}

/// Menu-bar-only entry point: a MenuBarExtra with effect toggles plus a Settings window.
@main
struct PointerSpotlightGlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
        } label: {
            MenuBarIcon()
        }
        Settings {
            SettingsView()
        }
    }
}

/// Menu bar symbol; switches to an outlined style when every effect is off.
struct MenuBarIcon: View {
    private let store = SettingsStore.shared
    var body: some View {
        Image(systemName: store.s.anyOn ? "cursorarrow.rays" : "cursorarrow")
    }
}

/// Items of the menu bar menu: effect toggles, settings, donation and quit.
struct MenuContent: View {
    @Bindable private var store = SettingsStore.shared

    var body: some View {
        Toggle("Highlight", isOn: $store.s.highlightOn)
        Toggle("Click Ripples", isOn: $store.s.ripplesOn)
        Toggle("Spotlight", isOn: $store.s.spotlightOn)
        Divider()
        Button(store.s.anyOn ? "Turn All Effects Off (\(store.s.toggleAllKey.display))"
                             : "Turn Effects On (\(store.s.toggleAllKey.display))") { store.toggleAll() }
        Divider()
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        Button("Support / Donate ❤️") { openDonationPage() }
        Divider()
        Button("Quit PointerSpotlightGlow") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// Wires up overlays, pointer tracking, global hotkeys and the first-launch permission sheet.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum HotKeyID: UInt32 { case toggleAll = 1, spotlight, shrink, grow }

    private var overlays: OverlayController?
    private let tracker = PointerTracker()
    private var welcomeWindow: NSWindow?
    private let store = SettingsStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlays = OverlayController()
        tracker.start()
        registerHotKeys()
        store.onChange { [weak self] old, new in
            if old.toggleAllKey != new.toggleAllKey || old.spotlightKey != new.spotlightKey
                || old.spotlightOn != new.spotlightOn {
                self?.registerHotKeys()
            }
        }
        if !UserDefaults.standard.bool(forKey: "didShowWelcome") { showWelcome() }
    }

    private func registerHotKeys() {
        let hk = HotKeyManager.shared
        let s = store.s
        hk.register(id: HotKeyID.toggleAll.rawValue, keyCode: s.toggleAllKey.keyCode,
                    modifiers: s.toggleAllKey.modifiers) { [weak self] in self?.store.toggleAll() }
        hk.register(id: HotKeyID.spotlight.rawValue, keyCode: s.spotlightKey.keyCode,
                    modifiers: s.spotlightKey.modifiers) { [weak self] in self?.store.s.spotlightOn.toggle() }
        // Bracket keys resize the spotlight, but are only captured while it is visible.
        if s.spotlightOn {
            hk.register(id: HotKeyID.shrink.rawValue, keyCode: UInt32(kVK_ANSI_LeftBracket), modifiers: 0) {
                [weak self] in self?.store.adjustSpotlightRadius(by: -20)
            }
            hk.register(id: HotKeyID.grow.rawValue, keyCode: UInt32(kVK_ANSI_RightBracket), modifiers: 0) {
                [weak self] in self?.store.adjustSpotlightRadius(by: 20)
            }
        } else {
            hk.unregister(id: HotKeyID.shrink.rawValue)
            hk.unregister(id: HotKeyID.grow.rawValue)
        }
    }

    private func showWelcome() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Welcome to PointerSpotlightGlow"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: WelcomeView { [weak self] in
            UserDefaults.standard.set(true, forKey: "didShowWelcome")
            self?.welcomeWindow?.close()
            self?.welcomeWindow = nil
        })
        window.center()
        welcomeWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

/// First-launch explanation of the Input Monitoring permission used for click ripples.
struct WelcomeView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("PointerSpotlightGlow", systemImage: "cursorarrow.rays")
                .font(.title2.bold())
            Text("Highlight your pointer, visualize clicks and spotlight parts of the screen during demos, lessons and screen shares. Everything lives in the menu bar.")
            Text("Permission for click ripples").font(.headline)
            Text("To see your clicks system-wide, macOS needs to grant **Input Monitoring** (or Accessibility). PointerSpotlightGlow only watches mouse buttons and scrolling — never keystrokes — and nothing leaves your Mac.")
            Text("Without it, the highlight and spotlight still work; only click ripples are disabled.")
                .foregroundStyle(.secondary)
            Spacer()
            HStack {
                Button("Support / Donate ❤️") { openDonationPage() }
                Spacer()
                Button("Not Now") { onDone() }
                Button("Grant Permission") {
                    Permissions.request()
                    onDone()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460, height: 380)
    }
}
