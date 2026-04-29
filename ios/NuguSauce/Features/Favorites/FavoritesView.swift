import SwiftUI

struct FavoritesView: View {
    let apiClient: APIClientProtocol
    @ObservedObject var authStore: AuthSessionStore
    @StateObject private var viewModel: FavoritesViewModel

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore) {
        self.apiClient = apiClient
        self.authStore = authStore
        _viewModel = StateObject(wrappedValue: FavoritesViewModel(apiClient: apiClient, authStore: authStore))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SauceSpacing.section) {
                header

                if authStore.isAuthenticated {
                    favoriteContent
                } else {
                    LoginGatePlaceholder(
                        title: "찜한 레시피는 로그인 후 볼 수 있어요.",
                        message: "로그인 화면으로 이동해 저장한 소스 조합을 확인해보세요.",
                        systemImage: "bookmark.fill"
                    )
                }
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.bottom, 42)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            if authStore.isAuthenticated {
                Task {
                    await viewModel.load()
                }
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
        .refreshable {
            await viewModel.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            SauceScreenTitle(title: "찜한 레시피")
            Text("\(viewModel.recipes.count)개 저장됨")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SauceColor.onSurfaceVariant)
        }
    }

    @ViewBuilder
    private var favoriteContent: some View {
        if viewModel.isLoading && viewModel.recipes.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 42)
        } else if let errorMessage = viewModel.errorMessage {
            SauceStatusBanner(message: errorMessage)
        } else if viewModel.recipes.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(viewModel.recipes) { recipe in
                    NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                        RecipeCard(recipe: recipe)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bookmark")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(SauceColor.primaryContainer)
            Text("찜한 레시피가 없어요.")
                .font(.title3.weight(.bold))
                .foregroundStyle(SauceColor.onSurface)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 46)
        .sauceCard(cornerRadius: 18)
    }
}
