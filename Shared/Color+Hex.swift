import SwiftUI

extension Color {
    /// Parse `#RRGGBB` or `#RRGGBBAA` (with or without leading `#`) into a
    /// SwiftUI sRGB color. Invalid input falls back to opaque white.
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b, a: Double
        switch s.count {
        case 6:
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8) & 0xFF) / 255
            b = Double(v & 0xFF) / 255
            a = 1
        case 8:
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8) & 0xFF) / 255
            a = Double(v & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1; a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
