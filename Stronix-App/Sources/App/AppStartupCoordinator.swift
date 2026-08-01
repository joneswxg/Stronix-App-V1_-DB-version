import Foundation
import OSLog

protocol DatabaseStartupPreparing: AnyObject {
    func prepareForStartup(arguments: [String]) -> DatabasePreparationResult
    func retryPreparation() -> DatabasePreparationResult
}

extension DatabaseManager: DatabaseStartupPreparing {}

@MainActor
protocol PersistedSessionRestoring: AnyObject {
    func restore() async
    func discardStaleState()
}

extension UserSession: PersistedSessionRestoring {}

enum StartupPerformanceMark: String, Equatable {
    case startupEntry
    case startupUIVisible
    case databasePrepared
    case sessionRestored
    case firstInteractiveGateway
}

enum AppStartupState: Equatable {
    case preparingDatabase
    case restoringSession
    case ready
    case blocked(DatabaseStartupBlockReason)

    var permitsProtectedContent: Bool {
        self == .ready
    }
}

enum DatabaseStartupBlockReason: Equatable {
    case incompatibleSchema
    case recoverablePreparationFailure
    case unrecoverableRecoveryFailure

    var permitsRetry: Bool {
        self == .recoverablePreparationFailure
    }
}

@MainActor
final class AppStartupCoordinator: ObservableObject {
    @Published private(set) var state: AppStartupState = .preparingDatabase

    private let database: any DatabaseStartupPreparing
    private let arguments: [String]
    private let session: any PersistedSessionRestoring
    private let reportDiagnostic: @MainActor (DatabaseStartupBlockReason, String) -> Void
    private let markPerformance: @MainActor (StartupPerformanceMark) -> Void
    private var didStart = false

    init(
        database: any DatabaseStartupPreparing,
        arguments: [String],
        session: any PersistedSessionRestoring,
        reportDiagnostic: @escaping @MainActor (DatabaseStartupBlockReason, String) -> Void = AppStartupCoordinator.reportToConsole,
        markPerformance: @escaping @MainActor (StartupPerformanceMark) -> Void = AppStartupCoordinator.markToSignpost
    ) {
        self.database = database
        self.arguments = arguments
        self.session = session
        self.reportDiagnostic = reportDiagnostic
        self.markPerformance = markPerformance
    }

    func start() async {
        guard !didStart else { return }
        didStart = true
        markPerformance(.startupEntry)
        state = .preparingDatabase
        let result = await Task.detached(priority: .userInitiated) { [database, arguments] in
            database.prepareForStartup(arguments: arguments)
        }.value
        await handle(result)
    }

    func retry() async {
        guard state == .blocked(.recoverablePreparationFailure) else { return }
        state = .preparingDatabase
        let result = await Task.detached(priority: .userInitiated) { [database] in
            database.retryPreparation()
        }.value
        await handle(result)
    }

    func markStartupUIVisible() {
        markPerformance(.startupUIVisible)
    }

    private func handle(_ result: DatabasePreparationResult) async {
        markPerformance(.databasePrepared)
        switch result {
        case .ready, .recovered:
            state = .restoringSession
            await session.restore()
            markPerformance(.sessionRestored)
            markPerformance(.firstInteractiveGateway)
            state = .ready
        case .incompatible:
            block(.incompatibleSchema, result: result)
        case .failed:
            block(.recoverablePreparationFailure, result: result)
        case .unrecoverable:
            block(.unrecoverableRecoveryFailure, result: result)
        }
    }

    private func block(
        _ reason: DatabaseStartupBlockReason,
        result: DatabasePreparationResult
    ) {
        if reason != .recoverablePreparationFailure {
            session.discardStaleState()
        }
        reportDiagnostic(reason, result.diagnostic.summary)
        state = .blocked(reason)
    }

    private static let startupLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.stronix.app", category: "startup-performance")

    private static func markToSignpost(_ mark: StartupPerformanceMark) {
        startupLogger.info("Startup performance mark: \(mark.rawValue, privacy: .public)")
    }

    private static func reportToConsole(
        reason: DatabaseStartupBlockReason,
        summary: String
    ) {
        print("Database startup blocked [\(reason)]: \(summary)")
    }
}
