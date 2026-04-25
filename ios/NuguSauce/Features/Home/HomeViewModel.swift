import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var recipes: [RecipeSummaryDTO] = []
    @Published var sort: RecipeSort = .popular
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            recipes = try await apiClient.fetchRecipes(query: RecipeListQuery(sort: sort))
        } catch {
            errorMessage = "레시피를 불러오지 못했어요."
        }
        isLoading = false
    }
}
