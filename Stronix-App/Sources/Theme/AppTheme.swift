import SwiftUI

// MARK: - 主题协议
protocol AppTheme {
    var primary: Color { get }
    var secondary: Color { get }
    var accent: Color { get }
    var background: Color { get }
    var surface: Color { get }
    var onPrimary: Color { get }
    var onSecondary: Color { get }
    var onBackground: Color { get }
    var onSurface: Color { get }
    var success: Color { get }
    var warning: Color { get }
    var error: Color { get }
    var disabled: Color { get }
    var shadow: Color { get }
}

// MARK: - 蓝色主题（当前默认主题）
struct BlueTheme: AppTheme {
    let primary = Color.blue
    let secondary = Color.gray
    let accent = Color.blue
    let background = Color(white: 0.95)
    let surface = Color.white
    let onPrimary = Color.white
    let onSecondary = Color.white
    let onBackground = Color.black
    let onSurface = Color.black
    let success = Color.green
    let warning = Color.orange
    let error = Color.red
    let disabled = Color.gray
    let shadow = Color.black.opacity(0.1)
}

// MARK: - 深蓝主题（新增主题）
struct DarkBlueTheme: AppTheme {
    let primary = Color(red: 0.1, green: 0.2, blue: 0.4)
    let secondary = Color.gray
    let accent = Color(red: 0.1, green: 0.2, blue: 0.4)
    let background = Color(white: 0.95)
    let surface = Color.white
    let onPrimary = Color.white
    let onSecondary = Color.white
    let onBackground = Color.black
    let onSurface = Color.black
    let success = Color.green
    let warning = Color.orange
    let error = Color.red
    let disabled = Color.gray
    let shadow = Color.black.opacity(0.1)
}

// MARK: - 主题类型枚举
enum ThemeType: String, CaseIterable {
    case blue = "蓝色"
    case darkBlue = "深蓝"
    
    var theme: AppTheme {
        switch self {
        case .blue:
            return BlueTheme()
        case .darkBlue:
            return DarkBlueTheme()
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}