import SwiftUI

struct LoginView: View {
    private static let kakaoLoginButtonAspectRatio: CGFloat = 600.0 / 90.0
    private static let kakaoLoginButtonMaxWidth: CGFloat = 300
    private static let kakaoLoginButtonMaxHeight: CGFloat = 45

    @StateObject private var viewModel: LoginViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        apiClient: APIClientProtocol,
        authStore: AuthSessionStore,
        kakaoLoginService: KakaoLoginServicing = KakaoLoginService()
    ) {
        _viewModel = StateObject(
            wrappedValue: LoginViewModel(
                apiClient: apiClient,
                authStore: authStore,
                kakaoLoginService: kakaoLoginService
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 14) {
                    Image("AppIconMark")
                        .renderingMode(.original)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 92, height: 92)
                        .accessibilityHidden(true)
                    Text("NuguSauce")
                        .font(.largeTitle.weight(.black).italic())
                        .foregroundStyle(SauceColor.primaryContainer)
                    Text("로그인하고 소스 조합을 저장해보세요")
                        .font(.title3.weight(.black))
                        .foregroundStyle(SauceColor.onSurface)
                        .multilineTextAlignment(.center)
                    Text("카카오 계정으로 계속하면 찜, 프로필, 소스 등록과 리뷰 작성 기능을 사용할 수 있어요.")
                        .font(.subheadline)
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)

                if let pendingConsentStatus = viewModel.pendingConsentStatus,
                   !pendingConsentStatus.requiredConsentsAccepted {
                    ConsentRequiredPanel(
                        status: pendingConsentStatus,
                        isAccepting: viewModel.isAcceptingConsents
                    ) {
                        Task {
                            if await viewModel.acceptRequiredConsents() {
                                dismiss()
                            }
                        }
                    }
                } else if viewModel.shouldShowNicknameSetup {
                    LoginNicknameSetupPanel(
                        nickname: $viewModel.nicknameDraft,
                        isSaving: viewModel.isSavingNickname,
                        errorMessage: viewModel.nicknameErrorMessage
                    ) {
                        Task {
                            if await viewModel.saveNicknameAndCompleteLogin() {
                                dismiss()
                            }
                        }
                    }
                } else {
                    LoginFlowNotice()

                    Button {
                        Task {
                            if await viewModel.loginWithKakao() {
                                dismiss()
                            }
                        }
                    } label: {
                        GeometryReader { proxy in
                            let buttonWidth = min(proxy.size.width, Self.kakaoLoginButtonMaxWidth)

                            Image("KakaoLoginLargeWide")
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    width: buttonWidth,
                                    height: buttonWidth / Self.kakaoLoginButtonAspectRatio
                                )
                                .opacity(viewModel.isLoggingIn ? 0.65 : 1)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: Self.kakaoLoginButtonMaxHeight)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoggingIn)
                    .accessibilityLabel(viewModel.isLoggingIn ? "카카오 로그인 중" : "카카오로 시작하기")
                }

                if let errorMessage = viewModel.errorMessage {
                    SauceStatusBanner(message: errorMessage)
                }
            }
            .frame(maxWidth: 430)
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.top, 70)
            .padding(.bottom, 42)
            .frame(maxWidth: .infinity)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .navigationTitle("로그인")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("login-screen")
    }
}

protocol KakaoLoginServicing {
    func login() async throws -> KakaoOIDCCredential
}

extension KakaoLoginService: KakaoLoginServicing {}

@MainActor
final class LoginViewModel: ObservableObject {
    @Published private(set) var isLoggingIn = false
    @Published private(set) var isAcceptingConsents = false
    @Published private(set) var isSavingNickname = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var pendingConsentStatus: ConsentStatusDTO?
    @Published var nicknameDraft = ""
    @Published private(set) var nicknameErrorMessage: String?

    private let apiClient: APIClientProtocol
    private let authStore: AuthSessionStore
    private let kakaoLoginService: KakaoLoginServicing
    private var pendingLogin: PendingLoginSession?

    init(
        apiClient: APIClientProtocol,
        authStore: AuthSessionStore,
        kakaoLoginService: KakaoLoginServicing
    ) {
        self.apiClient = apiClient
        self.authStore = authStore
        self.kakaoLoginService = kakaoLoginService
    }

    var shouldShowNicknameSetup: Bool {
        guard let pendingLogin else {
            return false
        }
        return requiresNicknameSetup(for: pendingLogin.member)
    }

    @MainActor
    func loginWithKakao() async -> Bool {
        guard !isLoggingIn else {
            return false
        }

        isLoggingIn = true
        errorMessage = nil
        defer {
            isLoggingIn = false
        }

        do {
            let credential = try await kakaoLoginService.login()
            let tokens: KakaoLoginResponseDTO
            do {
                tokens = try await apiClient.authenticateWithKakao(
                    idToken: credential.idToken,
                    nonce: credential.nonce,
                    kakaoAccessToken: credential.kakaoAccessToken
                )
            } catch {
                resetPendingLogin()
                errorMessage = KakaoLoginErrorMessage.message(for: error)
                return false
            }

            let login = PendingLoginSession(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                member: tokens.member
            )
            pendingLogin = login
            nicknameDraft = tokens.member.nickname ?? ""

            let consentStatus: ConsentStatusDTO
            do {
                consentStatus = try await apiClient.fetchConsentStatus(accessToken: tokens.accessToken)
            } catch let error as ApiError {
                resetPendingLogin()
                errorMessage = error.userVisibleMessage(default: "로그인을 완료하기 위한 필수 동의 상태를 확인하지 못했어요.")
                return false
            } catch {
                resetPendingLogin()
                errorMessage = "로그인을 완료하기 위한 필수 동의 상태를 확인하지 못했어요."
                return false
            }

            if consentStatus.requiredConsentsAccepted {
                return proceedAfterRequiredConsents(using: login)
            } else {
                pendingConsentStatus = consentStatus
                errorMessage = nil
                return false
            }
        } catch {
            resetPendingLogin()
            errorMessage = KakaoLoginErrorMessage.message(for: error)
            return false
        }
    }

    @MainActor
    func acceptRequiredConsents() async -> Bool {
        guard !isAcceptingConsents,
              let pendingConsentStatus,
              let pendingLogin else {
            return false
        }

        let request = ConsentAcceptRequestDTO(
            acceptedPolicies: pendingConsentStatus.missingPolicies.map {
                ConsentPolicyAcceptanceDTO(policyType: $0.policyType, version: $0.version)
            }
        )

        isAcceptingConsents = true
        errorMessage = nil
        defer {
            isAcceptingConsents = false
        }

        do {
            let updatedStatus = try await apiClient.acceptConsents(request, accessToken: pendingLogin.accessToken)
            if updatedStatus.requiredConsentsAccepted {
                return proceedAfterRequiredConsents(using: pendingLogin)
            } else {
                self.pendingConsentStatus = updatedStatus
                errorMessage = "필수 동의를 완료해주세요."
                return false
            }
        } catch let error as ApiError {
            errorMessage = error.userVisibleMessage(default: "필수 동의를 저장하지 못했어요.")
            return false
        } catch {
            errorMessage = "필수 동의를 저장하지 못했어요."
            return false
        }
    }

    @MainActor
    func saveNicknameAndCompleteLogin() async -> Bool {
        guard !isSavingNickname,
              let pendingLogin else {
            return false
        }

        let nickname = nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty else {
            nicknameErrorMessage = "닉네임을 입력해주세요."
            return false
        }

        isSavingNickname = true
        nicknameErrorMessage = nil
        errorMessage = nil
        defer {
            isSavingNickname = false
        }

        do {
            let updatedMember = try await apiClient.updateMyMember(
                nickname: nickname,
                profileImageId: nil,
                accessToken: pendingLogin.accessToken
            )
            return completeLogin(using: pendingLogin, member: updatedMember)
        } catch let error as ApiError {
            nicknameErrorMessage = nicknameMessage(for: error)
            return false
        } catch {
            nicknameErrorMessage = "닉네임을 저장하지 못했어요."
            return false
        }
    }

    @MainActor
    private func proceedAfterRequiredConsents(using login: PendingLoginSession) -> Bool {
        pendingConsentStatus = nil
        errorMessage = nil

        guard requiresNicknameSetup(for: login.member) else {
            return completeLogin(using: login, member: login.member)
        }

        nicknameDraft = login.member.nickname ?? ""
        nicknameErrorMessage = nil
        return false
    }

    @MainActor
    private func completeLogin(using login: PendingLoginSession, member: MemberProfileDTO) -> Bool {
        guard authStore.saveSession(accessToken: login.accessToken, refreshToken: login.refreshToken, member: member) else {
            let failureMessage = authStore.persistenceFailure?.message ?? "로그인 세션을 안전하게 저장하지 못했어요. 다시 시도해주세요."
            resetPendingLogin()
            errorMessage = failureMessage
            return false
        }

        resetPendingLogin()
        return true
    }

    @MainActor
    private func resetPendingLogin() {
        pendingConsentStatus = nil
        pendingLogin = nil
        nicknameDraft = ""
        nicknameErrorMessage = nil
    }

    private func requiresNicknameSetup(for member: MemberProfileDTO) -> Bool {
        member.profileSetupRequired ?? ((member.nickname ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func nicknameMessage(for error: ApiError) -> String {
        switch error.code {
        case ApiErrorCode.invalidNickname:
            return "2~20자의 한글, 영문, 숫자, 밑줄만 사용할 수 있어요."
        case ApiErrorCode.duplicateNickname:
            return "이미 사용 중인 닉네임입니다."
        default:
            return error.userVisibleMessage(default: "닉네임을 저장하지 못했어요.")
        }
    }
}

private struct PendingLoginSession {
    let accessToken: String
    let refreshToken: String?
    let member: MemberProfileDTO
}

struct LoginFlowNotice: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("카카오 인증 후 필수 약관 동의와 닉네임 설정을 완료해야 시작할 수 있어요.")
                .font(.caption.weight(.bold))
                .foregroundStyle(SauceColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ConsentRequiredPanel: View {
    let status: ConsentStatusDTO
    let isAccepting: Bool
    let onAccept: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("필수 동의가 필요해요")
                    .font(.headline.weight(.black))
                    .foregroundStyle(SauceColor.onSurface)
                Text("NuguSauce를 사용하려면 현재 버전의 정책에 동의해야 합니다.")
                    .font(.subheadline)
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(status.missingPolicies) { policy in
                    if let url = URL(string: policy.url) {
                        Link(policy.title, destination: url)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(SauceColor.primaryContainer)
                    } else {
                        Text(policy.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(SauceColor.onSurface)
                    }
                }
            }

            Button(action: onAccept) {
                HStack(spacing: 8) {
                    if isAccepting {
                        ProgressView()
                            .tint(SauceColor.onPrimary)
                    }
                    Text(isAccepting ? "동의 저장 중..." : "필수 동의하고 계속")
                }
            }
            .primarySauceButton()
            .disabled(isAccepting)
        }
        .padding(18)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct LoginNicknameSetupPanel: View {
    @Binding var nickname: String
    let isSaving: Bool
    let errorMessage: String?
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("닉네임을 설정해주세요")
                    .font(.headline.weight(.black))
                    .foregroundStyle(SauceColor.onSurface)
                Text("앱에서 보여줄 이름을 정하면 로그인 설정이 완료됩니다.")
                    .font(.subheadline)
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("소스장인", text: $nickname)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(SauceColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button(action: onSave) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(SauceColor.onPrimary)
                    }
                    Text(isSaving ? "저장 중..." : "닉네임 저장하고 시작")
                }
            }
            .primarySauceButton()
            .disabled(isSaving)

            if let errorMessage {
                SauceStatusBanner(message: errorMessage)
            }
        }
        .padding(18)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
