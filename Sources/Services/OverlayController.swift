import AppKit
import SwiftUI

/// Owns one transparent, click-through overlay window per display and rebuilds them
/// whenever the screen configuration changes.
final class OverlayController {
    private var windows: [NSWindow] = []
    private var screenObserver: NSObjectProtocol?

    init() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.rebuild() }
        SettingsStore.shared.onChange { [weak self] old, new in
            if old.excludeFromCapture != new.excludeFromCapture { self?.applySharingType() }
        }
        rebuild()
    }

    deinit {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map(makeWindow)
        applySharingType()
        windows.forEach { $0.orderFrontRegardless() }
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.setFrame(screen.frame, display: false)
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: OverlayView(screenFrame: screen.frame))
        return window
    }

    /// Overlays are visible in recordings by default; the user can opt to hide them from capture.
    private func applySharingType() {
        let type: NSWindow.SharingType = SettingsStore.shared.s.excludeFromCapture ? .none : .readOnly
        windows.forEach { $0.sharingType = type }
    }
}
