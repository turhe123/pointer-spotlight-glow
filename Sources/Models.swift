import AppKit
import Carbon
import Observation
import SwiftUI

/// A global keyboard shortcut expressed as a Carbon key code plus Carbon modifier mask.
struct HotKey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var display: String
}

/// Every user preference for the three effects, persisted as one JSON blob in UserDefaults.
struct EffectSettings: Codable, Equatable {
    var highlightOn = true
    var highlightColor = "FFC83D"
    var highlightOpacity = 0.35
    var highlightSize = 70.0
    var highlightFade = 0.25

    var ripplesOn = true
    var leftClickColor = "3D9BFF"
    var rightClickColor = "FF4D6D"
    var rippleOpacity = 0.9
    var rippleSize = 60.0
    var rippleDuration = 0.6

    var spotlightOn = false
    var spotlightDim = 0.65
    var spotlightRadius = 140.0
    var spotlightFade = 0.3

    var excludeFromCapture = false
    var toggleAllKey = HotKey(keyCode: UInt32(kVK_ANSI_H),
                              modifiers: UInt32(controlKey | optionKey | cmdKey), display: "⌃⌥⌘H")
    var spotlightKey = HotKey(keyCode: UInt32(kVK_ANSI_S),
                              modifiers: UInt32(controlKey | optionKey | cmdKey), display: "⌃⌥⌘S")
    /// Which effects were on before the "toggle all" hotkey switched everything off.
    var savedMask = [true, true, false]

    var anyOn: Bool { highlightOn || ripplesOn || spotlightOn }
}

/// Observable owner of `EffectSettings`; saves on every change and notifies AppKit-side listeners.
@Observable
final class SettingsStore {
    static let shared = SettingsStore()
    private static let key = "effectSettings.v1"

    var s: EffectSettings {
        didSet {
            guard s != oldValue else { return }
            if let data = try? JSONEncoder().encode(s) {
                UserDefaults.standard.set(data, forKey: Self.key)
            }
            listeners.forEach { $0(oldValue, s) }
        }
    }

    @ObservationIgnored private var listeners: [(EffectSettings, EffectSettings) -> Void] = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(EffectSettings.self, from: data) {
            s = decoded
        } else {
            s = EffectSettings()
        }
    }

    func onChange(_ listener: @escaping (EffectSettings, EffectSettings) -> Void) {
        listeners.append(listener)
    }

    /// Switches every effect off (remembering which were on), or restores the remembered set.
    func toggleAll() {
        if s.anyOn {
            s.savedMask = [s.highlightOn, s.ripplesOn, s.spotlightOn]
            s.highlightOn = false; s.ripplesOn = false; s.spotlightOn = false
        } else {
            let mask = s.savedMask.count == 3 && s.savedMask.contains(true) ? s.savedMask : [true, true, false]
            s.highlightOn = mask[0]; s.ripplesOn = mask[1]; s.spotlightOn = mask[2]
        }
    }

    func adjustSpotlightRadius(by delta: Double) {
        s.spotlightRadius = min(500, max(40, s.spotlightRadius + delta))
    }
}

/// A single click visualization: where and when it happened and which button caused it.
struct Ripple: Identifiable {
    let id = UUID()
    let location: CGPoint
    let start: Date
    let isRight: Bool
}

/// Live pointer state shared by all overlays: global location, pressed buttons and active ripples.
@Observable
final class PointerModel {
    static let shared = PointerModel()
    var location: CGPoint = NSEvent.mouseLocation
    var leftDown = false
    var rightDown = false
    var ripples: [Ripple] = []
    var clickPermission = Permissions.inputMonitoringGranted
}

/// Shortens animations when the user has "Reduce motion" enabled.
enum Motion {
    static func scaled(_ duration: Double) -> Double {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? duration * 0.35 : duration
    }
}

extension Color {
    /// Creates a color from a 6-digit RGB hex string, falling back to white on bad input.
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0xFFFFFF
        self.init(.sRGB,
                  red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    var hexString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "FFFFFF" }
        let r = Int((c.redComponent * 255).rounded()), g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
