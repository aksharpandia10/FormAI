import SwiftUI

enum Theme {
    static let background = Color(hex: "#F5F5F0")
    static let primary = Color(hex: "#1B2B5E")
    static let accent = Color(hex: "#4A6CF7")
    static let textPrimary = Color(hex: "#1A1A1A")
    static let textSecondary = Color(hex: "#6B6B6B")
    static let cardBackground = Color.white
    static let cardSelected = Color(hex: "#1B2B5E")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
