# PointerSpotlightGlow — specification

**Tagline:** Spotlight your pointer with a dimmed screen, highlight ring and click ripples for demos and screen shares.

**Category:** Presentation & Cursor

**Inspired by (paid):** Mouseposé ($9.99 one-time)

**Frameworks:** SwiftUI, AppKit, CoreGraphics, ApplicationServices, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does: Mouseposé from Boinx has been the standard presenter cursor tool for years, with a spotlight, a highlighted pointer and click visualization. It is sold around 9.99 dollars and is recommended constantly for teachers, streamers and software demos. Our free clean-room version covers the main effects.

Feature set: Three independent effects. First, a pointer highlight, a soft colored circle that follows the cursor in a chosen size and color. Second, click ripples, an expanding ring on left click and a different color on right click, with a visible press indicator while the button is held. Third, a spotlight mode toggled by hotkey, where the whole screen dims and only a circle around the pointer stays bright, with scroll wheel or bracket keys adjusting radius. Settings for each effect include color, opacity, size, and fade duration. A global hotkey toggles all effects, and another toggles spotlight.

UI spec: MenuBarExtra with a cursor symbol. The menu has toggles for Highlight, Click Ripples and Spotlight, plus Settings. The Settings window uses tabs for each effect with color wells and sliders and a live preview square. A first launch sheet explains the Input Monitoring permission. Hotkey recorders sit in a General tab with launch at login. When all effects are off, the menu icon shows an outlined style.

Technical approach: Create one borderless transparent NSWindow per screen at the screen saver level, ignoring mouse events, hosting a SwiftUI Canvas driven by a model. Track the pointer with an NSEvent global monitor for mouse moved, dragged and button events, which needs Input Monitoring or Accessibility trust on current macOS, so request through CGRequestListenEventAccess and IOHIDRequestAccess equivalents, falling back to polling NSEvent mouseLocation at 60 hertz which needs no permission for position. Convert global coordinates to each screen's window space. Ripples are small model objects with a start time, animated with TimelineView and removed after the duration. Spotlight uses a full screen black fill with a radial gradient mask or a destinationOut blend circle. Hotkeys use Carbon RegisterEventHotKey. Preferences are stored with AppStorage and launch at login with SMAppService.

Edge cases and error handling: Multiple displays with different scales are handled per screen. If the pointer leaves a screen, stop drawing the ring on that overlay. If permission is denied, the highlight still works by polling and only click ripples are disabled with an explanatory note in settings. Overlays must be excluded from screen recording only if the user chooses, with a toggle for sharing type none versus read only, so the effect is visible in recordings by default. Respect reduce motion by shortening animations. Overlays rebuild on screen configuration change. About 400 lines.
