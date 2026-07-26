import Foundation

protocol AuthenticationOperating {
    func register(_ registration: AuthRegistration) async throws -> User
    func login(email: String, password: String) async throws -> User
    func restoreSession() async throws -> User?
    func logout() async throws
}

extension AuthenticationUseCases: AuthenticationOperating {}

protocol CurrentUserProviding: AnyObject {
    var currentUser: User? { get }
    var currentUserID: Int? { get }
}

protocol UserScopedStateResetting: AnyObject {
    func resetUserScopedState()
}

enum UserSessionState: Equatable {
    case restoring
    case unauthenticated
    case authenticated(User)

    static func == (lhs: UserSessionState, rhs: UserSessionState) -> Bool {
        switch (lhs, rhs) {
        case (.restoring, .restoring), (.unauthenticated, .unauthenticated):
            return true
        case let (.authenticated(left), .authenticated(right)):
            return left.id == right.id
        default:
            return false
        }
    }
}

final class CurrentUserContext: CurrentUserProviding {
    static let shared = CurrentUserContext()

    private let lock = NSLock()
    private var user: User?

    private init() {}

    var currentUser: User? {
        lock.withLock { user }
    }

    var currentUserID: Int? {
        lock.withLock { user?.id }
    }

    func update(_ user: User?) {
        lock.withLock { self.user = user }
    }
}

private final class WeakUserScopedResetter {
    weak var value: (any UserScopedStateResetting)?

    init(_ value: any UserScopedStateResetting) {
        self.value = value
    }
}

@MainActor
final class UserSession: ObservableObject, CurrentUserProviding {
    @Published private(set) var state: UserSessionState = .restoring
    @Published private(set) var scopeID = 0

    private let operations: any AuthenticationOperating
    private var resetters: [WeakUserScopedResetter]
    private var operationGeneration = 0
    private var currentOperationID: UUID?
    private var cancelCurrentOperation: (() -> Void)?

    init(
        operations: any AuthenticationOperating,
        resetters: [any UserScopedStateResetting] = []
    ) {
        self.operations = operations
        self.resetters = resetters.map(WeakUserScopedResetter.init)
    }

    var currentUser: User? {
        guard case .authenticated(let user) = state else { return nil }
        return user
    }

    var currentUserID: Int? { currentUser?.id }
    var isAuthenticated: Bool { currentUser != nil }

    func registerResetter(_ resetter: any UserScopedStateResetting) {
        resetters.removeAll { $0.value == nil }
        resetters.append(WeakUserScopedResetter(resetter))
    }

    func restore() async {
        let generation = beginOperation()
        state = .restoring
        do {
            let user = try await runOperation { try await self.operations.restoreSession() }
            guard generation == operationGeneration else { return }
            transition(to: user.map(UserSessionState.authenticated) ?? .unauthenticated)
        } catch is CancellationError {
            return
        } catch {
            guard generation == operationGeneration else { return }
            transition(to: .unauthenticated)
        }
    }

    func discardStaleState() {
        _ = beginOperation()
        transition(to: .unauthenticated)
    }

    func login(email: String, password: String) async throws {
        let generation = beginOperation()
        do {
            let user = try await runOperation { try await self.operations.login(email: email, password: password) }
            guard generation == operationGeneration else { return }
            transition(to: .authenticated(user))
        } catch is CancellationError {
            return
        }
    }

    func register(_ registration: AuthRegistration) async throws {
        let generation = beginOperation()
        do {
            let user = try await runOperation { try await self.operations.register(registration) }
            guard generation == operationGeneration else { return }
            transition(to: .authenticated(user))
        } catch is CancellationError {
            return
        }
    }

    func logout() async throws {
        let generation = beginOperation()
        do {
            try await runOperation { try await self.operations.logout() }
            guard generation == operationGeneration else { return }
            transition(to: .unauthenticated)
        } catch is CancellationError {
            return
        }
    }

    private func beginOperation() -> Int {
        cancelCurrentOperation?()
        currentOperationID = nil
        operationGeneration += 1
        return operationGeneration
    }

    private func runOperation<T>(
        _ operation: @escaping @MainActor () async throws -> T
    ) async throws -> T {
        let operationID = UUID()
        let task = Task { @MainActor in try await operation() }
        currentOperationID = operationID
        cancelCurrentOperation = { task.cancel() }
        defer {
            if currentOperationID == operationID {
                currentOperationID = nil
                cancelCurrentOperation = nil
            }
        }
        return try await task.value
    }

    private func transition(to newState: UserSessionState) {
        let oldUserID = currentUserID
        let newUserID: Int?
        if case .authenticated(let user) = newState {
            newUserID = user.id
        } else {
            newUserID = nil
        }
        if oldUserID != newUserID, oldUserID != nil {
            resetters.forEach { $0.value?.resetUserScopedState() }
            scopeID += 1
        }
        let newUser: User?
        if case .authenticated(let user) = newState {
            newUser = user
        } else {
            newUser = nil
        }
        CurrentUserContext.shared.update(newUser)
        state = newState
    }
}
