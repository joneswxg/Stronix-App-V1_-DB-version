import SwiftUI

@main
struct Stronix_App_V1App: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var databaseState = DatabaseStartupState.preparing

    init() {
        guard !Self.isRunningUnitTests else { return }
        DispatchQueue.main.async {
            NotificationManager.shared.requestPermissionIfNeeded()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch databaseState {
                case .preparing:
                    ProgressView("正在准备本地数据库…")
                case .ready:
                    MainTabView()
                        .withAppTheme()
                case .failed(let message):
                    DatabaseStartupFailureView(
                        message: message,
                        retry: retryDatabasePreparation
                    )
                case .incompatible(let message):
                    DatabaseStartupIncompatibilityView(message: message)
                }
            }
            .task {
                guard !Self.isRunningUnitTests else { return }
                guard case .preparing = databaseState else { return }
                prepareDatabase()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            guard !Self.isRunningUnitTests else { return }
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    private static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    private func prepareDatabase() {
        runDatabasePreparation {
            DatabaseManager.shared.prepareForStartup(
                arguments: ProcessInfo.processInfo.arguments
            )
        }
    }

    private func retryDatabasePreparation() {
        runDatabasePreparation {
            DatabaseManager.shared.retryPreparation()
        }
    }

    private func runDatabasePreparation(
        _ operation: @escaping () -> DatabasePreparationResult
    ) {
        databaseState = .preparing
        Task.detached(priority: .userInitiated) {
            let result = operation()
            await MainActor.run {
                switch result {
                case .ready(let database):
                    print("✅ 数据库生命周期准备完成: \(database.databaseURL.path)")
                    databaseState = .ready
                case .recovered(let database, let failure):
                    print("⚠️ 数据库 migration 已恢复: \(database.databaseURL.path), \(failure.message)")
                    databaseState = .ready
                case .incompatible(let incompatibility):
                    print("❌ 数据库 schema 版本过新: \(incompatibility.supportedMigrationID)")
                    databaseState = .incompatible(
                        "本地数据库由较新版本的 App 创建，请更新 App 后再继续使用。"
                    )
                case .failed(let failure):
                    print("❌ 数据库生命周期准备失败: \(failure.message)")
                    databaseState = .failed(failure.message)
                case .unrecoverable(let failure):
                    print("❌ 数据库恢复失败: \(failure.restorationFailure.message)")
                    databaseState = .failed("本地数据库恢复失败，请重试或联系支持。")
                }
            }
        }
    }

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            print("📱 应用进入后台")
            TrainingSessionManager.shared.handleAppDidEnterBackground()
        case .active:
            print("📱 应用变为活跃状态")
            TrainingSessionManager.shared.handleAppDidBecomeActive()
        case .inactive:
            print("📱 应用变为非活跃状态")
        @unknown default:
            break
        }
    }
}

private enum DatabaseStartupState {
    case preparing
    case ready
    case failed(String)
    case incompatible(String)
}

private struct DatabaseStartupIncompatibilityView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("本地数据库需要更新")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

private struct DatabaseStartupFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.red)
            Text("本地数据库准备失败")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("重试", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
