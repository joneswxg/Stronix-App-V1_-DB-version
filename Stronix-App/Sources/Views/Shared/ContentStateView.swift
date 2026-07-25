import SwiftUI

enum ContentStateKind {
    case loading
    case empty
    case error
}

struct ContentStateView: View {
    let kind: ContentStateKind
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    @Environment(\.designTokens) private var tokens

    init(
        kind: ContentStateKind,
        symbol: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.kind = kind
        self.symbol = symbol
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
            VStack(spacing: DesignTokens.Spacing.large) {
                if kind == .loading {
                    ProgressView()
                        .tint(tokens.primary)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(kind == .error ? tokens.error : tokens.contentSecondary)
                        .accessibilityHidden(true)
                }

                VStack(spacing: DesignTokens.Spacing.small) {
                    Text(title)
                        .font(DesignTokens.Typography.action)
                        .foregroundStyle(tokens.contentPrimary)

                    Text(message)
                        .font(DesignTokens.Typography.supporting)
                        .foregroundStyle(tokens.contentSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .accessibilityElement(children: .combine)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(DesignTokens.Typography.action)
                        .foregroundStyle(tokens.onPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: DesignTokens.Metric.minimumTapSize)
                }
                .background(tokens.primary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.action, style: .continuous))
                .frame(maxWidth: 240)
            }
        }
        .padding(DesignTokens.Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
