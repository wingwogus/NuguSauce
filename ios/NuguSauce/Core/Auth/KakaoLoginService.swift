import Foundation
import KakaoSDKAuth
import KakaoSDKUser
import Security

struct KakaoOIDCCredential: Equatable {
    let idToken: String
    let nonce: String
    let kakaoAccessToken: String
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
            return "KAKAO_NATIVE_APP_KEY를 설정해주세요."
        case .missingIDToken:
            return "카카오 ID Token을 받지 못했습니다. Kakao Developers에서 OpenID Connect 설정을 확인해주세요."
        case .nonceGenerationFailed:
            return "로그인 nonce를 만들지 못했습니다."
        }
    }
}

enum KakaoLoginErrorMessage {
    static func message(for error: Error, bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> String {
        if isBundleIDMismatch(error) {
            if let bundleIdentifier, !bundleIdentifier.isEmpty {
                return "Kakao Developers의 iOS Bundle ID에 \(bundleIdentifier)를 등록해주세요."
            }
            return "Kakao Developers의 iOS Bundle ID와 앱 Bundle ID를 맞춰주세요."
        }

        if let apiError = error as? ApiError {
            return message(for: apiError)
        }

        if let localizedError = error as? LocalizedError,
           let message = localizedError.errorDescription {
            return message
        }

        return "카카오 로그인에 실패했습니다."
    }

    private static func message(for apiError: ApiError) -> String {
        switch apiError.code {
        case ApiErrorCode.invalidKakaoToken:
            return "카카오 토큰 검증에 실패했습니다. 백엔드 KAKAO_NATIVE_APP_KEY를 iOS Native App Key와 맞춰주세요. (\(apiError.code))"
        case ApiErrorCode.kakaoNonceMismatch:
            return "카카오 로그인 응답이 현재 요청과 일치하지 않습니다. 다시 시도해주세요. (\(apiError.code))"
        case ApiErrorCode.kakaoNonceReplay:
            return "이미 사용된 카카오 로그인 응답입니다. 다시 로그인해주세요. (\(apiError.code))"
        case ApiErrorCode.kakaoVerifiedEmailRequired:
            return "카카오 계정의 인증된 이메일 제공 동의가 필요합니다. Kakao Developers 동의항목을 확인해주세요. (\(apiError.code))"
        default:
            if !apiError.message.isEmpty {
                return apiError.message
            }
            return "카카오 로그인에 실패했습니다. (\(apiError.code))"
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

        let nonce = try NonceGenerator.randomNonce()
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

enum NonceGenerator {
    private static let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

    static func randomNonce(length: Int = 32) throws -> String {
        precondition(length > 0)

        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw KakaoLoginServiceError.nonceGenerationFailed
        }

        return bytes
            .map { String(characters[Int($0) % characters.count]) }
            .joined()
    }
}
