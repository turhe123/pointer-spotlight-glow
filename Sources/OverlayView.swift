import SwiftUI

/// Stateless drawing routines shared by the screen overlays and the settings preview.
enum EffectRenderer {
    static func spotlight(_ ctx: inout GraphicsContext, size: CGSize, center: CGPoint?, s: EffectSettings) {
        ctx.drawLayer { layer in
            layer.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(s.spotlightDim)))
            guard let center else { return }
            let outer = s.spotlightRadius * 1.15
            layer.blendMode = .destinationOut
            layer.fill(Path(ellipseIn: CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2)),
                       with: .radialGradient(Gradient(stops: [.init(color: .black, location: 0),
                                                              .init(color: .black, location: 0.85),
                                                              .init(color: .clear, location: 1)]),
                                             center: center, startRadius: 0, endRadius: outer))
        }
    }

    static func highlight(_ ctx: inout GraphicsContext, center: CGPoint, s: EffectSettings) {
        let r = s.highlightSize / 2
        let circle = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        let color = Color(hex: s.highlightColor)
        ctx.fill(circle, with: .color(color.opacity(s.highlightOpacity)))
        ctx.stroke(circle, with: .color(color.opacity(min(1, s.highlightOpacity + 0.3))), lineWidth: 2)
    }

    /// Draws one ripple at `progress` (0...1) of its lifetime.
    static func ripple(_ ctx: inout GraphicsContext, center: CGPoint, progress: Double, isRight: Bool, s: EffectSettings) {
        let t = min(1, max(0, progress))
        let eased = 1 - pow(1 - t, 3)
        let r = 6 + eased * s.rippleSize
        let color = Color(hex: isRight ? s.rightClickColor : s.leftClickColor)
        let ring = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ctx.stroke(ring, with: .color(color.opacity((1 - t) * s.rippleOpacity)), lineWidth: 3 + 3 * (1 - t))
    }

    static func press(_ ctx: inout GraphicsContext, center: CGPoint, isRight: Bool, s: EffectSettings) {
        let r = 11.0
        let dot = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        let color = Color(hex: isRight ? s.rightClickColor : s.leftClickColor)
        ctx.fill(dot, with: .color(color.opacity(s.rippleOpacity * 0.45)))
        ctx.stroke(dot, with: .color(color.opacity(s.rippleOpacity)), lineWidth: 2)
    }
}

/// Full-screen overlay for one display: converts global pointer coordinates into this
/// screen's space and layers the spotlight, highlight and ripple effects.
struct OverlayView: View {
    let screenFrame: CGRect
    private let model = PointerModel.shared
    private let store = SettingsStore.shared

    private func local(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x - screenFrame.minX, y: screenFrame.maxY - p.y)
    }

    private func isOnScreen(_ p: CGPoint) -> Bool {
        p.x >= screenFrame.minX && p.x <= screenFrame.maxX && p.y >= screenFrame.minY && p.y <= screenFrame.maxY
    }

    var body: some View {
        let s = store.s
        let pointer: CGPoint? = isOnScreen(model.location) ? local(model.location) : nil
        ZStack {
            Canvas { ctx, size in
                EffectRenderer.spotlight(&ctx, size: size, center: pointer, s: s)
            }
            .opacity(s.spotlightOn ? 1 : 0)
            .animation(.easeInOut(duration: Motion.scaled(s.spotlightFade)), value: s.spotlightOn)

            Canvas { ctx, _ in
                if let pointer { EffectRenderer.highlight(&ctx, center: pointer, s: s) }
            }
            .opacity(s.highlightOn ? 1 : 0)
            .animation(.easeInOut(duration: Motion.scaled(s.highlightFade)), value: s.highlightOn)

            if s.ripplesOn {
                TimelineView(.animation(paused: model.ripples.isEmpty)) { timeline in
                    Canvas { ctx, _ in
                        let duration = max(0.05, Motion.scaled(s.rippleDuration))
                        for ripple in model.ripples where isOnScreen(ripple.location) {
                            let progress = timeline.date.timeIntervalSince(ripple.start) / duration
                            EffectRenderer.ripple(&ctx, center: local(ripple.location), progress: progress,
                                                  isRight: ripple.isRight, s: s)
                        }
                        if let pointer, model.leftDown || model.rightDown {
                            EffectRenderer.press(&ctx, center: pointer, isRight: model.rightDown, s: s)
                        }
                    }
                }
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
        .allowsHitTesting(false)
    }
}
