import SwiftUI

struct HomeView: View {
    let apiClient: APIClientProtocol
    let authStore: AuthSessionStore
    let openSearch: () -> Void
    @StateObject private var viewModel: HomeViewModel

    init(apiClient: APIClientProtocol, authStore: AuthSessionStore, openSearch: @escaping () -> Void) {
        self.apiClient = apiClient
        self.authStore = authStore
        self.openSearch = openSearch
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
            Text("NuguSauce")
                .font(.title2.weight(.bold))
                .foregroundStyle(SauceColor.primaryContainer)
                .underline(color: SauceColor.primaryContainer)
            Spacer()
            SauceIconButton(
                systemName: "magnifyingglass",
                background: SauceColor.surfaceLowest,
                action: openSearch
            )
        }
        .padding(.top, 18)
    }

    private var searchBar: some View {
        SauceSearchBar(action: openSearch)
    }

    private var weeklyPopular: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("주간 인기 TOP 5")
                    .font(.title.weight(.black))
                Spacer()
                Button("전체보기", action: openSearch)
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
                LoginRequiredView(apiClient: apiClient, authStore: authStore)
            }
        }
    }

    private var latestRecipes: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("최신 소스 조합")
                    .font(.title.weight(.black))
                Spacer()
                Button(action: openSearch) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(SauceColor.primaryContainer)
                }
                .buttonStyle(.plain)
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
