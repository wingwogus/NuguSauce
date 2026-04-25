import SwiftUI

struct HomeView: View {
    let apiClient: APIClientProtocol
    let authStore: AuthSessionStoreProtocol
    @StateObject private var viewModel: HomeViewModel

    init(apiClient: APIClientProtocol, authStore: AuthSessionStoreProtocol) {
        self.apiClient = apiClient
        self.authStore = authStore
        _viewModel = StateObject(wrappedValue: HomeViewModel(apiClient: apiClient))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SauceSpacing.section) {
                header
                searchBar
                weeklyPopular
                latestRecipes
            }
            .padding(.horizontal, SauceSpacing.screen)
            .padding(.bottom, 34)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 38))
                .foregroundStyle(SauceColor.onSurfaceVariant)
            Spacer()
            Text("소스 마스터")
                .font(.title2.weight(.bold))
                .foregroundStyle(SauceColor.primaryContainer)
                .underline(color: SauceColor.primaryContainer)
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.bold))
                .foregroundStyle(SauceColor.primaryContainer)
        }
        .padding(.top, 18)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SauceColor.onSurfaceVariant)
            Text("새로운 맛을 찾아보세요...")
                .font(.subheadline)
                .foregroundStyle(SauceColor.muted)
            Spacer()
            Text("검색")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(SauceColor.primaryContainer)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(SauceColor.surfaceLowest)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 8)
    }

    private var weeklyPopular: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("주간 인기 TOP 5")
                    .font(.title.weight(.black))
                Spacer()
                Text("전체보기")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SauceColor.primaryContainer)
            }

            ForEach(viewModel.recipes.prefix(2)) { recipe in
                NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                    RecipeCard(recipe: recipe)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .recipeDetail(let id):
                RecipeDetailView(recipeID: id, apiClient: apiClient, authStore: authStore)
            case .publicProfile:
                PublicProfilePlaceholderView()
            case .loginRequired:
                LoginRequiredView(authStore: authStore)
            }
        }
    }

    private var latestRecipes: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("최신 소스 조합")
                    .font(.title.weight(.black))
                Spacer()
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(SauceColor.primaryContainer)
            }
            ForEach(viewModel.recipes.dropFirst(2).prefix(3)) { recipe in
                CompactRecipeRow(recipe: recipe)
            }
        }
        .padding(18)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
