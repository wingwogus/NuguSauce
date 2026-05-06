import Foundation

@MainActor
final class RecipeDetailViewModel: ObservableObject {
    @Published private(set) var detail: RecipeDetailDTO?
    @Published private(set) var reviews: [RecipeReviewDTO] = []
    @Published private(set) var availableTasteTags: [TagDTO] = []
    @Published private(set) var isLoadingTasteTags = false
    @Published private(set) var tasteTagErrorMessage: String?
    @Published var selectedRating = 5
    @Published var selectedTasteTagIDs: Set<Int> = []
    @Published var reviewText = ""
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var didSubmitReview = false
    @Published private(set) var isFavorite = false
    @Published private(set) var isUpdatingFavorite = false
    @Published private(set) var pendingConsentStatus: ConsentStatusDTO?
    @Published private(set) var isAcceptingConsents = false

    let recipeID: Int
    private let apiClient: APIClientProtocol
    private let authStore: AuthSessionStoreProtocol
    let maxReviewTextLength = 500

    init(recipeID: Int, apiClient: APIClientProtocol, authStore: AuthSessionStoreProtocol) {
        self.recipeID = recipeID
        self.apiClient = apiClient
        self.authStore = authStore
    }

    var canSubmitReview: Bool {
        authStore.isAuthenticated && !reviewText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isAuthenticated: Bool {
        authStore.isAuthenticated
    }

    func beginReviewDraft() {
        selectedRating = 5
        selectedTasteTagIDs.removeAll()
        reviewText = ""
        didSubmitReview = false
        errorMessage = nil
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let detail = apiClient.fetchRecipeDetail(id: recipeID)
            async let reviews = apiClient.fetchReviews(recipeID: recipeID)
            async let tags = apiClient.fetchTags()
            let loadedDetail = try await detail
            self.detail = loadedDetail
            isFavorite = loadedDetail.isFavorited
            self.reviews = try await reviews
            do {
                availableTasteTags = try await tags
                tasteTagErrorMessage = nil
            } catch {
                availableTasteTags = []
                tasteTagErrorMessage = "맛 태그를 불러오지 못했어요."
            }
        } catch {
            errorMessage = "상세 정보를 불러오지 못했어요."
        }
        isLoading = false
    }

    func loadTasteTagsIfNeeded() async {
        guard availableTasteTags.isEmpty, !isLoadingTasteTags else {
            return
        }

        isLoadingTasteTags = true
        tasteTagErrorMessage = nil
        do {
            availableTasteTags = try await apiClient.fetchTags()
        } catch {
            tasteTagErrorMessage = "맛 태그를 불러오지 못했어요."
        }
        isLoadingTasteTags = false
    }

    func toggleTasteTag(_ tag: TagDTO) {
        if selectedTasteTagIDs.contains(tag.id) {
            selectedTasteTagIDs.remove(tag.id)
        } else {
            selectedTasteTagIDs.insert(tag.id)
        }
    }

    func trimReviewTextIfNeeded() {
        guard reviewText.count > maxReviewTextLength else {
            return
        }
        reviewText = String(reviewText.prefix(maxReviewTextLength))
    }

    @discardableResult
    func submitReview() async -> Bool {
        guard canSubmitReview else {
            errorMessage = authStore.isAuthenticated ? "리뷰 내용을 입력해주세요." : "로그인이 필요합니다."
            return false
        }

        do {
            let review = try await apiClient.createReview(
                recipeID: recipeID,
                request: CreateReviewRequestDTO(
                    rating: selectedRating,
                    text: reviewText,
                    tasteTagIds: selectedTasteTagIDs.sorted()
                )
            )
            reviews.insert(review, at: 0)
            reviewText = ""
            selectedTasteTagIDs.removeAll()
            didSubmitReview = true
            return true
        } catch let error as ApiError {
            if error.code == ApiErrorCode.consentRequired {
                await loadConsentStatusAfterBlockedWrite()
            } else {
                errorMessage = error.userVisibleMessage(default: "리뷰를 저장하지 못했어요.")
            }
            return false
        } catch {
            errorMessage = "리뷰를 저장하지 못했어요."
            return false
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

    func toggleFavorite() async {
        guard authStore.isAuthenticated else {
            errorMessage = "로그인이 필요합니다."
            return
        }
        guard !isUpdatingFavorite else {
            return
        }

        errorMessage = nil
        isUpdatingFavorite = true
        defer {
            isUpdatingFavorite = false
        }
        let previousFavoriteState = isFavorite
        let nextFavoriteState = !previousFavoriteState
        isFavorite = nextFavoriteState
        do {
            if nextFavoriteState {
                _ = try await apiClient.addFavorite(recipeID: recipeID)
            } else {
                try await apiClient.deleteFavorite(recipeID: recipeID)
            }
        } catch {
            if let apiError = error as? ApiError {
                switch apiError.code {
                case ApiErrorCode.duplicateFavorite:
                    isFavorite = true
                case ApiErrorCode.favoriteNotFound:
                    isFavorite = false
                default:
                    isFavorite = previousFavoriteState
                    errorMessage = apiError.userVisibleMessage(default: "찜 상태를 변경하지 못했어요.")
                }
            } else {
                isFavorite = previousFavoriteState
                errorMessage = "찜 상태를 변경하지 못했어요."
            }
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
}
