import AppKit

/// Feeds `PointerModel`: polls the pointer position at 60 Hz (no permission needed) and listens
/// for global button / scroll events (needs Input Monitoring) to create click ripples.
final class PointerTracker {
    private let model = PointerModel.shared
    private let store = SettingsStore.shared
    private var timer: Timer?
    private var monitors: [Any] = []
    private var ticks = 0

    func start() {
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        installMonitors()
    }

    /// Re-installs event monitors, e.g. after the user granted permission.
    func installMonitors() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .scrollWheel]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] in self?.handle($0) }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func tick() {
        ticks += 1
        if ticks % 120 == 0 {
            let granted = Permissions.inputMonitoringGranted
            if granted != model.clickPermission {
                model.clickPermission = granted
                if granted { installMonitors() }
            }
        }
        guard store.s.anyOn else { return }
        let location = NSEvent.mouseLocation
        if location != model.location { model.location = location }
        if !model.ripples.isEmpty {
            let lifetime = Motion.scaled(store.s.rippleDuration)
            let now = Date()
            model.ripples.removeAll { now.timeIntervalSince($0.start) > lifetime }
        }
    }

    private func handle(_ event: NSEvent) {
        let location = NSEvent.mouseLocation
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            let isRight = event.type == .rightMouseDown
            if isRight { model.rightDown = true } else { model.leftDown = true }
            guard store.s.ripplesOn else { return }
            model.location = location
            model.ripples.append(Ripple(location: location, start: Date(), isRight: isRight))
        case .leftMouseUp:
            model.leftDown = false
        case .rightMouseUp:
            model.rightDown = false
        case .scrollWheel:
            // Option + scroll resizes the spotlight without hijacking normal scrolling.
            guard store.s.spotlightOn, event.modifierFlags.contains(.option) else { return }
            store.adjustSpotlightRadius(by: -event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : 8))
        default:
            break
        }
    }
}
