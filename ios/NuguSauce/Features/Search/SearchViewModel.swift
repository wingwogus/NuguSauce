import Foundation

struct SearchFilterDraft: Equatable {
    var tagIDs: Set<Int>
    var ingredientIDs: Set<Int>

    static let empty = SearchFilterDraft(tagIDs: [], ingredientIDs: [])
}

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

    var selectedTagSummary: String {
        let selectedTags = tags.filter { selectedTagIDs.contains($0.id) }
        guard let firstTag = selectedTags.first else {
            return "전체 맛"
        }
        guard selectedTags.count > 1 else {
            return firstTag.name
        }
        return "\(firstTag.name) 외 \(selectedTags.count - 1)개"
    }

    var selectedIngredientSummary: String {
        let selectedIngredients = ingredients.filter { selectedIngredientIDs.contains($0.id) }
        guard let firstIngredient = selectedIngredients.first else {
            return "전체 재료"
        }
        guard selectedIngredients.count > 1 else {
            return firstIngredient.name
        }
        return "\(firstIngredient.name) 외 \(selectedIngredients.count - 1)개"
    }

    var queryModel: RecipeListQuery {
        RecipeListQuery(keyword: query, tagIDs: selectedTagIDs, ingredientIDs: selectedIngredientIDs, sort: sort)
    }

    func makeFilterDraft() -> SearchFilterDraft {
        SearchFilterDraft(tagIDs: selectedTagIDs, ingredientIDs: selectedIngredientIDs)
    }

    func applyFilterDraft(_ draft: SearchFilterDraft) {
        selectedTagIDs = draft.tagIDs
        selectedIngredientIDs = draft.ingredientIDs
    }

    func resetFilterDraft() -> SearchFilterDraft {
        .empty
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

    func clearTags() {
        selectedTagIDs.removeAll()
    }

    func clearIngredients() {
        selectedIngredientIDs.removeAll()
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
