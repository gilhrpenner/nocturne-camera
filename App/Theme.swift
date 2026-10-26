import SwiftUI

enum Theme {
    static let background = Color(hex: 0x111827)
    static let panel = Color(hex: 0x1C2738)
    static let text = Color(hex: 0xE8EDF4)
    static let muted = Color(hex: 0xADBDCD)
    static let accent = Color(hex: 0xDDA8B4)
    static let success = Color(hex: 0x95CBB7)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255, opacity: 1)
    }
}
