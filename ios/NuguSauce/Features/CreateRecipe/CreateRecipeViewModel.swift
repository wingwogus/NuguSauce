import Foundation

struct EditableIngredient: Identifiable, Equatable {
    let id = UUID()
    let ingredient: IngredientDTO
    var amount: Double
    var unit: String
    var ratio: Double
}

struct IngredientQuickAddSection: Identifiable, Equatable {
    var id: String { title }
    let title: String
    let ingredients: [IngredientDTO]
}

@MainActor
final class CreateRecipeViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var tips = ""
    @Published var ingredientSearchText = ""
    @Published private(set) var ingredients: [EditableIngredient] = []
    @Published private(set) var quickAddIngredients: [IngredientDTO] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var didSubmit = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var submittedRecipeTitle: String?
    @Published private(set) var submittedRecipeID: Int?

    private let apiClient: APIClientProtocol
    private let authStore: AuthSessionStoreProtocol

    init(apiClient: APIClientProtocol, authStore: AuthSessionStoreProtocol) {
        self.apiClient = apiClient
        self.authStore = authStore
    }

    var isAuthenticated: Bool {
        authStore.isAuthenticated
    }

    var canSubmit: Bool {
        isAuthenticated &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !ingredients.isEmpty
    }

    var quickAddSections: [IngredientQuickAddSection] {
        groupedIngredientSections(from: filteredQuickAddIngredients)
    }

    var quickAddVisibleIngredientCount: Int {
        quickAddSections.reduce(0) { total, section in
            total + section.ingredients.count
        }
    }

    var hasIngredientSearchText: Bool {
        !normalizedIngredientSearchText.isEmpty
    }

    func load() async {
        do {
            let allIngredients = try await apiClient.fetchIngredients()
            quickAddIngredients = allIngredients
        } catch {
            errorMessage = "재료 목록을 불러오지 못했어요."
        }
    }

    func addIngredient(_ ingredient: IngredientDTO) {
        errorMessage = nil
        guard !ingredients.contains(where: { $0.ingredient.id == ingredient.id }) else {
            return
        }
        ingredients.append(EditableIngredient(ingredient: ingredient, amount: 1.0, unit: "비율", ratio: 1.0))
    }

    func clearIngredientSearch() {
        ingredientSearchText = ""
    }

    func removeIngredient(_ editableIngredient: EditableIngredient) {
        ingredients.removeAll { $0.id == editableIngredient.id }
    }

    func isIngredientSelected(_ ingredient: IngredientDTO) -> Bool {
        ingredients.contains { $0.ingredient.id == ingredient.id }
    }

    func categoryTitle(for ingredient: IngredientDTO) -> String {
        Self.categoryTitle(for: ingredient.category)
    }

    func updateRatio(for editableIngredient: EditableIngredient, ratio: Double) {
        guard let index = ingredients.firstIndex(where: { $0.id == editableIngredient.id }) else {
            return
        }
        let truncatedRatio = RecipeMeasurementFormatter.truncatedTenths(ratio)
        ingredients[index].ratio = truncatedRatio
        ingredients[index].amount = truncatedRatio
    }

    func makeRequest() -> CreateRecipeRequestDTO {
        CreateRecipeRequestDTO(
            title: title,
            description: description.isEmpty ? "맛있는 소스 조합" : description,
            imageUrl: nil,
            tips: tips.isEmpty ? "재료를 잘 섞어 농도를 맞춰주세요." : tips,
            ingredients: ingredients.map {
                CreateRecipeIngredientRequestDTO(
                    ingredientId: $0.ingredient.id,
                    amount: RecipeMeasurementFormatter.truncatedTenths($0.amount),
                    unit: $0.unit,
                    ratio: RecipeMeasurementFormatter.truncatedTenths($0.ratio)
                )
            }
        )
    }

    @discardableResult
    func submit() async -> Int? {
        guard !isSubmitting else {
            return nil
        }

        errorMessage = nil
        didSubmit = false
        submittedRecipeTitle = nil
        submittedRecipeID = nil

        guard isAuthenticated else {
            errorMessage = "로그인이 필요합니다."
            return nil
        }
        guard canSubmit else {
            errorMessage = "소스 이름과 재료를 입력해주세요."
            return nil
        }

        do {
            isSubmitting = true
            defer { isSubmitting = false }
            let recipe = try await apiClient.createRecipe(makeRequest())
            submittedRecipeTitle = recipe.title
            submittedRecipeID = recipe.id
            didSubmit = true
            return recipe.id
        } catch {
            isSubmitting = false
            if let apiError = error as? ApiError {
                errorMessage = apiError.message
            } else {
                errorMessage = "레시피를 등록하지 못했어요."
            }
            return nil
        }
    }

    private static func categoryTitle(for category: String?) -> String {
        categoryTitles[normalizedCategory(category)] ?? "기타"
    }

    private var normalizedIngredientSearchText: String {
        ingredientSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredQuickAddIngredients: [IngredientDTO] {
        let query = normalizedIngredientSearchText
        guard !query.isEmpty else {
            return quickAddIngredients
        }

        return quickAddIngredients.filter { ingredient in
            ingredient.name.localizedCaseInsensitiveContains(query) ||
            categoryTitle(for: ingredient).localizedCaseInsensitiveContains(query)
        }
    }

    private func groupedIngredientSections(from sourceIngredients: [IngredientDTO]) -> [IngredientQuickAddSection] {
        let groupedIngredients = Dictionary(grouping: sourceIngredients) { ingredient in
            Self.normalizedCategory(ingredient.category)
        }

        return Self.categoryOrder.compactMap { category in
            guard let ingredients = groupedIngredients[category],
                  let title = Self.categoryTitles[category] else {
                return nil
            }

            return IngredientQuickAddSection(
                title: title,
                ingredients: ingredients.sorted { lhs, rhs in
                    lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            )
        }
    }

    private static let categoryOrder = [
        "sauce_paste",
        "oil",
        "vinegar_citrus",
        "fresh_aromatic",
        "dry_seasoning",
        "sweet_dairy",
        "topping_seed",
        "protein",
        "other"
    ]

    private static let categoryTitles = [
        "sauce_paste": "소스/장류",
        "oil": "오일류",
        "vinegar_citrus": "식초/과즙",
        "fresh_aromatic": "채소/향신 재료",
        "dry_seasoning": "가루/시즈닝",
        "sweet_dairy": "당류/유제품",
        "topping_seed": "견과/씨앗 토핑",
        "protein": "고기/단백질",
        "other": "기타"
    ]

    private static func normalizedCategory(_ category: String?) -> String {
        let trimmed = category?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard categoryTitles.keys.contains(trimmed) else {
            return "other"
        }
        return trimmed
    }
}
