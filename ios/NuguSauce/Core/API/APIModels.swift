import Foundation

struct ApiEnvelope<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let error: ApiError?
}

struct EmptyResponse: Decodable, Equatable {
    init() {}
}

struct ApiError: Decodable, Equatable, Error {
    let code: String
    let message: String
    let detail: String?

    private enum CodingKeys: String, CodingKey {
        case code
        case message
        case detail
    }

    init(code: String, message: String, detail: String?) {
        self.code = code
        self.message = message
        self.detail = detail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        message = try container.decode(String.self, forKey: .message)
        do {
            detail = try container.decodeIfPresent(String.self, forKey: .detail)
        } catch {
            detail = nil
        }
    }
}

enum ApiErrorCode {
    static let unauthorized = "AUTH_001"
    static let forbidden = "AUTH_002"
    static let invalidKakaoToken = "AUTH_009"
    static let kakaoNonceMismatch = "AUTH_010"
    static let kakaoNonceReplay = "AUTH_011"
    static let kakaoVerifiedEmailRequired = "AUTH_012"
    static let invalidNickname = "USER_003"
    static let duplicateNickname = "USER_004"
    static let invalidInput = "COMMON_001"
    static let invalidJSON = "COMMON_002"
    static let internalError = "COMMON_999"
    static let resourceNotFound = "RESOURCE_001"
    static let duplicateReview = "RECIPE_005"
    static let invalidRating = "RECIPE_007"
    static let invalidIngredientAmount = "RECIPE_008"
    static let duplicateFavorite = "RECIPE_010"
    static let favoriteNotFound = "RECIPE_011"
    static let unsupportedMediaContentType = "MEDIA_002"
    static let mediaFileTooLarge = "MEDIA_003"
    static let mediaUploadNotVerified = "MEDIA_004"
    static let mediaAlreadyAttached = "MEDIA_006"
    static let mediaProviderUnavailable = "MEDIA_007"
    static let consentRequired = "CONSENT_001"
}

extension ApiError {
    func userVisibleMessage(default fallback: String) -> String {
        switch code {
        case ApiErrorCode.unauthorized:
            return "로그인이 필요합니다."
        case ApiErrorCode.forbidden:
            return "접근 권한이 없어요."
        case ApiErrorCode.invalidInput, ApiErrorCode.invalidJSON:
            return "입력한 내용을 확인해주세요."
        case ApiErrorCode.resourceNotFound:
            return "요청한 정보를 찾을 수 없어요."
        case ApiErrorCode.invalidNickname:
            return "2~20자의 한글, 영문, 숫자, 밑줄만 사용할 수 있어요."
        case ApiErrorCode.duplicateNickname:
            return "이미 사용 중인 닉네임입니다."
        case ApiErrorCode.duplicateReview:
            return "이미 리뷰를 남긴 소스입니다."
        case ApiErrorCode.invalidRating:
            return "평점을 확인해주세요."
        case ApiErrorCode.invalidIngredientAmount:
            return "재료 비율을 확인해주세요."
        case ApiErrorCode.unsupportedMediaContentType:
            return "지원하지 않는 이미지 형식입니다."
        case ApiErrorCode.mediaFileTooLarge:
            return "이미지 파일 크기가 너무 큽니다."
        case ApiErrorCode.mediaUploadNotVerified, ApiErrorCode.mediaProviderUnavailable:
            return "이미지 업로드를 잠시 사용할 수 없어요."
        case ApiErrorCode.mediaAlreadyAttached:
            return "이미 사용 중인 이미지입니다."
        case ApiErrorCode.consentRequired:
            return "필수 약관과 개인정보/콘텐츠 정책 동의가 필요해요."
        case ApiErrorCode.internalError:
            return fallback
        default:
            return fallback
        }
    }
}

enum RecipeSort: String, CaseIterable, Identifiable {
    case hot
    case popular
    case recent
    case rating

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hot:
            return "핫한순"
        case .popular:
            return "인기순"
        case .recent:
            return "최신순"
        case .rating:
            return "평점순"
        }
    }
}

struct RecipeListQuery: Equatable {
    var keyword: String = ""
    var tagIDs: Set<Int> = []
    var ingredientIDs: Set<Int> = []
    var sort: RecipeSort = .popular
}

struct TokenResponseDTO: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
}

struct MemberProfileDTO: Codable, Equatable, Identifiable {
    let id: Int
    let nickname: String?
    let displayName: String
    let profileImageUrl: String?
    let profileSetupRequired: Bool?
    let recipes: [RecipeSummaryDTO]?
    let favoriteRecipes: [RecipeSummaryDTO]?

    init(
        id: Int,
        nickname: String?,
        displayName: String,
        profileImageUrl: String? = nil,
        profileSetupRequired: Bool?,
        recipes: [RecipeSummaryDTO]? = nil,
        favoriteRecipes: [RecipeSummaryDTO]? = nil
    ) {
        self.id = id
        self.nickname = nickname
        self.displayName = displayName
        self.profileImageUrl = profileImageUrl
        self.profileSetupRequired = profileSetupRequired
        self.recipes = recipes
        self.favoriteRecipes = favoriteRecipes
    }
}

struct KakaoLoginResponseDTO: Codable, Equatable {
    let accessToken: String
    let refreshToken: String
    let member: MemberProfileDTO
}

struct ConsentStatusDTO: Codable, Equatable {
    let policies: [ConsentPolicyDTO]
    let missingPolicies: [ConsentPolicyDTO]
    let requiredConsentsAccepted: Bool
}

struct ConsentPolicyDTO: Codable, Equatable, Identifiable {
    let policyType: String
    let version: String
    let title: String
    let url: String
    let required: Bool
    let accepted: Bool
    let activeFrom: String

    var id: String {
        "\(policyType):\(version)"
    }
}

struct ConsentAcceptRequestDTO: Codable, Equatable {
    let acceptedPolicies: [ConsentPolicyAcceptanceDTO]
}

struct ConsentPolicyAcceptanceDTO: Codable, Equatable {
    let policyType: String
    let version: String
}

enum APIClientError: Error, Equatable {
    case invalidBaseURL(String)
    case invalidURL
    case invalidResponse
    case missingAuthentication
    case missingData
    case unsuccessfulEnvelope
    case httpStatus(Int)
}

protocol APIClientProtocol {
    func fetchRecipes(query: RecipeListQuery) async throws -> [RecipeSummaryDTO]
    func fetchRecipeDetail(id: Int) async throws -> RecipeDetailDTO
    func fetchReviews(recipeID: Int) async throws -> [RecipeReviewDTO]
    func fetchIngredients() async throws -> [IngredientDTO]
    func fetchTags() async throws -> [TagDTO]
    func createImageUploadIntent(_ request: ImageUploadIntentRequestDTO) async throws -> ImageUploadIntentDTO
    func uploadImage(
        data: Data,
        contentType: String,
        fileExtension: String,
        using intent: ImageUploadIntentDTO
    ) async throws
    func completeImageUpload(imageId: Int) async throws -> VerifiedImageDTO
    func createRecipe(_ request: CreateRecipeRequestDTO) async throws -> RecipeDetailDTO
    func createReview(recipeID: Int, request: CreateReviewRequestDTO) async throws -> RecipeReviewDTO
    func fetchMyRecipes() async throws -> [RecipeSummaryDTO]
    func fetchFavoriteRecipes() async throws -> [RecipeSummaryDTO]
    func addFavorite(recipeID: Int) async throws -> FavoriteResponseDTO
    func deleteFavorite(recipeID: Int) async throws
    func fetchMyMember() async throws -> MemberProfileDTO
    func fetchMember(id: Int) async throws -> MemberProfileDTO
    func updateMyMember(nickname: String, profileImageId: Int?) async throws -> MemberProfileDTO
    func updateMyMember(nickname: String, profileImageId: Int?, accessToken: String) async throws -> MemberProfileDTO
    func authenticateWithKakao(idToken: String, nonce: String, kakaoAccessToken: String) async throws -> KakaoLoginResponseDTO
    func reissue(refreshToken: String) async throws -> TokenResponseDTO
    func fetchConsentStatus() async throws -> ConsentStatusDTO
    func fetchConsentStatus(accessToken: String) async throws -> ConsentStatusDTO
    func acceptConsents(_ request: ConsentAcceptRequestDTO) async throws -> ConsentStatusDTO
    func acceptConsents(_ request: ConsentAcceptRequestDTO, accessToken: String) async throws -> ConsentStatusDTO
}
