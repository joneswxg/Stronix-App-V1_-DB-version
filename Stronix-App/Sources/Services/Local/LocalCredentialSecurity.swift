import CommonCrypto
import Foundation
import Security

protocol PasswordCredentialing {
    func makeCredential(password: String) throws -> String
    func verify(password: String, storedCredential: String) throws -> PasswordCredentialVerification
}

enum PasswordCredentialVerification: Equatable {
    case valid
    case validLegacy
    case invalid
}

enum LocalCredentialError: Error {
    case randomGenerationFailed
    case derivationFailed
    case malformedCredential
}

struct PBKDF2PasswordCredentialing: PasswordCredentialing {
    private let iterations: UInt32
    private let saltLength: Int
    private let keyLength: Int

    init(iterations: UInt32 = 310_000, saltLength: Int = 16, keyLength: Int = 32) {
        self.iterations = iterations
        self.saltLength = saltLength
        self.keyLength = keyLength
    }

    func makeCredential(password: String) throws -> String {
        var salt = [UInt8](repeating: 0, count: saltLength)
        guard SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt) == errSecSuccess else {
            throw LocalCredentialError.randomGenerationFailed
        }
        let key = try deriveKey(password: password, salt: salt, iterations: iterations, keyLength: keyLength)
        return "pbkdf2-sha256$v=1$i=\(iterations)$l=\(keyLength)$s=\(Data(salt).base64EncodedString())$h=\(Data(key).base64EncodedString())"
    }

    func verify(password: String, storedCredential: String) throws -> PasswordCredentialVerification {
        if storedCredential.hasPrefix("pbkdf2-sha256$") {
            let credential = try parse(storedCredential)
            let actual = try deriveKey(
                password: password,
                salt: [UInt8](credential.salt),
                iterations: credential.iterations,
                keyLength: credential.key.count
            )
            return constantTimeEquals(actual, [UInt8](credential.key)) ? .valid : .invalid
        }

        guard let decoded = Data(base64Encoded: storedCredential, options: []),
              let legacyPassword = String(data: decoded, encoding: .utf8) else {
            return .invalid
        }
        return constantTimeEquals(Array(password.utf8), Array(legacyPassword.utf8)) ? .validLegacy : .invalid
    }

    private func deriveKey(password: String, salt: [UInt8], iterations: UInt32, keyLength: Int) throws -> [UInt8] {
        guard !password.isEmpty, !salt.isEmpty, iterations >= 100_000, iterations <= 10_000_000, keyLength == 32 else {
            throw LocalCredentialError.malformedCredential
        }
        var derivedKey = [UInt8](repeating: 0, count: keyLength)
        let status = password.withCString { passwordBytes in
            salt.withUnsafeBufferPointer { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes,
                    password.utf8.count,
                    saltBytes.baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    iterations,
                    &derivedKey,
                    keyLength
                )
            }
        }
        guard status == kCCSuccess else {
            throw LocalCredentialError.derivationFailed
        }
        return derivedKey
    }

    private func parse(_ value: String) throws -> ParsedCredential {
        let fields = value.split(separator: "$").map(String.init)
        guard fields.count == 6, fields[0] == "pbkdf2-sha256" else {
            throw LocalCredentialError.malformedCredential
        }
        var parameters: [String: String] = [:]
        for field in fields.dropFirst() {
            let pair = field.split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2, parameters[pair[0]] == nil else {
                throw LocalCredentialError.malformedCredential
            }
            parameters[pair[0]] = pair[1]
        }
        guard parameters["v"] == "1",
              let iterations = parameters["i"].flatMap(UInt32.init),
              let keyLength = parameters["l"].flatMap(Int.init),
              let salt = parameters["s"].flatMap({ Data(base64Encoded: $0, options: []) }),
              let key = parameters["h"].flatMap({ Data(base64Encoded: $0, options: []) }),
              salt.count >= 16,
              key.count == 32,
              keyLength == 32,
              iterations >= 100_000,
              iterations <= 10_000_000 else {
            throw LocalCredentialError.malformedCredential
        }
        return ParsedCredential(iterations: iterations, salt: salt, key: key)
    }

    private func constantTimeEquals(_ left: [UInt8], _ right: [UInt8]) -> Bool {
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for (leftByte, rightByte) in zip(left, right) {
            difference |= leftByte ^ rightByte
        }
        return difference == 0
    }

    private struct ParsedCredential {
        let iterations: UInt32
        let salt: Data
        let key: Data
    }
}

struct LocalSessionReference: Equatable {
    let userID: Int
}

protocol LocalSessionStore {
    func load() throws -> LocalSessionReference?
    func save(_ session: LocalSessionReference) throws
    func clear() throws
}

enum LocalSessionStoreError: Error {
    case unexpectedStatus(OSStatus)
    case malformedReference
}

final class KeychainLocalSessionStore: LocalSessionStore {
    private let service: String
    private let account = "local-auth-session"

    init(service: String = Bundle.main.bundleIdentifier ?? "com.stronix.app") {
        self.service = service
    }

    func load() throws -> LocalSessionReference? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let rawID = String(data: data, encoding: .utf8), let userID = Int(rawID), userID > 0 else {
            if status == errSecSuccess { try clear() }
            if status == errSecSuccess { throw LocalSessionStoreError.malformedReference }
            throw LocalSessionStoreError.unexpectedStatus(status)
        }
        return LocalSessionReference(userID: userID)
    }

    func save(_ session: LocalSessionReference) throws {
        let data = Data(String(session.userID).utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw LocalSessionStoreError.unexpectedStatus(updateStatus)
        }
        var add = query
        add.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw LocalSessionStoreError.unexpectedStatus(addStatus)
        }
    }

    func clear() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LocalSessionStoreError.unexpectedStatus(status)
        }
    }
}

final class InMemoryLocalSessionStore: LocalSessionStore {
    private var session: LocalSessionReference?

    func load() throws -> LocalSessionReference? { session }
    func save(_ session: LocalSessionReference) throws { self.session = session }
    func clear() throws { session = nil }
}
