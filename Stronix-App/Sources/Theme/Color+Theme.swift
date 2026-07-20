import SwiftUI

// MARK: - Color Extension for Theme
extension Color {
    // 主题颜色的便捷访问方法
    static func themed(_ keyPath: KeyPath<AppTheme, Color>) -> Color {
        return ThemeManager.shared.currentTheme[keyPath: keyPath]
    }
    
    // 常用主题颜色的静态属性
    static var themePrimary: Color {
        return ThemeManager.shared.currentTheme.primary
    }
    
    static var themeSecondary: Color {
        return ThemeManager.shared.currentTheme.secondary
    }
    
    static var themeAccent: Color {
        return ThemeManager.shared.currentTheme.accent
    }
    
    static var themeBackground: Color {
        return ThemeManager.shared.currentTheme.background
    }
    
    static var themeSurface: Color {
        return ThemeManager.shared.currentTheme.surface
    }
    
    static var themeOnPrimary: Color {
        return ThemeManager.shared.currentTheme.onPrimary
    }
    
    static var themeOnSecondary: Color {
        return ThemeManager.shared.currentTheme.onSecondary
    }
    
    static var themeOnBackground: Color {
        return ThemeManager.shared.currentTheme.onBackground
    }
    
    static var themeOnSurface: Color {
        return ThemeManager.shared.currentTheme.onSurface
    }
    
    static var themeSuccess: Color {
        return ThemeManager.shared.currentTheme.success
    }
    
    static var themeWarning: Color {
        return ThemeManager.shared.currentTheme.warning
    }
    
    static var themeError: Color {
        return ThemeManager.shared.currentTheme.error
    }
    
    static var themeDisabled: Color {
        return ThemeManager.shared.currentTheme.disabled
    }
    
    static var themeShadow: Color {
        return ThemeManager.shared.currentTheme.shadow
    }
}

// MARK: - Environment-based Theme Colors
// 这些方法需要在View的body中使用，因为它们依赖于Environment
struct ThemeColors {
    let theme: AppTheme
    
    init(_ theme: AppTheme) {
        self.theme = theme
    }
    
    var primary: Color { theme.primary }
    var secondary: Color { theme.secondary }
    var accent: Color { theme.accent }
    var background: Color { theme.background }
    var surface: Color { theme.surface }
    var onPrimary: Color { theme.onPrimary }
    var onSecondary: Color { theme.onSecondary }
    var onBackground: Color { theme.onBackground }
    var onSurface: Color { theme.onSurface }
    var success: Color { theme.success }
    var warning: Color { theme.warning }
    var error: Color { theme.error }
    var disabled: Color { theme.disabled }
    var shadow: Color { theme.shadow }
}

// MARK: - View Extension for accessing theme colors
extension View {
    func themeColors(_ theme: AppTheme) -> ThemeColors {
        return ThemeColors(theme)
    }
}