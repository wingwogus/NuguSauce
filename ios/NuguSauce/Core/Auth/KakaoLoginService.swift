import Foundation
import AuthenticationServices
import CryptoKit
import KakaoSDKAuth
import KakaoSDKUser
import Security
import UIKit

struct KakaoOIDCCredential: Equatable {
    let idToken: String
    let nonce: String
    let kakaoAccessToken: String
}

struct AppleOIDCCredential: Equatable {
    let identityToken: String
    let nonce: String
    let authorizationCode: String?
    let userIdentifier: String
    let email: String?
    let fullName: String?
}

enum KakaoSDKConfiguration {
    static var nativeAppKey: String? {
        let rawValue = ProcessInfo.processInfo.environment["KAKAO_NATIVE_APP_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String
            ?? ""
        let key = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty,
              !key.contains("$("),
              !key.localizedCaseInsensitiveContains("YOUR_KAKAO_NATIVE_APP_KEY") else {
            return nil
        }
        return key
    }

    static var isConfigured: Bool {
        nativeAppKey != nil
    }
}

enum KakaoLoginServiceError: LocalizedError, Equatable {
    case missingNativeAppKey
    case missingIDToken
    case nonceGenerationFailed

    var errorDescription: String? {
        switch self {
        case .missingNativeAppKey:
            return "카카오 로그인에 실패했어요. 다시 시도해주세요."
        case .missingIDToken:
            return "카카오 로그인 정보를 확인하지 못했어요. 다시 시도해주세요."
        case .nonceGenerationFailed:
            return "카카오 로그인에 실패했어요. 다시 시도해주세요."
        }
    }
}

enum AppleLoginServiceError: LocalizedError, Equatable {
    case invalidCredential
    case missingIDToken
    case nonceGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidCredential, .missingIDToken, .nonceGenerationFailed:
            return "Apple 로그인에 실패했어요. 다시 시도해주세요."
        }
    }
}

enum KakaoLoginErrorMessage {
    static func message(for error: Error, bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> String {
        if isBundleIDMismatch(error) {
            return "카카오 로그인 설정을 확인할 수 없어요. 잠시 후 다시 시도해주세요."
        }

        if let apiError = error as? ApiError {
            return message(for: apiError)
        }

        if let serviceError = error as? KakaoLoginServiceError {
            return message(for: serviceError)
        }

        return "카카오 로그인에 실패했어요. 다시 시도해주세요."
    }

    private static func message(for apiError: ApiError) -> String {
        switch apiError.code {
        case ApiErrorCode.invalidKakaoToken:
            return "카카오 로그인에 실패했어요. 다시 시도해주세요."
        case ApiErrorCode.kakaoNonceMismatch, ApiErrorCode.kakaoNonceReplay:
            return "로그인 요청이 만료되었어요. 다시 시도해주세요."
        case ApiErrorCode.kakaoVerifiedEmailRequired:
            return "카카오 계정의 인증된 이메일 제공 동의가 필요해요."
        case ApiErrorCode.consentRequired:
            return "로그인을 완료하기 위한 약관 정보를 확인하지 못했어요. 잠시 후 다시 시도해주세요."
        default:
            return "카카오 로그인에 실패했어요. 다시 시도해주세요."
        }
    }

    private static func message(for serviceError: KakaoLoginServiceError) -> String {
        switch serviceError {
        case .missingNativeAppKey, .missingIDToken, .nonceGenerationFailed:
            return "카카오 로그인에 실패했어요. 다시 시도해주세요."
        }
    }

    private static func isBundleIDMismatch(_ error: Error) -> Bool {
        let nsError = error as NSError
        let candidates = [
            String(describing: error),
            nsError.localizedDescription,
            nsError.userInfo.description
        ]

        return candidates.contains { candidate in
            candidate.localizedCaseInsensitiveContains("KOE009")
                || candidate.localizedCaseInsensitiveContains("bundleId validation failed")
                || candidate.localizedCaseInsensitiveContains("bundle id validation failed")
        }
    }
}

enum AppleLoginErrorMessage {
    static func message(for error: Error) -> String {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            return "Apple 로그인이 취소되었어요."
        }

        if let apiError = error as? ApiError {
            return message(for: apiError)
        }

        if error is AppleLoginServiceError {
            return "Apple 로그인에 실패했어요. 다시 시도해주세요."
        }

        return "Apple 로그인에 실패했어요. 다시 시도해주세요."
    }

    private static func message(for apiError: ApiError) -> String {
        switch apiError.code {
        case ApiErrorCode.invalidAppleToken:
            return "Apple 로그인에 실패했어요. 다시 시도해주세요."
        case ApiErrorCode.appleNonceMismatch, ApiErrorCode.appleNonceReplay:
            return "로그인 요청이 만료되었어요. 다시 시도해주세요."
        case ApiErrorCode.appleVerifiedEmailRequired:
            return "Apple 계정의 인증된 이메일 제공이 필요해요."
        case ApiErrorCode.consentRequired:
            return "로그인을 완료하기 위한 약관 정보를 확인하지 못했어요. 잠시 후 다시 시도해주세요."
        default:
            return "Apple 로그인에 실패했어요. 다시 시도해주세요."
        }
    }
}

enum KakaoLoginRequiredScopes {
    static let oidcAndEmail = ["openid", "account_email"]

    static func needsAdditionalConsent(grantedScopes: [String]?) -> Bool {
        let grantedScopeSet = Set(grantedScopes ?? [])
        return !Set(oidcAndEmail).isSubset(of: grantedScopeSet)
    }
}

struct KakaoLoginService {
    func login() async throws -> KakaoOIDCCredential {
        guard KakaoSDKConfiguration.isConfigured else {
            throw KakaoLoginServiceError.missingNativeAppKey
        }

        let nonce = try kakaoNonce()
        let oauthToken = try await loginWithKakao(nonce: nonce)
        let tokenWithRequiredScopes = try await tokenWithRequiredEmailScope(oauthToken, nonce: nonce)
        guard let idToken = tokenWithRequiredScopes.idToken, !idToken.isEmpty else {
            throw KakaoLoginServiceError.missingIDToken
        }
        return KakaoOIDCCredential(
            idToken: idToken,
            nonce: nonce,
            kakaoAccessToken: tokenWithRequiredScopes.accessToken
        )
    }

    private func kakaoNonce() throws -> String {
        do {
            return try NonceGenerator.randomNonce()
        } catch {
            throw KakaoLoginServiceError.nonceGenerationFailed
        }
    }

    private func tokenWithRequiredEmailScope(_ token: OAuthToken, nonce: String) async throws -> OAuthToken {
        guard KakaoLoginRequiredScopes.needsAdditionalConsent(grantedScopes: token.scopes) else {
            return token
        }

        return try await loginWithKakaoAccount(scopes: KakaoLoginRequiredScopes.oidcAndEmail, nonce: nonce)
    }

    private func loginWithKakao(nonce: String) async throws -> OAuthToken {
        try await withCheckedThrowingContinuation { continuation in
            let completion: (OAuthToken?, Error?) -> Void = { token, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let token {
                    continuation.resume(returning: token)
                    return
                }
                continuation.resume(throwing: KakaoLoginServiceError.missingIDToken)
            }

            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(nonce: nonce, completion: completion)
            } else {
                UserApi.shared.loginWithKakaoAccount(nonce: nonce, completion: completion)
            }
        }
    }

    private func loginWithKakaoAccount(scopes: [String], nonce: String) async throws -> OAuthToken {
        try await withCheckedThrowingContinuation { continuation in
            UserApi.shared.loginWithKakaoAccount(scopes: scopes, nonce: nonce) { token, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let token {
                    continuation.resume(returning: token)
                    return
                }
                continuation.resume(throwing: KakaoLoginServiceError.missingIDToken)
            }
        }
    }
}

final class AppleLoginService: NSObject {
    @MainActor
    private var coordinator: AppleAuthorizationCoordinator?

    @MainActor
    func login() async throws -> AppleOIDCCredential {
        let nonce: String
        do {
            nonce = try NonceGenerator.randomNonce()
        } catch {
            throw AppleLoginServiceError.nonceGenerationFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let coordinator = AppleAuthorizationCoordinator(
                rawNonce: nonce,
                continuation: continuation
            ) { [weak self] in
                self?.coordinator = nil
            }
            self.coordinator = coordinator
            coordinator.perform()
        }
    }
}

@MainActor
private final class AppleAuthorizationCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let rawNonce: String
    private var continuation: CheckedContinuation<AppleOIDCCredential, Error>?
    private let onCompletion: @MainActor () -> Void

    init(
        rawNonce: String,
        continuation: CheckedContinuation<AppleOIDCCredential, Error>,
        onCompletion: @MainActor @escaping () -> Void
    ) {
        self.rawNonce = rawNonce
        self.continuation = continuation
        self.onCompletion = onCompletion
    }

    func perform() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = NonceGenerator.sha256Hex(rawNonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(AppleLoginServiceError.invalidCredential))
            return
        }

        guard let identityTokenData = appleCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              !identityToken.isEmpty else {
            finish(.failure(AppleLoginServiceError.missingIDToken))
            return
        }

        let authorizationCode = appleCredential.authorizationCode.flatMap {
            String(data: $0, encoding: .utf8)
        }
        let fullName = appleCredential.fullName.map {
            PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
        }

        finish(
            .success(
                AppleOIDCCredential(
                    identityToken: identityToken,
                    nonce: rawNonce,
                    authorizationCode: authorizationCode,
                    userIdentifier: appleCredential.user,
                    email: appleCredential.email,
                    fullName: fullName
                )
            )
        )
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(.failure(error))
    }

    private func finish(_ result: Result<AppleOIDCCredential, Error>) {
        guard let continuation else {
            return
        }
        self.continuation = nil

        switch result {
        case .success(let credential):
            continuation.resume(returning: credential)
        case .failure(let error):
            continuation.resume(throwing: error)
        }

        onCompletion()
    }
}

enum NonceGenerator {
    private static let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

    static func randomNonce(length: Int = 32) throws -> String {
        precondition(length > 0)

        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw NonceGeneratorError.generationFailed
        }

        return bytes
            .map { String(characters[Int($0) % characters.count]) }
            .joined()
    }

    static func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private enum NonceGeneratorError: Error {
    case generationFailed
}
