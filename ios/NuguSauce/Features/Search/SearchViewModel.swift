import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published var selectedTagIDs: Set<Int> = []
    @Published var selectedIngredientIDs: Set<Int> = []
    @Published var sort: RecipeSort = .popular
    @Published private(set) var tags: [TagDTO] = []
    @Published private(set) var ingredients: [IngredientDTO] = []
    @Published private(set) var results: [RecipeSummaryDTO] = []

    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    var queryModel: RecipeListQuery {
        RecipeListQuery(keyword: query, tagIDs: selectedTagIDs, ingredientIDs: selectedIngredientIDs, sort: sort)
    }

    func load() async {
        do {
            async let tags = apiClient.fetchTags()
            async let ingredients = apiClient.fetchIngredients()
            self.tags = try await tags
            self.ingredients = try await ingredients
            try await search()
        } catch {
            results = []
        }
    }

    func toggleTag(_ tag: TagDTO) {
        if selectedTagIDs.contains(tag.id) {
            selectedTagIDs.remove(tag.id)
        } else {
            selectedTagIDs.insert(tag.id)
        }
    }

    func toggleIngredient(_ ingredient: IngredientDTO) {
        if selectedIngredientIDs.contains(ingredient.id) {
            selectedIngredientIDs.remove(ingredient.id)
        } else {
            selectedIngredientIDs.insert(ingredient.id)
        }
    }

    func search() async throws {
        results = try await apiClient.fetchRecipes(query: queryModel)
    }
}
