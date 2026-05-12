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
              "visibility": "VISIBLE",
              "ratingSummary": { "averageRating": 4.7, "reviewCount": 18 },
              "tags": [{ "id": 1, "name": "고소함" }],
              "favoriteCount": 9,
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

    var isAuthenticated: Bool { currentSession?.profileSetupRequired == false }
    var accessToken: String? { isAuthenticated ? currentSession?.accessToken : nil }

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
            profileImageUrl: member.profileImageUrl,
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
    static var lastRequestBody: Data?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lastRequest = request
        Self.lastRequestBody = request.httpBody ?? request.httpBodyStream?.readAllData()
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
