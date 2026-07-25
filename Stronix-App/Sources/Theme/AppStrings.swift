import Foundation

private final class AppBundleLocator {}

enum AppStrings {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: Bundle(for: AppBundleLocator.self), comment: "")
    }
}
