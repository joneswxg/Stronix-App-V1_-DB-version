import SwiftUI

enum AuthFieldKind {
    case text
    case email
    case password
    case number
}

struct AuthTextField: View {
    @Binding var text: String
    let label: LocalizedStringKey
    let placeholder: LocalizedStringKey
    let symbol: String
    let kind: AuthFieldKind
    let error: LocalizedStringKey?

    @Environment(\.designTokens) private var tokens

    init(
        text: Binding<String>,
        label: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        symbol: String,
        kind: AuthFieldKind = .text,
        error: LocalizedStringKey? = nil
    ) {
        _text = text
        self.label = label
        self.placeholder = placeholder
        self.symbol = symbol
        self.kind = kind
        self.error = error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Text(label)
                .font(DesignTokens.Typography.label)
                .foregroundStyle(tokens.contentPrimary)

            HStack(spacing: DesignTokens.Spacing.medium) {
                Image(systemName: symbol)
                    .foregroundStyle(tokens.contentSecondary)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                field
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(tokens.contentPrimary)
                    .frame(minHeight: DesignTokens.Metric.minimumTapSize)
            }
            .padding(.horizontal, DesignTokens.Spacing.large)
            .background(tokens.controlSurface)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.control, style: .continuous)
                    .stroke(error == nil ? tokens.border : tokens.error, lineWidth: DesignTokens.Metric.borderWidth)
            }

            if let error {
                Text(error)
                    .font(DesignTokens.Typography.feedback)
                    .foregroundStyle(tokens.error)
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        switch kind {
        case .text:
            TextField(placeholder, text: $text)
        case .email:
            TextField(placeholder, text: $text)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)
        case .password:
            SecureField(placeholder, text: $text)
                .textContentType(.password)
        case .number:
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
        }
    }
}

enum AuthActionStyle {
    case primary
    case secondary
}

struct AuthActionButton: View {
    let title: LocalizedStringKey
    let loadingTitle: LocalizedStringKey
    let style: AuthActionStyle
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void

    @Environment(\.designTokens) private var tokens

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.small) {
                if isLoading {
                    ProgressView()
                        .tint(foreground)
                        .accessibilityHidden(true)
                }
                Text(isLoading ? loadingTitle : title)
                    .font(DesignTokens.Typography.action)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: DesignTokens.Metric.minimumTapSize)
            .padding(.vertical, DesignTokens.Spacing.small)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous))
        }
        .disabled(!isEnabled || isLoading)
        .accessibilityValue(isLoading ? Text("auth.accessibility.loading") : Text(""))
    }

    private var foreground: Color {
        switch style {
        case .primary: isEnabled && !isLoading ? tokens.onPrimary : tokens.disabledContent
        case .secondary: tokens.primary
        }
    }

    private var background: Color {
        switch style {
        case .primary: isEnabled && !isLoading ? tokens.primary : tokens.disabledFill
        case .secondary: Color.clear
        }
    }
}

#Preview("Auth controls") {
    VStack(spacing: DesignTokens.Spacing.large) {
        AuthTextField(text: .constant("member@example.com"), label: "auth.field.email.label", placeholder: "auth.field.email.placeholder", symbol: "envelope", kind: .email)
        AuthTextField(text: .constant("different"), label: "auth.field.passwordConfirmation.label", placeholder: "auth.field.passwordConfirmation.placeholder", symbol: "lock", kind: .password, error: "auth.feedback.passwordMismatch")
        AuthActionButton(title: "auth.action.login", loadingTitle: "auth.login.loading", style: .primary, isEnabled: true, isLoading: false, action: {})
        AuthActionButton(title: "auth.action.login", loadingTitle: "auth.login.loading", style: .primary, isEnabled: false, isLoading: false, action: {})
        AuthActionButton(title: "auth.action.login", loadingTitle: "auth.login.loading", style: .primary, isEnabled: true, isLoading: true, action: {})
    }
    .padding()
    .withAppTheme()
}
