import SwiftUI

struct ProfileView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    @StateObject private var viewModel: ProfileViewModel

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore) {
        self.apiClient = apiClient
        self.authStore = authStore
        _viewModel = StateObject(wrappedValue: ProfileViewModel(apiClient: apiClient, authStore: authStore))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                topBar
                if authStore.isAuthenticated {
                    profileHero
                    if viewModel.profileSetupRequired {
                        nicknameSetupCard
                    }
                    recipeSection(title: "내가 올린 레시피", recipes: viewModel.myRecipes)
                    NavigationLink(value: AppRoute.publicProfile(2)) {
                        Text("상대페이지")
                            .primarySauceButton()
                    }
                    .buttonStyle(.plain)
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
            case .publicProfile:
                PublicProfilePlaceholderView()
            case .loginRequired:
                LoginRequiredView(apiClient: apiClient, authStore: authStore)
            }
        }
        .task {
            if authStore.isAuthenticated {
                await viewModel.load()
            }
        }
        .onChange(of: authStore.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                Task {
                    await viewModel.load()
                }
            } else {
                viewModel.clearData()
            }
        }
    }

    private var topBar: some View {
        HStack {
            Text("Chef Profile")
                .font(.headline.weight(.bold))
                .foregroundStyle(SauceColor.primaryContainer)
            Spacer()
        }
        .padding(.top, 18)
    }

    private var profileHero: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 82))
                .foregroundStyle(SauceColor.onSurfaceVariant)
            Text(viewModel.displayName)
                .font(.largeTitle.weight(.black))
            Text("실제 백엔드 세션")
                .foregroundStyle(SauceColor.onSurfaceVariant)
            HStack(spacing: 44) {
                stat("\(viewModel.myRecipes.count)", "MY RECIPES")
                stat("\(viewModel.favoriteRecipes.count)", "FAVORITES")
            }
            Button("로그아웃") {
                authStore.clear()
            }
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 48)
                .padding(.vertical, 13)
                .background(SauceColor.primaryContainer)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.black))
            Text(label)
                .font(.caption2)
                .foregroundStyle(SauceColor.onSurfaceVariant)
        }
    }

    private func recipeSection(title: String, recipes: [RecipeSummaryDTO]) -> some View {
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

struct PublicProfilePlaceholderView: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 72))
                .foregroundStyle(SauceColor.primaryContainer)
            Text("상대페이지 준비 중")
                .font(.title.weight(.black))
            Text("공개 프로필 API 계약이 추가되면 백엔드 데이터로 연결합니다.")
                .multilineTextAlignment(.center)
                .foregroundStyle(SauceColor.onSurfaceVariant)
        }
        .padding(28)
        .background(SauceColor.surface.ignoresSafeArea())
    }
}

struct LoginRequiredView: View {
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
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.fill")
                    Text(isLoggingIn ? "카카오 로그인 중..." : "카카오로 시작하기")
                }
                .font(.headline.weight(.bold))
            }
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color(red: 1.0, green: 0.82, blue: 0.0))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .disabled(isLoggingIn)

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
            if authStore.saveSession(accessToken: tokens.accessToken, refreshToken: tokens.refreshToken, displayName: tokens.member.displayName) {
                authStore.updateMemberProfile(tokens.member)
                errorMessage = nil
            } else {
                errorMessage = authStore.persistenceFailure?.message ?? "로그인 세션을 안전하게 저장하지 못했어요. 다시 시도해주세요."
            }
        } catch {
            errorMessage = KakaoLoginErrorMessage.message(for: error)
        }
    }
}
