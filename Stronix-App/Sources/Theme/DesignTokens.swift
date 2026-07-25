import SwiftUI

struct DesignTokens {
    let theme: AppTheme
    let colorScheme: ColorScheme

    var primary: Color { theme.primary }
    var onPrimary: Color { theme.onPrimary }
    var canvas: Color { colorScheme == .dark ? Color(red: 0.07, green: 0.08, blue: 0.10) : Color(red: 0.95, green: 0.96, blue: 0.98) }
    var surface: Color { colorScheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.16) : Color.white }
    var controlSurface: Color { colorScheme == .dark ? Color(red: 0.17, green: 0.18, blue: 0.22) : Color.white }
    var contentPrimary: Color { colorScheme == .dark ? Color.white : Color(red: 0.08, green: 0.09, blue: 0.12) }
    var contentSecondary: Color { colorScheme == .dark ? Color(red: 0.70, green: 0.73, blue: 0.79) : Color(red: 0.34, green: 0.38, blue: 0.45) }
    var border: Color { colorScheme == .dark ? Color.white.opacity(0.20) : Color.black.opacity(0.14) }
    var disabledFill: Color { colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.12) }
    var disabledContent: Color { colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.45) }
    var error: Color { colorScheme == .dark ? Color(red: 1, green: 0.52, blue: 0.49) : Color(red: 0.73, green: 0.10, blue: 0.10) }
    var warning: Color { theme.warning }
    var errorSurface: Color { colorScheme == .dark ? Color(red: 0.28, green: 0.10, blue: 0.10) : Color(red: 1, green: 0.93, blue: 0.93) }
    var shadow: Color { Color.black.opacity(colorScheme == .dark ? 0.30 : 0.10) }

    enum Typography {
        static let screenTitle = Font.largeTitle.bold()
        static let pageTitle = Font.title.bold()
        static let action = Font.headline
        static let body = Font.body
        static let label = Font.subheadline.weight(.medium)
        static let supporting = Font.subheadline
        static let feedback = Font.footnote
    }

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 40
    }

    enum Radius {
        static let control: CGFloat = 12
        static let action: CGFloat = 16
    }

    enum Metric {
        static let minimumTapSize: CGFloat = 44
        static let borderWidth: CGFloat = 1
    }
}

private struct DesignTokensKey: EnvironmentKey {
    static let defaultValue = DesignTokens(theme: BlueTheme(), colorScheme: .light)
}

extension EnvironmentValues {
    var designTokens: DesignTokens {
        get { self[DesignTokensKey.self] }
        set { self[DesignTokensKey.self] = newValue }
    }
}

struct DesignTokenProvider<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content.environment(\.designTokens, DesignTokens(theme: theme, colorScheme: colorScheme))
    }
}

extension View {
    func withDesignTokens() -> some View {
        DesignTokenProvider { self }
    }
}
