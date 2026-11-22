import SwiftUI
import UIKit

extension Color {
    /// Returns the color with saturation and brightness pushed up — used to
    /// signal "active agitation" while keeping each tank's identity hue.
    /// Going through UIColor's HSB lets us preserve the user's chosen hue
    /// (which a flat red/orange overlay wouldn't).
    func intensified(saturationBoost: CGFloat = 1.35, brightnessBoost: CGFloat = 1.08) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(
            hue: Double(h),
            saturation: Double(min(1.0, s * saturationBoost)),
            brightness: Double(min(1.0, b * brightnessBoost)),
            opacity: Double(a)
        )
    }

    /// Adaptive "tinted ink" — substitute for `.primary` text inside
    /// tank-tinted views. Light mode: deep tinted color (brightness ~0.28)
    /// where the hue clearly reads but the text still feels near-black.
    /// Dark mode: off-white (~0.96) with a hint of the hue.
    var tintedInk: Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hue: h, saturation: 0.18, brightness: 0.96, alpha: a)
                : UIColor(hue: h, saturation: 0.85, brightness: 0.28, alpha: a)
        })
    }

}

extension TimerSession {
    var tint: Color {
        Color(hex: tintHex ?? "F46453")
    }
}

struct Haptics {
    @MainActor static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        #endif
    }
    @MainActor static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
    @MainActor static func warning() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}

/// A `Label` that tints its icon red to match the text color of a
/// `Button(role: .destructive)`. SwiftUI's role styling colors the text but
/// leaves SF Symbols in the menu's default tint — this label closes that
/// gap so destructive actions look consistently destructive throughout the
/// app (icon + label both red).
struct DestructiveLabel: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.red)
        }
    }
}

extension Animation {
    static let devvy = Animation.spring(response: 0.45, dampingFraction: 0.78, blendDuration: 0.1)
    static let devvyFast = Animation.spring(response: 0.32, dampingFraction: 0.85)
    static let devvyBounce = Animation.spring(response: 0.55, dampingFraction: 0.6)
}

/// A small "now" clock that ticks every second, used by progress rings.
@MainActor
@Observable
final class HeartbeatClock {
    private(set) var now: Date = .now
    private var task: Task<Void, Never>?

    func start() {
        task?.cancel()
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 250_000_000)
                await MainActor.run { self?.now = .now }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
