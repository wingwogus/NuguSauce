import Foundation
import Security

struct AuthSession: Equatable {
    let memberId: Int?
    let nickname: String?
    let displayName: String
    let profileImageUrl: String?
    let accessToken: String
    let refreshToken: String?
    let profileSetupRequired: Bool

    init(
        displayName: String,
        accessToken: String,
        refreshToken: String?,
        memberId: Int? = nil,
        nickname: String? = nil,
        profileImageUrl: String? = nil,
        profileSetupRequired: Bool = false
    ) {
        self.memberId = memberId
        self.nickname = nickname
        self.displayName = displayName
        self.profileImageUrl = profileImageUrl
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.profileSetupRequired = profileSetupRequired
    }

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
    @discardableResult
    func saveSession(accessToken: String, refreshToken: String?, displayName: String?) -> Bool
    func updateMemberProfile(_ member: MemberProfileDTO)
    func clear()
}

enum AuthSessionPersistenceFailure: Equatable {
    case emptyAccessToken
    case profileSetupIncomplete
    case accessTokenSaveFailed
    case refreshTokenSaveFailed
    case refreshTokenDeleteFailed

    var message: String {
        "로그인 세션을 안전하게 저장하지 못했어요. 다시 시도해주세요."
    }
}

final class AuthSessionStore: ObservableObject, AuthSessionStoreProtocol {
    @Published private(set) var currentSession: AuthSession?
    @Published private(set) var persistenceFailure: AuthSessionPersistenceFailure?

    private let displayNameKey = "auth.displayName"
    private let memberIdKey = "auth.memberId"
    private let nicknameKey = "auth.nickname"
    private let profileImageUrlKey = "auth.profileImageUrl"
    private let profileSetupRequiredKey = "auth.profileSetupRequired"
    private let tokenStore: AuthTokenStore
    private let userDefaults: UserDefaults

    init(tokenStore: AuthTokenStore = KeychainTokenStore(), userDefaults: UserDefaults = .standard) {
        self.tokenStore = tokenStore
        self.userDefaults = userDefaults
        restore()
    }

    var isAuthenticated: Bool {
        currentSession?.profileSetupRequired == false
    }

    var accessToken: String? {
        guard isAuthenticated else {
            return nil
        }
        return currentSession?.accessToken
    }

    var requiresProfileSetup: Bool {
        currentSession?.profileSetupRequired == true
    }

    func restore() {
        guard let accessToken = tokenStore.read(account: .accessToken) else {
            return
        }
        let refreshToken = tokenStore.read(account: .refreshToken)
        let displayName = userDefaults.string(forKey: displayNameKey) ?? "로그인 사용자"
        let memberId = userDefaults.object(forKey: memberIdKey) as? Int
        let nickname = userDefaults.string(forKey: nicknameKey)
        let profileImageUrl = userDefaults.string(forKey: profileImageUrlKey)
        let profileSetupRequired = (userDefaults.object(forKey: profileSetupRequiredKey) as? Bool) ?? false
        guard !profileSetupRequired else {
            rollbackFailedSave()
            return
        }
        currentSession = AuthSession(
            displayName: displayName,
            accessToken: accessToken,
            refreshToken: refreshToken,
            memberId: memberId,
            nickname: nickname,
            profileImageUrl: profileImageUrl,
            profileSetupRequired: profileSetupRequired
        )
    }

    @discardableResult
    func saveSession(accessToken: String, refreshToken: String?, displayName: String?) -> Bool {
        persistenceFailure = nil

        guard !accessToken.isEmpty else {
            return failSave(.emptyAccessToken)
        }

        let normalizedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDisplayName = normalizedDisplayName?.isEmpty == false ? normalizedDisplayName! : "로그인 사용자"
        let persistedRefreshToken = refreshToken?.isEmpty == false ? refreshToken : nil

        guard tokenStore.save(accessToken, account: .accessToken) else {
            return failSave(.accessTokenSaveFailed)
        }

        if let persistedRefreshToken {
            guard tokenStore.save(persistedRefreshToken, account: .refreshToken) else {
                return failSave(.refreshTokenSaveFailed)
            }
        } else if !tokenStore.delete(account: .refreshToken) {
            return failSave(.refreshTokenDeleteFailed)
        }

        userDefaults.set(resolvedDisplayName, forKey: displayNameKey)
        clearPersistedMemberProfile()
        currentSession = AuthSession(displayName: resolvedDisplayName, accessToken: accessToken, refreshToken: persistedRefreshToken)
        return true
    }

    @discardableResult
    func saveSession(accessToken: String, refreshToken: String?, member: MemberProfileDTO) -> Bool {
        let profileSetupRequired = member.profileSetupRequired ?? ((member.nickname ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        guard !profileSetupRequired else {
            return failSave(.profileSetupIncomplete)
        }
        guard saveSession(accessToken: accessToken, refreshToken: refreshToken, displayName: member.displayName) else {
            return false
        }
        updateMemberProfile(member)
        return true
    }

    func updateMemberProfile(_ member: MemberProfileDTO) {
        guard let session = currentSession else {
            return
        }
        let profileSetupRequired = member.profileSetupRequired ?? ((member.nickname ?? "").isEmpty)
        persistMemberProfile(member, profileSetupRequired: profileSetupRequired)
        currentSession = AuthSession(
            displayName: member.displayName,
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            memberId: member.id,
            nickname: member.nickname,
            profileImageUrl: member.profileImageUrl,
            profileSetupRequired: profileSetupRequired
        )
    }

    func clear() {
        persistenceFailure = nil
        tokenStore.delete(account: .accessToken)
        tokenStore.delete(account: .refreshToken)
        userDefaults.removeObject(forKey: displayNameKey)
        clearPersistedMemberProfile()
        currentSession = nil
    }

    private func failSave(_ failure: AuthSessionPersistenceFailure) -> Bool {
        persistenceFailure = failure
        rollbackFailedSave()
        return false
    }

    private func rollbackFailedSave() {
        tokenStore.delete(account: .accessToken)
        tokenStore.delete(account: .refreshToken)
        userDefaults.removeObject(forKey: displayNameKey)
        clearPersistedMemberProfile()
        currentSession = nil
    }

    private func persistMemberProfile(_ member: MemberProfileDTO, profileSetupRequired: Bool) {
        userDefaults.set(member.id, forKey: memberIdKey)
        userDefaults.set(member.displayName, forKey: displayNameKey)
        if let nickname = member.nickname, !nickname.isEmpty {
            userDefaults.set(nickname, forKey: nicknameKey)
        } else {
            userDefaults.removeObject(forKey: nicknameKey)
        }
        if let profileImageUrl = member.profileImageUrl, !profileImageUrl.isEmpty {
            userDefaults.set(profileImageUrl, forKey: profileImageUrlKey)
        } else {
            userDefaults.removeObject(forKey: profileImageUrlKey)
        }
        userDefaults.set(profileSetupRequired, forKey: profileSetupRequiredKey)
    }

    private func clearPersistedMemberProfile() {
        userDefaults.removeObject(forKey: memberIdKey)
        userDefaults.removeObject(forKey: nicknameKey)
        userDefaults.removeObject(forKey: profileImageUrlKey)
        userDefaults.removeObject(forKey: profileSetupRequiredKey)
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
    private let service: String

    init(service: String = "com.nugusauce.ios.auth") {
        self.service = service
    }

    @discardableResult
    func save(_ value: String, account: KeychainAccount) -> Bool {
        let data = Data(value.utf8)
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        if updateStatus != errSecItemNotFound {
            _ = SecItemDelete(query as CFDictionary)
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return true
        }
        guard addStatus == errSecDuplicateItem else {
            return false
        }

        _ = SecItemDelete(query as CFDictionary)
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
