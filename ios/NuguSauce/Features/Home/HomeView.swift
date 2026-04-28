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
            .padding(.bottom, 34)
        }
        .background(SauceColor.surface.ignoresSafeArea())
        .navigationBarHidden(true)
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
            await viewModel.load()
        }
    }

    private var header: some View {
        SauceScreenTitle(title: "NuguSauce")
            .padding(.horizontal, SauceSpacing.screen)
    }

    private var searchBar: some View {
        SauceSearchBar(action: openSearch)
            .padding(.horizontal, SauceSpacing.screen)
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
            .padding(.horizontal, SauceSpacing.screen)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(viewModel.weeklyPopularRecipes) { recipe in
                        NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                            RecipeCard(recipe: recipe)
                                .frame(width: 286)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, SauceSpacing.screen)
                .padding(.bottom, 10)
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
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(viewModel.latestRecipeCards) { recipe in
                        NavigationLink(value: AppRoute.recipeDetail(recipe.id)) {
                            CompactRecipeRow(recipe: recipe)
                                .frame(width: 306)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 18)
        .background(SauceColor.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, SauceSpacing.screen)
    }
}
