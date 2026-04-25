import Foundation

struct EditableIngredient: Identifiable, Equatable {
    let id = UUID()
    let ingredient: IngredientDTO
    var amount: Double
    var unit: String
    var ratio: Double
}

@MainActor
final class CreateRecipeViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var tips = ""
    @Published var selectedTagNames: Set<String> = ["매콤"]
    @Published private(set) var ingredients: [EditableIngredient] = []
    @Published private(set) var quickAddIngredients: [IngredientDTO] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var didSubmit = false

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

    func load() async {
        do {
            let allIngredients = try await apiClient.fetchIngredients()
            quickAddIngredients = allIngredients
            if ingredients.isEmpty {
                ingredients = Array(allIngredients.prefix(2)).enumerated().map { index, ingredient in
                    EditableIngredient(
                        ingredient: ingredient,
                        amount: index == 0 ? 3.0 : 1.5,
                        unit: "비율",
                        ratio: index == 0 ? 3.0 : 1.5
                    )
                }
            }
        } catch {
            errorMessage = "재료 목록을 불러오지 못했어요."
        }
    }

    func addIngredient(_ ingredient: IngredientDTO) {
        guard !ingredients.contains(where: { $0.ingredient.id == ingredient.id }) else {
            return
        }
        ingredients.append(EditableIngredient(ingredient: ingredient, amount: 1.0, unit: "비율", ratio: 1.0))
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
        guard isAuthenticated else {
            errorMessage = "로그인이 필요합니다."
            return
        }
        guard canSubmit else {
            errorMessage = "소스 이름과 재료를 입력해주세요."
            return
        }

        do {
            _ = try await apiClient.createRecipe(makeRequest())
            didSubmit = true
        } catch {
            errorMessage = "레시피를 등록하지 못했어요."
        }
    }
}
