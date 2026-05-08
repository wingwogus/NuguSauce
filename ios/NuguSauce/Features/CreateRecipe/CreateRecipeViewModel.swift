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

enum RecipeRatioInputRules {
    static let range: ClosedRange<Double> = 0.1...5.0
    static let step = 0.1

    static func normalizedRatio(_ value: Double) -> Double {
        guard value.isFinite else {
            return range.lowerBound
        }

        let clampedValue = min(max(value, range.lowerBound), range.upperBound)
        return RecipeMeasurementFormatter.truncatedTenths(clampedValue + 0.000_000_001)
    }

    static func ratio(from inputText: String) -> Double? {
        let normalizedText = inputText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !normalizedText.isEmpty else {
            return nil
        }

        guard let ratio = Double(normalizedText), ratio.isFinite else {
            return nil
        }

        return ratio
    }
}

@MainActor
final class CreateRecipeViewModel: ObservableObject {
    @Published var title = ""
    @Published var description = ""
    @Published var ingredientSearchText = ""
    @Published private(set) var ingredients: [EditableIngredient] = []
    @Published private(set) var quickAddIngredients: [IngredientDTO] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var didSubmit = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var isUploadingImage = false
    @Published private(set) var submittedRecipeTitle: String?
    @Published private(set) var submittedRecipeID: Int?
    @Published private(set) var selectedPhotoData: Data?
    @Published private(set) var selectedPhotoContentType = "image/jpeg"
    @Published private(set) var selectedPhotoFileExtension = "jpg"
    @Published var photoRightsAccepted = false
    @Published private(set) var pendingConsentStatus: ConsentStatusDTO?
    @Published private(set) var isAcceptingConsents = false

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
        !ingredients.isEmpty &&
        (selectedPhotoData == nil || photoRightsAccepted)
    }

    var hasSelectedPhoto: Bool {
        selectedPhotoData != nil
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

    func toggleIngredient(_ ingredient: IngredientDTO) {
        errorMessage = nil
        if let selectedIngredient = ingredients.first(where: { $0.ingredient.id == ingredient.id }) {
            removeIngredient(selectedIngredient)
            return
        }

        addIngredient(ingredient)
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
        let normalizedRatio = RecipeRatioInputRules.normalizedRatio(ratio)
        ingredients[index].ratio = normalizedRatio
        ingredients[index].amount = normalizedRatio
    }

    @discardableResult
    func updateRatio(for editableIngredient: EditableIngredient, inputText: String) -> Bool {
        guard let ratio = RecipeRatioInputRules.ratio(from: inputText) else {
            return false
        }

        updateRatio(for: editableIngredient, ratio: ratio)
        return true
    }

    func setSelectedPhoto(
        data: Data,
        contentType: String = "image/jpeg",
        fileExtension: String = "jpg"
    ) {
        selectedPhotoData = data
        selectedPhotoContentType = contentType
        selectedPhotoFileExtension = fileExtension
        photoRightsAccepted = false
        errorMessage = nil
    }

    func clearSelectedPhoto() {
        selectedPhotoData = nil
        selectedPhotoContentType = "image/jpeg"
        selectedPhotoFileExtension = "jpg"
        photoRightsAccepted = false
    }

    func makeRequest(imageId: Int? = nil) -> CreateRecipeRequestDTO {
        CreateRecipeRequestDTO(
            title: title,
            description: description.isEmpty ? "맛있는 소스 조합" : description,
            imageId: imageId,
            tips: nil,
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
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !ingredients.isEmpty else {
            errorMessage = "소스 이름과 재료를 입력해주세요."
            return nil
        }
        guard selectedPhotoData == nil || photoRightsAccepted else {
            errorMessage = "직접 촬영했거나 사용할 권리가 있는 사진만 올릴 수 있어요."
            return nil
        }

        do {
            isSubmitting = true
            defer {
                isSubmitting = false
                isUploadingImage = false
            }
            let imageId = try await uploadSelectedPhotoIfNeeded()
            let recipe = try await apiClient.createRecipe(makeRequest(imageId: imageId))
            submittedRecipeTitle = recipe.title
            submittedRecipeID = recipe.id
            didSubmit = true
            return recipe.id
        } catch let error as ApiError {
            isSubmitting = false
            if error.code == ApiErrorCode.consentRequired {
                await loadConsentStatusAfterBlockedWrite()
            } else {
                errorMessage = error.userVisibleMessage(default: "소스를 등록하지 못했어요.")
            }
            return nil
        } catch {
            isSubmitting = false
            errorMessage = "소스를 등록하지 못했어요."
            return nil
        }
    }

    func acceptRequiredConsents() async -> Bool {
        guard !isAcceptingConsents,
              let pendingConsentStatus else {
            return false
        }

        isAcceptingConsents = true
        errorMessage = nil
        defer {
            isAcceptingConsents = false
        }

        do {
            let updatedStatus = try await apiClient.acceptConsents(
                ConsentAcceptRequestDTO(
                    acceptedPolicies: pendingConsentStatus.missingPolicies.map {
                        ConsentPolicyAcceptanceDTO(policyType: $0.policyType, version: $0.version)
                    }
                )
            )
            if updatedStatus.requiredConsentsAccepted {
                self.pendingConsentStatus = nil
                return true
            }
            self.pendingConsentStatus = updatedStatus
            errorMessage = "필수 동의를 완료해주세요."
            return false
        } catch let error as ApiError {
            errorMessage = error.userVisibleMessage(default: "필수 동의를 저장하지 못했어요.")
            return false
        } catch {
            errorMessage = "필수 동의를 저장하지 못했어요."
            return false
        }
    }

    private func loadConsentStatusAfterBlockedWrite() async {
        do {
            pendingConsentStatus = try await apiClient.fetchConsentStatus()
            errorMessage = "필수 약관과 개인정보/콘텐츠 정책 동의가 필요해요."
        } catch let error as ApiError {
            errorMessage = error.userVisibleMessage(default: "필수 동의 상태를 확인하지 못했어요.")
        } catch {
            errorMessage = "필수 동의 상태를 확인하지 못했어요."
        }
    }

    private func uploadSelectedPhotoIfNeeded() async throws -> Int? {
        guard let selectedPhotoData else {
            return nil
        }
        isUploadingImage = true
        let intent = try await apiClient.createImageUploadIntent(
            ImageUploadIntentRequestDTO(
                contentType: selectedPhotoContentType,
                byteSize: selectedPhotoData.count,
                fileExtension: selectedPhotoFileExtension
            )
        )
        try await apiClient.uploadImage(
            data: selectedPhotoData,
            contentType: selectedPhotoContentType,
            fileExtension: selectedPhotoFileExtension,
            using: intent
        )
        let verifiedImage = try await apiClient.completeImageUpload(imageId: intent.imageId)
        isUploadingImage = false
        return verifiedImage.imageId
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
