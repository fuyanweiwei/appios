import SwiftUI

// ====== 与安卓 ui/theme 对齐：色板 + 强调色 + 主题模式 ======

enum ThemeColors {
    // Light
    static let lightPrimary = Color(hex: 0x4299E1)
    static let lightBackground = Color(hex: 0xF3F4F6)
    static let lightSurface = Color.white
    static let lightOnBackground = Color(hex: 0x191B21)
    static let lightSurfaceVariant = Color(hex: 0xE7E9F2)
    static let lightOnSurfaceVariant = Color(hex: 0x44474F)
    static let lightOutline = Color(hex: 0xC5C8D4)
    static let lightOutlineVariant = Color(hex: 0xE5E7EF)

    // Dark
    static let darkPrimary = Color(hex: 0xAEC6FF)
    static let darkBackground = Color(hex: 0x101319)
    static let darkSurface = Color(hex: 0x16191F)
    static let darkOnBackground = Color(hex: 0xE2E2E9)
    static let darkSurfaceVariant = Color(hex: 0x23262F)
    static let darkOnSurfaceVariant = Color(hex: 0xC5C7D1)
    static let darkOutline = Color(hex: 0x8E919C)
    static let darkOutlineVariant = Color(hex: 0x3A3D47)
}

/// 主题色预设（与网站风格一致的可选强调色）
struct AccentPreset: Identifiable, Equatable {
    let name: String
    let color: Color
    var id: String { name }

    init(_ name: String, _ color: Color) {
        self.name = name
        self.color = color
    }
}

let AccentPresets: [AccentPreset] = [
    AccentPreset("网站蓝", Color(hex: 0x4299E1)),
    AccentPreset("紫罗兰", Color(hex: 0x7C4DFF)),
    AccentPreset("翡翠绿", Color(hex: 0x00BFA5)),
    AccentPreset("珊瑚橙", Color(hex: 0xFF7043)),
    AccentPreset("玫红", Color(hex: 0xEC407A)),
]

/// 当前主题的语义色（Material colorScheme 的 SwiftUI 等价）
struct AppPalette {
    let isDark: Bool
    let accent: Color

    var primary: Color { accent }
    var onPrimary: Color { .white }
    var primaryContainer: Color { accent.opacity(0.15) }
    var onPrimaryContainer: Color { accent.opacity(0.85) }
    var background: Color { isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground }
    var surface: Color { isDark ? ThemeColors.darkSurface : ThemeColors.lightSurface }
    var onBackground: Color { isDark ? ThemeColors.darkOnBackground : ThemeColors.lightOnBackground }
    var surfaceVariant: Color { isDark ? ThemeColors.darkSurfaceVariant : ThemeColors.lightSurfaceVariant }
    var onSurfaceVariant: Color { isDark ? ThemeColors.darkOnSurfaceVariant : ThemeColors.lightOnSurfaceVariant }
    var outline: Color { isDark ? ThemeColors.darkOutline : ThemeColors.lightOutline }
    var outlineVariant: Color { isDark ? ThemeColors.darkOutlineVariant : ThemeColors.lightOutlineVariant }
    var secondaryContainer: Color { isDark ? Color(hex: 0x424759) : Color(hex: 0xDFE3F1) }
    var onSecondaryContainer: Color { isDark ? Color(hex: 0xDFE3F1) : Color(hex: 0x181C28) }
    var tertiary: Color { isDark ? Color(hex: 0x82D5C8) : Color(hex: 0x00897B) }
    var errorContainer: Color { isDark ? Color(hex: 0x5C1A1A) : Color(hex: 0xFDE7E7) }
    var onErrorContainer: Color { isDark ? Color(hex: 0xFFC9C9) : Color(hex: 0x8C1D1D) }

    static func of(dark: Bool, accentIndex: Int) -> AppPalette {
        AppPalette(isDark: dark, accent: AccentPresets[safe: accentIndex]?.color ?? AccentPresets[0].color)
    }
}

private extension Array where Element == AccentPreset {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = AppPalette.of(dark: false, accentIndex: 0)
}

extension EnvironmentValues {
    var palette: AppPalette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0
        )
    }
}
