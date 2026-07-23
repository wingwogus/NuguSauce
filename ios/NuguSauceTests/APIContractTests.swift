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
            "visibility": "VISIBLE",
            "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
            "tags": [{ "id": 1, "name": "고소함" }],
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
          "visibility": "VISIBLE",
          "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
          "tags": [],
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
          "authorId": 7,
          "authorName": "소스장인",
          "authorProfileImageUrl": "https://cdn.example.test/profile/7.jpg",
          "visibility": "VISIBLE",
          "ingredients": [],
          "tags": [],
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
        XCTAssertEqual(detail.authorProfileImageUrl, "https://cdn.example.test/profile/7.jpg")
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
          "visibility": "VISIBLE",
          "ingredients": [],
          "tags": [],
          "ratingSummary": { "averageRating": 0.0, "reviewCount": 0 },
          "favoriteCount": 0,
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

    func testCreateRecipeRequestEncodesOnlyWritableFields() throws {
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
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(Set(object.keys), ["title", "description", "ingredients"])
    }

    func testUpdateRecipeRequestEncodesOnlyWritableFields() throws {
        let request = UpdateRecipeRequestDTO(
            title: "수정한 소스",
            description: "더 고소하게 바꾼 조합",
            imageId: 50,
            tips: nil,
            ingredients: [
                CreateRecipeIngredientRequestDTO(ingredientId: 1, amount: 1.0, unit: "스푼", ratio: 1.0)
            ]
        )

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(Set(object.keys), ["title", "description", "imageId", "ingredients"])
    }

    func testRecipeNotFoundErrorUsesResourceNotFoundMessage() {
        let error = ApiError(code: ApiErrorCode.recipeNotFound, message: "recipe.not_found", detail: nil)

        XCTAssertEqual(error.userVisibleMessage(default: "fallback"), "요청한 정보를 찾을 수 없어요.")
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
          "authorProfileImageUrl": "https://cdn.example.test/profile/8.jpg",
          "rating": 5,
          "text": "고소하고 초보자도 먹기 좋았어요",
          "createdAt": "2026-04-25T01:00:00Z"
        }
        """.data(using: .utf8)!

        let review = try JSONDecoder().decode(RecipeReviewDTO.self, from: json)

        XCTAssertEqual(review.authorId, 8)
        XCTAssertEqual(review.authorName, "리뷰장인")
        XCTAssertEqual(review.authorProfileImageUrl, "https://cdn.example.test/profile/8.jpg")
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
            "profileImageUrl": "https://cdn.example.test/profile/1.jpg",
            "profileSetupRequired": true
          },
          "onboarding": {
            "status": "required",
            "requiredActions": [
              "accept_required_policies",
              "setup_profile"
            ]
          }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(KakaoLoginResponseDTO.self, from: json)

        XCTAssertEqual(response.accessToken, "access-token")
        XCTAssertEqual(response.member.id, 1)
        XCTAssertEqual(response.member.displayName, "사용자 1")
        XCTAssertEqual(response.member.profileImageUrl, "https://cdn.example.test/profile/1.jpg")
        XCTAssertEqual(response.member.profileSetupRequired, true)
        XCTAssertEqual(response.onboarding.status, .required)
        XCTAssertEqual(response.onboarding.requiredActions, [.acceptRequiredPolicies, .setupProfile])
    }

    func testKakaoLoginResponseWithoutOnboardingFailsDecoding() throws {
        let json = """
        {
          "accessToken": "access-token",
          "refreshToken": "refresh-token",
          "member": {
            "id": 1,
            "nickname": "소스장인",
            "displayName": "소스장인",
            "profileImageUrl": null,
            "profileSetupRequired": false
          }
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(KakaoLoginResponseDTO.self, from: json))
    }

    func testKakaoLoginResponseWithUnknownOnboardingStatusFailsDecoding() throws {
        let json = """
        {
          "accessToken": "access-token",
          "refreshToken": "refresh-token",
          "member": {
            "id": 1,
            "nickname": "소스장인",
            "displayName": "소스장인",
            "profileImageUrl": null,
            "profileSetupRequired": false
          },
          "onboarding": {
            "status": "unknown",
            "requiredActions": []
          }
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(KakaoLoginResponseDTO.self, from: json))
    }

    func testKakaoLoginResponseWithUnknownOnboardingActionFailsDecoding() throws {
        let json = """
        {
          "accessToken": "access-token",
          "refreshToken": "refresh-token",
          "member": {
            "id": 1,
            "nickname": "소스장인",
            "displayName": "소스장인",
            "profileImageUrl": null,
            "profileSetupRequired": false
          },
          "onboarding": {
            "status": "required",
            "requiredActions": ["unknown_action"]
          }
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(KakaoLoginResponseDTO.self, from: json))
    }

    func testBackendClientBuildsRecipeSearchPageRequest() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": {
            "items": [
              {
                "id": 1,
                "title": "건희 소스",
                "description": "고소하고 매콤한 인기 조합",
                "imageUrl": null,
                "visibility": "VISIBLE",
                "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
                "tags": [{ "id": 1, "name": "고소함" }],
                "favoriteCount": 9,
                "isFavorite": true,
                "createdAt": "2026-04-25T00:00:00Z"
              }
            ],
            "nextCursor": "cursor-1",
            "hasNext": true
          },
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

        let page = try await client.fetchRecipeSearchPage(
            query: RecipeListQuery(keyword: "건희", tagIDs: [2, 1], ingredientIDs: [13], sort: .recent),
            cursor: "cursor-0",
            limit: 20
        )

        XCTAssertEqual(page.items.first?.title, "건희 소스")
        XCTAssertEqual(page.items.first?.isFavorited, true)
        XCTAssertEqual(page.nextCursor, "cursor-1")
        XCTAssertEqual(page.hasNext, true)
        let requestURL = try XCTUnwrap(URLProtocolTestTransport.lastRequest?.url)
        XCTAssertEqual(requestURL.path, "/api/v1/recipes")
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
        let components = try XCTUnwrap(URLComponents(url: requestURL, resolvingAgainstBaseURL: false))
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "q", value: "건희")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "tagIds", value: "1")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "tagIds", value: "2")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "ingredientIds", value: "13")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "sort", value: "recent")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "limit", value: "20")) == true)
        XCTAssertTrue(components.queryItems?.contains(URLQueryItem(name: "cursor", value: "cursor-0")) == true)
    }

    func testRecipeSearchPageDecodesLegacyArrayEnvelope() throws {
        let json = """
        {
          "success": true,
          "data": [
            {
              "id": 1,
              "title": "건희 소스",
              "description": "고소하고 매콤한 인기 조합",
              "imageUrl": null,
              "visibility": "VISIBLE",
              "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
              "tags": [{ "id": 1, "name": "고소함" }],
              "favoriteCount": 9,
              "isFavorite": false,
              "createdAt": "2026-04-25T00:00:00Z"
            }
          ],
          "error": null
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(ApiEnvelope<RecipeSearchPageDTO>.self, from: json)

        let page = try XCTUnwrap(envelope.data)
        XCTAssertEqual(page.items.map(\.title), ["건희 소스"])
        XCTAssertNil(page.nextCursor)
        XCTAssertFalse(page.hasNext)
    }

    func testBackendClientFetchesHomeFeed() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": {
            "popularTop": [],
            "recentTop": []
          },
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

        let home = try await client.fetchHome()

        XCTAssertEqual(home.popularTop, [])
        XCTAssertEqual(home.recentTop, [])
        let requestURL = try XCTUnwrap(URLProtocolTestTransport.lastRequest?.url)
        XCTAssertEqual(requestURL.path, "/api/v1/home")
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
    }

    func testBackendClientFetchHomeFallsBackToRecipeSearchWhenAnonymousHomeRequiresAuth() async throws {
        URLProtocolTestTransport.queuedResponses = [
            (
                statusCode: 401,
                data: """
                {
                  "success": false,
                  "data": null,
                  "error": {
                    "code": "AUTH_001",
                    "message": "error.unauthorized",
                    "detail": "Authorization header missing or invalid"
                  }
                }
                """.data(using: .utf8)!
            ),
            (
                statusCode: 200,
                data: """
                {
                  "success": true,
                  "data": [
                    {
                      "id": 1,
                      "title": "운영 인기 소스",
                      "description": "구버전 운영 응답",
                      "imageUrl": null,
                      "visibility": "VISIBLE",
                      "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
                      "tags": [{ "id": 1, "name": "고소함" }],
                      "favoriteCount": 9,
                      "isFavorite": false,
                      "createdAt": "2026-04-25T00:00:00Z"
                    }
                  ],
                  "error": null
                }
                """.data(using: .utf8)!
            ),
            (
                statusCode: 200,
                data: """
                {
                  "success": true,
                  "data": [
                    {
                      "id": 2,
                      "title": "운영 최신 소스",
                      "description": "구버전 운영 응답",
                      "imageUrl": null,
                      "visibility": "VISIBLE",
                      "ratingSummary": { "averageRating": 0.0, "reviewCount": 0 },
                      "tags": [{ "id": 2, "name": "매콤함" }],
                      "favoriteCount": 1,
                      "isFavorite": false,
                      "createdAt": "2026-05-02T00:00:00Z"
                    }
                  ],
                  "error": null
                }
                """.data(using: .utf8)!
            )
        ]
        URLProtocolTestTransport.requests = []
        URLProtocolTestTransport.lastRequest = nil

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolTestTransport.self]
        let session = URLSession(configuration: configuration)
        let client = BackendAPIClient(
            configuration: APIConfiguration(baseURL: URL(string: "http://127.0.0.1:8080")!),
            session: session,
            authStore: ContractTestAuthSessionStore(currentSession: nil)
        )

        let home = try await client.fetchHome()

        XCTAssertFalse(home.popularTop.isEmpty)
        XCTAssertFalse(home.recentTop.isEmpty)
        let requests = URLProtocolTestTransport.requests
        XCTAssertEqual(requests.first?.url?.path, "/api/v1/home")
        XCTAssertNil(requests.first?.value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(requests.filter { $0.url?.path == "/api/v1/recipes" }.count, 2)
        let requestedSorts = Set(requests.compactMap { request -> String? in
            URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "sort" })?
                .value
        })
        XCTAssertTrue(requestedSorts.contains("popular"))
        XCTAssertTrue(requestedSorts.contains("recent"))
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
              "profileImageUrl": "https://cdn.example.test/profile/1.jpg",
              "profileSetupRequired": true
            },
            "onboarding": {
              "status": "required",
              "requiredActions": [
                "setup_profile"
              ]
            }
          },
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil
        URLProtocolTestTransport.lastRequestBody = nil

        let client = makeBackendClient()

        let response = try await client.authenticateWithKakao(
            idToken: "id-token",
            nonce: "nonce",
            kakaoAccessToken: "kakao-access-token"
        )

        XCTAssertEqual(response.accessToken, "access-token")
        XCTAssertEqual(response.member.displayName, "사용자 1")
        XCTAssertEqual(response.member.profileImageUrl, "https://cdn.example.test/profile/1.jpg")
        XCTAssertEqual(response.member.profileSetupRequired, true)
        XCTAssertEqual(response.onboarding.status, .required)
        XCTAssertEqual(response.onboarding.requiredActions, [.setupProfile])
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/auth/kakao/login")
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testBackendClientPostsAppleLoginRequestAndDecodesEnvelope() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": {
            "accessToken": "access-token",
            "refreshToken": "refresh-token",
            "member": {
              "id": 1,
              "nickname": "소스장인",
              "displayName": "소스장인",
              "profileImageUrl": null,
              "profileSetupRequired": false
            },
            "onboarding": {
              "status": "complete",
              "requiredActions": []
            }
          },
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil
        URLProtocolTestTransport.lastRequestBody = nil

        let client = makeBackendClient()

        let response = try await client.authenticateWithApple(
            identityToken: "apple-id-token",
            nonce: "apple-raw-nonce",
            authorizationCode: "apple-authorization-code",
            userIdentifier: "apple-user-id"
        )

        XCTAssertEqual(response.accessToken, "access-token")
        XCTAssertEqual(response.member.displayName, "소스장인")
        XCTAssertEqual(response.onboarding.status, .complete)
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/auth/apple/login")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(URLProtocolTestTransport.lastRequestBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["identityToken"], "apple-id-token")
        XCTAssertEqual(json["nonce"], "apple-raw-nonce")
        XCTAssertEqual(json["authorizationCode"], "apple-authorization-code")
        XCTAssertEqual(json["userIdentifier"], "apple-user-id")
    }

    func testBackendClientReissuesExpiredStoredSessionAndRetriesOnce() async throws {
        URLProtocolTestTransport.queuedResponses = [
            (statusCode: 401, data: unauthorizedEnvelope()),
            (statusCode: 200, data: tokenEnvelope(accessToken: "rotated-access", refreshToken: "rotated-refresh")),
            (statusCode: 200, data: memberProfileEnvelope(nickname: "소스장인", profileImageId: nil))
        ]
        URLProtocolTestTransport.requests = []
        let authStore = ContractTestAuthSessionStore()
        let client = makeBackendClient(authStore: authStore)

        let member = try await client.fetchMyMember()

        XCTAssertEqual(member.nickname, "소스장인")
        XCTAssertEqual(authStore.currentSession?.accessToken, "rotated-access")
        XCTAssertEqual(authStore.currentSession?.refreshToken, "rotated-refresh")
        XCTAssertEqual(authStore.clearCallCount, 0)
        XCTAssertEqual(URLProtocolTestTransport.requests.map(\.url?.path), [
            "/api/v1/members/me",
            "/api/v1/auth/reissue",
            "/api/v1/members/me"
        ])
        XCTAssertEqual(
            URLProtocolTestTransport.requests.map { $0.value(forHTTPHeaderField: "Authorization") },
            ["Bearer real-access-token", nil, "Bearer rotated-access"]
        )
    }

    func testBackendClientClearsMatchingSessionWhenRefreshIsUnauthorized() async {
        URLProtocolTestTransport.queuedResponses = [
            (statusCode: 401, data: unauthorizedEnvelope()),
            (statusCode: 401, data: unauthorizedEnvelope())
        ]
        URLProtocolTestTransport.requests = []
        let authStore = ContractTestAuthSessionStore()
        let client = makeBackendClient(authStore: authStore)

        do {
            _ = try await client.fetchMyMember()
            XCTFail("Expected refresh rejection")
        } catch let error as ApiError {
            XCTAssertEqual(error.code, ApiErrorCode.unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(authStore.currentSession)
        XCTAssertEqual(authStore.clearCallCount, 1)
        XCTAssertEqual(URLProtocolTestTransport.requests.map(\.url?.path), [
            "/api/v1/members/me",
            "/api/v1/auth/reissue"
        ])
    }

    func testBackendClientClearsMatchingSessionForAnyRefreshHTTPUnauthorizedResponse() async {
        URLProtocolTestTransport.queuedResponses = [
            (statusCode: 401, data: unauthorizedEnvelope()),
            (statusCode: 401, data: unauthorizedEnvelope(code: "AUTH_999"))
        ]
        URLProtocolTestTransport.requests = []
        let authStore = ContractTestAuthSessionStore()
        let client = makeBackendClient(authStore: authStore)

        do {
            _ = try await client.fetchMyMember()
            XCTFail("Expected refresh rejection")
        } catch let error as ApiError {
            XCTAssertEqual(error.code, "AUTH_999")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(authStore.currentSession)
        XCTAssertEqual(authStore.clearCallCount, 1)
        XCTAssertEqual(URLProtocolTestTransport.requests.map(\.url?.path), [
            "/api/v1/members/me",
            "/api/v1/auth/reissue"
        ])
    }

    func testBackendClientPreservesSessionWhenRefreshFailsTransiently() async {
        URLProtocolTestTransport.queuedResponses = [
            (statusCode: 401, data: unauthorizedEnvelope()),
            (statusCode: 503, data: serviceUnavailableEnvelope())
        ]
        URLProtocolTestTransport.requests = []
        let authStore = ContractTestAuthSessionStore()
        let client = makeBackendClient(authStore: authStore)

        do {
            _ = try await client.fetchMyMember()
            XCTFail("Expected transient refresh failure")
        } catch let error as APIClientError {
            XCTAssertEqual(error, .httpStatus(503))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(authStore.currentSession?.accessToken, "real-access-token")
        XCTAssertEqual(authStore.currentSession?.refreshToken, "real-refresh-token")
        XCTAssertEqual(authStore.clearCallCount, 0)
    }

    func testBackendClientPreservesSessionWhenRefreshTransportFails() async {
        URLProtocolTestTransport.queuedResponses = [
            (statusCode: 401, data: unauthorizedEnvelope())
        ]
        URLProtocolTestTransport.queuedErrors = [
            nil,
            URLError(.networkConnectionLost)
        ]
        URLProtocolTestTransport.requests = []
        defer {
            URLProtocolTestTransport.queuedErrors = []
        }
        let authStore = ContractTestAuthSessionStore()
        let client = makeBackendClient(authStore: authStore)

        do {
            _ = try await client.fetchMyMember()
            XCTFail("Expected refresh transport failure")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .networkConnectionLost)
        }

        XCTAssertEqual(authStore.currentSession?.accessToken, "real-access-token")
        XCTAssertEqual(authStore.currentSession?.refreshToken, "real-refresh-token")
        XCTAssertEqual(authStore.clearCallCount, 0)
    }

    func testBackendClientPreservesSessionWhenRefreshResponseCannotDecode() async {
        URLProtocolTestTransport.queuedResponses = [
            (statusCode: 401, data: unauthorizedEnvelope()),
            (statusCode: 200, data: Data("not-json".utf8))
        ]
        URLProtocolTestTransport.requests = []
        let authStore = ContractTestAuthSessionStore()
        let client = makeBackendClient(authStore: authStore)

        do {
            _ = try await client.fetchMyMember()
            XCTFail("Expected refresh decoding failure")
        } catch is DecodingError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(authStore.currentSession?.accessToken, "real-access-token")
        XCTAssertEqual(authStore.currentSession?.refreshToken, "real-refresh-token")
        XCTAssertEqual(authStore.clearCallCount, 0)
    }

    func testBackendClientDoesNotRecoverPendingLoginOverride() async {
        URLProtocolTestTransport.queuedResponses = [
            (statusCode: 401, data: unauthorizedEnvelope())
        ]
        URLProtocolTestTransport.requests = []
        let authStore = ContractTestAuthSessionStore()
        let client = makeBackendClient(authStore: authStore)

        do {
            _ = try await client.fetchConsentStatus(accessToken: "pending-login-token")
            XCTFail("Expected pending token rejection")
        } catch let error as ApiError {
            XCTAssertEqual(error.code, ApiErrorCode.unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(URLProtocolTestTransport.requests.count, 1)
        XCTAssertEqual(URLProtocolTestTransport.requests.first?.url?.path, "/api/v1/consents/status")
        XCTAssertEqual(authStore.currentSession?.accessToken, "real-access-token")
        XCTAssertEqual(authStore.clearCallCount, 0)
    }

    func testBackendClientDoesNotRetryTwiceWhenRetriedRequestIsUnauthorized() async {
        URLProtocolTestTransport.queuedResponses = [
            (statusCode: 401, data: unauthorizedEnvelope()),
            (statusCode: 200, data: tokenEnvelope(accessToken: "rotated-access", refreshToken: "rotated-refresh")),
            (statusCode: 401, data: unauthorizedEnvelope())
        ]
        URLProtocolTestTransport.requests = []
        let authStore = ContractTestAuthSessionStore()
        let client = makeBackendClient(authStore: authStore)

        do {
            _ = try await client.fetchMyMember()
            XCTFail("Expected retried request rejection")
        } catch let error as ApiError {
            XCTAssertEqual(error.code, ApiErrorCode.unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(URLProtocolTestTransport.requests.count, 3)
        XCTAssertEqual(URLProtocolTestTransport.requests.filter { $0.url?.path == "/api/v1/auth/reissue" }.count, 1)
        XCTAssertEqual(authStore.currentSession?.accessToken, "rotated-access")
        XCTAssertEqual(authStore.clearCallCount, 0)
    }

    func testTokenRefreshCoordinatorCachesSuccessfulRotationForLateUnauthorizedResponse() async throws {
        let coordinator = TokenRefreshCoordinator()
        let counter = RefreshOperationCounter()

        let first = try await coordinator.refresh(for: "rejected-access") {
            await counter.increment()
            return TokenResponseDTO(accessToken: "rotated-access", refreshToken: "rotated-refresh")
        }
        let second = try await coordinator.refresh(for: "rejected-access") {
            await counter.increment()
            return TokenResponseDTO(accessToken: "unexpected-access", refreshToken: "unexpected-refresh")
        }

        XCTAssertEqual(first, second)
        let operationCount = await counter.value
        XCTAssertEqual(operationCount, 1)
    }

    func testTokenRefreshCoordinatorSharesInFlightRotation() async throws {
        let coordinator = TokenRefreshCoordinator()
        let gate = RefreshOperationGate()
        let duplicateCounter = RefreshOperationCounter()

        let firstTask = Task {
            try await coordinator.refresh(for: "rejected-access") {
                await gate.waitForRelease()
                return TokenResponseDTO(accessToken: "rotated-access", refreshToken: "rotated-refresh")
            }
        }
        await gate.waitUntilStarted()
        let secondTask = Task {
            try await coordinator.refresh(for: "rejected-access") {
                await duplicateCounter.increment()
                return TokenResponseDTO(accessToken: "unexpected-access", refreshToken: "unexpected-refresh")
            }
        }
        await Task.yield()
        await gate.release()

        let first = try await firstTask.value
        let second = try await secondTask.value
        let duplicateOperationCount = await duplicateCounter.value
        XCTAssertEqual(first, second)
        XCTAssertEqual(duplicateOperationCount, 0)
    }

    func testBackendClientSharesOneRefreshAcrossConcurrentUnauthorizedRequests() async throws {
        ConcurrentRefreshURLProtocol.reset()
        let authStore = ContractTestAuthSessionStore()
        let client = makeBackendClient(
            authStore: authStore,
            protocolClass: ConcurrentRefreshURLProtocol.self
        )

        async let firstMember = client.fetchMyMember()
        async let secondMember = client.fetchMyMember()
        let members = try await [firstMember, secondMember]
        let counts = ConcurrentRefreshURLProtocol.requestCounts()

        XCTAssertEqual(members.map(\.nickname), ["동시 사용자", "동시 사용자"])
        XCTAssertEqual(counts.rejected, 2)
        XCTAssertEqual(counts.reissue, 1)
        XCTAssertEqual(counts.retried, 2)
        XCTAssertEqual(authStore.currentSession?.accessToken, "rotated-access")
        XCTAssertEqual(authStore.currentSession?.refreshToken, "rotated-refresh")
        XCTAssertEqual(authStore.clearCallCount, 0)
    }

    func testBackendClientLateTerminalRefreshDoesNotClearNewerSession() async {
        URLProtocolTestTransport.queuedResponses = [
            (statusCode: 401, data: unauthorizedEnvelope()),
            (statusCode: 401, data: unauthorizedEnvelope())
        ]
        URLProtocolTestTransport.requests = []
        let authStore = ContractTestAuthSessionStore()
        URLProtocolTestTransport.requestObserver = { request in
            guard request.url?.path == "/api/v1/auth/reissue" else {
                return
            }
            authStore.setCurrentSession(
                AuthSession(
                    displayName: "새 로그인",
                    accessToken: "new-login-access",
                    refreshToken: "new-login-refresh"
                )
            )
        }
        defer {
            URLProtocolTestTransport.requestObserver = nil
        }
        let client = makeBackendClient(authStore: authStore)

        do {
            _ = try await client.fetchMyMember()
            XCTFail("Expected stale refresh rejection")
        } catch let error as ApiError {
            XCTAssertEqual(error.code, ApiErrorCode.unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(authStore.currentSession?.accessToken, "new-login-access")
        XCTAssertEqual(authStore.currentSession?.refreshToken, "new-login-refresh")
        XCTAssertEqual(authStore.clearCallCount, 0)
    }

    func testBackendClientClearsSessionWhenRefreshCredentialIsMissing() async {
        URLProtocolTestTransport.queuedResponses = [
            (statusCode: 401, data: unauthorizedEnvelope())
        ]
        URLProtocolTestTransport.requests = []
        let authStore = ContractTestAuthSessionStore(
            currentSession: AuthSession(
                displayName: "테스터",
                accessToken: "real-access-token",
                refreshToken: nil
            )
        )
        let client = makeBackendClient(authStore: authStore)

        do {
            _ = try await client.fetchMyMember()
            XCTFail("Expected missing refresh rejection")
        } catch let error as ApiError {
            XCTAssertEqual(error.code, ApiErrorCode.unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(authStore.currentSession)
        XCTAssertEqual(authStore.clearCallCount, 1)
        XCTAssertEqual(URLProtocolTestTransport.requests.count, 1)
    }

    func testBackendClientDirectReissueDoesNotRecursivelyRecoverOrClearStoredSession() async {
        URLProtocolTestTransport.queuedResponses = [
            (statusCode: 401, data: unauthorizedEnvelope())
        ]
        URLProtocolTestTransport.requests = []
        let authStore = ContractTestAuthSessionStore()
        let client = makeBackendClient(authStore: authStore)

        do {
            _ = try await client.reissue(refreshToken: "rejected-refresh")
            XCTFail("Expected direct reissue rejection")
        } catch let error as ApiError {
            XCTAssertEqual(error.code, ApiErrorCode.unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(URLProtocolTestTransport.requests.count, 1)
        XCTAssertEqual(URLProtocolTestTransport.requests.first?.url?.path, "/api/v1/auth/reissue")
        XCTAssertNotNil(authStore.currentSession)
        XCTAssertEqual(authStore.clearCallCount, 0)
    }

    func testBackendClientLogoutPostsWithCurrentBearerCredential() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": null,
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.queuedResponses = []
        URLProtocolTestTransport.requests = []
        URLProtocolTestTransport.lastRequestBody = nil
        let client = makeBackendClient()

        try await client.logout()

        let request = try XCTUnwrap(URLProtocolTestTransport.requests.last)
        XCTAssertEqual(request.url?.path, "/api/v1/auth/logout")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
        XCTAssertNil(URLProtocolTestTransport.lastRequestBody)
    }

    func testConsentStatusDecodesMissingPolicies() throws {
        let json = """
        {
          "policies": [
            {
              "policyType": "terms_of_service",
              "version": "2026-05-01",
              "title": "서비스 이용약관",
              "url": "nugusauce://legal/terms",
              "required": true,
              "accepted": false,
              "activeFrom": "2026-05-01T00:00:00Z"
            }
          ],
          "missingPolicies": [
            {
              "policyType": "terms_of_service",
              "version": "2026-05-01",
              "title": "서비스 이용약관",
              "url": "nugusauce://legal/terms",
              "required": true,
              "accepted": false,
              "activeFrom": "2026-05-01T00:00:00Z"
            }
          ],
          "requiredConsentsAccepted": false
        }
        """.data(using: .utf8)!

        let status = try JSONDecoder().decode(ConsentStatusDTO.self, from: json)

        XCTAssertFalse(status.requiredConsentsAccepted)
        XCTAssertEqual(status.missingPolicies.first?.policyType, "terms_of_service")
        XCTAssertEqual(status.missingPolicies.first?.id, "terms_of_service:2026-05-01")
    }

    func testBackendClientFetchesConsentStatus() async throws {
        URLProtocolTestTransport.responseData = consentStatusEnvelope(requiredConsentsAccepted: false)
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()

        let status = try await client.fetchConsentStatus()

        XCTAssertFalse(status.requiredConsentsAccepted)
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/consents/status")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
    }

    func testBackendClientFetchesConsentStatusWithPendingLoginToken() async throws {
        URLProtocolTestTransport.responseData = consentStatusEnvelope(requiredConsentsAccepted: false)
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()

        let status = try await client.fetchConsentStatus(accessToken: "pending-login-token")

        XCTAssertFalse(status.requiredConsentsAccepted)
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/consents/status")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer pending-login-token")
    }

    func testBackendClientAcceptsConsents() async throws {
        URLProtocolTestTransport.responseData = consentStatusEnvelope(requiredConsentsAccepted: true)
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil
        URLProtocolTestTransport.lastRequestBody = nil

        let client = makeBackendClient()

        let status = try await client.acceptConsents(
            ConsentAcceptRequestDTO(
                acceptedPolicies: [
                    ConsentPolicyAcceptanceDTO(policyType: "terms_of_service", version: "2026-05-01")
                ]
            )
        )

        XCTAssertTrue(status.requiredConsentsAccepted)
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/consents/accept")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
        let body = try XCTUnwrap(URLProtocolTestTransport.lastRequestBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let policies = bodyJSON?["acceptedPolicies"] as? [[String: Any]]
        XCTAssertEqual(policies?.first?["policyType"] as? String, "terms_of_service")
        XCTAssertEqual(policies?.first?["version"] as? String, "2026-05-01")
    }

    func testBackendClientAcceptsConsentsWithPendingLoginToken() async throws {
        URLProtocolTestTransport.responseData = consentStatusEnvelope(requiredConsentsAccepted: true)
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()

        let status = try await client.acceptConsents(
            ConsentAcceptRequestDTO(
                acceptedPolicies: [
                    ConsentPolicyAcceptanceDTO(policyType: "terms_of_service", version: "2026-05-01")
                ]
            ),
            accessToken: "pending-login-token"
        )

        XCTAssertTrue(status.requiredConsentsAccepted)
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/consents/accept")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer pending-login-token")
    }

    func testBackendClientFetchesMyMemberProfile() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": {
            "id": 7,
            "nickname": "소스장인",
            "displayName": "소스장인",
            "profileImageUrl": "https://cdn.example.test/profile/7.jpg",
            "profileSetupRequired": false
          },
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil
        URLProtocolTestTransport.lastRequestBody = nil

        let client = makeBackendClient()

        let member = try await client.fetchMyMember()

        XCTAssertEqual(member.id, 7)
        XCTAssertEqual(member.nickname, "소스장인")
        XCTAssertEqual(member.profileImageUrl, "https://cdn.example.test/profile/7.jpg")
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
            "profileImageUrl": "https://cdn.example.test/profile/8.jpg",
            "profileSetupRequired": false,
            "recipes": [
              {
                "id": 81,
                "title": "마라초보 소스",
                "description": "직접 올린 소스",
                "imageUrl": null,
                "visibility": "VISIBLE",
                "ratingSummary": {
                  "averageRating": 0.0,
                  "reviewCount": 0
                },
                "tags": [],
                "favoriteCount": 0,
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
                "visibility": "VISIBLE",
                "ratingSummary": {
                  "averageRating": 4.5,
                  "reviewCount": 4
                },
                "tags": [],
                "favoriteCount": 4,
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
        XCTAssertEqual(member.profileImageUrl, "https://cdn.example.test/profile/8.jpg")
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
            "authorId": null,
            "authorName": "NuguSauce",
            "authorProfileImageUrl": null,
            "visibility": "VISIBLE",
            "ingredients": [],
            "tags": [],
            "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
            "favoriteCount": 9,
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
        URLProtocolTestTransport.responseData = memberProfileEnvelope(nickname: "소스장인", profileImageId: 50)
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil
        URLProtocolTestTransport.lastRequestBody = nil

        let client = makeBackendClient()

        let member = try await client.updateMyMember(nickname: "소스장인", profileImageId: 50)

        XCTAssertEqual(member.displayName, "소스장인")
        XCTAssertEqual(member.profileImageUrl, "https://cdn.example.test/profile/50.jpg")
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/members/me")
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
        let body = try XCTUnwrap(URLProtocolTestTransport.lastRequestBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(bodyJSON?["nickname"] as? String, "소스장인")
        XCTAssertEqual(bodyJSON?["profileImageId"] as? Int, 50)
    }

    func testBackendClientUpdatesMyMemberProfileWithPendingLoginToken() async throws {
        URLProtocolTestTransport.responseData = memberProfileEnvelope(nickname: "새닉네임", profileImageId: nil)
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()

        let member = try await client.updateMyMember(
            nickname: "새닉네임",
            profileImageId: nil,
            accessToken: "pending-login-token"
        )

        XCTAssertEqual(member.displayName, "새닉네임")
        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/members/me")
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer pending-login-token")
    }

    func testBackendClientDeletesMyAccount() async throws {
        URLProtocolTestTransport.responseData = """
        {
          "success": true,
          "data": null,
          "error": null
        }
        """.data(using: .utf8)!
        URLProtocolTestTransport.statusCode = 200
        URLProtocolTestTransport.lastRequest = nil

        let client = makeBackendClient()

        try await client.deleteMyAccount()

        let request = try XCTUnwrap(URLProtocolTestTransport.lastRequest)
        XCTAssertEqual(request.url?.path, "/api/v1/members/me")
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer real-access-token")
    }

    private func memberProfileEnvelope(nickname: String, profileImageId: Int?) -> Data {
        let imageURL = profileImageId.map { "\"https://cdn.example.test/profile/\($0).jpg\"" } ?? "null"
        return """
        {
          "success": true,
          "data": {
            "id": 7,
            "nickname": "\(nickname)",
            "displayName": "\(nickname)",
            "profileImageUrl": \(imageURL),
            "profileSetupRequired": false
          },
          "error": null
        }
        """.data(using: .utf8)!
    }

    private func consentStatusEnvelope(requiredConsentsAccepted: Bool) -> Data {
        let missingPoliciesJSON = requiredConsentsAccepted ? "[]" : """
        [
          {
            "policyType": "terms_of_service",
            "version": "2026-05-01",
            "title": "서비스 이용약관",
            "url": "nugusauce://legal/terms",
            "required": true,
            "accepted": false,
            "activeFrom": "2026-05-01T00:00:00Z"
          }
        ]
        """

        return """
        {
          "success": true,
          "data": {
            "policies": [
              {
                "policyType": "terms_of_service",
                "version": "2026-05-01",
                "title": "서비스 이용약관",
                "url": "nugusauce://legal/terms",
                "required": true,
                "accepted": \(requiredConsentsAccepted ? "true" : "false"),
                "activeFrom": "2026-05-01T00:00:00Z"
              }
            ],
            "missingPolicies": \(missingPoliciesJSON),
            "requiredConsentsAccepted": \(requiredConsentsAccepted ? "true" : "false")
          },
          "error": null
        }
        """.data(using: .utf8)!
    }

    private func unauthorizedEnvelope(code: String = ApiErrorCode.unauthorized) -> Data {
        """
        {
          "success": false,
          "data": null,
          "error": {
            "code": "\(code)",
            "message": "auth.unauthorized",
            "detail": null
          }
        }
        """.data(using: .utf8)!
    }

    private func serviceUnavailableEnvelope() -> Data {
        """
        {
          "success": false,
          "data": null,
          "error": null
        }
        """.data(using: .utf8)!
    }

    private func tokenEnvelope(accessToken: String, refreshToken: String) -> Data {
        """
        {
          "success": true,
          "data": {
            "accessToken": "\(accessToken)",
            "refreshToken": "\(refreshToken)"
          },
          "error": null
        }
        """.data(using: .utf8)!
    }

    private func makeBackendClient(
        authStore: ContractTestAuthSessionStore = ContractTestAuthSessionStore(),
        protocolClass: URLProtocol.Type = URLProtocolTestTransport.self
    ) -> BackendAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [protocolClass]
        let session = URLSession(configuration: configuration)
        return BackendAPIClient(
            configuration: APIConfiguration(baseURL: URL(string: "http://127.0.0.1:8080")!),
            session: session,
            authStore: authStore
        )
    }
}

private final class ContractTestAuthSessionStore: AuthSessionStoreProtocol {
    private(set) var currentSession: AuthSession?
    private(set) var clearCallCount = 0

    init(
        currentSession: AuthSession? = AuthSession(
            displayName: "테스터",
            accessToken: "real-access-token",
            refreshToken: "real-refresh-token"
        )
    ) {
        self.currentSession = currentSession
    }

    var isAuthenticated: Bool { currentSession?.profileSetupRequired == false }
    var accessToken: String? { isAuthenticated ? currentSession?.accessToken : nil }

    func restore() {}

    @discardableResult
    func saveSession(accessToken: String, refreshToken: String?, displayName: String?) -> Bool {
        currentSession = AuthSession(displayName: displayName ?? "테스터", accessToken: accessToken, refreshToken: refreshToken)
        return true
    }

    func replaceTokens(replacing expectedAccessToken: String, accessToken: String, refreshToken: String) -> Bool {
        guard let currentSession,
              currentSession.accessToken == expectedAccessToken,
              !accessToken.isEmpty,
              !refreshToken.isEmpty else {
            return false
        }
        self.currentSession = AuthSession(
            displayName: currentSession.displayName,
            accessToken: accessToken,
            refreshToken: refreshToken,
            memberId: currentSession.memberId,
            nickname: currentSession.nickname,
            profileImageUrl: currentSession.profileImageUrl,
            profileSetupRequired: currentSession.profileSetupRequired
        )
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
            profileImageUrl: member.profileImageUrl,
            profileSetupRequired: member.profileSetupRequired ?? false
        )
    }

    func clear() {
        clearCallCount += 1
        currentSession = nil
    }

    func setCurrentSession(_ session: AuthSession) {
        currentSession = session
    }
}

private actor RefreshOperationCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}

private actor RefreshOperationGate {
    private var started = false
    private var startedContinuations: [CheckedContinuation<Void, Never>] = []
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func waitForRelease() async {
        started = true
        startedContinuations.forEach { $0.resume() }
        startedContinuations = []
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func waitUntilStarted() async {
        guard !started else {
            return
        }
        await withCheckedContinuation { continuation in
            startedContinuations.append(continuation)
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

private final class URLProtocolTestTransport: URLProtocol {
    static var responseData = Data()
    static var statusCode = 200
    static var queuedResponses: [(statusCode: Int, data: Data)] = []
    static var queuedErrors: [Error?] = []
    static var requests: [URLRequest] = []
    static var lastRequest: URLRequest?
    static var lastRequestBody: Data?
    static var requestObserver: ((URLRequest) -> Void)?
    private static let lock = NSLock()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let requestBody = request.httpBody ?? request.httpBodyStream?.readAllData()
        let stub: (statusCode: Int, data: Data)
        let queuedError: Error?

        Self.lock.lock()
        Self.lastRequest = request
        Self.lastRequestBody = requestBody
        Self.requests.append(request)
        if Self.queuedResponses.isEmpty {
            stub = (statusCode: Self.statusCode, data: Self.responseData)
        } else {
            stub = Self.queuedResponses.removeFirst()
        }
        if Self.queuedErrors.isEmpty {
            queuedError = nil
        } else {
            queuedError = Self.queuedErrors.removeFirst()
        }
        Self.lock.unlock()
        Self.requestObserver?(request)

        if let queuedError {
            client?.urlProtocol(self, didFailWithError: queuedError)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: stub.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class ConcurrentRefreshURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var pendingRejectedRequests: [ConcurrentRefreshURLProtocol] = []
    private static var rejectedRequestCount = 0
    private static var reissueRequestCount = 0
    private static var retriedRequestCount = 0

    static func reset() {
        lock.lock()
        pendingRejectedRequests = []
        rejectedRequestCount = 0
        reissueRequestCount = 0
        retriedRequestCount = 0
        lock.unlock()
    }

    static func requestCounts() -> (rejected: Int, reissue: Int, retried: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (rejectedRequestCount, reissueRequestCount, retriedRequestCount)
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let path = request.url?.path
        let authorization = request.value(forHTTPHeaderField: "Authorization")

        if path == "/api/v1/members/me", authorization == "Bearer real-access-token" {
            Self.lock.lock()
            Self.rejectedRequestCount += 1
            Self.pendingRejectedRequests.append(self)
            guard Self.pendingRejectedRequests.count == 2 else {
                Self.lock.unlock()
                return
            }
            let pendingRequests = Self.pendingRejectedRequests
            Self.pendingRejectedRequests = []
            Self.lock.unlock()
            pendingRequests.forEach {
                $0.respond(statusCode: 401, data: Self.unauthorizedData)
            }
            return
        }

        if path == "/api/v1/auth/reissue" {
            Self.lock.lock()
            Self.reissueRequestCount += 1
            Self.lock.unlock()
            respond(statusCode: 200, data: Self.tokenData)
            return
        }

        if path == "/api/v1/members/me", authorization == "Bearer rotated-access" {
            Self.lock.lock()
            Self.retriedRequestCount += 1
            Self.lock.unlock()
            respond(statusCode: 200, data: Self.memberData)
            return
        }

        respond(statusCode: 500, data: Data())
    }

    override func stopLoading() {
        Self.lock.lock()
        Self.pendingRejectedRequests.removeAll { $0 === self }
        Self.lock.unlock()
    }

    private func respond(statusCode: Int, data: Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    private static let unauthorizedData = """
    {
      "success": false,
      "data": null,
      "error": { "code": "AUTH_001", "message": "auth.unauthorized", "detail": null }
    }
    """.data(using: .utf8)!

    private static let tokenData = """
    {
      "success": true,
      "data": { "accessToken": "rotated-access", "refreshToken": "rotated-refresh" },
      "error": null
    }
    """.data(using: .utf8)!

    private static let memberData = """
    {
      "success": true,
      "data": {
        "id": 7,
        "nickname": "동시 사용자",
        "displayName": "동시 사용자",
        "profileImageId": null,
        "profileImageUrl": null,
        "profileSetupRequired": false
      },
      "error": null
    }
    """.data(using: .utf8)!
}

private extension InputStream {
    func readAllData() -> Data {
        open()
        defer {
            close()
        }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }

        while hasBytesAvailable {
            let bytesRead = read(buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                data.append(buffer, count: bytesRead)
            } else {
                break
            }
        }

        return data
    }
}
