import AppKit
import ApplicationServices
import CoreGraphics

/// Checks and requests the Input Monitoring / Accessibility trust needed to observe clicks globally.
enum Permissions {
    static var inputMonitoringGranted: Bool {
        CGPreflightListenEventAccess() || AXIsProcessTrusted()
    }

    /// Triggers the system prompts; macOS shows each only once, later calls just return the status.
    static func request() {
        _ = CGRequestListenEventAccess()
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let link = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        if let url = URL(string: link) { NSWorkspace.shared.open(url) }
    }
}
