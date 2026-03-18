import SwiftUI

extension Color {
    static let appBg          = Color(hex: "#2C4347")
    static let appBgSecondary = Color(hex: "#3A5559")
    static let appCard        = Color(hex: "#476A6F")
    static let appAccent      = Color(hex: "#519E8A")
    static let appText        = Color(hex: "#F0F2E8")
    static let appCoral       = Color(hex: "#ECBEB4")
    static let appMint        = Color(hex: "#7EB09B")
    static let appPurple      = Color(hex: "#C5C9A4")
    static let appBorder      = Color(hex: "#4A7A6D")

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
