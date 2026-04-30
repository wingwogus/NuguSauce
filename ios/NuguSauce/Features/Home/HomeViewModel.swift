import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var hotRecipes: [RecipeSummaryDTO] = []
    @Published private(set) var recipes: [RecipeSummaryDTO] = []
    @Published private(set) var recentRecipes: [RecipeSummaryDTO] = []
    @Published var sort: RecipeSort = .popular
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    var hotHeroRecipe: RecipeSummaryDTO? {
        hotRecipes.first ?? recipes.first
    }

    var popularRankingRecipes: [RecipeSummaryDTO] {
        Array(recipes.prefix(5))
    }

    var latestGridRecipes: [RecipeSummaryDTO] {
        Array(recentRecipes.prefix(4))
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            let hotRecipes = try await apiClient.fetchRecipes(query: RecipeListQuery(sort: .hot))
            let popularRecipes = try await apiClient.fetchRecipes(query: RecipeListQuery(sort: .popular))
            let latestRecipes = try await apiClient.fetchRecipes(query: RecipeListQuery(sort: .recent))
            self.hotRecipes = hotRecipes
            recipes = popularRecipes
            recentRecipes = latestRecipes
        } catch {
            errorMessage = "레시피를 불러오지 못했어요."
        }
        isLoading = false
    }
}
