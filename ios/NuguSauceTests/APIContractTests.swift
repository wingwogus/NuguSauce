import XCTest
@testable import NuguSauce

final class APIContractTests: XCTestCase {
    func testEnvelopeSuccessDecodes() throws {
        let json = """
        {
          "success": true,
          "data": {
            "id": 1,
            "title": "건희 소스",
            "description": "고소하고 매콤한 인기 조합",
            "imageUrl": null,
            "authorType": "CURATED",
            "visibility": "VISIBLE",
            "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
            "reviewTags": [{ "id": 1, "name": "고소함", "count": 12 }],
            "favoriteCount": 9,
            "isFavorite": false,
            "createdAt": "2026-04-25T00:00:00Z"
          },
          "error": null
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(ApiEnvelope<RecipeSummaryDTO>.self, from: json)

        XCTAssertTrue(envelope.success)
        XCTAssertEqual(envelope.data?.title, "건희 소스")
        XCTAssertEqual(envelope.data?.displayFavoriteCount, 9)
        XCTAssertEqual(envelope.data?.isFavorited, false)
        XCTAssertNil(envelope.error)
    }

    func testRecipeSummaryDecodesFavoriteState() throws {
        let json = """
        {
          "id": 1,
          "title": "건희 소스",
          "description": "고소하고 매콤한 인기 조합",
          "imageUrl": null,
          "authorType": "CURATED",
          "visibility": "VISIBLE",
          "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
          "reviewTags": [],
          "favoriteCount": 11,
          "isFavorite": true,
          "createdAt": "2026-04-25T00:00:00Z"
        }
        """.data(using: .utf8)!

        let recipe = try JSONDecoder().decode(RecipeSummaryDTO.self, from: json)

        XCTAssertTrue(recipe.isFavorited)
        XCTAssertEqual(recipe.displayFavoriteCount, 11)
    }

    func testRecipeDetailDecodesAuthorName() throws {
        let json = """
        {
          "id": 101,
          "title": "마늘 듬뿍 고소 소스",
          "description": "마늘 향이 강한 커스텀 조합",
          "imageUrl": null,
          "tips": "땅콩소스를 먼저 푼다",
          "authorType": "USER",
          "authorId": 7,
          "authorName": "소스장인",
          "visibility": "VISIBLE",
          "ingredients": [],
          "reviewTags": [],
          "ratingSummary": { "averageRating": 0.0, "reviewCount": 0 },
          "favoriteCount": 5,
          "isFavorite": true,
          "createdAt": "2026-04-25T00:00:00Z",
          "lastReviewedAt": null
        }
        """.data(using: .utf8)!

        let detail = try JSONDecoder().decode(RecipeDetailDTO.self, from: json)

        XCTAssertEqual(detail.authorId, 7)
        XCTAssertEqual(detail.displayAuthorName, "소스장인")
        XCTAssertEqual(detail.displayFavoriteCount, 5)
        XCTAssertTrue(detail.isFavorited)
    }

    func testRecipeDetailDecodesWithoutAuthorNameForCompatibility() throws {
        let json = """
        {
          "id": 101,
          "title": "마늘 듬뿍 고소 소스",
          "description": "마늘 향이 강한 커스텀 조합",
          "imageUrl": null,
          "tips": "땅콩소스를 먼저 푼다",
          "authorType": "USER",
          "visibility": "VISIBLE",
          "ingredients": [],
          "reviewTags": [],
          "ratingSummary": { "averageRating": 0.0, "reviewCount": 0 },
          "createdAt": "2026-04-25T00:00:00Z",
          "lastReviewedAt": null
        }
        """.data(using: .utf8)!

        let detail = try JSONDecoder().decode(RecipeDetailDTO.self, from: json)

        XCTAssertNil(detail.displayAuthorName)
        XCTAssertFalse(detail.isFavorited)
    }

    func testEnvelopeFailureDecodesStableErrorCode() throws {
        let json = """
        {
          "success": false,
          "data": null,
          "error": {
            "code": "RECIPE_005",
            "message": "recipe.duplicate_review",
            "detail": null
          }
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(ApiEnvelope<EmptyResponse>.self, from: json)

        XCTAssertFalse(envelope.success)
        XCTAssertEqual(envelope.error?.code, ApiErrorCode.duplicateReview)
    }

    func testCreateRecipeRequestDoesNotEncodeTasteClassificationFields() throws {
        let request = CreateRecipeRequestDTO(
            title: "내 소스",
            description: "고소하고 살짝 매운 조합",
            imageId: nil,
            tips: nil,
            ingredients: [
                CreateRecipeIngredientRequestDTO(ingredientId: 1, amount: 1.0, unit: "스푼", ratio: nil)
            ]
        )

        let data = try JSONEncoder().encode(request)
        let encoded = String(decoding: data, as: UTF8.self)

        XCTAssertFalse(encoded.contains("spiceLevel"))
        XCTAssertFalse(encoded.contains("richnessLevel"))
        XCTAssertFalse(encoded.contains("tagIds"))
        XCTAssertFalse(encoded.contains("imageUrl"))
        XCTAssertFalse(encoded.contains("tips"))
    }

    func testIngredientResponseDecodesPhysicalCategory() throws {
        let json = """
        {
          "id": 2,
          "name": "땅콩소스",
          "category": "sauce_paste"
        }
        """.data(using: .utf8)!

        let ingredient = try JSONDecoder().decode(IngredientDTO.self, from: json)

        XCTAssertEqual(ingredient.name, "땅콩소스")
        XCTAssertEqual(ingredient.category, "sauce_paste")
    }

    func testReviewResponseDecodesAuthorName() throws {
        let json = """
        {
          "id": 10,
          "recipeId": 1,
          "authorId": 8,
          "authorName": "리뷰장인",
          "rating": 5,
          "text": "고소하고 초보자도 먹기 좋았어요",
          "tasteTags": [{ "id": 1, "name": "고소함" }],
          "createdAt": "2026-04-25T01:00:00Z"
        }
        """.data(using: .utf8)!

        let review = try JSONDecoder().decode(RecipeReviewDTO.self, from: json)

        XCTAssertEqual(review.authorId, 8)
        XCTAssertEqual(review.authorName, "리뷰장인")
    }

    func testKakaoLoginResponseDecodesMemberProfileSetupState() throws {
        let json = """
        {
          "accessToken": "access-token",
          "refreshToken": "refresh-token",
          "member": {
            "id": 1,
            "nickname": null,
            "displayName": "사용자 1",
            "profileSetupRequired": true
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(KakaoLoginResponseDTO.self, from: json)

        XCTAssertEqual(response.accessToken, "access-token")
        XCTAssertEqual(response.member.id, 1)
        XCTAssertEqual(response.member.displayName, "사용자 1")
        XCTAssertEqual(response.member.profileSetupRequired, true)
    }

    func testBackendClientBuildsRecipeListRequest() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": [
            {
              "id": 1,
              "title": "건희 소스",
              "description": "고소하고 매콤한 인기 조합",
              "imageUrl": null,
              "authorType": "CURATED",
              "visibility": "VISIBLE",
              "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
              "reviewTags": [{ "id": 1, "name": "고소함", "count": 12 }],
              "isFavorite": true,
              "createdAt": "2026-04-25T00:00:00Z"
            }
          ],
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolTestTransport.self]
        let session = URLSession(configuration: configuration)
        let authStore = ContractTestAuthSessionStore()
        let client = BackendAPIClient(
            configuration: APIConfiguration(baseURL: URL(string: "http://127.0.0.1:8080")!),
            session: session,
            authStore: authStore
        )

        let recipes = try await client.fetchRecipes(
            query: RecipeListQuery(keyword: "건희", tagIDs: [2, 1], ingredientIDs: [13], sort: .rating)
        )

        XCTAssertEqual(recipes.first?.title, "건희 소스")
        XCTAssertEqual(recipes.first?.isFavorited, true)
        let requestURL = try XCTUnwrap(URLProtocolTestTransport.lastRequest?.url)
        XCTAssertEqual(requestURL.path, "/api/v1/recipes")
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "q", value: "건희")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "tagIds", value: "1")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "tagIds", value: "2")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "ingredientIds", value: "13")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "sort", value: "rating")) == true)
    }

    func testBackendClientDecodesKakaoLoginEnvelopeWithMemberProfile() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": {
            "accessToken": "access-token",
            "refreshToken": "refresh-token",
            "member": {
              "id": 1,
              "nickname": null,
              "displayName": "사용자 1",
              "profileSetupRequired": true
            }
          },
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()

        let response = try await client.authenticateWithKakao(
            idToken: "id-token",
            nonce: "nonce",
            kakaoAccessToken: "kakao-access-token"
        )

        XCTAssertEqual(response.accessToken, "access-token")
        XCTAssertEqual(response.member.displayName, "사용자 1")
        XCTAssertEqual(response.member.profileSetupRequired, true)
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/auth/kakao/login")
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testBackendClientFetchesMyMemberProfile() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": {
            "id": 7,
            "nickname": "소스장인",
            "displayName": "소스장인",
            "profileSetupRequired": false
          },
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()

        let member = try await client.fetchMyMember()

        XCTAssertEqual(member.id, 7)
        XCTAssertEqual(member.nickname, "소스장인")
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/members/me")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
    }

    func testBackendClientFetchesPublicMemberProfile() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": {
            "id": 8,
            "nickname": "마라초보",
            "displayName": "마라초보",
            "profileSetupRequired": false,
            "recipes": [
              {
                "id": 81,
                "title": "마라초보 소스",
                "description": "직접 올린 소스",
                "imageUrl": null,
                "authorType": "USER",
                "visibility": "VISIBLE",
                "ratingSummary": {
                  "averageRating": 0.0,
                  "reviewCount": 0
                },
                "reviewTags": [],
                "isFavorite": false,
                "createdAt": "2026-04-25T00:00:00Z"
              }
            ],
            "favoriteRecipes": [
              {
                "id": 82,
                "title": "찜한 소스",
                "description": "찜한 공개 소스",
                "imageUrl": null,
                "authorType": "CURATED",
                "visibility": "VISIBLE",
                "ratingSummary": {
                  "averageRating": 4.5,
                  "reviewCount": 4
                },
                "reviewTags": [],
                "isFavorite": false,
                "createdAt": "2026-04-25T00:00:00Z"
              }
            ]
          },
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()

        let member = try await client.fetchMember(id: 8)

        XCTAssertEqual(member.id, 8)
        XCTAssertEqual(member.displayName, "마라초보")
        XCTAssertEqual(member.recipes?.map(\.id), [81])
        XCTAssertEqual(member.favoriteRecipes?.map(\.id), [82])
        XCTAssertEqual(member.recipes?.first?.isFavorited, false)
        XCTAssertEqual(member.favoriteRecipes?.first?.isFavorited, false)
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/members/8")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testBackendClientFetchesRecipeDetailWithOptionalAuthorization() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": {
            "id": 10,
            "title": "건희 소스",
            "description": "고소하고 매콤한 인기 조합",
            "imageUrl": null,
            "tips": "참기름은 마지막에 넣는다",
            "authorType": "CURATED",
            "authorId": null,
            "authorName": "NuguSauce",
            "visibility": "VISIBLE",
            "ingredients": [],
            "reviewTags": [],
            "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
            "isFavorite": true,
            "createdAt": "2026-04-25T00:00:00Z",
            "lastReviewedAt": null
          },
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()

        let detail = try await client.fetchRecipeDetail(id: 10)

        XCTAssertTrue(detail.isFavorited)
        XCTAssertNil(detail.authorId)
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/recipes/10")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
    }

    func testBackendClientCreatesImageUploadIntent() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": {
            "imageId": 50,
            "upload": {
              "url": "https://api.cloudinary.com/v1_1/demo/image/upload",
              "method": "POST",
              "headers": {},
              "fields": {
                "api_key": "api-key",
                "public_id": "nugusauce/recipes/1/image",
                "timestamp": "1777399200",
                "signature": "signature"
              },
              "fileField": "file",
              "expiresAt": "2026-04-28T14:30:00Z"
            },
            "constraints": {
              "maxBytes": 5242880,
              "allowedContentTypes": ["image/jpeg", "image/png", "image/heic", "image/heif"]
            }
          },
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()
        let intent = try await client.createImageUploadIntent(
            ImageUploadIntentRequestDTO(contentType: "image/jpeg", byteSize: 2000, fileExtension: "jpg")
        )

        XCTAssertEqual(intent.imageId, 50)
        XCTAssertEqual(intent.upload.fileField, "file")
        XCTAssertEqual(intent.upload.fields["signature"], "signature")
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/media/images/upload-intent")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
    }

    func testBackendClientUploadsImageToSignedTarget() async throws {
        URLProtocolTestTransport.responseData = "{}".data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()
        let intent = ImageUploadIntentDTO(
            imageId: 50,
            upload: ImageUploadTargetDTO(
                url: "https://upload.example.test/image/upload",
                method: "POST",
                headers: [:],
                fields: ["signature": "signature", "public_id": "nugusauce/recipes/1/image"],
                fileField: "file",
                expiresAt: "2026-04-28T14:30:00Z"
            ),
            constraints: ImageUploadConstraintsDTO(maxBytes: 5_242_880, allowedContentTypes: ["image/jpeg"])
        )

        try await client.uploadImage(
            data: Data([1, 2, 3]),
            contentType: "image/jpeg",
            fileExtension: "jpg",
            using: intent
        )

        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.host, "upload.example.test")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data") == true)
    }

    func testBackendClientCompletesImageUpload() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": {
            "imageId": 50,
            "imageUrl": "https://res.cloudinary.com/demo/image/upload/f_auto,q_auto/nugusauce/recipes/1/image",
            "width": 800,
            "height": 600
          },
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()
        let image = try await client.completeImageUpload(imageId: 50)

        XCTAssertEqual(image.imageId, 50)
        XCTAssertEqual(image.width, 800)
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/media/images/50/complete")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
    }

    func testBackendClientUpdatesMyMemberProfile() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": {
            "id": 7,
            "nickname": "소스장인",
            "displayName": "소스장인",
            "profileSetupRequired": false
          },
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()

        let member = try await client.updateMyMember(nickname: "소스장인")

        XCTAssertEqual(member.displayName, "소스장인")
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/members/me")
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
    }

    private func makeBackendClient() -> BackendAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolTestTransport.self]
        let session = URLSession(configuration: configuration)
        return BackendAPIClient(
            configuration: APIConfiguration(baseURL: URL(string: "http://127.0.0.1:8080")!),
            session: session,
            authStore: ContractTestAuthSessionStore()
        )
    }
}

private final class ContractTestAuthSessionStore: AuthSessionStoreProtocol {
    private(set) var currentSession: AuthSession? = AuthSession(
        displayName: "테스터",
        accessToken: "real-access-token",
        refreshToken: "real-refresh-token"
    )

    var isAuthenticated: Bool { currentSession != nil }
    var accessToken: String? { currentSession?.accessToken }

    func restore() {}

    @discardableResult
    func saveSession(accessToken: String, refreshToken: String?, displayName: String?) -> Bool {
        currentSession = AuthSession(displayName: displayName ?? "테스터", accessToken: accessToken, refreshToken: refreshToken)
        return true
    }

    func updateMemberProfile(_ member: MemberProfileDTO) {
        guard let currentSession else {
            return
        }
        self.currentSession = AuthSession(
            displayName: member.displayName,
            accessToken: currentSession.accessToken,
            refreshToken: currentSession.refreshToken,
            memberId: member.id,
            nickname: member.nickname,
            profileSetupRequired: member.profileSetupRequired ?? false
        )
    }

    func clear() {
        currentSession = nil
    }
}

private final class URLProtocolTestTransport: URLProtocol {
    static var responseData = Data()
    static var statusCode = 200
    static var lastRequest: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
