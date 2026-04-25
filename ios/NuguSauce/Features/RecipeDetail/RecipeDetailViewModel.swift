import Foundation

@MainActor
final class RecipeDetailViewModel: ObservableObject {
    @Published private(set) var detail: RecipeDetailDTO?
    @Published private(set) var reviews: [RecipeReviewDTO] = []
    @Published var selectedRating = 5
    @Published var reviewText = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var didSubmitReview = false

    let recipeID: Int
    private let apiClient: APIClientProtocol
    private let authStore: AuthSessionStoreProtocol

    init(recipeID: Int, apiClient: APIClientProtocol, authStore: AuthSessionStoreProtocol) {
        self.recipeID = recipeID
        self.apiClient = apiClient
        self.authStore = authStore
    }

    var canSubmitReview: Bool {
        authStore.isAuthenticated && !reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let detail = apiClient.fetchRecipeDetail(id: recipeID)
            async let reviews = apiClient.fetchReviews(recipeID: recipeID)
            self.detail = try await detail
            self.reviews = try await reviews
        } catch {
            errorMessage = "상세 정보를 불러오지 못했어요."
        }
        isLoading = false
    }

    func submitReview() async {
        guard canSubmitReview else {
            errorMessage = authStore.isAuthenticated ? "리뷰 내용을 입력해주세요." : "로그인이 필요합니다."
            return
        }

        do {
            let review = try await apiClient.createReview(
                recipeID: recipeID,
                request: CreateReviewRequestDTO(rating: selectedRating, text: reviewText, tasteTagIds: [1, 2])
            )
            reviews.insert(review, at: 0)
            reviewText = ""
            didSubmitReview = true
        } catch {
            errorMessage = "리뷰를 저장하지 못했어요."
        }
    }
}
