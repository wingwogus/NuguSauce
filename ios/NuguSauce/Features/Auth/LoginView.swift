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
                switch viewModel.flowStep {
                case .consent:
                    ConsentAgreementScreen(
                        status: viewModel.pendingConsentStatus,
                        isLoading: viewModel.isLoadingConsentStatus,
                        isAccepting: viewModel.isAcceptingConsents
                    ) {
                        Task {
                            if await viewModel.acceptRequiredConsents() {
                                dismiss()
                            }
                        }
                    } onRetry: {
                        Task {
                            _ = await viewModel.reloadRequiredConsents()
                        }
                    }
                case .nickname:
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
                case .login:
                    LoginBrandHeader()
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
        .navigationTitle(viewModel.flowStep.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("login-screen")
    }
}

enum LoginFlowStep: Equatable {
    case login
    case consent
    case nickname

    var navigationTitle: String {
        switch self {
        case .login:
            return "로그인"
        case .consent:
            return "약관 동의"
        case .nickname:
            return "닉네임 설정"
        }
    }
}

protocol KakaoLoginServicing {
    func login() async throws -> KakaoOIDCCredential
}

extension KakaoLoginService: KakaoLoginServicing {}

@MainActor
final class LoginViewModel: ObservableObject {
    @Published private(set) var isLoggingIn = false
    @Published private(set) var isLoadingConsentStatus = false
    @Published private(set) var isAcceptingConsents = false
    @Published private(set) var isSavingNickname = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var pendingConsentStatus: ConsentStatusDTO?
    @Published private(set) var flowStep: LoginFlowStep = .login
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
                member: tokens.member,
                requiredActions: tokens.onboarding.requiredActions
            )
            pendingLogin = login
            nicknameDraft = tokens.member.nickname ?? ""

            return await routePendingLogin(using: login)
        } catch {
            resetPendingLogin()
            errorMessage = KakaoLoginErrorMessage.message(for: error)
            return false
        }
    }

    @MainActor
    func reloadRequiredConsents() async -> Bool {
        guard let pendingLogin else {
            return false
        }
        return await loadPendingConsentStatus(using: pendingLogin)
    }

    @MainActor
    private func loadPendingConsentStatus(using login: PendingLoginSession) async -> Bool {
        flowStep = .consent
        isLoadingConsentStatus = true
        defer {
            isLoadingConsentStatus = false
        }

        do {
            let consentStatus = try await apiClient.fetchConsentStatus(accessToken: login.accessToken)
            if consentStatus.requiredConsentsAccepted {
                return await routePendingLogin(using: login.removing(.acceptRequiredPolicies))
            }

            pendingConsentStatus = consentStatus
            errorMessage = nil
            return false
        } catch let error as ApiError {
            errorMessage = consentStatusLoadMessage(for: error)
            return false
        } catch {
            errorMessage = "로그인을 완료하기 위한 필수 동의 상태를 확인하지 못했어요."
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

        guard LegalPolicyContent.canDisplayAllMissingPolicies(in: pendingConsentStatus) else {
            errorMessage = LegalPolicyContent.missingDocumentMessage
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
                return await routePendingLogin(using: pendingLogin.removing(.acceptRequiredPolicies))
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
            return await routePendingLogin(using: pendingLogin.updating(member: updatedMember).removing(.setupProfile))
        } catch let error as ApiError {
            nicknameErrorMessage = nicknameMessage(for: error)
            return false
        } catch {
            nicknameErrorMessage = "닉네임을 저장하지 못했어요."
            return false
        }
    }

    @MainActor
    private func routePendingLogin(using login: PendingLoginSession) async -> Bool {
        pendingLogin = login
        pendingConsentStatus = nil
        errorMessage = nil

        if login.requires(.acceptRequiredPolicies) {
            return await loadPendingConsentStatus(using: login)
        }

        if login.requires(.setupProfile) {
            return showNicknameSetup(using: login)
        }

        return completeLogin(using: login, member: login.member)
    }

    @MainActor
    private func showNicknameSetup(using login: PendingLoginSession) -> Bool {
        pendingLogin = login
        nicknameDraft = login.member.nickname ?? ""
        nicknameErrorMessage = nil
        flowStep = .nickname
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
        flowStep = .login
        nicknameDraft = ""
        nicknameErrorMessage = nil
        isLoadingConsentStatus = false
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

    private func consentStatusLoadMessage(for error: ApiError) -> String {
        switch error.code {
        case ApiErrorCode.unauthorized:
            return "로그인 상태를 확인하지 못했어요. 다시 시도해주세요."
        case ApiErrorCode.resourceNotFound:
            return "필수 약관 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요."
        default:
            return error.userVisibleMessage(default: "로그인을 완료하기 위한 필수 동의 상태를 확인하지 못했어요.")
        }
    }
}

private struct PendingLoginSession {
    let accessToken: String
    let refreshToken: String?
    var member: MemberProfileDTO
    var requiredActions: [KakaoOnboardingRequiredActionDTO]

    func requires(_ action: KakaoOnboardingRequiredActionDTO) -> Bool {
        requiredActions.contains(action)
    }

    func removing(_ action: KakaoOnboardingRequiredActionDTO) -> PendingLoginSession {
        var copy = self
        copy.requiredActions.removeAll { $0 == action }
        return copy
    }

    func updating(member: MemberProfileDTO) -> PendingLoginSession {
        var copy = self
        copy.member = member
        return copy
    }
}

struct LoginBrandHeader: View {
    var body: some View {
        VStack(spacing: 14) {
            Image("SplashIconMark")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 168, height: 168)
                .accessibilityHidden(true)
            Image("SplashWordmark")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(SauceColor.onSurface)
                .frame(width: 188)
                .accessibilityLabel("NuguSauce")
            Text("로그인하고 소스 조합을 저장해보세요")
                .font(SauceTypography.sectionTitle())
                .foregroundStyle(SauceColor.onSurface)
                .multilineTextAlignment(.center)
            Text("카카오 계정으로 계속하면 찜, 프로필, 소스 등록과 리뷰 작성 기능을 사용할 수 있어요.")
                .font(SauceTypography.body())
                .foregroundStyle(SauceColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LoginFlowNotice: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("카카오 인증 후 필수 약관 동의와 닉네임 설정을 완료해야 시작할 수 있어요.")
                .font(SauceTypography.badge(.bold))
                .foregroundStyle(SauceColor.onSurfaceVariant)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ConsentAgreementScreen: View {
    let status: ConsentStatusDTO?
    let isLoading: Bool
    let isAccepting: Bool
    let onAccept: () -> Void
    let onRetry: () -> Void
    @State private var checkedPolicyIDs: Set<String> = []
    @State private var selectedDocument: LegalPolicyDocument?

    init(
        status: ConsentStatusDTO?,
        isLoading: Bool,
        isAccepting: Bool,
        onAccept: @escaping () -> Void,
        onRetry: @escaping () -> Void = {}
    ) {
        self.status = status
        self.isLoading = isLoading
        self.isAccepting = isAccepting
        self.onAccept = onAccept
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("약관에 동의해주세요")
                    .font(SauceTypography.sectionTitle())
                    .foregroundStyle(SauceColor.onSurface)
                Text("필수 약관 전문을 앱 안에서 확인한 뒤 동의해야 NuguSauce를 사용할 수 있어요.")
                    .font(SauceTypography.body())
                    .foregroundStyle(SauceColor.onSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let status {
                VStack(alignment: .leading, spacing: 12) {
                    allAgreeButton(for: status)

                    ForEach(status.missingPolicies) { policy in
                        ConsentPolicyChecklistRow(
                            policy: policy,
                            document: LegalPolicyContent.document(for: policy),
                            isChecked: checkedPolicyIDs.contains(policy.id),
                            onToggle: {
                                toggle(policy)
                            },
                            onOpenDocument: { document in
                                selectedDocument = document
                            }
                        )
                    }
                }
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("동의할 정책 버전을 확인하는 중...")
                        .font(SauceTypography.badge(.bold))
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                }
            } else {
                Button("약관 정보 다시 불러오기", action: onRetry)
                    .font(SauceTypography.body(.bold))
                    .foregroundStyle(SauceColor.primaryContainer)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SauceColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: SauceSpacing.controlRadius, style: .continuous))
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
            .disabled(isAccepting || isLoading || !canAccept(status))
        }
        .padding(18)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .sheet(item: $selectedDocument) { document in
            NavigationStack {
                LegalDocumentView(document: document)
            }
        }
        .onChange(of: status?.missingPolicies.map(\.id) ?? []) { _, policyIDs in
            checkedPolicyIDs.formIntersection(Set(policyIDs))
        }
    }

    private func allAgreeButton(for status: ConsentStatusDTO) -> some View {
        Button {
            let policyIDs = Set(status.missingPolicies.map(\.id))
            if policyIDs.isSubset(of: checkedPolicyIDs) {
                checkedPolicyIDs.subtract(policyIDs)
            } else {
                checkedPolicyIDs.formUnion(policyIDs)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: allMissingPoliciesChecked(status) ? "checkmark.square.fill" : "square")
                    .font(SauceTypography.iconSmall(.bold))
                    .foregroundStyle(allMissingPoliciesChecked(status) ? SauceColor.primaryContainer : SauceColor.onSurfaceVariant)
                Text("필수 약관 모두 동의")
                    .font(SauceTypography.body(.bold))
                    .foregroundStyle(SauceColor.onSurface)
                Spacer()
            }
            .padding(14)
            .background(SauceColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ policy: ConsentPolicyDTO) {
        if checkedPolicyIDs.contains(policy.id) {
            checkedPolicyIDs.remove(policy.id)
        } else {
            checkedPolicyIDs.insert(policy.id)
        }
    }

    private func allMissingPoliciesChecked(_ status: ConsentStatusDTO) -> Bool {
        let policyIDs = Set(status.missingPolicies.map(\.id))
        return !policyIDs.isEmpty && policyIDs.isSubset(of: checkedPolicyIDs)
    }

    private func canAccept(_ status: ConsentStatusDTO?) -> Bool {
        guard let status else {
            return false
        }
        let missingPolicyIDs = Set(status.missingPolicies.map(\.id))
        return !missingPolicyIDs.isEmpty &&
            missingPolicyIDs.isSubset(of: checkedPolicyIDs) &&
            LegalPolicyContent.canDisplayAllMissingPolicies(in: status)
    }
}

struct ConsentPolicyChecklistRow: View {
    let policy: ConsentPolicyDTO
    let document: LegalPolicyDocument?
    let isChecked: Bool
    let onToggle: () -> Void
    let onOpenDocument: (LegalPolicyDocument) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button(action: onToggle) {
                    Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                        .font(SauceTypography.iconMedium(.bold))
                        .foregroundStyle(isChecked ? SauceColor.primaryContainer : SauceColor.onSurfaceVariant)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isChecked ? "\(policy.title) 동의 해제" : "\(policy.title) 동의")

                VStack(alignment: .leading, spacing: 4) {
                    Text(policy.title)
                        .font(SauceTypography.body(.bold))
                        .foregroundStyle(SauceColor.onSurface)
                    Text("버전 \(policy.version) · 시행일 \(policy.activeFrom)")
                        .font(SauceTypography.metric(.regular))
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            if let document {
                Button {
                    onOpenDocument(document)
                } label: {
                    Label("전문 보기", systemImage: "doc.text.magnifyingglass")
                        .font(SauceTypography.badge(.bold))
                }
                .foregroundStyle(SauceColor.primaryContainer)
                .buttonStyle(.plain)
            } else {
                Text(LegalPolicyContent.missingDocumentMessage)
                    .font(SauceTypography.metric(.regular))
                    .foregroundStyle(SauceColor.primaryContainer)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(SauceColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    .font(SauceTypography.sectionTitle())
                    .foregroundStyle(SauceColor.onSurface)
                Text("앱에서 보여줄 이름을 정하면 로그인 설정이 완료됩니다.")
                    .font(SauceTypography.body())
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
