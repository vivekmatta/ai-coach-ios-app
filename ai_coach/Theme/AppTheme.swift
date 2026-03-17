import SwiftUI

extension Color {
    static let appBg          = Color(hex: "#001514")
    static let appBgSecondary = Color(hex: "#021e1c")
    static let appCard        = Color(hex: "#042b28")
    static let appAccent      = Color(hex: "#456990")
    static let appText        = Color(hex: "#D7D9CE")
    static let appCoral       = Color(hex: "#eb5e55")
    static let appMint        = Color(hex: "#e4fde1")
    static let appPurple      = Color(hex: "#c0a9b0")
    static let appBorder      = Color(hex: "#0a3d38")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

enum AppFont {
    static let title   = Font.system(size: 22, weight: .bold)
    static let heading = Font.system(size: 17, weight: .semibold)
    static let body    = Font.system(size: 14, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let mono    = Font.system(size: 13, weight: .regular, design: .monospaced)
}

enum AppRadius {
    static let card:   CGFloat = 16
    static let badge:  CGFloat = 8
    static let input:  CGFloat = 12
}
