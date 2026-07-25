import SwiftUI
import Combine

// MARK: - 主题管理器
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: AppTheme
    @Published var currentThemeType: ThemeType
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "selectedTheme"
    
    private init() {
        // 从UserDefaults读取保存的主题，默认为蓝色主题
        let savedThemeRawValue = userDefaults.string(forKey: themeKey) ?? ThemeType.blue.rawValue
        let savedThemeType = ThemeType(rawValue: savedThemeRawValue) ?? .blue
        
        self.currentThemeType = savedThemeType
        self.currentTheme = savedThemeType.theme
    }
    
    // 切换主题
    func setTheme(_ themeType: ThemeType) {
        currentThemeType = themeType
        currentTheme = themeType.theme
        
        // 保存到UserDefaults
        userDefaults.set(themeType.rawValue, forKey: themeKey)
    }
}

// MARK: - SwiftUI Environment Key
struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppTheme = BlueTheme()
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - View Extension for Theme
extension View {
    func withAppTheme() -> some View {
        ThemeWrapper(content: self)
    }
}

// MARK: - Theme Wrapper
struct ThemeWrapper<Content: View>: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let content: Content
    
    var body: some View {
        content
            .environmentObject(themeManager)
            .environment(\.theme, themeManager.currentTheme)
            .withDesignTokens()
    }
}