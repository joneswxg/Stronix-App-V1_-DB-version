@testable import Stronix

final class ResultAuthRepository: AuthRepository {
    var registerResult: Result<User, Error>
    var authenticateResult: Result<User, Error>
    var userResult: Result<User?, Error>
    private(set) var registrations: [AuthRegistration] = []
    private(set) var authenticationAttempts: [(email: String, password: String)] = []
    private(set) var requestedUserIDs: [Int] = []

    init(
        authenticatedUser: User,
        userResult: Result<User?, Error>? = nil
    ) {
        registerResult = .success(authenticatedUser)
        authenticateResult = .success(authenticatedUser)
        self.userResult = userResult ?? .success(authenticatedUser)
    }

    init(
        registerResult: Result<User, Error>,
        authenticateResult: Result<User, Error>,
        userResult: Result<User?, Error>
    ) {
        self.registerResult = registerResult
        self.authenticateResult = authenticateResult
        self.userResult = userResult
    }

    func register(_ registration: AuthRegistration) async throws -> User {
        registrations.append(registration)
        return try registerResult.get()
    }

    func authenticate(email: String, password: String) async throws -> User {
        authenticationAttempts.append((email, password))
        return try authenticateResult.get()
    }

    func user(id: Int) async throws -> User? {
        requestedUserIDs.append(id)
        return try userResult.get()
    }
}

final class RecordingSessionStore: LocalSessionStore {
    var loadedSession: LocalSessionReference?
    private(set) var savedSession: LocalSessionReference?
    var saveError: Error?
    var clearError: Error?
    private(set) var saveCallCount = 0
    private(set) var clearCallCount = 0

    func load() throws -> LocalSessionReference? { loadedSession }

    func save(_ session: LocalSessionReference) throws {
        saveCallCount += 1
        if let saveError { throw saveError }
        savedSession = session
        loadedSession = session
    }

    func clear() throws {
        clearCallCount += 1
        if let clearError { throw clearError }
        loadedSession = nil
        savedSession = nil
    }
}

final class ResultTrainingHistoryPersistence: TrainingHistoryPersisting {
    var result: Result<SaveTrainingHistoryResponse, Error>
    private(set) var requests: [SaveTrainingHistoryRequest] = []
    var onSave: () -> Void

    init(
        result: Result<SaveTrainingHistoryResponse, Error> = .success(SaveTrainingHistoryResponse(history_id: 1)),
        onSave: @escaping () -> Void = {}
    ) {
        self.result = result
        self.onSave = onSave
    }

    func saveTrainingHistory(_ request: SaveTrainingHistoryRequest) async throws -> SaveTrainingHistoryResponse {
        requests.append(request)
        onSave()
        return try result.get()
    }
}

final class ResultUserPlanWriter: UserPlanWriting {
    struct Call {
        let planID: Int
        let draft: PlanDraft
    }

    private(set) var calls: [Call] = []
    private var results: [Result<Void, Error>]
    var onWrite: () -> Void

    init(
        result: Result<Void, Error> = .success(()),
        onWrite: @escaping () -> Void = {}
    ) {
        results = [result]
        self.onWrite = onWrite
    }

    init(results: [Result<Void, Error>], onWrite: @escaping () -> Void = {}) {
        self.results = results
        self.onWrite = onWrite
    }

    func write(planID: Int, draft: PlanDraft) async throws {
        calls.append(Call(planID: planID, draft: draft))
        onWrite()
        let result = results.count > 1 ? results.removeFirst() : results[0]
        try result.get()
    }
}
