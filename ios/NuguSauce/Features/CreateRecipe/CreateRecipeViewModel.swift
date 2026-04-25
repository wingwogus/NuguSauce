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
    @Published private(set) var ingredients: [EditableIngredient] = []
    @Published private(set) var quickAddIngredients: [IngredientDTO] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var didSubmit = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var submittedRecipeTitle: String?

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
        let titles = quickAddIngredients.reduce(into: [String]()) { result, ingredient in
            let title = categoryTitle(for: ingredient)
            if !result.contains(title) {
                result.append(title)
            }
        }

        return titles.map { title in
            IngredientQuickAddSection(
                title: title,
                ingredients: quickAddIngredients.filter { categoryTitle(for: $0) == title }
            )
        }
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

    func addNextIngredient() {
        guard let ingredient = quickAddIngredients.first(where: { candidate in
            !ingredients.contains { $0.ingredient.id == candidate.id }
        }) else {
            errorMessage = "추가할 재료가 없습니다."
            return
        }
        addIngredient(ingredient)
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
        ingredients[index].ratio = ratio
        ingredients[index].amount = ratio
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
                    amount: $0.amount,
                    unit: $0.unit,
                    ratio: $0.ratio
                )
            }
        )
    }

    func submit() async {
        guard !isSubmitting else {
            return
        }

        errorMessage = nil
        didSubmit = false
        submittedRecipeTitle = nil

        guard isAuthenticated else {
            errorMessage = "로그인이 필요합니다."
            return
        }
        guard canSubmit else {
            errorMessage = "소스 이름과 재료를 입력해주세요."
            return
        }

        do {
            isSubmitting = true
            let recipe = try await apiClient.createRecipe(makeRequest())
            submittedRecipeTitle = recipe.title
            didSubmit = true
            isSubmitting = false
        } catch {
            isSubmitting = false
            if let apiError = error as? ApiError {
                errorMessage = apiError.message
            } else {
                errorMessage = "레시피를 등록하지 못했어요."
            }
        }
    }

    private static func categoryTitle(for category: String?) -> String {
        let trimmed = category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else {
            return "기타"
        }

        switch trimmed.lowercased() {
        case "acid":
            return "산미"
        case "aromatic":
            return "향신 채소"
        case "herb":
            return "허브"
        case "oil":
            return "오일"
        case "pungent":
            return "알싸한 맛"
        case "sauce":
            return "소스"
        case "seasoning":
            return "조미료"
        case "spicy":
            return "매운맛"
        case "sweetener":
            return "단맛"
        case "topping":
            return "토핑"
        case "umami":
            return "감칠맛"
        default:
            return trimmed
        }
    }
}
