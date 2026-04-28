import SwiftUI

struct ProfileView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    @StateObject private var viewModel: ProfileViewModel
    @AppStorage(SauceThemePreference.storageKey) private var themePreferenceRawValue = SauceThemePreference.system.rawValue

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore) {
        self.apiClient = apiClient
        self.authStore = authStore
        _viewModel = StateObject(wrappedValue: ProfileViewModel(apiClient: apiClient, authStore: authStore))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                topBar
                appearanceSettingsCard
                if authStore.isAuthenticated {
                    ProfileHeroCard(
                        displayName: viewModel.displayName,
                        stats: [
                            ProfileHeroStat(value: "\(viewModel.myRecipes.count)", label: "내 레시피"),
                            ProfileHeroStat(value: "\(viewModel.favoriteRecipes.count)", label: "찜한 레시피")
                        ],
                        actionTitle: "로그아웃",
                        action: {
                            authStore.clear()
                        }
                    )
                    if viewModel.profileSetupRequired {
                        nicknameSetupCard
                    }
                    ProfileRecipeSection(title: "내가 올린 레시피", recipes: viewModel.myRecipes)
                } else {
                    LoginRequiredView(apiClient: apiClient, authStore: authStore)
                }
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.bottom, 42)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .recipeDetail(let id):
                RecipeDetailView(recipeID: id, apiClient: apiClient, authStore: authStore)
            case .publicProfile(let id):
                PublicProfileView(memberID: id, apiClient: apiClient)
            case .loginRequired:
                LoginRequiredView(apiClient: apiClient, authStore: authStore)
            }
        }
        .task {
            if authStore.isAuthenticated {
                await viewModel.load()
            }
        }
        .onChange(of: authStore.currentSession) { _, session in
            if session != nil {
                Task {
                    await viewModel.load()
                }
            } else {
                viewModel.clearData()
            }
        }
    }

    private var topBar: some View {
        SauceScreenTitle(title: "내 프로필")
    }

    private var appearanceSettingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SauceColor.primaryContainer)
                Text("화면 모드")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SauceColor.onSurface)
            }

            Picker("화면 모드", selection: themePreferenceBinding) {
                ForEach(SauceThemePreference.allCases) { preference in
                    Text(preference.title)
                        .tag(preference)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(16)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var themePreferenceBinding: Binding<SauceThemePreference> {
        Binding(
            get: {
                SauceThemePreference(rawValue: themePreferenceRawValue) ?? .system
            },
            set: { preference in
                themePreferenceRawValue = preference.rawValue
            }
        )
    }

    private var nicknameSetupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("닉네임 설정")
                .font(.title3.weight(.black))
            TextField("소스장인", text: $viewModel.nicknameDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(SauceColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Button {
                Task {
                    _ = await viewModel.saveNickname()
                }
            } label: {
                Text(viewModel.isSavingNickname ? "저장 중..." : "저장")
                    .frame(maxWidth: .infinity)
            }
            .primarySauceButton()
            .disabled(viewModel.isSavingNickname)

            if let nicknameErrorMessage = viewModel.nicknameErrorMessage {
                SauceStatusBanner(message: nicknameErrorMessage)
            }
        }
        .padding(18)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

}

struct PublicProfileView: View {
    @StateObject private var viewModel: PublicProfileViewModel

    init(memberID: Int, apiClient: APIClientProtocol) {
        _viewModel = StateObject(wrappedValue: PublicProfileViewModel(memberID: memberID, apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SauceScreenTitle(title: "프로필")

                if let member = viewModel.member {
                    ProfileHeroCard(
                        displayName: member.displayName,
                        stats: [
                            ProfileHeroStat(value: "\(viewModel.recipes.count)", label: "내 레시피"),
                            ProfileHeroStat(value: "\(viewModel.favoriteRecipes.count)", label: "찜한 레시피")
                        ],
                        actionTitle: nil,
                        action: nil
                    )
                    ProfileRecipeSection(title: viewModel.authoredRecipeSectionTitle, recipes: viewModel.recipes)
                } else if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                }

                if let errorMessage = viewModel.errorMessage {
                    VStack(alignment: .leading, spacing: 14) {
                        SauceStatusBanner(message: errorMessage)
                        Button {
                            Task {
                                await viewModel.load()
                            }
                        } label: {
                            Text("다시 불러오기")
                                .frame(maxWidth: .infinity)
                        }
                        .primarySauceButton()
                    }
                }
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.bottom, 42)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
    }

}

private struct ProfileHeroStat: Identifiable {
    var id: String { label }
    let value: String
    let label: String
}

private struct ProfileHeroCard: View {
    let displayName: String
    let stats: [ProfileHeroStat]
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 82))
                .foregroundStyle(SauceColor.onSurfaceVariant)
            Text(displayName)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(SauceColor.onSurface)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            HStack(spacing: 44) {
                ForEach(stats) { stat in
                    VStack(spacing: 2) {
                        Text(stat.value)
                            .font(.title3.weight(.black))
                        Text(stat.label)
                            .font(.caption2)
                            .foregroundStyle(SauceColor.onSurfaceVariant)
                    }
                }
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(SauceColor.onPrimary)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 13)
                    .background(SauceColor.primaryContainer)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProfileRecipeSection: View {
    let title: String
    let recipes: [RecipeSummaryDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title2.weight(.black))
            ForEach(recipes) { recipe in
                NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                    RecipeCard(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct ProfileSetupGateView: View {
    @StateObject private var viewModel: ProfileViewModel
    @FocusState private var isNicknameFocused: Bool

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(apiClient: apiClient, authStore: authStore))
    }

    var body: some View {
        ZStack {
            SauceColor.surfaceContainerLow.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NuguSauce")
                        .font(.largeTitle.weight(.black).italic())
                        .foregroundStyle(SauceColor.primaryContainer)
                    Text("닉네임을 정해주세요")
                        .font(.title.weight(.black))
                    Text("저장한 닉네임은 레시피와 리뷰에 표시됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(SauceColor.onSurfaceVariant)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("닉네임")
                        .font(.headline.weight(.bold))
                    TextField("소스장인", text: $viewModel.nicknameDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.nickname)
                        .submitLabel(.done)
                        .focused($isNicknameFocused)
                        .padding(16)
                        .background(SauceColor.surfaceContainerLow)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .onSubmit {
                            Task {
                                await saveNickname()
                            }
                        }
                }

                Button {
                    Task {
                        await saveNickname()
                    }
                } label: {
                    Text(viewModel.isSavingNickname ? "저장 중..." : "닉네임 저장")
                        .frame(maxWidth: .infinity)
                }
                .primarySauceButton()
                .disabled(!canSaveNickname)

                if let nicknameErrorMessage = viewModel.nicknameErrorMessage {
                    SauceStatusBanner(message: nicknameErrorMessage)
                }
            }
            .padding(26)
            .frame(maxWidth: 430)
            .background(SauceColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, SauceSpacing.screen)
        }
        .task {
            isNicknameFocused = true
        }
    }

    private var canSaveNickname: Bool {
        !viewModel.isSavingNickname &&
            !viewModel.nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func saveNickname() async {
        guard canSaveNickname else {
            return
        }
        _ = await viewModel.saveNickname()
    }
}

struct LoginRequiredView: View {
    private static let kakaoLoginButtonAspectRatio: CGFloat = 600.0 / 90.0
    private static let kakaoLoginButtonMaxWidth: CGFloat = 300
    private static let kakaoLoginButtonMaxHeight: CGFloat = 45

    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    private let kakaoLoginService = KakaoLoginService()
    @State private var isLoggingIn = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NuguSauce")
                .font(.largeTitle.weight(.black).italic())
                .foregroundStyle(SauceColor.primaryContainer)
            Text("로그인이 필요한 기능입니다.")
                .font(.headline)

            Button {
                Task {
                    await loginWithKakao()
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
                        .opacity(isLoggingIn ? 0.65 : 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                .frame(height: Self.kakaoLoginButtonMaxHeight)
            }
            .buttonStyle(.plain)
            .disabled(isLoggingIn)
            .accessibilityLabel(isLoggingIn ? "카카오 로그인 중" : "카카오로 시작하기")

            if let errorMessage {
                SauceStatusBanner(message: errorMessage)
            }
        }
        .padding(28)
        .sauceCard(cornerRadius: 18)
    }

    @MainActor
    private func loginWithKakao() async {
        guard !isLoggingIn else {
            return
        }

        isLoggingIn = true
        errorMessage = nil
        defer {
            isLoggingIn = false
        }

        do {
            let credential = try await kakaoLoginService.login()
            let tokens = try await apiClient.authenticateWithKakao(
                idToken: credential.idToken,
                nonce: credential.nonce,
                kakaoAccessToken: credential.kakaoAccessToken
            )
            if authStore.saveSession(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken, member: tokens.member) {
                errorMessage = nil
            } else {
                errorMessage = authStore.persistenceFailure?.message ?? "로그인 세션을 안전하게 저장하지 못했어요. 다시 시도해주세요."
            }
        } catch {
            errorMessage = KakaoLoginErrorMessage.message(for: error)
        }
    }
}
