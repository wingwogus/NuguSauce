import Foundation

struct AuthSession: Equatable {
    let userID: Int
    let displayName: String
    let accessTokenRedacted: String
}

protocol AuthSessionStoreProtocol: AnyObject {
    var currentSession: AuthSession? { get }
    var isAuthenticated: Bool { get }
    func restore()
    func saveMockSession()
    func clear()
}

final class MockAuthSessionStore: ObservableObject, AuthSessionStoreProtocol {
    @Published private(set) var currentSession: AuthSession?

    init(isAuthenticated: Bool = true) {
        if isAuthenticated {
            currentSession = AuthSession(
                userID: 1,
                displayName: "셰프 웨이",
                accessTokenRedacted: "mock-token-redacted"
            )
        }
    }

    var isAuthenticated: Bool {
        currentSession != nil
    }

    func restore() {
        if currentSession == nil {
            saveMockSession()
        }
    }

    func saveMockSession() {
        currentSession = AuthSession(
            userID: 1,
            displayName: "셰프 웨이",
            accessTokenRedacted: "mock-token-redacted"
        )
    }

    func clear() {
        currentSession = nil
    }
}
