import Foundation
import Security

struct AuthSession: Equatable {
    let displayName: String
    let accessToken: String
    let refreshToken: String?

    var accessTokenRedacted: String {
        guard accessToken.count > 12 else {
            return "stored-token"
        }
        return "\(accessToken.prefix(6))...\(accessToken.suffix(4))"
    }
}

protocol AuthSessionStoreProtocol: AnyObject {
    var currentSession: AuthSession? { get }
    var isAuthenticated: Bool { get }
    var accessToken: String? { get }
    func restore()
    func saveSession(accessToken: String, refreshToken: String?, displayName: String?)
    func clear()
}

final class AuthSessionStore: ObservableObject, AuthSessionStoreProtocol {
    @Published private(set) var currentSession: AuthSession?

    private let displayNameKey = "auth.displayName"
    private let tokenStore: AuthTokenStore

    init(tokenStore: AuthTokenStore = KeychainTokenStore()) {
        self.tokenStore = tokenStore
        restore()
    }

    var isAuthenticated: Bool {
        currentSession != nil
    }

    var accessToken: String? {
        currentSession?.accessToken
    }

    func restore() {
        guard let accessToken = tokenStore.read(account: .accessToken) else {
            return
        }
        let refreshToken = tokenStore.read(account: .refreshToken)
        let displayName = UserDefaults.standard.string(forKey: displayNameKey) ?? "로그인 사용자"
        currentSession = AuthSession(displayName: displayName, accessToken: accessToken, refreshToken: refreshToken)
    }

    func saveSession(accessToken: String, refreshToken: String?, displayName: String?) {
        let normalizedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = normalizedDisplayName?.isEmpty == false ? normalizedDisplayName! : "로그인 사용자"

        tokenStore.save(accessToken, account: .accessToken)
        if let refreshToken, !refreshToken.isEmpty {
            tokenStore.save(refreshToken, account: .refreshToken)
        } else {
            tokenStore.delete(account: .refreshToken)
        }
        UserDefaults.standard.set(resolvedDisplayName, forKey: displayNameKey)
        currentSession = AuthSession(displayName: resolvedDisplayName, accessToken: accessToken, refreshToken: refreshToken)
    }

    func clear() {
        tokenStore.delete(account: .accessToken)
        tokenStore.delete(account: .refreshToken)
        UserDefaults.standard.removeObject(forKey: displayNameKey)
        currentSession = nil
    }
}

enum KeychainAccount: String {
    case accessToken = "nugusauce.access-token"
    case refreshToken = "nugusauce.refresh-token"
}

protocol AuthTokenStore {
    @discardableResult
    func save(_ value: String, account: KeychainAccount) -> Bool
    func read(account: KeychainAccount) -> String?
    @discardableResult
    func delete(account: KeychainAccount) -> Bool
}

struct KeychainTokenStore: AuthTokenStore {
    private let service = "com.nugusauce.ios.auth"

    @discardableResult
    func save(_ value: String, account: KeychainAccount) -> Bool {
        let data = Data(value.utf8)
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    func read(account: KeychainAccount) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    @discardableResult
    func delete(account: KeychainAccount) -> Bool {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private func baseQuery(account: KeychainAccount) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue
        ]
    }
}
