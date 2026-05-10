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
    @Published private(set) var isFavorite = false
    @Published private(set) var isUpdatingFavorite = false
    @Published private(set) var isDeleting = false
    @Published private(set) var didDelete = false
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

    var canMutateRecipe: Bool {
        guard let authorId = detail?.authorId,
              let memberId = authStore.currentSession?.memberId else {
            return false
        }
        return authorId == memberId
    }

    func applyUpdatedRecipe(_ updatedRecipe: RecipeDetailDTO) {
        guard updatedRecipe.id == recipeID else {
            return
        }
        detail = updatedRecipe
        isFavorite = updatedRecipe.isFavorited
    }

    func beginReviewDraft() {
        selectedRating = 5
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
            let loadedDetail = try await detail
            self.detail = loadedDetail
            isFavorite = loadedDetail.isFavorited
            self.reviews = try await reviews
        } catch {
            errorMessage = "상세 정보를 불러오지 못했어요."
        }
        isLoading = false
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
                    text: reviewText
                )
            )
            reviews.insert(review, at: 0)
            reviewText = ""
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

        guard LegalPolicyContent.canDisplayAllMissingPolicies(in: pendingConsentStatus) else {
            errorMessage = LegalPolicyContent.missingDocumentMessage
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

    @discardableResult
    func deleteRecipe() async -> Bool {
        guard canMutateRecipe else {
            errorMessage = "삭제 권한이 없어요."
            return false
        }
        guard !isDeleting else {
            return false
        }

        isDeleting = true
        errorMessage = nil
        defer {
            isDeleting = false
        }

        do {
            try await apiClient.deleteRecipe(id: recipeID)
            didDelete = true
            NotificationCenter.default.post(
                name: RecipeMutationEvents.didDelete,
                object: nil,
                userInfo: [RecipeMutationEvents.recipeIDKey: recipeID]
            )
            return true
        } catch let error as ApiError {
            if error.code == ApiErrorCode.consentRequired {
                await loadConsentStatusAfterBlockedWrite()
            } else {
                errorMessage = error.userVisibleMessage(default: "소스를 삭제하지 못했어요.")
            }
            return false
        } catch {
            errorMessage = "소스를 삭제하지 못했어요."
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
}
